import { db, admin } from '../database/index.js';
import { NotFoundError, ValidationError, ForbiddenError } from '../errors/index.js';
import { paginate } from '../utils/paginate.js';
import { fcmService } from './fcmService.js';

class StationCleaningService {

  _resolveStationId(requestedStationId, user) {
    const role = (user?.role || '').toUpperCase();
    if (user?.stationId && role === 'RAILWAY_SUPERVISOR') {
      return user.stationId;
    }
    return requestedStationId;
  }

  _resolveAreaId(requestedAreaId, user) {
    const role = (user?.role || '').toUpperCase();
    return requestedAreaId;
  }

  _isMasterOrAdmin(user) {
    const role = (user?.role || '').toUpperCase();
    return ['SUPER_ADMIN', 'COMPANY_MASTER', 'RAILWAY_MASTER', 'ADMIN'].includes(role);
  }

  _scopeByContract(query, user, stationField = 'stationId') {
    if (this._isMasterOrAdmin(user)) return query;
    const userStations = user?.stations;
    if (userStations && Array.isArray(userStations) && userStations.length > 0) {
      return query.where(stationField, 'in', userStations);
    }
    return query;
  }

  _scopeByDivision(query, user, divisionField = 'division') {
    const role = (user?.role || '').toUpperCase();
    if (this._isMasterOrAdmin(user)) return query;
    if (user?.division) {
      return query.where(divisionField, '==', user.division);
    }
    return query;
  }

  _scopeByArea(query, user, field = 'areaId') {
    return query;
  }

  _scopeByEntity(query, user, entityField = 'entityId') {
    if (user?.userType === 'contractor' && user?.entityId) {
      return query.where(entityField, '==', user.entityId);
    }
    return query;
  }

  _scopeByContractId(query, user, contractField = 'contractId') {
    if (this._isMasterOrAdmin(user)) return query;
    if (user?.contractId) {
      return query.where(contractField, '==', user.contractId);
    }
    return query;
  }

  _verifyStationAccess(task, user) {
    const role = (user?.role || '').toUpperCase();
    const userStationId = user?.stationId;
    if (userStationId && task.stationId && task.stationId !== userStationId) {
      throw new ForbiddenError('You can only access tasks in your assigned station');
    }
  }

  _calcTenderedArea(basicAreaSqFt, frequencyType, frequencyTimes) {
    const area = basicAreaSqFt || 0;
    const times = frequencyTimes || 1;
    switch ((frequencyType || 'daily').toLowerCase()) {
      case 'monthly': return Math.round((area * times) / 30);
      case 'weekly': return Math.round((area * times) / 7);
      case 'daily':
      default: return Math.round(area * times);
    }
  }

  // ─── Station Areas ──────────────────────────────────────────────────────────
  async createStationArea(body) {
    const { stationId, areaName } = body;
    if (!stationId || !areaName) throw new ValidationError('stationId and areaName are required');
    const stationDoc = await db.collection('stations').doc(stationId).get();
    if (!stationDoc.exists) throw new NotFoundError('Station not found');
    const ref = db.collection('stationAreas').doc();

    const mainArea = body.mainArea || '';
    const basicAreaSqFt = parseFloat(body.basicAreaSqFt) || 0;
    const frequencyType = body.frequencyType || 'daily';
    const boqTimesPerPeriod = parseInt(body.boqTimesPerPeriod ?? body.frequencyTimes) || 1;
    const tenderedAreaPerDay = body.tenderedAreaPerDay !== undefined
      ? parseFloat(body.tenderedAreaPerDay)
      : this._calcTenderedArea(basicAreaSqFt, frequencyType, boqTimesPerPeriod);

    const data = {
      uid: ref.id, stationId,
      stationName: stationDoc.data().stationName || '',
      areaName, name: areaName, areaType: body.areaType || 'Other',
      mainArea,
      basicAreaSqFt,
      frequencyType,
      boqTimesPerPeriod,
      tenderedAreaPerDay,
      cleaningFrequency: body.cleaningFrequency || 'daily',
      priority: body.priority || 3,
      status: 'active',
      platformId: body.platformId || null,
      createdAt: new Date().toISOString(), updatedAt: new Date().toISOString()
    };
    await ref.set(data);
    return { message: 'Station area created', uid: ref.id, data };
  }

  async updateStationArea(uid, body) {
    const ref = db.collection('stationAreas').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Station area not found');
    const existing = doc.data();
    const updates = { ...body, updatedAt: new Date().toISOString() };
    delete updates.uid;

    const basicAreaSqFt = body.basicAreaSqFt !== undefined ? parseFloat(body.basicAreaSqFt) : (existing.basicAreaSqFt || 0);
    const frequencyType = body.frequencyType || existing.frequencyType || 'daily';
    const boqTimesPerPeriod = body.boqTimesPerPeriod !== undefined ? parseInt(body.boqTimesPerPeriod) : (existing.boqTimesPerPeriod || 1);
    if (body.basicAreaSqFt !== undefined || body.frequencyType !== undefined || body.boqTimesPerPeriod !== undefined) {
      updates.tenderedAreaPerDay = this._calcTenderedArea(basicAreaSqFt, frequencyType, boqTimesPerPeriod);
    }

    await ref.update(updates);
    return { message: 'Station area updated', uid };
  }

  async deleteStationArea(uid) {
    const ref = db.collection('stationAreas').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Station area not found');
    await ref.update({ status: 'inactive', deletedAt: new Date().toISOString(), updatedAt: new Date().toISOString() });
    return { message: 'Station area deleted', uid };
  }

  async listStationAreas(stationId, user) {
    if (!stationId) throw new ValidationError('stationId is required');
    const snapshot = await db.collection('stationAreas')
      .where('stationId', '==', stationId)
      .where('status', '==', 'active').get();
    const areas = snapshot.docs.map(d => ({ id: d.id, ...d.data() }));
    areas.sort((a, b) => (a.areaName || '').localeCompare(b.areaName || ''));
    return { count: areas.length, areas };
  }

  async getStationArea(uid) {
    const doc = await db.collection('stationAreas').doc(uid).get();
    if (!doc.exists) throw new NotFoundError('Station area not found');
    return { id: doc.id, ...doc.data() };
  }

  async getStationAreaSummary(stationId) {
    if (!stationId) throw new ValidationError('stationId is required');
    const snapshot = await db.collection('stationAreas')
      .where('stationId', '==', stationId)
      .where('status', '==', 'active').get();
    const areas = snapshot.docs.map(d => ({ id: d.id, ...d.data() }));

    const grouped = {};
    let totalBasicArea = 0;
    let totalTenderedArea = 0;

    for (const area of areas) {
      const main = area.mainArea || 'Uncategorized';
      if (!grouped[main]) grouped[main] = [];
      grouped[main].push(area);
      totalBasicArea += (area.basicAreaSqFt || 0);
      totalTenderedArea += (area.tenderedAreaPerDay || 0);
    }

    return {
      count: areas.length,
      grouped,
      totals: {
        totalBasicArea: Math.round(totalBasicArea),
        totalTenderedArea: Math.round(totalTenderedArea)
      }
    };
  }

  // ─── Station Zones ──────────────────────────────────────────────────────────
  async createStationZone(body) {
    const { stationId } = body;
    const zoneName = body.zoneName || body.name;
    if (!stationId || !zoneName) throw new ValidationError('stationId and zoneName are required');
    const ref = db.collection('stationZones').doc();
    const data = {
      uid: ref.id, stationId, areaId: body.areaId || null,
      zoneName, name: zoneName, zoneType: body.zoneType || 'Other',
      description: body.description || '',
      status: 'active',
      createdAt: new Date().toISOString(), updatedAt: new Date().toISOString()
    };
    await ref.set(data);
    return { message: 'Station zone created', uid: ref.id, data };
  }

  async listStationZones(stationId, areaId, user) {
    if (!stationId) throw new ValidationError('stationId is required');
    let q = db.collection('stationZones').where('stationId', '==', stationId).where('status', '==', 'active');
    if (areaId) q = q.where('areaId', '==', areaId);
    const snapshot = await q.get();
    let zones = snapshot.docs.map(d => {
      const data = d.data();
      const zName = data.zoneName || data.name || '';
      return {
        id: d.id,
        uid: d.id,
        ...data,
        name: zName,
        zoneName: zName
      };
    });

    if (zones.length === 0 && areaId) {
      const areaDoc = await db.collection('stationAreas').doc(areaId).get();
      if (areaDoc.exists && (areaDoc.data().areaName || areaDoc.data().name || '').toLowerCase().includes('platform')) {
        zones = [
          { id: `${areaId}-toilet`, uid: `${areaId}-toilet`, stationId, areaId, name: 'Toilet', zoneName: 'Toilet', status: 'active', createdAt: new Date().toISOString(), updatedAt: new Date().toISOString() },
          { id: `${areaId}-waiting`, uid: `${areaId}-waiting`, stationId, areaId, name: 'Waiting Room', zoneName: 'Waiting Room', status: 'active', createdAt: new Date().toISOString(), updatedAt: new Date().toISOString() },
          { id: `${areaId}-concourse`, uid: `${areaId}-concourse`, stationId, areaId, name: 'Concourse', zoneName: 'Concourse', status: 'active', createdAt: new Date().toISOString(), updatedAt: new Date().toISOString() },
          { id: `${areaId}-track`, uid: `${areaId}-track`, stationId, areaId, name: 'Track Side', zoneName: 'Track Side', status: 'active', createdAt: new Date().toISOString(), updatedAt: new Date().toISOString() }
        ];
      }
    }

    return { count: zones.length, zones };
  }

