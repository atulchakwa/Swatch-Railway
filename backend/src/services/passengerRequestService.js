import { db, admin } from '../database/index.js';
import { NotFoundError, ValidationError, ForbiddenError } from '../errors/index.js';
import { paginate } from '../utils/paginate.js';

class PassengerRequestService {
  constructor() {
    this.collection = 'passenger_service_requests';
  }

  async createFromTransmitter(data) {
    const { trainNumber, coachNumber, cabinNumber, requestType, source, buttonPressed, requestTime } = data;

    if (!trainNumber || !coachNumber || cabinNumber === undefined || !requestType) {
      throw new ValidationError('trainNumber, coachNumber, cabinNumber, requestType are required');
    }

    const trainQuery = await db.collection('trains')
      .where('trainNo', '==', trainNumber)
      .limit(1)
      .get();

    if (trainQuery.empty) {
      throw new NotFoundError(`Train ${trainNumber} not found`);
    }

    const trainDoc = trainQuery.docs[0];
    const trainId = trainDoc.id;

    const cabinQuery = await db.collection('cabin_transmitters')
      .where('trainId', '==', trainId)
      .where('coachNumber', '==', coachNumber)
      .where('cabinNumber', '==', parseInt(cabinNumber))
      .where('isActive', '==', true)
      .limit(1)
      .get();

    if (cabinQuery.empty) {
      throw new NotFoundError(`No active transmitter mapping for train ${trainNumber}, coach ${coachNumber}, cabin ${cabinNumber}`);
    }

    const cabinDoc = cabinQuery.docs[0];
    const cabinData = cabinDoc.data();
    const transmitterId = cabinDoc.id;

    const isAC = ['AC', 'A1', 'A2', 'A3', 'B1', 'CC', '1AC', '2AC', '3AC'].some(
      t => cabinData.coachType?.toUpperCase().includes(t)
    );

    let assignedWorkerId, assignedWorkerRole;

    if (data.requestType === 'ATTENDANT' || data.requestType === 'LINEN') {
      if (!isAC) {
        throw new ValidationError('Attendant/Linen requests only available for AC coaches');
      }
      if (!cabinData.assignedAttendantId) {
        throw new ValidationError('No attendant assigned to this cabin');
      }
      assignedWorkerId = cabinData.assignedAttendantId;
      assignedWorkerRole = 'ATTENDANT';
    } else {
      if (!cabinData.assignedJanitorId) {
        throw new ValidationError('No janitor assigned to this cabin');
      }
      assignedWorkerId = cabinData.assignedJanitorId;
      assignedWorkerRole = 'JANITOR';
    }

    const workerDoc = await db.collection('users').doc(assignedWorkerId).get();
    if (!workerDoc.exists) {
      throw new NotFoundError('Assigned worker not found');
    }
    const workerData = workerDoc.data();

    const requestRef = db.collection(this.collection).doc();
    const requestData = {
      requestId: requestRef.id,
      transmitterId,
      trainId,
      trainNumber,
      coachNumber,
      cabinNumber: parseInt(cabinNumber),
      coachType: cabinData.coachType,
      requestType: data.requestType,
      status: 'PENDING',
      passengerPressedAt: new Date().toISOString(),
      source: data.source || 'TRANSMITTER',
      buttonPressed: 'PASSENGER_BUTTON',
      assignedWorkerId,
      assignedWorkerRole,
      assignedWorkerName: workerData.fullName,
      statusHistory: [{
        status: 'PENDING',
        timestamp: new Date().toISOString(),
        actor: 'PASSENGER'
      }],
      timing: {
        passengerPressedAt: new Date().toISOString()
      },
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    };

    await requestRef.set(requestData);

    try {
      const { fcmService } = await import('./fcmService.js');
      await fcmService.sendToWorker(assignedWorkerId, {
        title: `${data.requestType === 'ATTENDANT' ? 'New Attendant Request' : 'New Cleaning Request'}`,
        body: `Train ${trainNumber} • Coach ${coachNumber} • Cabin ${cabinNumber}`,
        data: { requestId: requestRef.id, requestType: data.requestType, type: 'PASSENGER_REQUEST' }
      });
    } catch (e) {
      console.error('Push notification failed:', e);
    }

    return {
      success: true,
      requestId: requestRef.id,
      status: 'PENDING',
      assignedWorker: {
        workerId: assignedWorkerId,
        name: workerData.fullName,
        role: assignedWorkerRole,
        phone: workerData.mobile
      },
      message: `Request assigned to ${assignedWorkerRole} ${workerData.fullName} (Coach ${coachNumber}, Cabin ${cabinNumber})`
    };
  }

