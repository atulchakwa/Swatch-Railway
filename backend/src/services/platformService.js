import { db } from '../database/index.js';
import { NotFoundError, ValidationError, ConflictError } from '../errors/index.js';
import { paginate } from '../utils/paginate.js';

class PlatformService {
  async createPlatform(userData, body) {
    const { platformNumber, stationId, platformName, surfaceType, length, width } = body;
    if (!platformNumber || !stationId) throw new ValidationError('platformNumber and stationId are required');

    const stationDoc = await db.collection('stations').doc(stationId).get();
    if (!stationDoc.exists) throw new NotFoundError('Station not found');

    const existing = await db.collection('platforms')
      .where('stationId', '==', stationId)
      .where('platformNumber', '==', platformNumber)
      .where('status', '==', 'active').limit(1).get();
    if (!existing.empty) throw new ConflictError(`Platform ${platformNumber} already exists at this station`);

    const stationData = stationDoc.data();
    const ref = db.collection('platforms').doc();
    const data = {
      uid: ref.id, platformNumber, stationId,
      stationName: stationData.stationName || '',
      platformName: platformName || `Platform ${platformNumber}`,
      surfaceType: surfaceType || null,
      length: length || null,
      width: width || null,
      status: 'active',
      createdBy: userData.uid,
      createdAt: new Date().toISOString(), updatedAt: new Date().toISOString()
    };
    await ref.set(data);
    return { message: 'Platform created', uid: ref.id, platform: data };
  }

  async getPlatforms(query = {}) {
    const { stationId, status, limit = 50, cursor } = query;
    let firestoreQuery = db.collection('platforms');
    if (stationId) firestoreQuery = firestoreQuery.where('stationId', '==', stationId);
    if (status) firestoreQuery = firestoreQuery.where('status', '==', status);
    else firestoreQuery = firestoreQuery.where('status', '==', 'active');
    const result = await paginate(firestoreQuery, { limit, cursor, orderBy: 'platformNumber', orderDir: 'asc' });
    return { count: result.items.length, platforms: result.items, pagination: result.pagination };
  }

  async getPlatformById(uid) {
    const doc = await db.collection('platforms').doc(uid).get();
    if (!doc.exists) throw new NotFoundError('Platform not found');
    return { id: doc.id, ...doc.data() };
  }

  async updatePlatform(uid, body) {
    const ref = db.collection('platforms').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Platform not found');
    const updates = {};
    const allowed = ['platformNumber', 'platformName', 'surfaceType', 'length', 'width', 'status'];
    for (const key of allowed) {
      if (body[key] !== undefined) updates[key] = body[key];
    }
    if (body.stationId) {
      const stationDoc = await db.collection('stations').doc(body.stationId).get();
      if (!stationDoc.exists) throw new NotFoundError('Station not found');
      updates.stationId = body.stationId;
      updates.stationName = stationDoc.data().stationName || '';
    }
    updates.updatedAt = new Date().toISOString();
    await ref.update(updates);
    return { message: 'Platform updated', uid };
  }

  async deletePlatform(uid) {
    const ref = db.collection('platforms').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Platform not found');
    await ref.update({ status: 'inactive', deletedAt: new Date().toISOString(), updatedAt: new Date().toISOString() });
    return { message: 'Platform deactivated' };
  }

  async getPlatformsByStation(stationId) {
    if (!stationId) throw new ValidationError('stationId is required');
    const snapshot = await db.collection('platforms').get();
    const platforms = [];
    snapshot.forEach(doc => {
      const data = doc.data();
      if (data.stationId === stationId && data.status === 'active') {
        platforms.push({ id: doc.id, ...data });
      }
    });
    platforms.sort((a, b) => (a.platformNumber || '').localeCompare(b.platformNumber || ''));
    return { count: platforms.length, platforms };
  }

  async getMasterDashboard(user) {
    const [platformsSnap, areasSnap] = await Promise.all([
      db.collection('platforms').where('status', '==', 'active').get(),
      db.collection('areas').where('status', '==', 'active').get()
    ]);
    return {
      totalPlatforms: platformsSnap.size,
      totalAreas: areasSnap.size,
      activeWorkers: 0
    };
  }

  async getPlatformAreas(uid) {
    const snapshot = await db.collection('areas')
      .where('platformId', '==', uid)
      .where('status', '==', 'active').get();
    const areas = [];
    snapshot.forEach(doc => areas.push({ id: doc.id, ...doc.data() }));
    return { count: areas.length, areas };
  }