  async getStationZone(uid) {
    const doc = await db.collection('stationZones').doc(uid).get();
    if (!doc.exists) throw new NotFoundError('Station zone not found');
    const data = doc.data();
    const zName = data.zoneName || data.name || '';
    return {
      id: doc.id,
      uid: doc.id,
      ...data,
      name: zName,
      zoneName: zName
    };
  }

  async updateStationZone(uid, body) {
    const ref = db.collection('stationZones').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Station zone not found');
    const zoneName = body.zoneName || body.name;
    const updates = { ...body, updatedAt: new Date().toISOString() };
    if (zoneName) {
      updates.zoneName = zoneName;
      updates.name = zoneName;
    }
    delete updates.uid;
    await ref.update(updates);
    return { message: 'Station zone updated', uid };
  }

  async deleteStationZone(uid) {
    const ref = db.collection('stationZones').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Station zone not found');
    await ref.update({ status: 'inactive', deletedAt: new Date().toISOString(), updatedAt: new Date().toISOString() });
    return { message: 'Station zone deleted', uid };
  }

  // ─── Contractor Mappings ────────────────────────────────────────────────────
  async mapContractor(body) {
    const { stationId, contractorId } = body;
    if (!stationId || !contractorId) throw new ValidationError('stationId and contractorId are required');
    const ref = db.collection('stationContractorMappings').doc();
    const data = {
      uid: ref.id, stationId, contractorId,
      contractId: body.contractId || null,
      status: 'active',
      createdAt: new Date().toISOString(), updatedAt: new Date().toISOString()
    };
    await ref.set(data);
    return { message: 'Contractor mapped', uid: ref.id, data };
  }

  async listContractorMappings(stationId, user) {
    if (!stationId) throw new ValidationError('stationId is required');
    const snapshot = await db.collection('stationContractorMappings')
      .where('stationId', '==', stationId).where('status', '==', 'active').get();
    const mappings = snapshot.docs.map(d => ({ id: d.id, ...d.data() }));
    return { count: mappings.length, mappings };
  }

  async getContractorMapping(uid) {
    const doc = await db.collection('stationContractorMappings').doc(uid).get();
    if (!doc.exists) throw new NotFoundError('Contractor mapping not found');
    return { id: doc.id, ...doc.data() };
  }

  async updateContractorMapping(uid, body) {
    const ref = db.collection('stationContractorMappings').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Contractor mapping not found');
    await ref.update({ ...body, updatedAt: new Date().toISOString() });
    return { message: 'Contractor mapping updated', uid };
  }

  async deleteContractorMapping(uid) {
    const ref = db.collection('stationContractorMappings').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Contractor mapping not found');
    await ref.update({ status: 'inactive', deletedAt: new Date().toISOString(), updatedAt: new Date().toISOString() });
    return { message: 'Contractor mapping deleted', uid };
  }

  // ─── Schedules ──────────────────────────────────────────────────────────────
  async createSchedule(body) {
    const { stationId } = body;
    if (!stationId) throw new ValidationError('stationId is required');
    const ref = db.collection('stationSchedules').doc();
    const data = {
      uid: ref.id,
      stationId,
      scheduleName: body.scheduleName || 'Schedule',
      areaId: body.areaId || '',
      zoneId: body.zoneId || '',
      frequency: body.frequency || 'daily',
      shift: body.shift || body.shiftType || 'morning',
      shiftType: body.shift || body.shiftType || 'morning',
      entityId: body.entityId || '',
      entityName: body.entityName || '',
      supervisorId: body.supervisorId || '',
      supervisorName: body.supervisorName || '',
      startTime: body.startTime || '06:00',
      endTime: body.endTime || '14:00',
      daysOfWeek: body.daysOfWeek || [],
      estimatedHours: body.estimatedHours || null,
      effectiveFrom: body.effectiveFrom || null,
      effectiveTo: body.effectiveTo || null,
      status: 'active',
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    };
    await ref.set(data);
    return { message: 'Schedule created', uid: ref.id, data };
  }

  async listSchedules(stationId, user) {
    if (!stationId) throw new ValidationError('stationId is required');
    const role = (user?.role || '').toUpperCase();
    if (!this._isMasterOrAdmin(user)) {
      const userStations = user?.stations || (user?.stationId ? [user.stationId] : []);
      if (userStations.length > 0 && !userStations.includes(stationId)) {
        throw new ForbiddenError('You can only access schedules for your assigned stations');
      }
    }
    const snapshot = await db.collection('stationSchedules')
      .where('stationId', '==', stationId).where('status', '==', 'active').get();
    const schedules = snapshot.docs.map(d => ({ id: d.id, ...d.data() }));
    return { count: schedules.length, schedules };
  }

  async getSchedule(uid) {
    const doc = await db.collection('stationSchedules').doc(uid).get();
    if (!doc.exists) throw new NotFoundError('Schedule not found');
    return { id: doc.id, ...doc.data() };
  }

  async updateSchedule(uid, body) {
    const ref = db.collection('stationSchedules').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Schedule not found');
    await ref.update({ ...body, updatedAt: new Date().toISOString() });
    return { message: 'Schedule updated', uid };
  }

  async deleteSchedule(uid) {
    const ref = db.collection('stationSchedules').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Schedule not found');
    await ref.update({ status: 'inactive', deletedAt: new Date().toISOString(), updatedAt: new Date().toISOString() });
    return { message: 'Schedule deleted', uid };
  }

  async generateTasksFromSchedule(data) {
    const { scheduleId, date, generateForDays } = data;
    if (!scheduleId) throw new ValidationError('scheduleId is required');
    const scheduleDoc = await db.collection('stationSchedules').doc(scheduleId).get();
    if (!scheduleDoc.exists) throw new NotFoundError('Schedule not found');
    const schedule = scheduleDoc.data();

    const targetDate = date || new Date().toISOString().split('T')[0];
    const startTime = schedule.startTime || '06:00';
    const endTime = schedule.endTime || '14:00';
    const frequency = schedule.frequency || 'daily';

    let areaName = schedule.areaName || '';
    if (!areaName && schedule.areaId) {
      try {
        const areaDoc = await db.collection('stationAreas').doc(schedule.areaId).get();
        if (areaDoc.exists) {
          areaName = areaDoc.data().name || areaDoc.data().areaName || '';
        }
      } catch (_) {}
    }
    schedule.areaName = areaName;

    const taskTimes = this._calculateTaskTimes(frequency, startTime, endTime);

    const numDays = Math.max(1, generateForDays || 1);
    const daysToGenerate = [];
    const start = new Date(targetDate + 'T00:00:00');
    for (let i = 0; i < numDays; i++) {
      const d = new Date(start);
      d.setDate(d.getDate() + i);
      daysToGenerate.push(d.toISOString().split('T')[0]);
    }

    const existingKeys = new Set();
    if (daysToGenerate.length > 0) {
      try {
        const existingSnap = await db.collection('cleaningTasks')
          .where('scheduleId', '==', scheduleId)
          .where('date', '>=', daysToGenerate[0])
          .where('date', '<=', daysToGenerate[daysToGenerate.length - 1])
          .select('date', 'scheduledTime')
          .get();
        existingSnap.forEach(doc => {
          const d = doc.data();
          existingKeys.add(`${d.date}|${d.scheduledTime}`);
        });
      } catch (indexErr) {
        const allSnap = await db.collection('cleaningTasks')
          .where('scheduleId', '==', scheduleId)
          .select('date', 'scheduledTime')
          .get();
        allSnap.forEach(doc => {
          const d = doc.data();
          if (d.date >= daysToGenerate[0] && d.date <= daysToGenerate[daysToGenerate.length - 1]) {
            existingKeys.add(`${d.date}|${d.scheduledTime}`);
          }
        });
      }
    }

    let totalCount = 0;
    const allTaskIds = [];

    for (const dayStr of daysToGenerate) {
      const batch = db.batch();
      let batchCount = 0;

      for (const timeSlot of taskTimes) {
        const key = `${dayStr}|${timeSlot}`;
        if (existingKeys.has(key)) continue;

        const taskRef = db.collection('cleaningTasks').doc();
        const task = {
          uid: taskRef.id,
          stationId: schedule.stationId,
          stationName: schedule.stationName || '',
          areaId: schedule.areaId || '',
          areaName: schedule.areaName || '',
          zoneId: schedule.zoneId || '',
          shift: schedule.shift || schedule.shiftType || 'morning',
          frequency,
          date: dayStr,
          scheduledDate: dayStr,
          scheduledTime: timeSlot,
          supervisorId: schedule.supervisorId || null,
          supervisorName: schedule.supervisorName || '',
          scheduleId,
          entityId: schedule.entityId || '',
          entityName: schedule.entityName || '',
          activityType: 'station_cleaning',
          status: 'pending',
          workerId: null,
          workerName: null,
          priority: 3,
          startedAt: null, completedAt: null,
          approvedAt: null, rejectedAt: null,
          beforePhoto: null, afterPhoto: null,
          gpsLat: null, gpsLng: null,
          supervisorNotes: null, rejectionReason: null,
          resubmittedAt: null,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: new Date().toISOString()
        };
        batch.set(taskRef, task);
        allTaskIds.push(taskRef.id);
        batchCount++;
      }

      if (batchCount > 0) {
        await batch.commit();
        totalCount += batchCount;
      }
    }

    return { message: `Generated ${totalCount} tasks for ${daysToGenerate.length} day(s)`, count: totalCount, taskIds: allTaskIds };
  }

