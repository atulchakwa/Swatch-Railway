import { db, admin } from '../database/index.js';
import { NotFoundError, ValidationError } from '../errors/index.js';
import { geofenceService } from './geofenceService.js';
import logger from '../logger/index.js';

const VALID_SHIFTS = ['morning', 'afternoon', 'night'];
const VALID_STATUSES = ['present', 'absent', 'late', 'half_day', 'on_leave'];
const VALID_CAPTURE_MODES = ['biometric', 'manual', 'api', 'gps'];
const VALID_LEAVE_TYPES = ['sick', 'casual', 'earned', 'emergency', 'other'];

class StationAttendanceService {
  async markAttendance(user, data) {
    const { stationId, workerId, date, shift, captureMode, photoUrl, reason, workerName, latitude, longitude } = data;
    if (!stationId || !workerId || !date || !shift) throw new ValidationError('stationId, workerId, date, and shift are required');
    if (!VALID_SHIFTS.includes(shift.toLowerCase())) throw new ValidationError(`shift must be one of: ${VALID_SHIFTS.join(', ')}`);
    const mode = (captureMode || 'manual').toLowerCase();
    if (!VALID_CAPTURE_MODES.includes(mode)) throw new ValidationError(`captureMode must be one of: ${VALID_CAPTURE_MODES.join(', ')}`);

    const stationDoc = await db.collection('stations').doc(stationId).get();
    if (!stationDoc.exists) throw new NotFoundError('Station not found');

    const workerDoc = await db.collection('users').doc(workerId).get();
    const resolvedWorkerName = workerName || (workerDoc.exists ? (workerDoc.data().fullName || workerDoc.data().name) : 'Unknown Worker');

    const attendanceId = `${stationId}_${date}_${shift}_${workerId}`;
    const existingDoc = await db.collection('station_attendance').doc(attendanceId).get();
    if (existingDoc.exists) throw new ValidationError(`Attendance already marked for worker ${workerId} on ${date} ${shift} shift`);

    const now = new Date().toISOString();
    const currentHour = parseInt(now.split('T')[1].split(':')[0]);
    const isLate = currentHour >= (shift === 'morning' ? 8 : shift === 'afternoon' ? 15 : 23);
    const status = data.status || (isLate ? 'late' : 'present');
    if (!VALID_STATUSES.includes(status)) throw new ValidationError(`status must be one of: ${VALID_STATUSES.join(', ')}`);

    let geofenceValid = null;
    if (latitude != null && longitude != null && (mode === 'gps' || mode === 'biometric')) {
      geofenceValid = await geofenceService.isWithinGeofence(stationId, latitude, longitude);
    }

    const record = {
      attendanceId, stationId, stationName: stationDoc.data().stationName || '',
      workerId, workerName: resolvedWorkerName, date, shift: shift.toLowerCase(),
      status, captureMode: mode, isManual: mode === 'manual', isLate,
      photoUrl: photoUrl || '', reason: reason || '',
      latitude: latitude || null, longitude: longitude || null,
      geofenceValid: geofenceValid?.within ?? true,
      geofenceCheck: geofenceValid,
      markedBy: user.uid, markedByName: user.fullName || user.name || '', markedAt: now, createdAt: now,
    };
    await db.collection('station_attendance').doc(attendanceId).set(record);
    logger.info('StationAttendance', `Attendance marked: ${workerId} @ ${stationId} on ${date} ${shift}`);
    return { message: 'Attendance marked successfully', attendanceId, record };
  }

