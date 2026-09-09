import { db } from '../database/index.js';
import { NotFoundError, ValidationError, ConflictError, ForbiddenError } from '../errors/index.js';
import { paginate } from '../utils/paginate.js';

const VALID_SHIFT_TYPES = ['morning', 'afternoon', 'night'];
const VALID_SHIFT_TIMES = {
  morning: { start: '06:00', end: '14:00' },
  afternoon: { start: '14:00', end: '22:00' },
  night: { start: '22:00', end: '06:00' }
};

class ShiftService {
  async createShift(userData, body) {
    const { shiftType, stationId, customStartTime, customEndTime, maxWorkers, description } = body;
    if (!shiftType || !stationId) throw new ValidationError('shiftType and stationId are required');
    if (!VALID_SHIFT_TYPES.includes(shiftType.toLowerCase())) {
      throw new ValidationError(`shiftType must be one of: ${VALID_SHIFT_TYPES.join(', ')}`);
    }

    const stationDoc = await db.collection('stations').doc(stationId).get();
    if (!stationDoc.exists) throw new NotFoundError('Station not found');

    const existing = await db.collection('shifts')
      .where('shiftType', '==', shiftType.toLowerCase())
      .where('stationId', '==', stationId)
      .where('status', '==', 'active').limit(1).get();
    if (!existing.empty) throw new ConflictError(`Shift ${shiftType} already exists for this station`);

    const defaults = VALID_SHIFT_TIMES[shiftType.toLowerCase()];
    const ref = db.collection('shifts').doc();
    const data = {
      uid: ref.id, shiftType: shiftType.toLowerCase(),
      stationId, stationName: stationDoc.data().stationName || '',
      startTime: customStartTime || defaults.start,
      endTime: customEndTime || defaults.end,
      maxWorkers: Math.max(1, Number(maxWorkers) || 50),
      description: description || '',
      supervisors: [], workers: [],
      status: 'active',
      createdBy: userData.uid,
      createdAt: new Date().toISOString(), updatedAt: new Date().toISOString()
    };
    await ref.set(data);
    return { message: 'Shift created', uid: ref.id, shift: data };
  }

  async getShifts(query = {}) {
    const { stationId, shiftType, status, limit = 50, cursor } = query;
    let firestoreQuery = db.collection('shifts');
    if (stationId) firestoreQuery = firestoreQuery.where('stationId', '==', stationId);
    if (shiftType) firestoreQuery = firestoreQuery.where('shiftType', '==', shiftType.toLowerCase());
    if (status) firestoreQuery = firestoreQuery.where('status', '==', status);
    const result = await paginate(firestoreQuery, { limit, cursor, orderBy: 'shiftType', orderDir: 'asc' });
    return { count: result.items.length, shifts: result.items, pagination: result.pagination };
  }

  async getShiftById(uid) {
    const doc = await db.collection('shifts').doc(uid).get();
    if (!doc.exists) throw new NotFoundError('Shift not found');
    return { id: doc.id, ...doc.data() };
  }

  async updateShift(uid, body) {
    const ref = db.collection('shifts').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Shift not found');
    const updates = {};
    const allowed = ['startTime', 'endTime', 'maxWorkers', 'description', 'status'];
    for (const key of allowed) {
      if (body[key] !== undefined) updates[key] = body[key];
    }
    updates.updatedAt = new Date().toISOString();
    await ref.update(updates);
    return { message: 'Shift updated', uid };
  }

  async deleteShift(uid) {
    const ref = db.collection('shifts').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Shift not found');
    await ref.update({ status: 'inactive', deletedAt: new Date().toISOString(), updatedAt: new Date().toISOString() });
    return { message: 'Shift deactivated' };
  }

  async assignSupervisor(uid, supervisorId) {
    const shiftRef = db.collection('shifts').doc(uid);
    const shiftDoc = await shiftRef.get();
    if (!shiftDoc.exists) throw new NotFoundError('Shift not found');

    const userDoc = await db.collection('users').doc(supervisorId).get();
    if (!userDoc.exists) throw new NotFoundError('User not found');
    const userData = userDoc.data();

    const supervisors = shiftDoc.data().supervisors || [];
    if (!supervisors.find(s => s.uid === supervisorId)) {
      supervisors.push({ uid: supervisorId, name: userData.fullName || userData.name || 'Unknown', assignedAt: new Date().toISOString() });
      await shiftRef.update({ supervisors, updatedAt: new Date().toISOString() });
    }
    return { message: 'Supervisor assigned', uid };
  }