  _calculateTaskTimes(frequency, startTime, endTime) {
    const [startH, startM] = (startTime || '06:00').split(':').map(Number);
    const [endH, endM] = (endTime || '14:00').split(':').map(Number);
    const startMinutes = startH * 60 + (startM || 0);
    const endMinutes = endH * 60 + (endM || 0);
    const durationMinutes = endMinutes - startMinutes;

    if (durationMinutes <= 0) return [startTime || '08:00'];

    if (frequency === 'hourly_mopping') {
      const slots = [];
      for (let m = 300; m < 1380; m += 60) {
        slots.push(`${String(Math.floor(m / 60)).padStart(2, '0')}:${String(m % 60).padStart(2, '0')}`);
      }
      return slots;
    }

    const intervalMap = {
      every_15_min: 15, every15min: 15, every_15min: 15,
      every_30_min: 30, every30min: 30, every_30min: 30,
      hourly: 60, every_1_hour: 60,
      every_2_hour: 120, every2h: 120, every_2h: 120,
      every_3_hour: 180,
      every_4_hour: 240, every4h: 240, every_4h: 240,
      every_6_hour: 360, every6h: 360, every_6h: 360,
    };

    const interval = intervalMap[frequency];
    if (interval) {
      const slots = [];
      for (let m = startMinutes; m < endMinutes; m += interval) {
        slots.push(`${String(Math.floor(m / 60)).padStart(2, '0')}:${String(m % 60).padStart(2, '0')}`);
      }
      return slots;
    }

    switch (frequency) {
      case 'twice_daily':
      case 'twice_daily_shift':
      case 'two_times_daily': {
        const mid1 = startMinutes + Math.floor(durationMinutes * 0.33);
        const mid2 = startMinutes + Math.floor(durationMinutes * 0.66);
        return [
          `${String(Math.floor(mid1 / 60)).padStart(2, '0')}:${String(mid1 % 60).padStart(2, '0')}`,
          `${String(Math.floor(mid2 / 60)).padStart(2, '0')}:${String(mid2 % 60).padStart(2, '0')}`
        ];
      }
      case 'three_times_daily': {
        const slots = [];
        for (let i = 1; i <= 3; i++) {
          const m = startMinutes + Math.floor(durationMinutes * i / 4);
          slots.push(`${String(Math.floor(m / 60)).padStart(2, '0')}:${String(m % 60).padStart(2, '0')}`);
        }
        return slots;
      }
      case 'four_times_daily': {
        const slots = [];
        for (let i = 1; i <= 4; i++) {
          const m = startMinutes + Math.floor(durationMinutes * i / 5);
          slots.push(`${String(Math.floor(m / 60)).padStart(2, '0')}:${String(m % 60).padStart(2, '0')}`);
        }
        return slots;
      }
      case 'six_times_daily':
      case 'once_every_4h': {
        const allSlots = [];
        for (let m = 0; m < 1440; m += 240) {
          if (m >= startMinutes && m < endMinutes) {
            allSlots.push(`${String(Math.floor(m / 60)).padStart(2, '0')}:${String(m % 60).padStart(2, '0')}`);
          }
        }
        return allSlots.length > 0 ? allSlots : [startTime || '08:00'];
      }
      case 'once_daily':
      case 'once_per_day':
      case 'daily':
        return [startTime || '08:00'];
      case 'twice_weekly':
      case 'twice_monthly':
      case 'once_weekly':
      case 'once_monthly':
      case 'weekly':
      case 'monthly':
        return [startTime || '08:00'];
      default:
        return [startTime || '08:00'];
    }
  }

  _shiftDefaultTime(shift) {
    const s = (shift || '').toLowerCase();
    if (s.includes('morning')) return '08:00';
    if (s.includes('afternoon')) return '12:00';
    if (s.includes('evening')) return '16:00';
    if (s.includes('night')) return '20:00';
    return '08:00';
  }

  async _createPlatformTasks(platforms, runData, user) {
    const batch = admin.firestore().batch();
    const tasks = [];
    const now = new Date().toISOString();
    const scheduledTime = this._shiftDefaultTime(runData.shift);
    for (const plat of (platforms || [])) {
      if (!runData.supervisorId && !user?.uid) continue;
      const taskRef = db.collection('cleaningTasks').doc();
      const areaId = plat.areaId || `platform_${plat.platformNumber || 'unknown'}_${runData.stationId}`;
      const areaName = plat.areaName || (plat.platformNumber ? `Platform ${plat.platformNumber}` : 'Station Area');
      const taskData = {
        uid: taskRef.id,
        stationId: runData.stationId,
        stationName: runData.stationName || '',
        platformId: plat.platformNumber || '',
        areaId,
        areaName,
        workerId: runData.supervisorId || (user && user.uid) || null,
        workerName: runData.supervisorName || '',
        supervisorId: runData.supervisorId || (user && user.uid) || null,
        activityType: 'station_cleaning',
        frequency: runData.frequency || 'daily',
        scheduledDate: runData.date || runData.runDate,
        scheduledTime,
        priority: 3,
        shift: runData.shift || 'morning',
        status: 'pending',
        runInstanceId: runData.runInstanceId || '',
        createdBy: user && user.uid,
        createdAt: now,
        updatedAt: now
      };
      batch.set(taskRef, taskData);
      tasks.push(taskData);
    }
    if (tasks.length > 0) await batch.commit();
    return tasks;
  }

  // ─── Station Runs ───────────────────────────────────────────────────────────
  async createStationRun(body, user) {
    const { stationId } = body;
    if (!stationId) throw new ValidationError('stationId is required');
    const ref = db.collection('stationRuns').doc();
    
    const runDate = body.date || body.runDate || new Date().toISOString().split('T')[0];
    const shiftType = body.shift || body.shiftType || 'morning';
    const runInstanceId = body.runInstanceId || ref.id;

    const data = {
      ...body,
      uid: ref.id,
      runInstanceId,
      stationId,
      stationName: body.stationName || '',
      date: runDate,
      runDate,
      shift: shiftType,
      shiftType: shiftType.toLowerCase(),
      platforms: body.platforms || [],
      supervisorId: body.supervisorId || (user && user.uid) || null,
      contractorId: body.contractorId || null,
      contractId: body.contractId || (user && user.contractId) || null,
      status: body.status || 'active',
      createdBy: user && user.uid,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    };
    await ref.set(data);

    const tasks = await this._createPlatformTasks(body.platforms, data, user);

    return { message: 'Station run created', uid: ref.id, data, tasksCreated: tasks.length };
  }

  async listStationRuns(query, user) {
    const { stationId } = query;
    let q = db.collection('stationRuns').limit(200);
    q = this._scopeByContract(q, user, 'stationId');
    q = this._scopeByContractId(q, user);
    if (stationId) q = q.where('stationId', '==', stationId);
    const snapshot = await q.get();
    const runs = snapshot.docs
      .filter(d => d.data().status !== 'deleted')
      .map(d => ({ id: d.id, ...d.data() }));
    return { count: runs.length, runs };
  }

  async updateStationRun(runId, body) {
    const ref = db.collection('stationRuns').doc(runId);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Station run not found');
    
    const runDate = body.date || body.runDate || new Date().toISOString().split('T')[0];
    const shiftType = body.shift || body.shiftType || 'morning';

    await ref.update({
      ...body,
      date: runDate,
      runDate,
      shift: shiftType,
      shiftType: shiftType.toLowerCase(),
      updatedAt: new Date().toISOString()
    });
    return { message: 'Station run updated', runId };
  }

  async getMyStationRuns(userId) {
    const supervisorSnap = await db.collection('stationRuns')
      .where('supervisorId', '==', userId).limit(100).get();
    
    const runs = [];
    supervisorSnap.forEach(d => {
      const data = d.data();
      if (data.status !== 'deleted') {
        runs.push({ id: d.id, ...data });
      }
    });
    return { count: runs.length, runs };
  }

  async deleteStationRun(runId) {
    const ref = db.collection('stationRuns').doc(runId);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Station run not found');
    await ref.update({ status: 'deleted', deletedAt: new Date().toISOString(), updatedAt: new Date().toISOString() });
    return { message: 'Station run deleted', runId };
  }

  async getWorkerStationRuns(workerId, user) {
    let q = db.collection('stationRuns').limit(300);
    q = this._scopeByContractId(q, user);
    const snapshot = await q.get();
    const runs = [];
    snapshot.forEach(d => {
      const runData = d.data();
      if (runData.status === 'deleted') return;
      if (runData.platforms && Array.isArray(runData.platforms)) {
        const workerPlatforms = runData.platforms.filter(p => p.janitorId === workerId);
        if (workerPlatforms.length > 0) {
          runs.push({ id: d.id, ...runData, platforms: workerPlatforms });
        }
      }
    });
    return { count: runs.length, runs };
  }

  async getSupervisorStationRuns(supervisorId, user) {
    let q = db.collection('stationRuns')
      .where('supervisorId', '==', supervisorId).limit(100);
    q = this._scopeByContractId(q, user);
    const snapshot = await q.get();
    const runs = snapshot.docs
      .filter(d => d.data().status !== 'deleted')
      .map(d => ({ id: d.id, ...d.data() }));
    return { count: runs.length, runs };
  }

