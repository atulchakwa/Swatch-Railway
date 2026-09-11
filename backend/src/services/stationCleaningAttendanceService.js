import { db, admin } from '../database/index.js';
import logger from '../logger/index.js';
import { NotFoundError, ValidationError, ForbiddenError } from '../errors/index.js';
import { fcmService } from './fcmService.js';

class StationCleaningAttendanceService {
  async markAttendance(userData, body) {
    const allowedFields = ['runInstanceId', 'stationId', 'attendanceType', 'imageUrl', 'latitude', 'longitude', 'deviceTimestamp', 'mobileNumber', 'deviceId', 'livenessChallenge'];
    for (const key of Object.keys(body)) {
      if (!allowedFields.includes(key)) throw new ValidationError(`Invalid field: '${key}'`);
    }
    const { runInstanceId, stationId, attendanceType, imageUrl, latitude, longitude, deviceTimestamp, mobileNumber, deviceId, livenessChallenge } = body;
    if (!attendanceType || !deviceTimestamp) {
      throw new ValidationError('attendanceType and deviceTimestamp are required.');
    }
    const effectiveRunId = runInstanceId || `self_${userData.uid}_${new Date().toISOString().split('T')[0]}`;
    if (!['start', 'mid', 'end'].includes(attendanceType)) {
      throw new ValidationError("attendanceType must be 'start', 'mid', or 'end'");
    }
    const { uid: workerId, fullName: workerName } = userData;
    const finalWorkerName = workerName || 'Unknown Worker';
    let isLateAttendance = false;
    let lateByMinutes = 0;
    let firstAttendanceTime = null;

    // Liveness (biometric) verification — mirrors OBHS attendance flow
    if (livenessChallenge) {
      const { verifyFaceLiveness } = await import('./rekognitionService.js');
      const livenessResult = await verifyFaceLiveness(imageUrl, livenessChallenge);
      if (!livenessResult.matched && !livenessResult.error) {
        throw new ValidationError(`Liveness Verification Failed: ${livenessResult.reason}`);
      }
    }

    try {
      if (runInstanceId && attendanceType === 'start') {
        const runSnap = await db.collection('stationRuns').doc(runInstanceId).get();
        if (runSnap.exists) {
          const runData = runSnap.data();
          firstAttendanceTime = runData.first_attendance_time;
          const currentTimestamp = new Date(deviceTimestamp || new Date().toISOString());
          if (!firstAttendanceTime) {
            firstAttendanceTime = currentTimestamp.toISOString();
            await db.collection('stationRuns').doc(runInstanceId).update({ first_attendance_time: firstAttendanceTime, updatedAt: new Date().toISOString() });
          } else {
            const diffMs = currentTimestamp.getTime() - new Date(firstAttendanceTime).getTime();
            const diffMins = Math.floor(diffMs / 60000);
            if (diffMins > 15) { isLateAttendance = true; lateByMinutes = diffMins - 15; }
          }
        }
      }
    } catch (winErr) { logger.error('StationCleaning', '(Attendance Timing Engine) Error:', winErr); }

    const getISTDateString = (date) => {
      const ist = new Date(date.getTime() + 5.5 * 60 * 60 * 1000);
      return ist.toISOString().split('T')[0];
    };
    const todayIST = getISTDateString(new Date());

    const getTaskCompletion = async () => {
      try {
        const taskSnap = await db.collection('cleaningTasks')
          .where('workerId', '==', workerId)
          .where('date', '==', todayIST)
          .get();
        const tasks = [];
        taskSnap.forEach(doc => tasks.push(doc.data()));
        const doneStatuses = ['completed', 'approved'];
        const completedCount = tasks.filter(t => doneStatuses.includes(t.status)).length;
        const total = tasks.length;
        return { total, completedCount };
      } catch (e) {
        logger.error('StationCleaning', '(Attendance Task Completion) Error:', e);
        return { total: 0, completedCount: 0 };
      }
    };

    if (attendanceType !== 'start') {
      const { total, completedCount } = await getTaskCompletion();
      if (total === 0) {
        throw new ValidationError(`You have no cleaning tasks scheduled today. Mark 'start' attendance only.`);
      }
      if (attendanceType === 'mid' && completedCount < Math.ceil(total / 2)) {
        throw new ValidationError(
          `MID attendance requires at least half your tasks (${Math.ceil(total / 2)} of ${total}) completed. Currently ${completedCount} completed.`
        );
      }
      if (attendanceType === 'end' && completedCount < total) {
        throw new ValidationError(`END attendance requires all ${total} tasks completed. Currently ${completedCount} completed.`);
      }
    }

    const snapshot = await db.collection('station_cleaning_attendance').where('workerId', '==', workerId).get();
    let latestDoc = null;
    let latestTime = 0;
    snapshot.forEach(doc => {
      const data = doc.data();
      const time = new Date(data.createdAt).getTime();
      if (time > latestTime) {
        latestTime = time;
        latestDoc = doc;
      }
    });

    let attendanceDocId = `${effectiveRunId}_${workerId}`;
    let attendanceRef = db.collection('station_cleaning_attendance').doc(attendanceDocId);
    let attendanceDoc = await attendanceRef.get();

    if (latestDoc && getISTDateString(new Date(latestDoc.data().createdAt)) === todayIST) {
        attendanceDoc = latestDoc;
        attendanceDocId = latestDoc.id;
        attendanceRef = db.collection('station_cleaning_attendance').doc(attendanceDocId);
    } else if (attendanceDoc.exists && attendanceDoc.data().date !== todayIST) {
        attendanceDocId = `${effectiveRunId}_${workerId}_${todayIST}`;
        attendanceRef = db.collection('station_cleaning_attendance').doc(attendanceDocId);
        attendanceDoc = await attendanceRef.get();
    }
    const attendanceEntry = {
      photoUrl: imageUrl, deviceTimestamp, serverTimestamp: new Date().toISOString(),
      location: (latitude && longitude) ? { latitude, longitude } : null,
      mobileNumber: mobileNumber || null, deviceId: deviceId || null,
      isLate: isLateAttendance, lateByMinutes,
      firstAttendanceReference: firstAttendanceTime,
      status: isLateAttendance ? 'LATE' : 'PRESENT'
    };

    if (!attendanceDoc.exists) {
      if (attendanceType !== 'start') throw new ValidationError("You must submit 'start' attendance first.");
      await attendanceRef.set({
        uid: attendanceDocId, runInstanceId: effectiveRunId, stationId: stationId || null, workerId, workerName: finalWorkerName,
        date: todayIST,
        mobileNumber: mobileNumber || null, deviceId: deviceId || null,
        isStartMarked: true, isMidMarked: false, isEndMarked: false,
        attendanceStatus: isLateAttendance ? 'LATE' : 'PRESENT',
        lateByMinutes, firstAttendanceReference: firstAttendanceTime,
        identityAuditStatus: 'PENDING_VERIFICATION',
        startAttendance: attendanceEntry, midAttendance: null, endAttendance: null,
        createdAt: new Date().toISOString(), updatedAt: new Date().toISOString()
      });
    } else {
      const currentData = attendanceDoc.data();
      const updateData = { updatedAt: new Date().toISOString() };
      if (attendanceType === 'start') throw new ValidationError('Start attendance already submitted.');
      const baseStartPhoto = currentData.startAttendance?.photoUrl;
      if (!baseStartPhoto) throw new ValidationError('Baseline image missing from DB.');

      const { compareFaces } = await import('./rekognitionService.js');
      const faceVerification = await compareFaces(baseStartPhoto, imageUrl);
      const isInfraError = faceVerification.error === true;

      if (!faceVerification.matched && !isInfraError) {
        await attendanceRef.update({
          identityAuditStatus: 'MISMATCH_ALERT',
          lastMismatchReason: faceVerification.reason,
          lastMismatchSimilarity: faceVerification.similarity,
          lastMismatchAt: new Date().toISOString(),
          updatedAt: new Date().toISOString()
        });
        throw new ValidationError(
          `Identity Verification Failed. Face match score (${faceVerification.similarity}%) below threshold. ${faceVerification.reason}`
        );
      }

      if (attendanceType === 'mid') {
        if (currentData.midAttendance) throw new ValidationError('Mid attendance already submitted.');
        updateData.midAttendance = attendanceEntry;
        updateData.isMidMarked = true;
        updateData.identityAuditStatus = isInfraError ? 'MID_UNVERIFIED_REVIEW' : 'MID_VERIFIED';
      }
      if (attendanceType === 'end') {
        if (currentData.endAttendance) throw new ValidationError('End attendance already submitted.');
        updateData.endAttendance = attendanceEntry;
        updateData.isEndMarked = true;
        updateData.identityAuditStatus = isInfraError ? 'UNVERIFIED_REVIEW' : 'VERIFIED_SUCCESS';
      }
      updateData.attendanceStatus = isLateAttendance ? 'LATE' : 'PRESENT';
      if (isInfraError) {
        updateData.identityVerification = { status: 'PENDING_REVIEW', reason: faceVerification.reason };
        updateData.updatedAt = new Date().toISOString();
      }
      updateData.timingSnapshot = {
        isLate: isLateAttendance, lateByMinutes,
        firstAttendanceReference: firstAttendanceTime,
        recordedAt: new Date().toISOString()
      };
      await attendanceRef.update(updateData);
    }

    // Send shift summary reminder notification when end attendance is marked
    if (attendanceType === 'end') {
      try {
        const title = 'Shift Ended — Submit Photos';
        const body = 'You must photograph at least 5 critical areas and submit your shift summary to complete your shift.';
        const data = { type: 'shift_summary_reminder', stationId: stationId || '', shift: '' };
        fcmService.sendPush(workerId, title, body, data).catch(() => {});
      } catch (_) { /* notification failure should not block attendance */ }
    }

    return { success: true, message: `${attendanceType.toUpperCase()} attendance processed successfully.`, uid: attendanceDocId, isLate: isLateAttendance };
  }

