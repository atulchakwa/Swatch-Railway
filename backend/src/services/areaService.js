import { db } from '../database/index.js';
import { NotFoundError, ValidationError } from '../errors/index.js';
import { paginate } from '../utils/paginate.js';
import { taskManagementService } from './taskManagementService.js';

const VALID_AREA_TYPES = [
  'Toilet', 'Waiting Hall', 'Track', 'Escalator', 'Lift',
  'Dustbin', 'Water Booth', 'Parking', 'Entrance', 'Corridor',
  'Staircase', 'Office', 'Canteen', 'Concourse', 'FOB',
  'Circulating Area', 'Approach Road', 'Gardens',
  'Goods Platform/Goods Line', 'Drains', 'Other',
  'Platform Surface', 'Platform Toilet', 'Water Booth Zone',
  'Dustbin Zone', 'Track Side', 'Bench Area', 'Signage Area'
];

const PLATFORM_AREA_TYPES = ['Platform Surface', 'Platform Toilet', 'Water Booth Zone', 'Dustbin Zone', 'Track Side', 'Bench Area', 'Signage Area'];
const STATION_AREA_TYPES = ['Waiting Room', 'Station Toilet', 'FOB', 'Escalator', 'Lift', 'Parking', 'Garden', 'Office', 'Canteen', 'Concourse', 'Circulating Area', 'Goods Shed', 'Drains'];

const TENDER_FIELDS = ['section', 'sectionName', 'platformRef', 'surfaceType', 'areaSqft', 'shiftConsidered', 'tenderedAreaPerDay', 'cleaningInterval'];

function _calcTenderedArea(basicAreaSqFt, frequencyType, frequencyTimes) {
  const area = basicAreaSqFt || 0;
  const times = frequencyTimes || 1;
  switch ((frequencyType || 'daily').toLowerCase()) {
    case 'monthly': return Math.round((area * times) / 30);
    case 'weekly': return Math.round((area * times) / 7);
    case 'daily':
    default: return Math.round(area * times);
  }
}

const VALID_FREQUENCIES = ['hourly', '2hrs', '4hrs', 'daily', 'shift_wise', 'once_per_day', 'twice_per_day', 'three_times_per_day', 'every_six_hours', 'weekly', 'fortnightly', 'monthly', 'as_and_when_required'];

async function _generateAreaCode(stationId, platformId, areaType) {
  const stationDoc = await db.collection('stations').doc(stationId).get();
  const stationCode = stationDoc.exists ? (stationDoc.data().stationCode || stationDoc.data().stationName || 'STN') : 'STN';
  const prefix = stationCode.substring(0, 3).toUpperCase();
  if (platformId) {
    const platformDoc = await db.collection('platforms').doc(platformId).get();
    const platformNumber = platformDoc.exists ? (platformDoc.data().platformNumber || 'PF') : 'PF';
    return `${prefix}-PF${platformNumber}-${(areaType || 'AREA').substring(0, 5).toUpperCase().replace(/\s/g, '')}`;
  }
  return `${prefix}-STN-${(areaType || 'AREA').substring(0, 5).toUpperCase().replace(/\s/g, '')}`;
}