  async completePlatform(runId, body, user) {
    const ref = db.collection('stationRuns').doc(runId);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Station run not found');

    const runData = doc.data();
    if (runData.status === 'deleted') throw new NotFoundError('Station run not found');

    const platformNumber = body.platformNumber;
    const photoUrl = body.photoUrl;

    if (!platformNumber) {
      throw new Error('platformNumber is required in the body');
    }

    const platforms = runData.platforms || [];
    const platformIndex = platforms.findIndex(p => p.platformNumber === platformNumber);
    if (platformIndex === -1) {
      throw new NotFoundError('Platform not found in this run');
    }

    if (platforms[platformIndex].status === 'Completed') {
       throw new Error('Platform is already completed');
    }

    platforms[platformIndex].status = 'Completed';
    platforms[platformIndex].completedAt = new Date().toISOString();
    platforms[platformIndex].completedBy = user.uid;
    if (photoUrl) {
      platforms[platformIndex].photoUrl = photoUrl;
    }

    const allCompleted = platforms.every(p => p.status === 'Completed');
    const newStatus = allCompleted ? 'Completed' : 'In Progress';

    await ref.update({
      platforms: platforms,
      status: newStatus,
      updatedAt: new Date().toISOString()
    });

    return { message: `Platform ${platformNumber} marked complete`, runId, platformNumber: platformNumber };
  }

  // ─── Station Tasks ──────────────────────────────────────────────────────────
  // Tasks are primarily managed via taskManagementService (used by tasksV2 routes).
  // These methods provide station-task CRUD for admin use cases.

  async submitStationTask(body, user) {
    const { stationId, areaId, workerId } = body;
    const userStationId = user?.stationId;
    if (userStationId && stationId && stationId !== userStationId) {
      throw new ForbiddenError('You can only create tasks in your assigned station');
    }
    const ref = db.collection('cleaningTasks').doc();
    const data = {
      uid: ref.id, stationId, areaId: areaId || null,
      workerId: workerId || null,
      taskType: body.taskType || 'cleaning',
      status: 'pending',
      beforePhoto: body.beforePhoto || null,
      afterPhoto: body.afterPhoto || null,
      remarks: body.remarks || '',
      createdAt: new Date().toISOString(), updatedAt: new Date().toISOString()
    };
    await ref.set(data);
    return { message: 'Task created', uid: ref.id, data };
  }

  async getStationTask(taskId, user) {
    const doc = await db.collection('cleaningTasks').doc(taskId).get();
    if (!doc.exists) throw new NotFoundError('Station task not found');
    const task = doc.data();
    this._verifyStationAccess(task, user);
    return { id: doc.id, ...task };
  }

  async updateStationTask(taskId, body, user) {
    const ref = db.collection('cleaningTasks').doc(taskId);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Station task not found');
    this._verifyStationAccess(doc.data(), user);
    await ref.update({ ...body, updatedAt: new Date().toISOString() });
    return { message: 'Station task updated', taskId };
  }

  async deleteStationTask(taskId) {
    const ref = db.collection('cleaningTasks').doc(taskId);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Station task not found');
    await ref.delete();
    return { message: 'Station task deleted', taskId };
  }

  async listPendingStationTasks(runInstanceId, user) {
    const pendingStatuses = ['completed', 'resubmitted'];
    let allTasks = [];
    const userStationId = user?.stationId || null;
    for (const status of pendingStatuses) {
      let q = db.collection('cleaningTasks').where('status', '==', status).limit(200);
      if (runInstanceId) q = q.where('runInstanceId', '==', runInstanceId);
      if (userStationId) q = q.where('stationId', '==', userStationId);
      const snapshot = await q.get();
      snapshot.forEach(d => allTasks.push({ id: d.id, ...d.data() }));
    }
    return { count: allTasks.length, tasks: allTasks };
  }

  // ─── Area-Task Frequency Mapping (SRS #2) ──────────────────────────────────
  async createAreaTaskFrequency(body) {
    const { stationId, areaId, taskTypeId, frequencyId, shift } = body;
    if (!stationId || !areaId || !taskTypeId || !frequencyId) {
      throw new ValidationError('stationId, areaId, taskTypeId, and frequencyId are required');
    }
    const ref = db.collection('areaTaskFrequencies').doc();
    const data = {
      uid: ref.id, stationId, areaId, taskTypeId, frequencyId,
      shift: shift || null,
      isActive: true,
      createdAt: new Date().toISOString(), updatedAt: new Date().toISOString()
    };
    await ref.set(data);
    return { message: 'Area-task frequency mapping created', uid: ref.id, data };
  }

  async updateAreaTaskFrequency(uid, body) {
    const ref = db.collection('areaTaskFrequencies').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Area-task frequency mapping not found');
    await ref.update({ ...body, updatedAt: new Date().toISOString() });
    return { message: 'Area-task frequency mapping updated', uid };
  }

  async deleteAreaTaskFrequency(uid) {
    const ref = db.collection('areaTaskFrequencies').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Area-task frequency mapping not found');
    await ref.update({ isActive: false, updatedAt: new Date().toISOString() });
    return { message: 'Area-task frequency mapping deactivated', uid };
  }

  async listAreaTaskFrequencies(query) {
    const { stationId, areaId } = query;
    let q = db.collection('areaTaskFrequencies').where('isActive', '==', true);
    if (stationId) q = q.where('stationId', '==', stationId);
    if (areaId) q = q.where('areaId', '==', areaId);
    const snapshot = await q.limit(200).get();
    const mappings = snapshot.docs.map(d => ({ id: d.id, ...d.data() }));
    return { count: mappings.length, mappings };
  }

  // ─── Station Cleaning Forms ─────────────────────────────────────────────────
  async createStationCleaningForm(body, user) {
    const { stationId } = body;
    if (!stationId) throw new ValidationError('stationId is required');
    const ref = db.collection('stationCleaningForms').doc();
    const data = {
      uid: ref.id, stationId,
      entityId: body.entityId || null,
      contractId: body.contractId || null,
      platformId: body.platformId || null,
      shiftType: body.shiftType || 'morning',
      formDate: body.formDate || new Date().toISOString().split('T')[0],
      status: body.status || 'draft',
      createdBy: user && user.uid,
      createdByName: user && (user.fullName || user.name) || 'Unknown',
      submittedBy: user && user.uid,
      submittedByName: user && (user.fullName || user.name) || 'Unknown',
      createdAt: new Date().toISOString(), updatedAt: new Date().toISOString()
    };
    await ref.set(data);
    return { message: 'Cleaning form created', uid: ref.id, data };
  }

  async submitStationCleaningForm(uid, body, user) {
    const ref = db.collection('stationCleaningForms').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Cleaning form not found');
    const currentStatus = doc.data().status;
    const allowed = ['draft', 'rejected'];
    if (!allowed.includes(currentStatus)) {
      throw new ValidationError(`Only draft or rejected forms can be submitted. Current status: ${currentStatus}`);
    }
    await ref.update({
      ...body, status: 'submitted',
      submittedBy: user && user.uid,
      submittedByName: user && (user.fullName || user.name) || 'Unknown',
      submittedAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    });
    return { message: 'Cleaning form submitted', uid };
  }

  async approveStationCleaningForm(uid, user) {
    const ref = db.collection('stationCleaningForms').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Cleaning form not found');
    await ref.update({
      status: 'approved',
      approvedBy: user && user.uid,
      approvedAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    });
    return { message: 'Cleaning form approved', uid };
  }

  async rejectStationCleaningForm(uid, reason, user) {
    const ref = db.collection('stationCleaningForms').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Cleaning form not found');
    await ref.update({
      status: 'rejected',
      rejectionReason: reason || '',
      rejectedBy: user && user.uid,
      rejectedAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    });
    return { message: 'Cleaning form rejected', uid };
  }

  async scoreStationCleaningForm(uid, scoringData, totalScore, grade, user) {
    const ref = db.collection('stationCleaningForms').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Cleaning form not found');
    await ref.update({
      scoringData: scoringData || {},
      totalScore: totalScore || 0,
      grade: grade || 'D',
      scoredBy: user && user.uid,
      scoredAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    });
    return { message: 'Cleaning form scored', uid, totalScore, grade };
  }

  async lockStationCleaningForm(uid) {
    const ref = db.collection('stationCleaningForms').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Cleaning form not found');
    await ref.update({ locked: true, lockedAt: new Date().toISOString(), updatedAt: new Date().toISOString() });
    return { message: 'Cleaning form locked', uid };
  }

  async listStationCleaningForms(query, user) {
    const { stationId, status, startDate, endDate } = query;
    let q = db.collection('stationCleaningForms').limit(200);
    q = this._scopeByContract(q, user, 'stationId');
    q = this._scopeByContractId(q, user);
    if (stationId) q = q.where('stationId', '==', stationId);
    if (status) q = q.where('status', '==', status);
    const snapshot = await q.get();
    let forms = snapshot.docs.map(d => ({ id: d.id, ...d.data() }));
    if (startDate) forms = forms.filter(f => (f.formDate || '') >= startDate);
    if (endDate) forms = forms.filter(f => (f.formDate || '') <= endDate);
    return { count: forms.length, forms };
  }