  async acceptRequest(requestId, workerId) {
    const requestRef = db.collection(this.collection).doc(requestId);
    const requestDoc = await requestRef.get();

    if (!requestDoc.exists) {
      throw new NotFoundError('Request not found');
    }

    const requestData = requestDoc.data();

    if (requestData.status !== 'PENDING') {
      throw new ValidationError(`Cannot accept request with status: ${requestData.status}`);
    }

    if (requestData.assignedWorkerId !== workerId) {
      throw new ValidationError('Not authorized to accept this request');
    }

    const now = new Date();
    const passengerPressedAt = new Date(requestDoc.data().passengerPressedAt);
    const reactionTimeMs = now.getTime() - passengerPressedAt.getTime();

    await requestRef.update({
      status: 'ACCEPTED',
      acceptedAt: new Date().toISOString(),
      acceptedBy: workerId,
      reactionTimeMs,
      statusHistory: admin.firestore.FieldValue.arrayUnion({
        status: 'ACCEPTED',
        timestamp: new Date().toISOString(),
        actor: 'WORKER'
      }),
      updatedAt: new Date().toISOString()
    });

    return {
      success: true,
      status: 'ACCEPTED',
      acceptedAt: new Date().toISOString(),
      reactionTimeMs,
      message: 'Request accepted successfully'
    };
  }

  async rejectRequest(requestId, workerId, reason) {
    const requestRef = db.collection(this.collection).doc(requestId);
    const requestDoc = await requestRef.get();

    if (!requestDoc.exists) {
      throw new NotFoundError('Request not found');
    }

    const requestData = requestDoc.data();

    if (requestData.status !== 'PENDING') {
      throw new ValidationError(`Cannot reject request with status: ${requestData.status}`);
    }

    if (requestData.assignedWorkerId !== workerId) {
      throw new ForbiddenError('Not authorized to reject this request');
    }

    if (!reason) {
      throw new ValidationError('Rejection reason required');
    }

    await requestRef.update({
      status: 'REJECTED',
      rejectedAt: new Date().toISOString(),
      rejectedBy: workerId,
      rejectionReason: reason,
      statusHistory: admin.firestore.FieldValue.arrayUnion({
        status: 'REJECTED',
        timestamp: new Date().toISOString(),
        actor: 'WORKER',
        reason
      }),
      updatedAt: new Date().toISOString()
    });

    await this.autoReassign(requestDoc.id);

    return { success: true, status: 'REJECTED', message: 'Request rejected and reassigned' };
  }