class AreaService {
  async createArea(userData, body) {
    const { stationId, platformId, areaName, areaType, frequency, priority,
            cleaningFrequency, frequencyTimes, supervisorId, defaultWorkers, defaultShift, qrCode } = body;
    if (!stationId || !areaName) throw new ValidationError('stationId and areaName are required');

    const stationDoc = await db.collection('stations').doc(stationId).get();
    if (!stationDoc.exists) throw new NotFoundError('Station not found');

    if (platformId) {
      const platformDoc = await db.collection('platforms').doc(platformId).get();
      if (!platformDoc.exists) throw new NotFoundError('Platform not found');
    }

    const cf = cleaningFrequency || frequency || 'daily';
    if (!VALID_FREQUENCIES.includes(cf)) {
      throw new ValidationError(`Invalid cleaningFrequency: ${cf}. Must be one of: ${VALID_FREQUENCIES.join(', ')}`);
    }

    if (frequencyTimes && (!Array.isArray(frequencyTimes) || frequencyTimes.length === 0)) {
      throw new ValidationError('frequencyTimes must be a non-empty array of time strings (HH:MM)');
    }

    const ref = db.collection('areas').doc();
    const areaCode = body.areaCode || await _generateAreaCode(stationId, platformId, areaType || 'Other');

    const mainArea = body.mainArea || '';
    const basicAreaSqFt = parseFloat(body.basicAreaSqFt) || 0;
    const boqFrequencyType = body.frequencyType || '';
    const boqTimesPerPeriod = parseInt(body.boqTimesPerPeriod || body.frequencyTimes) || 1;
    const tenderedAreaPerDay = body.tenderedAreaPerDay !== undefined
      ? parseFloat(body.tenderedAreaPerDay)
      : (basicAreaSqFt && boqFrequencyType ? _calcTenderedArea(basicAreaSqFt, boqFrequencyType, boqTimesPerPeriod) : (body.tenderedAreaPerDay || 0));

    const data = {
      uid: ref.id, stationId,
      stationName: stationDoc.data().stationName || '',
      platformId: platformId || null,
      areaName, areaType: areaType || 'Other',
      areaCode,
      mainArea,
      basicAreaSqFt,
      frequencyType: boqFrequencyType,
      boqTimesPerPeriod,
      tenderedAreaPerDay,
      cleaningFrequency: cf,
      priority: Math.max(1, Math.min(5, Number(priority) || 3)),
      supervisorId: supervisorId || null,
      defaultWorkers: defaultWorkers || [],
      defaultShift: defaultShift || 'morning',
      qrCode: qrCode || null,
      status: 'active',
      createdBy: userData.uid,
      createdAt: new Date().toISOString(), updatedAt: new Date().toISOString()
    };
    for (const field of TENDER_FIELDS) {
      if (body[field] !== undefined) data[field] = body[field];
    }
    if (body.frequency !== undefined) data.frequency = body.frequency;
    await ref.set(data);
    return { message: 'Area created', uid: ref.id, area: data };
  }

  async configureArea(userData, body) {
    const { uid, ...updateData } = body;
    if (uid) {
      const ref = db.collection('areas').doc(uid);
      const doc = await ref.get();
      if (!doc.exists) throw new NotFoundError('Area not found');
      const existing = doc.data();
      const updates = {};
      const allowed = ['areaName', 'areaType', 'areaCode', 'cleaningFrequency', 'frequencyTimes', 'priority',
                        'supervisorId', 'defaultWorkers', 'defaultShift', 'qrCode', 'status', 'surfaceType',
                        'areaSqft', 'platformId', 'mainArea', 'basicAreaSqFt', 'frequencyType', 'boqTimesPerPeriod',
                        'tenderedAreaPerDay', ...TENDER_FIELDS];
      for (const key of allowed) {
        if (updateData[key] !== undefined) {
          if (key === 'cleaningFrequency' && !VALID_FREQUENCIES.includes(updateData[key])) {
            throw new ValidationError(`Invalid cleaningFrequency: ${updateData[key]}`);
          }
          updates[key] = updateData[key];
        }
      }
      if (updates.cleaningFrequency === undefined && updateData.frequency !== undefined) {
        updates.cleaningFrequency = updateData.frequency;
      }
      if (updateData.stationId) {
        const stationDoc = await db.collection('stations').doc(updateData.stationId).get();
        if (!stationDoc.exists) throw new NotFoundError('Station not found');
        updates.stationId = updateData.stationId;
        updates.stationName = stationDoc.data().stationName || '';
      }
      if (updateData.basicAreaSqFt !== undefined || updateData.frequencyType !== undefined || updateData.boqTimesPerPeriod !== undefined) {
        const basic = updateData.basicAreaSqFt !== undefined ? parseFloat(updateData.basicAreaSqFt) : (existing.basicAreaSqFt || 0);
        const freqType = updateData.frequencyType || existing.frequencyType || '';
        const times = updateData.boqTimesPerPeriod !== undefined ? parseInt(updateData.boqTimesPerPeriod) : (existing.boqTimesPerPeriod || 1);
        if (basic && freqType) {
          updates.tenderedAreaPerDay = _calcTenderedArea(basic, freqType, times);
        }
      }
      updates.updatedAt = new Date().toISOString();
      await ref.update(updates);
      return { message: 'Area configured', uid };
    }
    return this.createArea(userData, body);
  }