  async getStationCleaningFormDetail(uid) {
    const doc = await db.collection('stationCleaningForms').doc(uid).get();
    if (!doc.exists) throw new NotFoundError('Cleaning form not found');
    return { id: doc.id, ...doc.data() };
  }

  // ─── Station Dashboard ──────────────────────────────────────────────────────
  async getStationDashboard(user) {
    const now = new Date();
    const today = now.toISOString().split('T')[0];
    const stationId = user && user.stationId;
    const userStations = user?.stations;

    let tasks = [];
    let tasksQuery = db.collection('cleaningTasks')
      .where('scheduledDate', '==', today).limit(500);
    if (stationId) {
      tasksQuery = tasksQuery.where('stationId', '==', stationId);
    } else if (userStations && Array.isArray(userStations) && userStations.length > 0) {
      tasksQuery = tasksQuery.where('stationId', 'in', userStations);
    }
    const snapshot = await tasksQuery.get();
    tasks = snapshot.docs.map(d => d.data());

    const total = tasks.length;
    const completed = tasks.filter(t => t.status === 'completed' || t.status === 'approved').length;
    const inProgress = tasks.filter(t => t.status === 'in_progress').length;
    const pending = tasks.filter(t => t.status === 'pending').length;
    const approved = tasks.filter(t => t.status === 'approved').length;
    const rejected = tasks.filter(t => t.status === 'rejected').length;
    const completionRate = total > 0 ? Math.round(completed / total * 100) : 0;
    const avgScore = total > 0 ? Math.round(tasks.reduce((s, t) => s + (t.score || 0), 0) / total) : 0;

    return {
      stationId: stationId || null,
      date: today,
      totalTasks: total, completedTasks: completed,
      pendingTasks: pending, inProgressTasks: inProgress,
      approvedTasks: approved, rejectedTasks: rejected,
      completionRate, averageScore: avgScore
    };
  }

  // ─── Pest Control ───────────────────────────────────────────────────────────
  async recordPestControl(body, user) {
    const { stationId, pestType } = body;
    if (!stationId) throw new ValidationError('stationId is required');
    const ref = db.collection('pestControlRecords').doc();
    const data = {
      uid: ref.id, stationId,
      stationName: body.stationName || '',
      pestType: pestType || 'General',
      entityId: body.entityId || null,
      contractId: body.contractId || (user && user.contractId) || null,
      frequency: body.frequency || 'monthly',
      conductedDate: body.conductedDate || new Date().toISOString().split('T')[0],
      area: body.area || '',
      zone: body.zone || '',
      severity: body.severity || 'LOW',
      treatmentMethod: body.treatmentMethod || '',
      chemicalsUsed: body.chemicalsUsed || [],
      status: 'pending',
      evidence: body.evidence || [],
      beforePhoto: body.beforePhoto || '',
      afterPhoto: body.afterPhoto || '',
      remarks: body.remarks || '',
      recordedBy: user && user.uid,
      createdAt: new Date().toISOString(), updatedAt: new Date().toISOString()
    };
    await ref.set(data);
    return { message: 'Pest control record created', uid: ref.id, data };
  }

  async listPestControl(stationId, query, user) {
    if (!stationId) throw new ValidationError('stationId is required');
    const snapshot = await db.collection('pestControlRecords')
      .where('stationId', '==', stationId).limit(200).get();
    const records = snapshot.docs.map(d => ({ id: d.id, ...d.data() }));
    return records;
  }

  async listAllPestControl(query, user) {
    const { stationId, status } = query || {};
    let q = db.collection('pestControlRecords').limit(300);
    q = this._scopeByContract(q, user, 'stationId');
    q = this._scopeByContractId(q, user);
    if (stationId) q = q.where('stationId', '==', stationId);
    if (status) q = q.where('status', '==', status);
    const snapshot = await q.get();
    return snapshot.docs.map(d => ({ id: d.id, ...d.data() }));
  }

  async reviewPestControl(uid, body, user) {
    const ref = db.collection('pestControlRecords').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Pest control record not found');
    const status = body.status || 'approved';
    await ref.update({
      status,
      reviewedBy: user && user.uid,
      reviewedAt: new Date().toISOString(),
      reviewNotes: body.notes || '',
      updatedAt: new Date().toISOString()
    });
    return { message: 'Pest control record reviewed', uid, status };
  }

  async pestControlReport(query, user) {
    const { stationId, startDate, endDate } = query || {};
    let q = db.collection('pestControlRecords').limit(300);
    q = this._scopeByContract(q, user, 'stationId');
    q = this._scopeByContractId(q, user);
    if (stationId) q = q.where('stationId', '==', stationId);
    const snapshot = await q.get();
    let records = snapshot.docs.map(d => ({ id: d.id, ...d.data() }));
    if (startDate) records = records.filter(r => (r.conductedDate || '') >= startDate);
    if (endDate) records = records.filter(r => (r.conductedDate || '') <= endDate);
    return { count: records.length, records };
  }

  // ─── Machine Deployment ─────────────────────────────────────────────────────
  async deployMachine(body, user) {
    const { stationId, machineType } = body;
    if (!stationId) throw new ValidationError('stationId is required');
    const ref = db.collection('machineDeployments').doc();
    const data = {
      uid: ref.id, stationId,
      machineType: machineType || 'General',
      entityId: body.entityId || null,
      contractId: body.contractId || (user && user.contractId) || null,
      deployedDate: body.deployedDate || new Date().toISOString().split('T')[0],
      status: 'deployed',
      quantity: body.quantity || 1,
      remarks: body.remarks || '',
      deployedBy: user && user.uid,
      createdAt: new Date().toISOString(), updatedAt: new Date().toISOString()
    };
    await ref.set(data);
    return { message: 'Machine deployed', uid: ref.id, data };
  }

  async listMachines(query, user) {
    const { stationId } = query || {};
    let q = db.collection('machineDeployments').limit(200);
    q = this._scopeByContract(q, user, 'stationId');
    q = this._scopeByContractId(q, user);
    if (stationId) q = q.where('stationId', '==', stationId);
    const snapshot = await q.get();
    return snapshot.docs.map(d => ({ id: d.id, ...d.data() }));
  }

  async returnMachine(uid, body, user) {
    const ref = db.collection('machineDeployments').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Machine deployment not found');
    await ref.update({
      status: 'returned',
      returnedDate: body.returnedDate || new Date().toISOString().split('T')[0],
      returnedBy: user && user.uid,
      returnRemarks: body.remarks || '',
      updatedAt: new Date().toISOString()
    });
    return { message: 'Machine returned', uid };
  }

  async maintenanceMachine(uid, body, user) {
    const ref = db.collection('machineDeployments').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Machine deployment not found');
    await ref.update({
      status: 'maintenance',
      maintenanceReason: body.reason || '',
      maintenanceBy: user && user.uid,
      updatedAt: new Date().toISOString()
    });
    return { message: 'Machine sent for maintenance', uid };
  }

  async machineReport(query, user) {
    const { stationId } = query || {};
    let q = db.collection('machineDeployments').limit(300);
    q = this._scopeByContract(q, user, 'stationId');
    q = this._scopeByContractId(q, user);
    if (stationId) q = q.where('stationId', '==', stationId);
    const snapshot = await q.get();
    const records = snapshot.docs.map(d => ({ id: d.id, ...d.data() }));
    return { count: records.length, records };
  }

  // ─── Garbage Disposal ───────────────────────────────────────────────────────
  async recordGarbageDisposal(body, user) {
    const { stationId } = body;
    if (!stationId) throw new ValidationError('stationId is required');
    const ref = db.collection('garbageDisposalRecords').doc();
    const data = {
      uid: ref.id, stationId,
      stationName: body.stationName || '',
      entityId: body.entityId || null,
      contractId: body.contractId || (user && user.contractId) || null,
      disposalDate: body.disposalDate || new Date().toISOString().split('T')[0],
      garbageType: body.garbageType || body.wasteType || 'General',
      wasteType: body.wasteType || '',
      quantityKg: body.quantityKg || 0,
      area: body.area || '',
      disposalMethod: body.disposalMethod || '',
      disposalAgency: body.disposalAgency || '',
      vehicleNumber: body.vehicleNumber || '',
      notes: body.notes || '',
      status: 'recorded',
      evidence: body.evidence || [],
      beforePhoto: body.beforePhoto || '',
      afterPhoto: body.afterPhoto || '',
      remarks: body.remarks || '',
      recordedBy: user && user.uid,
      createdAt: new Date().toISOString(), updatedAt: new Date().toISOString()
    };
    await ref.set(data);
    return { message: 'Garbage disposal recorded', uid: ref.id, data };
  }

  async listGarbageRecords(query, user) {
    const { stationId, startDate, endDate, status } = query || {};
    let q = db.collection('garbageDisposalRecords').limit(300);
    q = this._scopeByContract(q, user, 'stationId');
    q = this._scopeByContractId(q, user);
    if (stationId) q = q.where('stationId', '==', stationId);
    if (status) q = q.where('status', '==', status);
    const snapshot = await q.get();
    let records = snapshot.docs.map(d => ({ id: d.id, ...d.data() }));
    if (startDate) records = records.filter(r => (r.disposalDate || '') >= startDate);
    if (endDate) records = records.filter(r => (r.disposalDate || '') <= endDate);
    return records;
  }