  async markBulkAttendance(user, data) {
    const { stationId, date, shift, workers } = data;
    if (!stationId || !date || !shift || !Array.isArray(workers) || workers.length === 0) throw new ValidationError('stationId, date, shift, and workers array are required');
    const stationDoc = await db.collection('stations').doc(stationId).get();
    if (!stationDoc.exists) throw new NotFoundError('Station not found');
    const now = new Date().toISOString();
    const batch = db.batch();
    const results = [];
    for (const w of workers) {
      const attendanceId = `${stationId}_${date}_${shift}_${w.workerId}`;
      const existing = await db.collection('station_attendance').doc(attendanceId).get();
      if (existing.exists) { results.push({ workerId: w.workerId, status: 'skipped', reason: 'Already marked' }); continue; }
      batch.set(db.collection('station_attendance').doc(attendanceId), {
        attendanceId, stationId, stationName: stationDoc.data().stationName || '',
        workerId: w.workerId, workerName: w.workerName || 'Unknown',
        date, shift: shift.toLowerCase(), status: w.status || 'present',
        captureMode: w.captureMode || 'manual', isManual: (w.captureMode || 'manual') === 'manual',
        isLate: false, photoUrl: w.photoUrl || '', reason: w.reason || '',
        latitude: w.latitude || null, longitude: w.longitude || null,
        markedBy: user.uid, markedByName: user.fullName || '', markedAt: now, createdAt: now,
      });
      results.push({ workerId: w.workerId, status: 'marked', attendanceId });
    }
    await batch.commit();
    return { message: 'Bulk attendance processed', results };
  }

  async getShiftAttendance(stationId, date, shift) {
    if (!stationId || !date) throw new ValidationError('stationId and date are required');
    let query = db.collection('station_attendance').where('stationId', '==', stationId).where('date', '==', date);
    if (shift) query = query.where('shift', '==', shift.toLowerCase());
    const snapshot = await query.orderBy('createdAt', 'desc').limit(500).get();
    const records = []; snapshot.forEach(doc => records.push(doc.data()));
    const summary = { total: records.length, present: 0, absent: 0, late: 0, halfDay: 0, onLeave: 0 };
    for (const r of records) { switch (r.status) { case 'present': summary.present++; break; case 'absent': summary.absent++; break; case 'late': summary.late++; break; case 'half_day': summary.halfDay++; break; case 'on_leave': summary.onLeave++; break; } }
    return { stationId, date, shift: shift || 'all', summary, records };
  }

  async getPlannedVsActual(stationId, date, shift) {
    if (!stationId || !date || !shift) throw new ValidationError('stationId, date, and shift are required');
    const planQuery = await db.collection('execution_plans').where('stationId', '==', stationId).where('status', '==', 'APPROVED').orderBy('createdAt', 'desc').limit(1).get();
    let plannedCount = 0;
    if (!planQuery.empty) { const plan = planQuery.docs[0].data(); plannedCount = (plan.manpowerPlan || {})[shift.toLowerCase()] || 0; }
    const attendanceSnap = await db.collection('station_attendance').where('stationId', '==', stationId).where('date', '==', date).where('shift', '==', shift.toLowerCase()).get();
    let actualPresent = 0;
    attendanceSnap.forEach(doc => { const s = doc.data().status; if (s === 'present' || s === 'late') actualPresent++; });
    return { stationId, date, shift, planned: plannedCount, actual: actualPresent, variance: actualPresent - plannedCount, shortfall: Math.max(0, plannedCount - actualPresent), status: actualPresent >= plannedCount ? 'ADEQUATE' : 'SHORTFALL' };
  }