  async getAreas(query = {}) {
    const { stationId, platformId, areaType, status, section, supervisorId, limit = 50, cursor } = query;
    let firestoreQuery = db.collection('areas');
    if (stationId) firestoreQuery = firestoreQuery.where('stationId', '==', stationId);
    if (platformId) firestoreQuery = firestoreQuery.where('platformId', '==', platformId);
    if (areaType) firestoreQuery = firestoreQuery.where('areaType', '==', areaType);
    if (status) firestoreQuery = firestoreQuery.where('status', '==', status);
    if (section !== undefined) firestoreQuery = firestoreQuery.where('section', '==', Number(section));
    if (supervisorId) firestoreQuery = firestoreQuery.where('supervisorId', '==', supervisorId);
    const result = await paginate(firestoreQuery, { limit, cursor, orderBy: 'areaName', orderDir: 'asc' });
    return { count: result.items.length, areas: result.items, pagination: result.pagination };
  }

  async getAreasByHierarchy(query = {}) {
    const { stationId, platformId } = query;
    if (stationId && platformId) {
      return this.getAreasByPlatform(platformId);
    }
    if (stationId) {
      return this.getAreasByStation(stationId);
    }
    throw new ValidationError('stationId is required');
  }

  async getAreaById(uid) {
    const doc = await db.collection('areas').doc(uid).get();
    if (!doc.exists) throw new NotFoundError('Area not found');
    return { id: doc.id, ...doc.data() };
  }

  async updateArea(uid, body) {
    const ref = db.collection('areas').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Area not found');
    const existing = doc.data();
    const updates = {};
    const allowed = ['areaName', 'areaType', 'areaCode', 'cleaningFrequency', 'frequencyTimes', 'priority',
                      'supervisorId', 'defaultWorkers', 'defaultShift', 'qrCode', 'status',
                      'mainArea', 'basicAreaSqFt', 'frequencyType', 'boqTimesPerPeriod', 'tenderedAreaPerDay',
                      ...TENDER_FIELDS];
    for (const key of allowed) {
      if (body[key] !== undefined) updates[key] = key === 'priority' ? Math.max(1, Math.min(5, Number(body[key]))) : body[key];
    }
    if (body.frequency !== undefined && updates.cleaningFrequency === undefined) {
      updates.cleaningFrequency = body.frequency;
    }
    if (body.stationId) {
      const stationDoc = await db.collection('stations').doc(body.stationId).get();
      if (!stationDoc.exists) throw new NotFoundError('Station not found');
      updates.stationId = body.stationId;
      updates.stationName = stationDoc.data().stationName || '';
    }
    if (body.platformId !== undefined) updates.platformId = body.platformId || null;
    if (body.basicAreaSqFt !== undefined || body.frequencyType !== undefined || body.boqTimesPerPeriod !== undefined) {
      const basic = body.basicAreaSqFt !== undefined ? parseFloat(body.basicAreaSqFt) : (existing.basicAreaSqFt || 0);
      const freqType = body.frequencyType || existing.frequencyType || '';
      const times = body.boqTimesPerPeriod !== undefined ? parseInt(body.boqTimesPerPeriod) : (existing.boqTimesPerPeriod || 1);
      if (basic && freqType) {
        updates.tenderedAreaPerDay = _calcTenderedArea(basic, freqType, times);
      }
    }
    updates.updatedAt = new Date().toISOString();
    await ref.update(updates);
    return { message: 'Area updated', uid };
  }