  async approveGarbageRecord(uid, user) {
    const ref = db.collection('garbageDisposalRecords').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Garbage record not found');
    const record = doc.data();
    if (record.status !== 'recorded') throw new ValidationError(`Cannot approve. Current status: ${record.status}`);
    await ref.update({
      status: 'approved',
      reviewedBy: user && user.uid,
      reviewedAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    });
    return { message: 'Garbage record approved', uid };
  }

  async rejectGarbageRecord(uid, body, user) {
    const reason = body.reason || '';
    if (!reason.trim()) throw new ValidationError('Rejection reason is required');
    const ref = db.collection('garbageDisposalRecords').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Garbage record not found');
    const record = doc.data();
    if (record.status !== 'recorded') throw new ValidationError(`Cannot reject. Current status: ${record.status}`);
    await ref.update({
      status: 'rejected',
      reviewedBy: user && user.uid,
      reviewedAt: new Date().toISOString(),
      rejectionReason: reason,
      updatedAt: new Date().toISOString()
    });
    return { message: 'Garbage record rejected', uid };
  }

  async garbageReport(query, user) {
    const { stationId, startDate, endDate } = query || {};
    let q = db.collection('garbageDisposalRecords').limit(300);
    q = this._scopeByContract(q, user, 'stationId');
    q = this._scopeByContractId(q, user);
    if (stationId) q = q.where('stationId', '==', stationId);
    const snapshot = await q.get();
    let records = snapshot.docs.map(d => ({ id: d.id, ...d.data() }));
    if (startDate) records = records.filter(r => (r.disposalDate || '') >= startDate);
    if (endDate) records = records.filter(r => (r.disposalDate || '') <= endDate);
    const totalKg = records.reduce((s, r) => s + (r.quantityKg || 0), 0);
    return { count: records.length, totalKg, records };
  }

  // ─── Legacy Dashboards ──────────────────────────────────────────────────────
  async getWorkerDashboard(workerId, query = {}) {
    const { date } = query;
    const targetDate = date || new Date().toISOString().split('T')[0];
    const workerDoc = await db.collection('users').doc(workerId).get();
    if (!workerDoc.exists) throw new NotFoundError('Worker not found');
    const worker = workerDoc.data();
    const tasksSnapshot = await db.collection('cleaningTasks').where('workerId', '==', workerId).where('scheduledDate', '==', targetDate).get();
    const tasks = tasksSnapshot.docs.map(d => d.data());
    const total = tasks.length;
    const completed = tasks.filter(t => t.status === 'completed' || t.status === 'approved').length;
    const inProgress = tasks.filter(t => t.status === 'in_progress').length;
    const pending = tasks.filter(t => t.status === 'pending').length;
    const approved = tasks.filter(t => t.status === 'approved').length;
    const rejected = tasks.filter(t => t.status === 'rejected').length;
    const avgScore = total > 0 ? Math.round(tasks.reduce((s, t) => s + (t.score || 0), 0) / total) : 0;
    return {
      workerId, workerName: worker.fullName || '',
      date: targetDate, totalTasks: total,
      completedTasks: completed, inProgressTasks: inProgress,
      pendingTasks: pending, approvedTasks: approved,
      rejectedTasks: rejected, averageScore: avgScore, tasks
    };
  }

  async getSupervisorDashboard(supervisorId, query = {}, user) {
    const { date } = query;
    const targetDate = date || new Date().toISOString().split('T')[0];
    const supDoc = await db.collection('users').doc(supervisorId).get();
    if (!supDoc.exists) throw new NotFoundError('Supervisor not found');
    const supervisor = supDoc.data();
    if (user && !this._isMasterOrAdmin(user)) {
      const userStations = user?.stations || (user?.stationId ? [user.stationId] : []);
      const supStations = supervisor.stations?.length ? supervisor.stations : supervisor.stationId ? [supervisor.stationId] : [];
      const overlap = supStations.filter(s => userStations.includes(s));
      if (overlap.length === 0 && (user.uid !== supervisorId || userStations.length === 0)) {
        throw new ForbiddenError('You can only access data for your assigned stations');
      }
    }
    const stationIds = supervisor.stations && supervisor.stations.length > 0
      ? supervisor.stations
      : supervisor.stationId ? [supervisor.stationId] : [];
    let tasks = [];
    if (stationIds.length > 0) {
      const s = await db.collection('cleaningTasks')
        .where('supervisorId', '==', supervisorId)
        .where('scheduledDate', '==', targetDate)
        .get();
      tasks = s.docs.map(d => d.data()).filter(t => stationIds.includes(t.stationId));
    }
    const total = tasks.length;
    const completed = tasks.filter(t => t.status === 'completed' || t.status === 'approved').length;
    const inProgress = tasks.filter(t => t.status === 'in_progress').length;
    const pending = tasks.filter(t => t.status === 'pending').length;
    const approved = tasks.filter(t => t.status === 'approved').length;
    const rejected = tasks.filter(t => t.status === 'rejected').length;
    const now = new Date();
    const overdue = tasks.filter(t => {
      const actionableStatuses = ['pending', 'assigned', 'in_progress'];
      if (!actionableStatuses.includes(t.status)) return false;
      const taskDate = t.date || t.scheduledDate || '';
      const taskTime = t.scheduledTime || '23:59';
      return new Date(`${taskDate}T${taskTime}:00`) < now;
    }).length;

    // Fetch workers count for this supervisor
    let workerPerformance = [];
    try {
      const workersSnap = await db.collection('supervisorWorkers')
        .where('supervisorId', '==', supervisorId)
        .where('isActive', '==', true)
        .limit(300)
        .get();
      workerPerformance = workersSnap.docs.map(d => ({ uid: d.id, fullName: d.data().fullName || '' }));
    } catch (e) {
      console.error('Error fetching supervisor workers:', e.message);
    }

    return {
      supervisorId, supervisorName: supervisor.fullName || '',
      date: targetDate, totalTasks: total,
      completedTasks: completed, inProgressTasks: inProgress,
      pendingTasks: pending, approvedTasks: approved, rejectedTasks: rejected,
      overdueTasks: overdue,
      workerPerformance
    };
  }

  _verifyStationAccessForStationId(stationId, user) {
    if (this._isMasterOrAdmin(user)) return;
    const userStations = user?.stations || (user?.stationId ? [user.stationId] : []);
    if (userStations.length > 0 && !userStations.includes(stationId)) {
      throw new ForbiddenError('You can only access data for your assigned stations');
    }
  }

  async generateDailyReport(stationId, query = {}, user) {
    const { date } = query;
    const targetDate = date || new Date().toISOString().split('T')[0];
    this._verifyStationAccessForStationId(stationId, user);
    const stationDoc = await db.collection('stations').doc(stationId).get();
    if (!stationDoc.exists) throw new NotFoundError('Station not found');
    const station = stationDoc.data();
    const snapshot = await db.collection('cleaningTasks').where('stationId', '==', stationId).where('scheduledDate', '==', targetDate).get();
    const tasks = snapshot.docs.map(d => d.data());
    const total = tasks.length;
    const completed = tasks.filter(t => t.status === 'completed' || t.status === 'approved').length;
    const avgScore = total > 0 ? Math.round(tasks.reduce((s, t) => s + (t.score || 0), 0) / total) : 0;
    return {
      stationId, stationName: station.stationName || '',
      date: targetDate, totalTasks: total, completedTasks: completed,
      averageScore: avgScore,
      grade: avgScore >= 90 ? 'A' : avgScore >= 75 ? 'B' : avgScore >= 60 ? 'C' : 'D',
      generatedAt: new Date().toISOString()
    };
  }

  async generateWeeklyReport(stationId, query = {}, user) {
    const { endDate } = query;
    const end = endDate || new Date().toISOString().split('T')[0];
    const start = new Date(end); start.setDate(start.getDate() - 6);
    const startStr = start.toISOString().split('T')[0];
    this._verifyStationAccessForStationId(stationId, user);
    const stationDoc = await db.collection('stations').doc(stationId).get();
    if (!stationDoc.exists) throw new NotFoundError('Station not found');
    const station = stationDoc.data();
    const snapshot = await db.collection('cleaningTasks')
      .where('stationId', '==', stationId)
      .where('scheduledDate', '>=', startStr).where('scheduledDate', '<=', end).get();
    const tasks = snapshot.docs.map(d => d.data());
    const total = tasks.length;
    const completed = tasks.filter(t => t.status === 'completed' || t.status === 'approved').length;
    const avgScore = total > 0 ? Math.round(tasks.reduce((s, t) => s + (t.score || 0), 0) / total) : 0;
    return {
      stationId, stationName: station.stationName || '',
      startDate: startStr, endDate: end, totalTasks: total, completedTasks: completed,
      completionRate: total > 0 ? Math.round(completed / total * 100) : 0,
      averageScore: avgScore, grade: avgScore >= 90 ? 'A' : avgScore >= 75 ? 'B' : avgScore >= 60 ? 'C' : 'D',
      generatedAt: new Date().toISOString()
    };
  }