  async getMonthlySummary(stationId, month, year) {
    if (!stationId || !month || !year) throw new ValidationError('stationId, month, year are required');
    const monthPad = String(month).padStart(2, '0');
    const snapshot = await db.collection('station_attendance').where('stationId', '==', stationId).where('date', '>=', `${year}-${monthPad}-01`).where('date', '<=', `${year}-${monthPad}-31`).get();
    const records = []; snapshot.forEach(doc => records.push(doc.data()));
    const workerMap = {};
    for (const r of records) {
      if (!workerMap[r.workerId]) workerMap[r.workerId] = { workerId: r.workerId, workerName: r.workerName, present: 0, absent: 0, late: 0, halfDay: 0, onLeave: 0, total: 0 };
      workerMap[r.workerId].total++;
      switch (r.status) { case 'present': workerMap[r.workerId].present++; break; case 'absent': workerMap[r.workerId].absent++; break; case 'late': workerMap[r.workerId].late++; break; case 'half_day': workerMap[r.workerId].halfDay++; break; case 'on_leave': workerMap[r.workerId].onLeave++; break; }
    }
    const totalPresent = records.filter(r => r.status === 'present' || r.status === 'late').length;
    return { stationId, month, year, totalDays: [...new Set(records.map(r => r.date))].length, totalRecords: records.length, totalPresent, totalAbsent: records.filter(r => r.status === 'absent').length, attendancePercentage: records.length > 0 ? Math.round(totalPresent / records.length * 100) : 0, workerSummaries: Object.values(workerMap) };
  }

  async flagAbsences(stationId, date, shift) {
    if (!stationId || !date || !shift) throw new ValidationError('stationId, date, shift are required');
    const shiftDoc = await db.collection('shifts').where('stationId', '==', stationId).where('shiftType', '==', shift.toLowerCase()).where('status', '==', 'active').limit(1).get();
    if (shiftDoc.empty) return { message: 'No active shift found', flagged: 0 };
    const assignedWorkers = shiftDoc.docs[0].data().workers || [];
    const attendanceSnap = await db.collection('station_attendance').where('stationId', '==', stationId).where('date', '==', date).where('shift', '==', shift.toLowerCase()).get();
    const markedWorkerIds = new Set(); attendanceSnap.forEach(doc => markedWorkerIds.add(doc.data().workerId));
    const batch = db.batch(); let flagged = 0; const now = new Date().toISOString();
    for (const w of assignedWorkers) {
      if (!markedWorkerIds.has(w.uid)) {
        const attendanceId = `${stationId}_${date}_${shift}_${w.uid}`;
        const issueRef = db.collection('attendance_issues').doc();
        batch.set(issueRef, { uid: issueRef.id, stationId, workerId: w.uid, workerName: w.name, date, shift: shift.toLowerCase(), issueType: 'absent_not_marked', attendanceId, flaggedAt: now, resolved: false });
        batch.set(db.collection('station_attendance').doc(attendanceId), { attendanceId, stationId, workerId: w.uid, workerName: w.name, date, shift: shift.toLowerCase(), status: 'absent', captureMode: 'auto_flag', isManual: false, isLate: false, photoUrl: '', reason: 'Auto-flagged as absent', markedBy: 'system', markedByName: 'System', markedAt: now, createdAt: now }, { merge: true });
        flagged++;
      }
    }
    if (flagged > 0) await batch.commit();
    return { message: `${flagged} worker(s) flagged as absent`, flagged };
  }

  async updateAttendance(attendanceId, data) {
    const ref = db.collection('station_attendance').doc(attendanceId);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Attendance record not found');
    const allowed = ['status', 'reason', 'photoUrl', 'latitude', 'longitude'];
    const updates = { updatedAt: new Date().toISOString() };
    for (const key of allowed) { if (data[key] !== undefined) updates[key] = data[key]; }
    if (data.status && !VALID_STATUSES.includes(data.status)) throw new ValidationError(`status must be one of: ${VALID_STATUSES.join(', ')}`);
    await ref.update(updates);
    return { message: 'Attendance updated', attendanceId };
  }

  async getWorkerHistory(workerId, stationId, startDate, endDate) {
    if (!workerId) throw new ValidationError('workerId is required');
    let query = db.collection('station_attendance').where('workerId', '==', workerId);
    if (stationId) query = query.where('stationId', '==', stationId);
    if (startDate) query = query.where('date', '>=', startDate);
    if (endDate) query = query.where('date', '<=', endDate);
    const snapshot = await query.orderBy('date', 'desc').limit(365).get();
    const records = []; snapshot.forEach(doc => records.push(doc.data()));
    return { workerId, count: records.length, records };
  }