  async getPlatformWorkers(uid) {
    const snapshot = await db.collection('areaWorkerAssignments')
      .where('platformId', '==', uid)
      .where('isActive', '==', true).get();
    const workers = [];
    snapshot.forEach(doc => workers.push({ id: doc.id, ...doc.data() }));
    return { count: workers.length, workers };
  }

  async getPlatformTasks(uid, query = {}) {
    const { status, limit = 50 } = query;
    let q = db.collection('cleaningTasks').where('platformId', '==', uid);
    if (status) q = q.where('status', '==', status);
    const snapshot = await q.limit(Number(limit)).get();
    const tasks = [];
    snapshot.forEach(doc => tasks.push({ id: doc.id, ...doc.data() }));
    return { count: tasks.length, tasks };
  }

  async getPlatformReports(uid, query = {}) {
    return { platformId: uid, reports: [] };
  }

  async assignWorkerToPlatform(uid, body) {
    const { workerId, workerName, shift, startDate } = body;
    if (!workerId || !shift || !startDate) throw new ValidationError('workerId, shift, and startDate are required');
    const platformDoc = await db.collection('platforms').doc(uid).get();
    if (!platformDoc.exists) throw new NotFoundError('Platform not found');
    const plat = platformDoc.data();
    const ref = db.collection('areaWorkerAssignments').doc();
    const assignment = {
      uid: ref.id,
      areaId: null,
      stationId: plat.stationId || '',
      platformId: uid,
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

  async unassignWorkerFromPlatform(uid, workerId) {
    const snapshot = await db.collection('areaWorkerAssignments')
      .where('platformId', '==', uid)
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

  async assignAreaToPlatform(uid, body) {
    const { areaId } = body;
    if (!areaId) throw new ValidationError('areaId is required');
    let ref = db.collection('areas').doc(areaId);
    let doc = await ref.get();
    if (!doc.exists) {
      ref = db.collection('stationAreas').doc(areaId);
      doc = await ref.get();
    }
    if (!doc.exists) throw new NotFoundError('Area not found');
    await ref.update({ platformId: uid, updatedAt: new Date().toISOString() });
    return { message: 'Area assigned to platform successfully', areaId };
  }

  async unassignAreaFromPlatform(uid, areaId) {
    let ref = db.collection('areas').doc(areaId);
    let doc = await ref.get();
    if (!doc.exists) {
      ref = db.collection('stationAreas').doc(areaId);
      doc = await ref.get();
    }
    if (!doc.exists) throw new NotFoundError('Area not found');
    await ref.update({ platformId: null, updatedAt: new Date().toISOString() });
    return { message: 'Area unassigned from platform successfully' };
  }

  async generateTasksFromFrequency(uid, body) {
    return { message: 'Tasks generated successfully', platformId: uid };
  }

  async getZonePlatforms(userData) {
    const zone = userData.zone;
    if (!zone) throw new ValidationError('Zone not defined in user profile');
    return this.getPlatformsByZone(zone);
  }

  async getPlatformsByZone(zoneId) {
    if (!zoneId) throw new ValidationError('zoneId is required');
    const [stationsSnap1, stationsSnap2] = await Promise.all([
      db.collection('stations').where('zoneId', '==', zoneId).get(),
      db.collection('stations').where('zone', '==', zoneId).get()
    ]);
    const stationIds = new Set();
    stationsSnap1.forEach(doc => stationIds.add(doc.id));
    stationsSnap2.forEach(doc => stationIds.add(doc.id));
    const stationIdsArray = Array.from(stationIds);
    if (stationIdsArray.length === 0) {
      return { count: 0, platforms: [] };
    }
    const platformsSnap = await db.collection('platforms').where('status', '==', 'active').get();
    const platforms = [];
    platformsSnap.forEach(doc => {
      const data = doc.data();
      if (stationIdsArray.includes(data.stationId)) {
        platforms.push({ id: doc.id, ...data });
      }
    });
    platforms.sort((a, b) => String(a.platformNumber).localeCompare(String(b.platformNumber), undefined, { numeric: true, sensitivity: 'base' }));
    return { count: platforms.length, platforms };
  }

  async getPlatformsByCompany(companyId) {
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
      return { count: 0, platforms: [] };
    }
    const platformsSnap = await db.collection('platforms').where('status', '==', 'active').get();
    const platforms = [];
    platformsSnap.forEach(doc => {
      const data = doc.data();
      if (stationIdsArray.includes(data.stationId)) {
        platforms.push({ id: doc.id, ...data });
      }
    });
    platforms.sort((a, b) => String(a.platformNumber).localeCompare(String(b.platformNumber), undefined, { numeric: true, sensitivity: 'base' }));
    return { count: platforms.length, platforms };
  }
}

export const platformService = new PlatformService();