  async generateMonthlyReport(stationId, query = {}, user) {
    const { month, year } = query;
    const now = new Date();
    const m = month !== undefined ? parseInt(month) : now.getMonth() + 1;
    const y = year !== undefined ? parseInt(year) : now.getFullYear();
    const startStr = `${y}-${String(m).padStart(2, '0')}-01`;
    const lastDay = new Date(y, m, 0).getDate();
    const endStr = `${y}-${String(m).padStart(2, '0')}-${String(lastDay).padStart(2, '0')}`;
    this._verifyStationAccessForStationId(stationId, user);
    const stationDoc = await db.collection('stations').doc(stationId).get();
    if (!stationDoc.exists) throw new NotFoundError('Station not found');
    const station = stationDoc.data();
    const snapshot = await db.collection('cleaningTasks')
      .where('stationId', '==', stationId)
      .where('scheduledDate', '>=', startStr).where('scheduledDate', '<=', endStr).get();
    const tasks = snapshot.docs.map(d => d.data());
    const total = tasks.length;
    const completed = tasks.filter(t => t.status === 'completed' || t.status === 'approved').length;
    const avgScore = total > 0 ? Math.round(tasks.reduce((s, t) => s + (t.score || 0), 0) / total) : 0;
    return {
      stationId, stationName: station.stationName || '',
      month: m, year: y, period: `${startStr} to ${endStr}`,
      totalTasks: total, completedTasks: completed,
      completionRate: total > 0 ? Math.round(completed / total * 100) : 0,
      averageScore: avgScore, grade: avgScore >= 90 ? 'A' : avgScore >= 75 ? 'B' : avgScore >= 60 ? 'C' : 'D',
      generatedAt: new Date().toISOString()
    };
  }

  async getScoreTrend(stationId, query = {}, user) {
    const { months } = query;
    this._verifyStationAccessForStationId(stationId, user);
    const numMonths = months ? parseInt(months) : 6;
    const now = new Date();
    const data = [];
    for (let i = numMonths - 1; i >= 0; i--) {
      const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
      const m = d.getMonth() + 1;
      const y = d.getFullYear();
      const startStr = `${y}-${String(m).padStart(2, '0')}-01`;
      const lastDay = new Date(y, m, 0).getDate();
      const endStr = `${y}-${String(m).padStart(2, '0')}-${String(lastDay).padStart(2, '0')}`;
      const snapshot = await db.collection('cleaningTasks')
        .where('stationId', '==', stationId)
        .where('scheduledDate', '>=', startStr).where('scheduledDate', '<=', endStr).get();
      const tasks = snapshot.docs.map(d => d.data());
      const withScore = tasks.filter(t => t.score);
      const avgScore = withScore.length > 0 ? Math.round(withScore.reduce((s, t) => s + (t.score || 0), 0) / withScore.length) : 0;
      data.push({ month: m, year: y, label: `${y}-${String(m).padStart(2, '0')}`, averageScore: avgScore, taskCount: tasks.length });
    }
    return { stationId, trend: data };
  }

  // ─── Daily Log ──────────────────────────────────────────────────────────────

  async submitDailyLog(body, user) {
    const { activitiesSummary, machineUsage, issuesEncountered, handoverNotes } = body;
    if (!activitiesSummary) {
      throw new Error('Activities summary is required');
    }

    const logData = {
      supervisorId: user.uid,
      supervisorName: user.name || 'Unknown',
      contractId: user.contractId || null,
      stationId: user.stationId || null,
      date: new Date().toISOString().split('T')[0],
      activitiesSummary,
      machineUsage: machineUsage || '',
      issuesEncountered: issuesEncountered || '',
      handoverNotes: handoverNotes || '',
      createdAt: new Date().toISOString(),
      status: 'SUBMITTED'
    };

    const ref = await db.collection('stationDailyLogs').add(logData);
    return { id: ref.id, ...logData };
  }

  // ─── Supervisor Workers CRUD ───────────────────────────────────────────────
  async createWorker(body, user) {
    const { fullName, phone, employeePhotoUrl, aadhaarNumber, aadhaarPhotoUrl, panNumber, panPhotoUrl, pfUanNumber, pfDocumentUrl, policeVerificationNumber, policeVerificationDocUrl, stationId } = body;
    if (!fullName || !phone) throw new ValidationError('fullName and phone are required');
    const ref = db.collection('supervisorWorkers').doc();
    const data = {
      uid: ref.id,
      supervisorId: user.uid,
      supervisorName: user.name || user.fullName || 'Unknown',
      fullName, phone,
      employeePhotoUrl: employeePhotoUrl || '',
      aadhaarNumber: aadhaarNumber || '',
      aadhaarPhotoUrl: aadhaarPhotoUrl || '',
      panNumber: panNumber || '',
      panPhotoUrl: panPhotoUrl || '',
      pfUanNumber: pfUanNumber || '',
      pfDocumentUrl: pfDocumentUrl || '',
      policeVerificationNumber: policeVerificationNumber || '',
      policeVerificationDocUrl: policeVerificationDocUrl || '',
      stationId: stationId || user.stationId || '',
      contractId: user.contractId || '',
      isActive: true,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    };
    await ref.set(data);
    return { message: 'Worker created', uid: ref.id, data };
  }

  async updateWorker(uid, body, user) {
    const ref = db.collection('supervisorWorkers').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Worker not found');
    const worker = doc.data();
    if (worker.supervisorId !== user.uid && !this._isMasterOrAdmin(user)) {
      throw new ForbiddenError('You can only update your own workers');
    }
    const updates = { ...body, updatedAt: new Date().toISOString() };
    delete updates.uid;
    delete updates.supervisorId;
    await ref.update(updates);
    return { message: 'Worker updated', uid };
  }

  async deleteWorker(uid, user) {
    const ref = db.collection('supervisorWorkers').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Worker not found');
    const worker = doc.data();
    if (worker.supervisorId !== user.uid && !this._isMasterOrAdmin(user)) {
      throw new ForbiddenError('You can only delete your own workers');
    }
    await ref.update({ isActive: false, updatedAt: new Date().toISOString() });
    return { message: 'Worker deactivated', uid };
  }

  async listWorkers(query, user) {
    let q = db.collection('supervisorWorkers').where('isActive', '==', true);
    const role = (user?.role || '').toUpperCase();
    const isContractorSupervisor = role === 'CONTRACTOR_SUPERVISOR';
    if (isContractorSupervisor) {
      q = q.where('supervisorId', '==', user.uid);
    } else if (user.contractId) {
      q = q.where('contractId', '==', user.contractId);
    }
    if (query.stationId) q = q.where('stationId', '==', query.stationId);
    if (query.supervisorId) q = q.where('supervisorId', '==', query.supervisorId);
    const snapshot = await q.limit(200).get();
    const workers = snapshot.docs.map(d => ({ id: d.id, ...d.data() }));
    return { count: workers.length, workers };
  }

  async getWorker(uid) {
    const doc = await db.collection('supervisorWorkers').doc(uid).get();
    if (!doc.exists) throw new NotFoundError('Worker not found');
    return { id: doc.id, ...doc.data() };
  }

  // ─── Cleaning Submissions CRUD ─────────────────────────────────────────────
  async createSubmission(body, user) {
    const { stationId, stationName, areaId, areaName, taskTypeId, taskTypeName, beforePhotoUrl, afterPhotoUrl, notes } = body;
    if (!stationId || !areaId || !beforePhotoUrl || !afterPhotoUrl) {
      throw new ValidationError('stationId, areaId, beforePhotoUrl, and afterPhotoUrl are required');
    }
    if (!user.stationId && !stationId) throw new ValidationError('stationId is required');
    const resolvedStationId = this._resolveStationId(stationId, user);
    const ref = db.collection('cleaningSubmissions').doc();
    const data = {
      uid: ref.id,
      stationId: resolvedStationId,
      stationName: stationName || '',
      areaId, areaName: areaName || '',
      taskTypeId: taskTypeId || '',
      taskTypeName: taskTypeName || '',
      beforePhotoUrl, afterPhotoUrl,
      notes: notes || '',
      supervisorId: user.uid,
      supervisorName: user.name || user.fullName || 'Unknown',
      contractId: user.contractId || '',
      submittedAt: new Date().toISOString(),
      status: 'pending',
      reviewedBy: null,
      reviewedAt: null,
      rejectionReason: null
    };
    await ref.set(data);
    return { message: 'Submission created', uid: ref.id, data };
  }

  async listMySubmissions(query, user) {
    let q = db.collection('cleaningSubmissions')
      .where('supervisorId', '==', user.uid)
      .orderBy('submittedAt', 'desc');
    if (query.date) {
      const start = query.date + 'T00:00:00.000Z';
      const end = query.date + 'T23:59:59.999Z';
      q = q.where('submittedAt', '>=', start).where('submittedAt', '<=', end);
    }
    const snapshot = await q.limit(100).get();
    const submissions = snapshot.docs.map(d => ({ id: d.id, ...d.data() }));
    return { count: submissions.length, submissions };
  }

  async listAllSubmissions(query, user) {
    let q = db.collection('cleaningSubmissions');
    if (query.stationId) q = q.where('stationId', '==', query.stationId);
    if (query.status) q = q.where('status', '==', query.status);
    if (query.supervisorId) q = q.where('supervisorId', '==', query.supervisorId);
    if (user.contractId) q = q.where('contractId', '==', user.contractId);
    q = q.orderBy('submittedAt', 'desc');
    const snapshot = await q.limit(200).get();
    const submissions = snapshot.docs.map(d => ({ id: d.id, ...d.data() }));
    return { count: submissions.length, submissions };
  }

  async reviewSubmission(uid, body, user) {
    const ref = db.collection('cleaningSubmissions').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Submission not found');
    const { status, rejectionReason } = body;
    if (!['approved', 'rejected'].includes(status)) throw new ValidationError('status must be approved or rejected');
    await ref.update({
      status,
      rejectionReason: rejectionReason || null,
      reviewedBy: user.uid,
      reviewedAt: new Date().toISOString()
    });
    return { message: `Submission ${status}`, uid };
  }