  async handleDeviceEvent(requestId, eventData) {
    const { transmitterId, buttonPressed, pressedBy, pressedAt } = eventData;

    const requestRef = db.collection(this.collection).doc(requestId);
    const requestDoc = await requestRef.get();

    if (!requestDoc.exists) {
      throw new NotFoundError('Request not found');
    }

    const requestData = requestDoc.data();

    if (requestData.transmitterId !== transmitterId) {
      throw new ValidationError('Transmitter mismatch');
    }

    if (requestData.assignedWorkerId !== pressedBy) {
      throw new ForbiddenError('Worker not assigned to this request');
    }

    const isAC = ['AC', 'A1', 'A2', 'A3', 'B1', 'CC', '1AC', '2AC', '3AC'].some(
      t => requestData.coachType?.toUpperCase().includes(t)
    );

    if (buttonPressed === 'CLEANER_RESET' && requestData.assignedWorkerRole !== 'JANITOR') {
      throw new ValidationError('Only janitor can press cleaner reset');
    }
    if (buttonPressed === 'ATTENDANT_RESET' && requestData.assignedWorkerRole !== 'ATTENDANT') {
      throw new ValidationError('Only attendant can press attendant reset');
    }

    if (buttonPressed === 'CLEANER_RESET' || buttonPressed === 'ATTENDANT_RESET') {
      if (requestData.status === 'PENDING' || requestData.status === 'ACCEPTED') {
        await requestRef.update({
          status: 'IN_PROGRESS',
          startedAt: new Date().toISOString(),
          startedBy: pressedBy,
          deviceButtonPressed: buttonPressed,
          statusHistory: admin.firestore.FieldValue.arrayUnion({
            status: 'IN_PROGRESS',
            timestamp: new Date().toISOString(),
            actor: 'DEVICE',
            buttonPressed
          }),
          updatedAt: new Date().toISOString()
        });
        return { status: 'IN_PROGRESS', message: `Task started via ${buttonPressed} button` };
      } else if (requestDoc.data().status === 'IN_PROGRESS') {
        const completedAt = new Date().toISOString();
        const durationSec = Math.floor((Date.now() - new Date(requestDoc.data().startedAt).getTime()) / 1000);

        await requestRef.update({
          status: 'COMPLETED',
          completedAt: new Date().toISOString(),
          completedBy: pressedBy,
          deviceButtonPressed: buttonPressed,
          durationSec,
          totalReactionTimeSec: Math.floor((Date.now() - new Date(requestDoc.data().passengerPressedAt).getTime()) / 1000),
          statusHistory: admin.firestore.FieldValue.arrayUnion({
            status: 'COMPLETED',
            timestamp: new Date().toISOString(),
            actor: 'DEVICE',
            buttonPressed,
            durationSec
          }),
          updatedAt: new Date().toISOString()
        });
        return { status: 'COMPLETED', durationSec, message: `Task completed via ${buttonPressed} button` };
      }
    }

    throw new ValidationError(`Invalid button press for current status`);
  }

  async acceptRequestManual(requestId, workerId) {
    return this.acceptRequest(requestId, workerId);
  }

  async getWorkerRequests(userId, query = {}) {
    const { status, limit = 50, cursor } = query;

    let firestoreQuery = db.collection(this.collection)
      .where('assignedWorkerId', '==', userId)
      .orderBy('passengerPressedAt', 'desc');

    if (status) {
      firestoreQuery = firestoreQuery.where('status', '==', status);
    }

    const result = await paginate(firestoreQuery, { limit: parseInt(limit), cursor });
    return { requests: result.items, pagination: result.pagination };
  }

  async getAllRequests(query = {}) {
    const { status, trainNumber, requestType, startDate, endDate, limit = 100, cursor } = query;

    let firestoreQuery = db.collection(this.collection).orderBy('passengerPressedAt', 'desc');

    if (status) firestoreQuery = firestoreQuery.where('status', '==', status);
    if (trainNumber) firestoreQuery = firestoreQuery.where('trainNumber', '==', trainNumber);
    if (requestType) firestoreQuery = firestoreQuery.where('requestType', '==', requestType);
    if (startDate) firestoreQuery = firestoreQuery.where('passengerPressedAt', '>=', new Date(startDate));
    if (endDate) firestoreQuery = firestoreQuery.where('passengerPressedAt', '<=', new Date(endDate));

    const result = await paginate(firestoreQuery, { limit: parseInt(limit), cursor });
    return { requests: result.items, pagination: result.pagination };
  }