  async applyLeave(user, data) {
    const { workerId, leaveType, startDate, endDate, reason, stationId } = data;
    if (!workerId || !leaveType || !startDate || !endDate) throw new ValidationError('workerId, leaveType, startDate, endDate are required');
    if (!VALID_LEAVE_TYPES.includes(leaveType)) throw new ValidationError(`leaveType must be one of: ${VALID_LEAVE_TYPES.join(', ')}`);
    const ref = db.collection('leave_applications').doc();
    const record = { uid: ref.id, workerId, workerName: data.workerName || '', stationId: stationId || '', leaveType, startDate, endDate, reason: reason || '', status: 'PENDING', appliedBy: user.uid, appliedByName: user.fullName || '', appliedAt: new Date().toISOString(), updatedAt: new Date().toISOString() };
    await ref.set(record);
    return { message: 'Leave applied', uid: ref.id, leave: record };
  }

  async approveLeave(uid, user, body) {
    const ref = db.collection('leave_applications').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Leave application not found');
    await ref.update({ status: body.action === 'reject' ? 'REJECTED' : 'APPROVED', rejectionReason: body.reason || null, reviewedBy: user.uid, reviewedAt: new Date().toISOString(), updatedAt: new Date().toISOString() });
    return { message: `Leave ${body.action === 'reject' ? 'rejected' : 'approved'}` };
  }

  async listLeaves(query = {}) {
    const { workerId, stationId, status, startDate, endDate, limit = 50 } = query;
    let q = db.collection('leave_applications');
    if (workerId) q = q.where('workerId', '==', workerId);
    if (stationId) q = q.where('stationId', '==', stationId);
    if (status) q = q.where('status', '==', status);
    if (startDate) q = q.where('startDate', '>=', startDate);
    if (endDate) q = q.where('endDate', '<=', endDate);
    const snapshot = await q.orderBy('appliedAt', 'desc').limit(parseInt(limit)).get();
    const leaves = []; snapshot.forEach(doc => leaves.push(doc.data()));
    return { count: leaves.length, leaves };
  }

  async calculateOvertime(stationId, month, year) {
    if (!stationId || !month || !year) throw new ValidationError('stationId, month, year are required');
    const monthPad = String(month).padStart(2, '0');
    const snapshot = await db.collection('station_attendance').where('stationId', '==', stationId).where('date', '>=', `${year}-${monthPad}-01`).where('date', '<=', `${year}-${monthPad}-31`).get();
    const records = []; snapshot.forEach(doc => records.push(doc.data()));
    const workerOt = {};
    for (const r of records) {
      if (!workerOt[r.workerId]) workerOt[r.workerId] = { workerId: r.workerId, workerName: r.workerName, totalDays: 0, extraShifts: 0 };
      workerOt[r.workerId].totalDays++;
    }
    const shiftCounts = {};
    for (const r of records) {
      const key = `${r.workerId}_${r.date}`;
      if (!shiftCounts[key]) shiftCounts[key] = new Set();
      shiftCounts[key].add(r.shift);
    }
    for (const [key, shifts] of Object.entries(shiftCounts)) {
      if (shifts.size > 1) {
        const wid = key.split('_')[0];
        if (workerOt[wid]) workerOt[wid].extraShifts += shifts.size - 1;
      }
    }
    return { stationId, month, year, workerOvertime: Object.values(workerOt) };
  }

  async exportAttendance(stationId, month, year) {
    const data = await this.getMonthlySummary(stationId, month, year);
    const headers = 'Worker Name,Total Days,Present,Absent,Late,Half Day,On Leave\n';
    const rows = data.workerSummaries.map(w => `${w.workerName},${w.total},${w.present},${w.absent},${w.late},${w.halfDay},${w.onLeave}`).join('\n');
    return { csv: headers + rows, filename: `attendance_${stationId}_${month}_${year}.csv` };
  }
}

export const stationAttendanceService = new StationAttendanceService();
