import { db } from '../database/index.js';
import { NotFoundError, ValidationError } from '../errors/index.js';
import { notificationService } from './notificationService.js';
import { paginate } from '../utils/paginate.js';

class DeploymentService {
  async createDeployment(userData, body) {
    const { workerId, stationId, platformId, areaId, taskId, shiftId, supervisorId, startDate, endDate } = body;
    if (!workerId || !stationId || !taskId || !shiftId) throw new ValidationError('workerId, stationId, taskId, shiftId are required');

    const workerDoc = await db.collection('users').doc(workerId).get();
    if (!workerDoc.exists) throw new NotFoundError('Worker not found');

    if (supervisorId) {
      const supDoc = await db.collection('users').doc(supervisorId).get();
      if (!supDoc.exists) throw new NotFoundError('Supervisor not found');
    }

    const ref = db.collection('deployments').doc();
    const data = {
      uid: ref.id, workerId, workerName: workerDoc.data().fullName || workerDoc.data().name || 'Unknown',
      stationId, platformId: platformId || null, areaId: areaId || null, taskId,
      shiftId, supervisorId: supervisorId || null,
      startDate: startDate || new Date().toISOString().split('T')[0],
      endDate: endDate || null,
      status: 'active', attendance: {},
      createdBy: userData.uid,
      createdAt: new Date().toISOString(), updatedAt: new Date().toISOString()
    };
    await ref.set(data);
    return { message: 'Deployment created', uid: ref.id, deployment: data };
  }

  async getDeployments(query = {}) {
    const { workerId, stationId, shiftId, supervisorId, status, limit = 50, cursor } = query;
    let firestoreQuery = db.collection('deployments');
    if (workerId) firestoreQuery = firestoreQuery.where('workerId', '==', workerId);
    if (stationId) firestoreQuery = firestoreQuery.where('stationId', '==', stationId);
    if (shiftId) firestoreQuery = firestoreQuery.where('shiftId', '==', shiftId);
    if (supervisorId) firestoreQuery = firestoreQuery.where('supervisorId', '==', supervisorId);
    if (status) firestoreQuery = firestoreQuery.where('status', '==', status);
    const result = await paginate(firestoreQuery, { limit, cursor, orderBy: 'createdAt', orderDir: 'desc' });
    return { count: result.items.length, deployments: result.items, pagination: result.pagination };
  }

  async getDeploymentById(uid) {
    const doc = await db.collection('deployments').doc(uid).get();
    if (!doc.exists) throw new NotFoundError('Deployment not found');
    return { id: doc.id, ...doc.data() };
  }

  async updateDeployment(uid, body) {
    const ref = db.collection('deployments').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Deployment not found');
    const updates = {};
    const allowed = ['platformId', 'areaId', 'taskId', 'shiftId', 'supervisorId', 'startDate', 'endDate', 'status'];
    for (const key of allowed) {
      if (body[key] !== undefined) updates[key] = body[key];
    }
    updates.updatedAt = new Date().toISOString();
    await ref.update(updates);
    return { message: 'Deployment updated', uid };
  }

  async deleteDeployment(uid) {
    const ref = db.collection('deployments').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Deployment not found');
    await ref.update({ status: 'inactive', deletedAt: new Date().toISOString(), updatedAt: new Date().toISOString() });
    return { message: 'Deployment deactivated' };
  }

  async getWorkerSchedule(workerId, date) {
    if (!workerId) throw new ValidationError('workerId is required');
    const targetDate = date || new Date().toISOString().split('T')[0];
    const snapshot = await db.collection('deployments')
      .where('workerId', '==', workerId)
      .where('status', '==', 'active').get();
    const deployments = [];
    snapshot.forEach(doc => {
      const d = doc.data();
      if (!d.startDate || targetDate >= d.startDate) {
        if (!d.endDate || targetDate <= d.endDate) deployments.push({ id: doc.id, ...d });
      }
    });
    return { count: deployments.length, deployments };
  }

  async getPlannedManpower(date, stationId) {
    if (!stationId) return 0;
    const targetDate = date || new Date().toISOString().split('T')[0];
    const snapshot = await db.collection('deployments')
      .where('stationId', '==', stationId)
      .where('status', '==', 'active').get();
    let count = 0;
    snapshot.forEach(doc => {
      const d = doc.data();
      if (!d.startDate || targetDate >= d.startDate) {
        if (!d.endDate || targetDate <= d.endDate) count++;
      }
    });
    return count;
  }

  async getActualManpower(date, stationId) {
    if (!stationId) return 0;
    const targetDate = date || new Date().toISOString().split('T')[0];
    const startOfDay = new Date(`${targetDate}T00:00:00.000Z`);
    const endOfDay = new Date(`${targetDate}T23:59:59.999Z`);
    const snapshot = await db.collection('deployments')
      .where('isStartMarked', '==', true).get();
    let count = 0;
    const startStr = startOfDay.toISOString();
    const endStr = endOfDay.toISOString();
    snapshot.forEach(doc => {
      const d = doc.data();
      if (d.createdAt && d.createdAt >= startStr && d.createdAt <= endStr) {
        count++;
      }
    });
    return count;
  }

  async getManpowerVariance(query = {}) {
    const { date, stationId } = query;
    if (!stationId) throw new ValidationError('stationId is required');
    const targetDate = date || new Date().toISOString().split('T')[0];
    const planned = await this.getPlannedManpower(targetDate, stationId);
    const actual = await this.getActualManpower(targetDate, stationId);
    const variance = planned - actual;
    return {
      date: targetDate,
      stationId,
      planned,
      actual,
      variance,
      variancePercentage: planned > 0 ? parseFloat(((variance / planned) * 100).toFixed(2)) : 0,
      status: variance === 0 ? 'FULLY_STAFFED' : variance < 0 ? 'OVER_STAFFED' : 'SHORTAGE'
    };
  }

  async getShiftWiseManpower(date, stationId) {
    if (!stationId) throw new ValidationError('stationId is required');
    const targetDate = date || new Date().toISOString().split('T')[0];
    const [deploySnap] = await Promise.all([
      db.collection('deployments').where('stationId', '==', stationId).where('status', '==', 'active').get(),
    ]);
    const deployments = [];
    deploySnap.forEach(doc => {
      const d = doc.data();
      if (!d.startDate || targetDate >= d.startDate) {
        if (!d.endDate || targetDate <= d.endDate) deployments.push(d);
      }
    });
    const shiftMap = {};
    for (const dep of deployments) {
      const shiftId = dep.shiftId || 'unknown';
      if (!shiftMap[shiftId]) shiftMap[shiftId] = { shiftId, planned: 0, actual: 0, workerIds: [] };
      shiftMap[shiftId].planned++;
      shiftMap[shiftId].workerIds.push(dep.workerId);
    }
    const shifts = Object.values(shiftMap).map(s => ({
      ...s,
      variance: s.planned - s.actual,
      variancePercentage: s.planned > 0 ? parseFloat((((s.planned - s.actual) / s.planned) * 100).toFixed(2)) : 0
    }));
    return { date: targetDate, stationId, shifts, totalPlanned: deployments.length, totalActual: 0 };
  }
}

export const deploymentService = new DeploymentService();