  async getTimingAnalytics(query = {}) {
    const { trainNumber, startDate, endDate } = query;

    let firestoreQuery = db.collection(this.collection)
      .where('status', 'in', ['COMPLETED', 'REJECTED']);

    if (trainNumber) firestoreQuery = firestoreQuery.where('trainNumber', '==', trainNumber);
    if (startDate) firestoreQuery = firestoreQuery.where('passengerPressedAt', '>=', new Date(startDate));
    if (endDate) firestoreQuery = firestoreQuery.where('passengerPressedAt', '<=', new Date(endDate));

    const snapshot = await firestoreQuery.get();
    const requests = snapshot.docs.map(doc => doc.data());

    let totalReactionTime = 0;
    let totalArrivalTime = 0;
    let totalDuration = 0;
    let totalResolutionTime = 0;
    let completedCount = 0;
    let rejectedCount = 0;

    for (const req of requests) {
      const pressedAt = new Date(req.passengerPressedAt);
      
      if (req.acceptedAt) {
        totalReactionTime += new Date(req.acceptedAt).getTime() - pressedAt.getTime();
      }
      
      if (req.startedAt) {
        totalArrivalTime += new Date(req.startedAt).getTime() - new Date(req.acceptedAt || req.passengerPressedAt).getTime();
      }
      
      if (req.completedAt && req.startedAt) {
        totalDuration += new Date(req.completedAt).getTime() - new Date(req.startedAt).getTime();
        completedCount++;
      }
      
      if (req.status === 'COMPLETED') {
        totalResolutionTime += new Date(req.completedAt).getTime() - new Date(req.passengerPressedAt).getTime();
        completedCount++;
      }
      
      if (req.status === 'REJECTED') {
        rejectedCount++;
      }
    }

    const count = requests.length;
    return {
      period: { startDate: query.startDate, endDate: query.endDate },
      totalRequests: requests.length,
      completed: completedCount,
      rejected: rejectedCount,
      pending: requests.filter(r => r.status === 'PENDING').length,
      inProgress: requests.filter(r => r.status === 'IN_PROGRESS').length,
      avgReactionTimeMs: requests.length > 0 ? Math.round(totalReactionTime / requests.length) : 0,
      avgArrivalTimeMs: requests.length > 0 ? Math.round(totalArrivalTime / requests.length) : 0,
      avgTaskDurationSec: completedCount > 0 ? Math.round(totalDuration / completedCount) : 0,
      avgResolutionTimeSec: completedCount > 0 ? Math.round(totalResolutionTime / completedCount / 1000) : 0,
      byRequestType: this.groupBy(requests, 'requestType'),
      byTrain: this.groupBy(requests, 'trainNumber'),
      byWorker: this.groupBy(requests, 'assignedWorkerId')
    };
  }

  async getById(requestId) {
    const doc = await db.collection(this.collection).doc(requestId).get();
    if (!doc.exists) throw new NotFoundError('Request not found');
    return { id: doc.id, ...doc.data() };
  }

  async autoReassign(requestId) {
    const requestDoc = await db.collection(this.collection).doc(requestId).get();
    if (!requestDoc.exists) return;

    const req = requestDoc.data();
    const isAC = ['AC', 'A1', 'A2', 'A3', 'B1', 'CC'].some(t => req.coachType?.toUpperCase().includes(t));
    const isAttendant = req.requestType === 'ATTENDANT' || req.requestType === 'LINEN';
    const field = isAttendant ? 'assignedAttendantId' : 'assignedJanitorId';

    const cabinDoc = await db.collection('cabin_transmitters').doc(req.transmitterId).get();
    if (!cabinDoc.exists) return;

    await db.collection(this.collection).doc(req.requestId).update({
      status: 'PENDING_REASSIGNMENT',
      reassignedFrom: req.assignedWorkerId,
      reassignedAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    });
  }

  async sendPushNotification(workerId, payload) {
    try {
      const workerDoc = await db.collection('users').doc(workerId).get();
      if (!workerDoc.exists) return;
      
      const workerData = workerDoc.data();
      if (!workerData.fcmToken) return;

      await admin.messaging().send({
        token: workerData.fcmToken,
        notification: {
          title: payload.requestType === 'ATTENDANT' ? 'New Attendant Request' : 'New Cleaning Request',
          body: `Train ${payload.trainNumber} • Coach ${payload.coachNumber} • Cabin ${payload.cabinNumber}`
        },
        data: {
          requestId: payload.requestId,
          type: 'PASSENGER_REQUEST',
          requestType: payload.requestType
        }
      });
    } catch (e) {
      console.error('Push notification failed:', e);
    }
  }

  groupBy(array, key) {
    return array.reduce((acc, item) => {
      const k = item[key] || 'Unknown';
      acc[k] = (acc[k] || 0) + 1;
      return acc;
    }, {});
  }
}

export const passengerRequestService = new PassengerRequestService();