  async deleteArea(uid) {
    const ref = db.collection('areas').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Area not found');
    await ref.update({ status: 'inactive', deletedAt: new Date().toISOString(), updatedAt: new Date().toISOString() });
    return { message: 'Area deactivated' };
  }

  async getAreaSummary(stationId) {
    if (!stationId) throw new ValidationError('stationId is required');
    const snapshot = await db.collection('areas')
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

  async getAreasByStation(stationId, section) {
    if (!stationId) throw new ValidationError('stationId is required');
    let query = db.collection('areas').where('stationId', '==', stationId).where('status', '==', 'active');
    if (section !== undefined) query = query.where('section', '==', Number(section));
    const snapshot = await query.get();
    const areas = [];
    snapshot.forEach(doc => areas.push({ id: doc.id, ...doc.data() }));
    areas.sort((a, b) => (a.areaName || '').localeCompare(b.areaName || ''));
    return { count: areas.length, areas };
  }

  async getAreasByPlatform(platformId) {
    if (!platformId) throw new ValidationError('platformId is required');
    const snapshot = await db.collection('areas').where('platformId', '==', platformId).where('status', '==', 'active').get();
    const areas = [];
    snapshot.forEach(doc => areas.push({ id: doc.id, ...doc.data() }));
    areas.sort((a, b) => (a.areaName || '').localeCompare(b.areaName || ''));
    return { count: areas.length, areas };
  }

  async getMasterDashboard(user) {
    const [areasSnap, stationAreasSnap, tasksSnap] = await Promise.all([
      db.collection('areas').where('status', '==', 'active').get(),
      db.collection('stationAreas').where('status', '==', 'active').get(),
      db.collection('cleaningTasks').limit(100).get()
    ]);
    return {
      totalAreas: areasSnap.size + stationAreasSnap.size,
      totalTasks: tasksSnap.size,
      pendingTasks: tasksSnap.docs.filter(d => d.data().status === 'pending').length,
      completedTasks: tasksSnap.docs.filter(d => d.data().status === 'completed').length
    };
  }

  async getAreaWorkers(uid) {
    const snapshot = await db.collection('areaWorkerAssignments')
      .where('areaId', '==', uid)
      .where('isActive', '==', true).get();
    const workers = [];
    snapshot.forEach(doc => workers.push({ id: doc.id, ...doc.data() }));
    return { count: workers.length, workers };
  }

  async getAreaTasks(uid, query = {}) {
    const { status, limit = 50 } = query;
    let q = db.collection('cleaningTasks').where('areaId', '==', uid);
    if (status) q = q.where('status', '==', status);
    const snapshot = await q.limit(Number(limit)).get();
    const tasks = [];
    snapshot.forEach(doc => tasks.push({ id: doc.id, ...doc.data() }));
    return { count: tasks.length, tasks };
  }

  async getAreaReports(uid, query = {}) {
    return { areaId: uid, reports: [] };
  }

  async assignWorkerToArea(uid, body) {
    const { workerId, workerName, shift, startDate } = body;
    if (!workerId || !shift || !startDate) throw new ValidationError('workerId, shift, and startDate are required');
    let areaDoc = await db.collection('areas').doc(uid).get();
    if (!areaDoc.exists) {
      areaDoc = await db.collection('stationAreas').doc(uid).get();
    }
    if (!areaDoc.exists) throw new NotFoundError('Area not found');
    const area = areaDoc.data();
    const ref = db.collection('areaWorkerAssignments').doc();
    const assignment = {
      uid: ref.id,
      areaId: uid,
      stationId: area.stationId || '',
      platformId: area.platformId || null,
      workerId,
      workerName: workerName || 'Unknown Worker',
      shift,
      startDate,
      isActive: true,
      status: 'active',
      assignedAt: new Date().toISOString()
    };
    await ref.set(assignment);
    return { message: 'Worker assigned successfully', uid: ref.id, assignment };
  }

  async unassignWorkerFromArea(uid, workerId) {
    const snapshot = await db.collection('areaWorkerAssignments')
      .where('areaId', '==', uid)
      .where('workerId', '==', workerId)
      .where('isActive', '==', true).get();
    if (snapshot.empty) throw new NotFoundError('Active assignment not found');
    const batch = db.batch();
    snapshot.forEach(doc => {
      batch.update(doc.ref, { isActive: false, status: 'inactive', updatedAt: new Date().toISOString() });
    });
    await batch.commit();
    return { message: 'Worker unassigned successfully' };
  }

  async assignPlatformToArea(uid, body) {
    const { platformId } = body;
    if (!platformId) throw new ValidationError('platformId is required');
    let ref = db.collection('areas').doc(uid);
    let doc = await ref.get();
    if (!doc.exists) {
      ref = db.collection('stationAreas').doc(uid);
      doc = await ref.get();
    }
    if (!doc.exists) throw new NotFoundError('Area not found');
    await ref.update({ platformId, updatedAt: new Date().toISOString() });
    return { message: 'Platform assigned to area successfully', platformId };
  }

  async unassignPlatformFromArea(uid, platformId) {
    let ref = db.collection('areas').doc(uid);
    let doc = await ref.get();
    if (!doc.exists) {
      ref = db.collection('stationAreas').doc(uid);
      doc = await ref.get();
    }
    if (!doc.exists) throw new NotFoundError('Area not found');
    await ref.update({ platformId: null, updatedAt: new Date().toISOString() });
    return { message: 'Platform unassigned from area successfully' };
  }

  async generateTasksFromFrequency(uid, body, user) {
    const { date, workerIds } = body;
    const targetDate = date || new Date().toISOString().split('T')[0];
    const result = await taskManagementService.bulkGenerate(
      { areaIds: [uid], date: targetDate, workerIds: workerIds || [] },
      user
    );
    return { message: `Generated ${result.count} tasks for area ${uid}`, areaId: uid, ...result };
  }

  async getAreasByCompany(companyId) {
    if (!companyId) throw new ValidationError('companyId is required');
    const contractsSnap = await db.collection('contracts').where('entityId', '==', companyId).get();
    const stationIds = new Set();
    contractsSnap.forEach(doc => {
      const data = doc.data();
      const status = (data.status || '').toUpperCase();
      if (status !== 'INACTIVE' && status !== 'CLOSED' && status !== 'SUSPENDED') {
        const sids = data.stationIds || [];
        sids.forEach(sid => stationIds.add(sid));
      }
    });
    const stationIdsArray = Array.from(stationIds);
    if (stationIdsArray.length === 0) {
      return { count: 0, areas: [] };
    }
    const [areasSnap, stationAreasSnap] = await Promise.all([
      db.collection('areas').where('status', '==', 'active').get(),
      db.collection('stationAreas').where('status', '==', 'active').get()
    ]);
    const areas = [];
    areasSnap.forEach(doc => {
      const data = doc.data();
      if (stationIdsArray.includes(data.stationId)) {
        areas.push({ id: doc.id, ...data });
      }
    });
    stationAreasSnap.forEach(doc => {
      const data = doc.data();
      if (stationIdsArray.includes(data.stationId)) {
        if (!areas.some(a => a.id === doc.id)) {
          areas.push({ id: doc.id, ...data });
        }
      }
    });
    areas.sort((a, b) => (a.areaName || '').localeCompare(b.areaName || ''));
    return { count: areas.length, areas };
  }
}

export const areaService = new AreaService();