  // ─── Execution Plan with Supervisor Assignments ────────────────────────────
  async createExecutionPlanWithAssignments(body, user) {
    const { contractId, stationId, month, year, shiftPlan, machinePlan, materialPlan, garbageDisposalPlan, weeklySchedule } = body;
    if (!contractId || !stationId || !shiftPlan) throw new ValidationError('contractId, stationId, and shiftPlan are required');
    const ref = db.collection('executionPlans').doc();
    const data = {
      uid: ref.id, contractId, stationId,
      month: month || new Date().getMonth() + 1,
      year: year || new Date().getFullYear(),
      shiftPlan: typeof shiftPlan === 'object' ? shiftPlan : {},
      manpowerPlan: body.manpowerPlan || {},
      machinePlan: machinePlan || {},
      materialPlan: materialPlan || [],
      garbageDisposalPlan: garbageDisposalPlan || {},
      weeklySchedule: weeklySchedule || [],
      status: 'DRAFT',
      version: 1,
      createdBy: user.uid,
      createdByName: user.name || user.fullName || 'Unknown',
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    };
    await ref.set(data);
    return { message: 'Execution plan created', uid: ref.id, data };
  }

  async submitShiftSummary(data, user) {
    const { supervisorId, supervisorName, stationId, stationName, date, shift, areas } = data;
    if (!supervisorId || !stationId || !date || !areas || !Array.isArray(areas)) {
      throw new ValidationError('supervisorId, stationId, date, and areas array are required');
    }
    if (areas.length < 5) {
      throw new ValidationError(`At least 5 areas must be submitted for the shift summary. Received ${areas.length}.`);
    }
    for (const a of areas) {
      if (!a.photoUrl) throw new ValidationError(`Photo is required for area ${a.areaName || a.areaId || ''}`);
      if (!a.remark || !String(a.remark).trim()) throw new ValidationError(`Remark is required for area ${a.areaName || a.areaId || ''}`);
    }

    const now = new Date().toISOString();
    const ref = db.collection('stationShiftSummaries').doc();
    const enriched = await Promise.all(areas.map(async (a) => {
      let areaBasicAreaSqFt = parseFloat(a.basicAreaSqFt) || 0;
      let areaTimesPerPeriod = parseInt(a.boqTimesPerPeriod, 10) || 1;
      let frequency = a.cleaningFrequency || a.frequency || 'daily';
      let mainArea = a.mainArea || '';
      let areaName = a.areaName || '';
      let tenderedAreaPerDay = parseFloat(a.tenderedAreaPerDay) || 0;
      if (a.areaId) {
        try {
          const areaDoc = await db.collection('stationAreas').doc(a.areaId).get();
          if (areaDoc.exists) {
            const area = areaDoc.data();
            if (!areaBasicAreaSqFt) areaBasicAreaSqFt = parseFloat(area.basicAreaSqFt) || 0;
            if (!areaTimesPerPeriod) areaTimesPerPeriod = parseInt(area.boqTimesPerPeriod || area.frequencyTimes, 10) || 1;
            if (!frequency || frequency === 'daily') frequency = area.cleaningFrequency || area.frequency || frequency || 'daily';
            if (!mainArea) mainArea = area.mainArea || '';
            if (!areaName) areaName = area.areaName || area.name || '';
            if (!tenderedAreaPerDay) tenderedAreaPerDay = parseFloat(area.tenderedAreaPerDay) || 0;
          }
        } catch (_) { /* keep provided values */ }
      }
      const workDone = Math.round(areaBasicAreaSqFt * areaTimesPerPeriod);
      return {
        areaId: a.areaId || '',
        areaName: areaName,
        mainArea: mainArea || '',
        basicAreaSqFt: areaBasicAreaSqFt,
        cleaningFrequency: frequency || 'daily',
        boqTimesPerPeriod: areaTimesPerPeriod,
        workDone,
        tenderedAreaPerDay: tenderedAreaPerDay || workDone,
        photoUrl: a.photoUrl || '',
        scheduledTime: a.scheduledTime || '',
        taskId: a.taskId || null,
        remark: String(a.remark || '').trim(),
      };
    }));

    const totalWorkDone = enriched.reduce((sum, a) => sum + (a.workDone || 0), 0);
    const totalTenderedArea = enriched.reduce((sum, a) => sum + (a.tenderedAreaPerDay || 0), 0);
    const record = {
      uid: ref.id,
      supervisorId,
      supervisorName: supervisorName || '',
      stationId,
      stationName: stationName || '',
      date,
      shift: shift || '',
      areas: enriched,
      totalWorkDone,
      totalTenderedArea,
      status: 'submitted',
      submittedAt: now,
      submittedBy: (user && user.uid) || supervisorId,
      approvedBy: null, approvedByName: null, approvedAt: null,
      rejectedBy: null, rejectionReason: null, rejectedAt: null,
      createdAt: now,
      updatedAt: now,
    };
    await ref.set(record);

    // Notify railway supervisors/admins for approval
    try {
      const notifyRoles = ['RAILWAY_SUPERVISOR', 'RAILWAY_ADMIN', 'RAILWAY_MASTER', 'SUPER_ADMIN'];
      const usersSnap = await db.collection('users')
        .where('role', 'in', notifyRoles)
        .limit(50)
        .get();
      const title = 'Shift Summary Submitted';
      const body = `${supervisorName || 'Supervisor'} submitted shift summary for ${stationName || 'station'} — ${shift || ''} shift. Please review and approve.`;
      const data = { type: 'shift_summary_approval', summaryUid: ref.id, stationId: stationId || '' };
      for (const userDoc of usersSnap.docs) {
        const userData = userDoc.data();
        if (userData.stationId === stationId || (userData.stations && Array.isArray(userData.stations) && userData.stations.includes(stationId))) {
          fcmService.sendPush(userDoc.id, title, body, data).catch(() => {});
        }
      }
    } catch (_) { /* notification failure should not block submission */ }

    return { message: 'Shift summary submitted for approval', uid: ref.id, count: enriched.length, totalWorkDone, status: 'submitted' };
  }

  async listShiftSummaries(query = {}, user) {
    const { stationId, date, shift, supervisorId, status } = query;
    let q = db.collection('stationShiftSummaries');
    if (stationId) q = q.where('stationId', '==', stationId);
    if (date) q = q.where('date', '==', date);
    if (shift) q = q.where('shift', '==', shift);
    if (status) q = q.where('status', '==', status);
    const role = (user && user.role) ? String(user.role).toUpperCase() : '';
    const isRailwayOrMaster = ['SUPER_ADMIN', 'COMPANY_MASTER', 'RAILWAY_MASTER', 'ADMIN', 'RAILWAY_ADMIN', 'RAILWAY_INSPECTOR', 'RAILWAY_SUPERVISOR'].includes(role);
    let snap;
    try {
      snap = await q.orderBy('submittedAt', 'desc').limit(200).get();
    } catch (indexErr) {
      snap = await q.limit(200).get();
      const docs = [];
      snap.forEach(d => docs.push(d));
      docs.sort((a, b) => (b.data().submittedAt || '').localeCompare(a.data().submittedAt || ''));
      const records = docs
        .filter(d => {
          if (supervisorId && d.data().supervisorId !== supervisorId) return false;
          if (!isRailwayOrMaster && d.data().supervisorId !== user.uid) return false;
          return true;
        })
        .map(d => ({ id: d.id, ...d.data() }));
      return { count: records.length, summaries: records };
    }
    const summaries = [];
    snap.forEach(d => {
      const s = d.data();
      if (supervisorId && s.supervisorId !== supervisorId) return;
      if (!isRailwayOrMaster && s.supervisorId !== user.uid) return;
      summaries.push({ id: d.id, ...s });
    });
    return { count: summaries.length, summaries };
  }

  async getShiftSummary(uid) {
    const doc = await db.collection('stationShiftSummaries').doc(uid).get();
    if (!doc.exists) throw new NotFoundError('Shift summary not found');
    return { id: doc.id, ...doc.data() };
  }

  async approveShiftSummary(uid, user) {
    const ref = db.collection('stationShiftSummaries').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Shift summary not found');
    if (doc.data().status !== 'submitted') {
      throw new ValidationError(`Only submitted shift summaries can be approved. Current: ${doc.data().status}`);
    }
    await ref.update({
      status: 'approved',
      approvedBy: user.uid,
      approvedByName: user.fullName || user.name || 'Unknown',
      approvedAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    });
    return { message: 'Shift summary approved', uid };
  }

  async rejectShiftSummary(uid, reason, user) {
    const ref = db.collection('stationShiftSummaries').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Shift summary not found');
    if (doc.data().status !== 'submitted') {
      throw new ValidationError(`Only submitted shift summaries can be rejected. Current: ${doc.data().status}`);
    }
    const rejectionReason = typeof reason === 'string' ? reason : (reason && reason.reason) || '';
    await ref.update({
      status: 'rejected',
      rejectedBy: user.uid,
      rejectedByName: user.fullName || user.name || 'Unknown',
      rejectionReason,
      rejectedAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    });
    return { message: 'Shift summary rejected', uid };
  }
}

export const stationCleaningService = new StationCleaningService();