  async getAttendanceStatus(runInstanceId, workerId) {
    if (!workerId) {
      throw new ValidationError('workerId is required.');
    }
    
    const getISTDateString = (date) => {
      const ist = new Date(date.getTime() + 5.5 * 60 * 60 * 1000);
      return ist.toISOString().split('T')[0];
    };
    const todayIST = getISTDateString(new Date());

    const snapshot = await db.collection('station_cleaning_attendance').where('workerId', '==', workerId).get();
    let latestData = null;
    let latestTime = 0;
    snapshot.forEach(doc => {
      const data = doc.data();
      const time = new Date(data.createdAt).getTime();
      if (time > latestTime) {
        latestTime = time;
        latestData = data;
      }
    });

    if (!latestData || getISTDateString(new Date(latestData.createdAt)) !== todayIST) {
      return { exists: false, isStartMarked: false, isMidMarked: false, isEndMarked: false, identityAuditStatus: null };
    }
    
    const data = latestData;
    return {
      exists: true,
      isStartMarked: data.isStartMarked || false,
      isMidMarked: data.isMidMarked || false,
      isEndMarked: data.isEndMarked || false,
      identityAuditStatus: data.identityAuditStatus || null,
      attendanceStatus: data.attendanceStatus || null,
      startAttendance: data.startAttendance || null,
      midAttendance: data.midAttendance || null,
      endAttendance: data.endAttendance || null,
      uid: data.uid,
      createdAt: data.createdAt,
      runInstanceId: data.runInstanceId,
      stationId: data.stationId || null
    };
  }

