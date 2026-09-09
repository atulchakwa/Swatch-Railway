import { db } from '../database/index.js';
import { NotFoundError, ValidationError, ForbiddenError } from '../errors/index.js';

class AreaAssignmentService {
  async createAssignment(data, user) {
    const { stationId, platformId, areaId, workerId, workerName, shift, startDate, endDate, isPrimary } = data;
    if (!stationId || !areaId || !workerId || !workerName || !shift || !startDate) {
      throw new ValidationError('stationId, areaId, workerId, workerName, shift, startDate are required');
    }

    let areaDoc = await db.collection('areas').doc(areaId).get();
    if (!areaDoc.exists) {
      areaDoc = await db.collection('stationAreas').doc(areaId).get();
    }
    if (!areaDoc.exists) throw new NotFoundError('Area not found');
    if (areaDoc.data().stationId !== stationId) throw new ValidationError('Area does not belong to specified station');

    const ref = db.collection('areaWorkerAssignments').doc();
    const assignment = {
      uid: ref.id, stationId, platformId: platformId || null, areaId,
      workerId, workerName, shift,
      startDate, endDate: endDate || null,
      isPrimary: isPrimary === true,
      isActive: true,
      status: 'active',
      assignedBy: user.uid, assignedByName: user.fullName || user.name || 'Unknown',
      assignedAt: new Date().toISOString(), updatedAt: new Date().toISOString()
    };
    await ref.set(assignment);
    return { message: 'Worker assigned to area', uid: ref.id, assignment };
  }

  async listAssignments(query = {}, user) {
    const { stationId, platformId, areaId, workerId, isActive, status } = query;
    let q = db.collection('areaWorkerAssignments');

    if (stationId) q = q.where('stationId', '==', stationId);
    if (platformId) q = q.where('platformId', '==', platformId);
    if (areaId) q = q.where('areaId', '==', areaId);
    if (workerId) q = q.where('workerId', '==', workerId);
    if (isActive !== undefined) q = q.where('isActive', '==', isActive === 'true' || isActive === true);
    if (status) q = q.where('status', '==', status);

    const snapshot = await q.limit(200).get();
    const assignments = [];
    snapshot.forEach(doc => assignments.push({ id: doc.id, ...doc.data() }));
    return { count: assignments.length, assignments };
  }

  async getAreaWorkers(areaId) {
    if (!areaId) throw new ValidationError('areaId is required');
    const snapshot = await db.collection('areaWorkerAssignments')
      .where('areaId', '==', areaId)
      .where('isActive', '==', true)
      .limit(100).get();
    const workers = [];
    snapshot.forEach(doc => workers.push({ id: doc.id, ...doc.data() }));
    return { count: workers.length, workers };
  }

  async getWorkerAreas(workerId) {
    if (!workerId) throw new ValidationError('workerId is required');
    const snapshot = await db.collection('areaWorkerAssignments')
      .where('workerId', '==', workerId)
      .where('isActive', '==', true)
      .limit(100).get();
    const areas = [];
    snapshot.forEach(doc => areas.push({ id: doc.id, ...doc.data() }));
    return { count: areas.length, assignments: areas };
  }

  async updateAssignment(uid, data, user) {
    const ref = db.collection('areaWorkerAssignments').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Assignment not found');
    const assignment = doc.data();
    const allowed = ['shift', 'startDate', 'endDate', 'isActive', 'isPrimary', 'platformId', 'status'];
    const updates = { updatedAt: new Date().toISOString(), updatedBy: user.uid };
    for (const key of allowed) {
      if (data[key] !== undefined) updates[key] = data[key];
    }

    // Shift changes are scoped: contract supervisors may only change the shift
    // of workers on their own roster; admins/masters may change any.
    if (data.shift !== undefined && data.shift !== assignment.shift) {
      await this._assertShiftScope(assignment.workerId, assignment.workerName, user, doc.id);
    }

    await ref.update(updates);
    return { message: 'Assignment updated', uid };
  }

  async _assertShiftScope(workerId, workerName, user, assignmentId) {
    const role = (user?.role || '').toUpperCase().replace(/\s+/g, '_');
    if (['SUPER_ADMIN', 'COMPANY_MASTER', 'RAILWAY_MASTER', 'ADMIN', 'CONTRACTOR_ADMIN', 'CONTRACTOR_MASTER'].includes(role)) {
      return;
    }
    if (role !== 'CONTRACTOR_SUPERVISOR') {
      throw new ForbiddenError('You are not allowed to change worker shifts');
    }
    const workerDoc = await db.collection('users').doc(workerId).get();
    const worker = workerDoc.exists ? workerDoc.data() : { fullName: workerName || '' };
    if (worker.contractId && user.contractId && worker.contractId !== user.contractId) {
      throw new ForbiddenError('You can only change shifts for workers in your contract');
    }
    const rosterQuery = await db.collection('supervisorWorkers')
      .where('isActive', '==', true)
      .where('supervisorId', '==', user.uid)
      .limit(300)
      .get();
    const rosterHas = rosterQuery.docs.some(aDoc => {
      const d = aDoc.data();
      return (d.uid && d.uid === workerId)
        || (d.fullName && d.fullName === worker.fullName)
        || (d.phone && (d.phone === worker.mobile || d.phone === worker.phone || d.phone === worker.email));
    });
    if (!rosterHas) {
      throw new ForbiddenError('This worker is not on your roster');
    }
  }

  async deleteAssignment(uid) {
    const ref = db.collection('areaWorkerAssignments').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Assignment not found');
    await ref.update({ isActive: false, status: 'inactive', updatedAt: new Date().toISOString() });
    return { message: 'Assignment deactivated' };
  }

  async bulkAssign(data, user) {
    const { assignments } = data;
    if (!assignments || !Array.isArray(assignments) || assignments.length === 0) {
      throw new ValidationError('assignments array is required');
    }
    const results = [];
    for (const a of assignments) {
      const result = await this.createAssignment(a, user);
      results.push(result);
    }
    return { message: `${results.length} workers assigned`, count: results.length, results };
  }
}

export const areaAssignmentService = new AreaAssignmentService();