  async assignWorker(uid, workerId) {
    const shiftRef = db.collection('shifts').doc(uid);
    const shiftDoc = await shiftRef.get();
    if (!shiftDoc.exists) throw new NotFoundError('Shift not found');

    const userDoc = await db.collection('users').doc(workerId).get();
    if (!userDoc.exists) throw new NotFoundError('User not found');
    const userData = userDoc.data();

    const shiftData = shiftDoc.data();
    const workers = shiftData.workers || [];
    if (workers.length >= (shiftData.maxWorkers || 50)) throw new ValidationError('Shift already at maximum capacity');

    if (!workers.find(w => w.uid === workerId)) {
      workers.push({ uid: workerId, name: userData.fullName || userData.name || 'Unknown', assignedAt: new Date().toISOString() });
      await shiftRef.update({ workers, updatedAt: new Date().toISOString() });
    }
    return { message: 'Worker assigned', uid };
  }

  // Reassign a worker's shift. Contract supervisors may only reassign workers
  // within their own roster (same contract, and either the worker belongs to
  // them in the supervisorWorkers roster or there is no other supervisor);
  // contractor admins / masters may reassign any worker in their contract.
  async reassignWorkerShift(body, user) {
    const { workerId, shiftType } = body;
    if (!workerId) throw new ValidationError('workerId is required');
    if (!shiftType || !VALID_SHIFT_TYPES.includes(String(shiftType).toLowerCase())) {
      throw new ValidationError(`shiftType must be one of: ${VALID_SHIFT_TYPES.join(', ')}`);
    }
    const targetType = String(shiftType).toLowerCase();

    // The supplied id may be a users uid OR a supervisorWorkers roster uid.
    // Resolve to the real user (who actually performs tasks) where possible.
    let workerDoc = await db.collection('users').doc(workerId).get();
    let worker = workerDoc.exists ? workerDoc.data() : null;
    let resolvedWorkerId = workerDoc.exists ? workerId : null;

    if (!workerDoc.exists) {
      const rosterDoc = await db.collection('supervisorWorkers').doc(workerId).get();
      if (!rosterDoc.exists) throw new NotFoundError('Worker not found');
      const roster = rosterDoc.data();
      const phone = roster.phone || '';
      const name = roster.fullName || '';
      let userSnap = null;
      if (phone) {
        userSnap = await db.collection('users').where('mobile', '==', phone).limit(1).get();
        if (userSnap.empty) userSnap = await db.collection('users').where('phone', '==', phone).limit(1).get();
      }
      if ((!userSnap || userSnap.empty) && name) {
        userSnap = await db.collection('users').where('fullName', '==', name).limit(1).get().catch(() => null);
      }
      if (userSnap && !userSnap.empty) {
        resolvedWorkerId = userSnap.docs[0].id;
        worker = userSnap.docs[0].data();
      }
    }
    // Fall back to a lightweight worker record carrying just the info we need.
    if (!worker) {
      const rosterDoc = await db.collection('supervisorWorkers').doc(workerId).get();
      worker = { fullName: rosterDoc.exists ? rosterDoc.data().fullName : 'Unknown', phone: rosterDoc.exists ? rosterDoc.data().phone : '', stationId: rosterDoc.exists ? rosterDoc.data().stationId : '' };
      resolvedWorkerId = resolvedWorkerId || workerId;
    }

    const role = (user?.role || '').toUpperCase().replace(/\s+/g, '_');
    const isAdmin = ['SUPER_ADMIN', 'COMPANY_MASTER', 'RAILWAY_MASTER', 'ADMIN', 'CONTRACTOR_ADMIN', 'CONTRACTOR_MASTER']
      .includes(role);
    if (!isAdmin) {
      // Supervisor path: must own the worker's roster entry (same contract +
      // either created by them or unclaimed by another supervisor).
      const isSupervisor = role === 'CONTRACTOR_SUPERVISOR';
      if (!isSupervisor) throw new ForbiddenError('You are not allowed to reassign shifts');
      if (worker.contractId && user.contractId && worker.contractId !== user.contractId) {
        throw new ForbiddenError('You can only reassign shifts for workers in your contract');
      }
      const rosterQuery = await db.collection('supervisorWorkers')
        .where('isActive', '==', true)
        .where('supervisorId', '==', user.uid)
        .limit(300)
        .get();
      const rosterHas = rosterQuery.docs.some(doc => {
        const d = doc.data();
        return (d.uid && d.uid === workerId)
          || (d.uid && resolvedWorkerId && d.uid === resolvedWorkerId)
          || (d.fullName && d.fullName === worker.fullName)
          || (d.phone && (d.phone === worker.mobile || d.phone === worker.phone || d.phone === worker.email));
      });
      if (!rosterHas) {
        throw new ForbiddenError('This worker is not on your roster');
      }
    }

    // Use the resolved user uid for assignment updates (they key assignments).
    const effectiveWorkerId = resolvedWorkerId || workerId;
    const workerName = worker.fullName || worker.name || 'Unknown';

    // Resolve the target shift document for the worker's station + shift type.
    const stationId = worker.stationId || worker.stations?.[0] || '';
    const shiftsSnap = await db.collection('shifts')
      .where('shiftType', '==', targetType)
      .where('status', '==', 'active')
      .limit(50)
      .get();
    let shiftSnapshot = null;
    for (const s of shiftsSnap.docs) {
      const sd = s.data();
      if (stationId && sd.stationId === stationId) { shiftSnapshot = { id: s.id, data: sd }; break; }
    }
    if (!shiftSnapshot && shiftsSnap.size === 1) {
      const only = shiftsSnap.docs[0];
      shiftSnapshot = { id: only.id, data: only.data() };
    }
    if (!shiftSnapshot) {
      // Dynamic fallback: ensure a shift document exists for this worker's
      // station + type so the membership is recorded consistently.
      const ref = db.collection('shifts').doc();
      shiftSnapshot = {
        id: ref.id,
        data: {
          uid: ref.id, shiftType: targetType, stationId: stationId || '',
          startTime: VALID_SHIFT_TIMES[targetType].start,
          endTime: VALID_SHIFT_TIMES[targetType].end,
          maxWorkers: 50, supervisors: [], workers: [],
          status: 'active', createdAt: new Date().toISOString(), updatedAt: new Date().toISOString(),
        },
      };
      await db.collection('shifts').doc(shiftSnapshot.id).set(shiftSnapshot.data);
    }

    const batch = db.batch();

    // 1) Update shift membership: remove the worker from any other active shift,
    //    then add them to the target shift.
    const allShiftsSnap = await db.collection('shifts')
      .where('status', '==', 'active')
      .limit(200)
      .get();
    for (const s of allShiftsSnap.docs) {
      if (s.id === shiftSnapshot.id) continue;
      const sd = s.data();
      const workers = (sd.workers || []).filter(w => (w.uid !== effectiveWorkerId));
      if (workers.length !== (sd.workers || []).length) {
        batch.update(db.collection('shifts').doc(s.id), { workers, updatedAt: new Date().toISOString() });
      }
    }
    const targetWorkers = shiftSnapshot.data.workers || [];
    if (!targetWorkers.some(w => w.uid === effectiveWorkerId)) {
      targetWorkers.push({ uid: effectiveWorkerId, name: workerName, assignedAt: new Date().toISOString() });
      batch.update(db.collection('shifts').doc(shiftSnapshot.id), { workers: targetWorkers, updatedAt: new Date().toISOString() });
    }

    // 2) Update every active area-worker assignment for this worker.
    const assignmentsSnap = await db.collection('areaWorkerAssignments')
      .where('workerId', '==', effectiveWorkerId)
      .where('isActive', '==', true)
      .limit(200)
      .get();
    let assignmentCount = 0;
    assignmentsSnap.forEach(aDoc => {
      batch.update(db.collection('areaWorkerAssignments').doc(aDoc.id), {
        shift: targetType,
        updatedAt: new Date().toISOString(),
      });
      assignmentCount++;
    });

    await batch.commit();

    return {
      message: `Shift reassigned to ${targetType}`, workerId, workerName, shift: targetType,
      assignmentsUpdated: assignmentCount,
    };
  }

  async removeAssignment(uid, userId) {
    const shiftRef = db.collection('shifts').doc(uid);
    const shiftDoc = await shiftRef.get();
    if (!shiftDoc.exists) throw new NotFoundError('Shift not found');
    const data = shiftDoc.data();
    const supervisors = (data.supervisors || []).filter(s => s.uid !== userId);
    const workers = (data.workers || []).filter(w => w.uid !== userId);
    await shiftRef.update({ supervisors, workers, updatedAt: new Date().toISOString() });
    return { message: 'User removed from shift' };
  }
}

export const shiftService = new ShiftService();