  async listAttendance(filters = {}, user) {
    const { runInstanceId, stationId, callerId, role } = filters;
    let query = db.collection('station_cleaning_attendance');
    if (runInstanceId) query = query.where('runInstanceId', '==', runInstanceId);
    const roleUpper = (role || '').toUpperCase();
    const isWorker = roleUpper === 'WORKER' || roleUpper === 'RAILWAY WORKER';
    if (!isWorker && user) {
      const userStations = user.stations || (user.stationId ? [user.stationId] : []);
      if (stationId) {
        if (userStations.length > 0 && !userStations.includes(stationId)) {
          throw new ForbiddenError('You can only access attendance for your assigned stations');
        }
        query = query.where('stationId', '==', stationId);
      } else if (userStations.length > 0) {
        query = query.where('stationId', 'in', userStations);
      }
    } else if (stationId) {
      query = query.where('stationId', '==', stationId);
    }
    const snapshot = await query.limit(200).get();
    let records = [];
    snapshot.forEach(doc => records.push(doc.data()));
    if (isWorker) records = records.filter(r => r.workerId === callerId);
    records.sort((a, b) => ((b.updatedAt || '') > (a.updatedAt || '') ? 1 : -1));
    return { count: records.length, records };
  }

  async reportAttendanceIssue(userData, body) {
    const { runInstanceId, stationId, issueType, remark, photoUrl, latitude, longitude, attendanceType } = body;
    if (!runInstanceId || !issueType) {
      throw new ValidationError('runInstanceId and issueType are required.');
    }
    const workerId = userData.uid;
    const workerName = userData.fullName || 'Unknown';
    const issueRef = db.collection('station_attendance_exceptions').doc();
    await issueRef.set({
      exceptionId: issueRef.id,
      runInstanceId,
      stationId: stationId || null,
      workerId,
      workerName,
      issueType,
      remark: remark || '',
      photoUrl: photoUrl || null,
      location: (latitude && longitude) ? { latitude, longitude } : null,
      attendanceType: attendanceType || null,
      status: 'PENDING',
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    });
    return { success: true, message: 'Attendance issue reported.', exceptionId: issueRef.id };
  }

  async getAttendanceExceptions(filters = {}) {
    const { status } = filters;
    let query = db.collection('station_attendance_exceptions');
    if (status) query = query.where('status', '==', status);
    const snapshot = await query.limit(200).get();
    const exceptions = [];
    snapshot.forEach(doc => exceptions.push(doc.data()));
    exceptions.sort((a, b) => ((b.createdAt || '') > (a.createdAt || '') ? 1 : -1));
    return { success: true, count: exceptions.length, exceptions };
  }

  async takeActionOnException(body) {
    const { exceptionId, action, adminRemark } = body;
    if (!exceptionId || !action) throw new ValidationError('exceptionId and action are required.');
    const validActions = ['APPROVED', 'REJECTED'];
    if (!validActions.includes(action)) throw new ValidationError('Action must be APPROVED or REJECTED.');
    const ref = db.collection('station_attendance_exceptions').doc(exceptionId);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Attendance exception not found.');
    await ref.update({
      status: action,
      adminRemark: adminRemark || '',
      actionTakenAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    });
    return { success: true, message: `Exception ${action} successfully` };
  }
}

export const stationCleaningAttendanceService = new StationCleaningAttendanceService();
