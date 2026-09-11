import { db, admin } from '../database/index.js';
import { NotFoundError, ValidationError, ForbiddenError } from '../errors/index.js';

class TaskManagementService {
  async generateFrequencyBasedTasks(targetDate) {
    if (!targetDate) targetDate = new Date().toISOString().split('T')[0];

    const assignmentsQuery = await db.collection('areaWorkerAssignments')
      .where('isActive', '==', true)
      .limit(500).get();

    if (assignmentsQuery.empty) return { message: 'No active assignments found', count: 0, taskIds: [] };

    const allTaskIds = [];
    let totalCount = 0;

    for (const doc of assignmentsQuery.docs) {
      const assignment = doc.data();
      let areaDoc = await db.collection('areas').doc(assignment.areaId).get();
      if (!areaDoc.exists) {
        areaDoc = await db.collection('stationAreas').doc(assignment.areaId).get();
      }
      if (!areaDoc.exists) continue;
      const area = areaDoc.data();

      const cleaningFrequency = area.cleaningFrequency || area.frequency || 'daily';
      const frequencyTimes = area.frequencyTimes || this._getDefaultFrequencyTimes(cleaningFrequency);
      const areaName = area.areaName || area.name || assignment.areaName || '';
      const areaCode = area.areaCode || '';
      const mainArea = area.mainArea || '';
      const platformId = assignment.platformId || area.platformId || null;
      const supervisorId = area.supervisorId || assignment.supervisorId || null;

      const batch = db.batch();
      let batchCount = 0;

      for (const scheduledTime of frequencyTimes) {
        const taskRef = db.collection('cleaningTasks').doc();
        const displayName = [mainArea, areaName].filter(Boolean).join(' - ');
        const task = {
          uid: taskRef.id,
          stationId: area.stationId || assignment.stationId,
          platformId,
          areaId: assignment.areaId,
          areaName: displayName,
          areaCode,
          mainArea,
          workerId: assignment.workerId,
          workerName: assignment.workerName,
          supervisorId,
          assignmentId: assignment.uid,
          activityType: area.areaType || 'Cleaning',
          frequency: cleaningFrequency,
          date: targetDate,
          scheduledDate: targetDate,
          scheduledTime,
          priority: area.priority || 3,
          shift: assignment.shift || area.defaultShift || 'morning',
          status: 'pending',
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

    return { message: `Generated ${totalCount} tasks for ${targetDate}`, count: totalCount, taskIds: allTaskIds };
  }

  _getDefaultFrequencyTimes(frequency) {
    switch (frequency) {
      case 'hourly': return ['06:00', '07:00', '08:00', '09:00', '10:00', '11:00', '12:00', '13:00', '14:00', '15:00', '16:00', '17:00', '18:00', '19:00', '20:00', '21:00', '22:00'];
      case '2hrs': return ['06:00', '08:00', '10:00', '12:00', '14:00', '16:00', '18:00', '20:00', '22:00'];
      case '4hrs': return ['06:00', '10:00', '14:00', '18:00', '22:00'];
      case 'daily': return ['08:00'];
      case 'twice_daily': return ['06:00', '18:00'];
      case 'shift_wise': return ['06:00', '14:00', '22:00'];
      case 'four_times_daily': return ['06:00', '10:00', '14:00', '18:00'];
      case 'week_wise': return ['08:00'];
      case 'fortnightly': return ['08:00'];
      case 'monthly': return ['08:00'];
      default: return ['08:00'];
    }
  }

  async generateTasksForDate(targetDate, user) {
    return this.generateFrequencyBasedTasks(targetDate);
  }

  async startTask(taskId, data, user) {
    const ref = db.collection('cleaningTasks').doc(taskId);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Task not found');
    const task = doc.data();
    if (task.status !== 'pending' && task.status !== 'assigned') {
      throw new ValidationError(`Task cannot be started. Current status: ${task.status}`);
    }

    const updates = {
      status: 'in_progress',
      startedAt: new Date().toISOString(),
      beforePhoto: data.beforePhoto || null,
      gpsLat: data.gpsLat || null,
      gpsLng: data.gpsLng || null,
      updatedAt: new Date().toISOString(),
      startedBy: user.uid
    };
    await ref.update(updates);
    return { message: 'Task started', taskId };
  }

  async completeTask(taskId, data, user) {
    const ref = db.collection('cleaningTasks').doc(taskId);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Task not found');
    const task = doc.data();
    if (task.status !== 'in_progress' && task.status !== 'resubmitted') {
      throw new ValidationError(`Only in-progress or resubmitted tasks can be completed. Current: ${task.status}`);
    }

    const updates = {
      status: 'completed',
      completedAt: new Date().toISOString(),
      afterPhoto: data.afterPhoto || task.afterPhoto || null,
      gpsLat: data.gpsLat || task.gpsLat || null,
      gpsLng: data.gpsLng || task.gpsLng || null,
      remarks: data.remarks || task.remarks || '',
      updatedAt: new Date().toISOString()
    };
    await ref.update(updates);
    return { message: 'Task completed and submitted for review', taskId };
  }

  async resubmitTask(taskId, data, user) {
    const ref = db.collection('cleaningTasks').doc(taskId);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Task not found');
    const task = doc.data();
    if (task.status !== 'rejected') throw new ValidationError('Only rejected tasks can be resubmitted');

    const updates = {
      status: 'resubmitted',
      resubmittedAt: new Date().toISOString(),
      afterPhoto: data.afterPhoto || task.afterPhoto || null,
      gpsLat: data.gpsLat || task.gpsLat || null,
      gpsLng: data.gpsLng || task.gpsLng || null,
      remarks: data.remarks || task.remarks || '',
      rejectionReason: null,
      updatedAt: new Date().toISOString()
    };
    await ref.update(updates);
    return { message: 'Task resubmitted for review', taskId };
  }

  async getTasks(query = {}, user) {
    const { stationId, platformId, areaId, workerId, status, date, startDate, endDate, supervisorId, includeOverdue } = query;
    let q = db.collection('cleaningTasks');
    const filters = [];
    if (stationId) { q = q.where('stationId', '==', stationId); filters.push('stationId'); }
    if (workerId) { q = q.where('workerId', '==', workerId); filters.push('workerId'); }
    if (areaId) { q = q.where('areaId', '==', areaId); filters.push('areaId'); }
    if (platformId) { q = q.where('platformId', '==', platformId); filters.push('platformId'); }
    if (supervisorId) { q = q.where('supervisorId', '==', supervisorId); filters.push('supervisorId'); }
    if (status) { q = q.where('status', '==', status); filters.push('status'); }
    if (date) { q = q.where('date', '==', date); filters.push('date'); }
    if (startDate && endDate) {
      q = q.where('date', '>=', startDate).where('date', '<=', endDate);
    } else if (startDate) {
      q = q.where('date', '>=', startDate);
    } else if (endDate) {
      q = q.where('date', '<=', endDate);
    }
    if (user && !['SUPER_ADMIN', 'COMPANY_MASTER', 'RAILWAY_MASTER', 'ADMIN'].includes((user.role || '').toUpperCase())) {
      const userStations = user.stations || (user.stationId ? [user.stationId] : []);
      if (stationId) {
        if (userStations.length > 0 && !userStations.includes(stationId)) {
          throw new ForbiddenError('You can only access tasks for your assigned stations');
        }
      } else if (userStations.length === 1) {
        q = q.where('stationId', '==', userStations[0]);
      } else if (userStations.length > 1) {
        q = q.where('stationId', 'in', userStations);
      }
    }
    const snapshot = await q.limit(300).get();
    const tasks = [];
    const now = new Date();
    snapshot.forEach(doc => {
      const t = { id: doc.id, ...doc.data() };
      const taskDate = t.date || t.scheduledDate || '';
      const taskTime = t.scheduledTime || '23:59';
      const taskDateTime = new Date(`${taskDate}T${taskTime}:00`);
      const actionableStatuses = ['pending', 'assigned', 'in_progress'];
      t.isOverdue = actionableStatuses.includes(t.status) && taskDateTime < now;
      t.isDue = actionableStatuses.includes(t.status) && !t.isOverdue;
      tasks.push(t);
    });

    if (includeOverdue === 'true') {
      tasks = tasks.filter(t => t.isOverdue);
    }

    tasks.sort((a, b) => {
      const aTime = a.createdAt ? new Date(a.createdAt).getTime() : 0;
      const bTime = b.createdAt ? new Date(b.createdAt).getTime() : 0;
      return bTime - aTime;
    });

    return { count: tasks.length, tasks };
  }

  async getTaskById(taskId, user) {
    const doc = await db.collection('cleaningTasks').doc(taskId).get();
    if (!doc.exists) throw new NotFoundError('Task not found');
    const task = { id: doc.id, ...doc.data() };
    const role = (user?.role || '').toUpperCase();
    if (!['SUPER_ADMIN', 'COMPANY_MASTER', 'RAILWAY_MASTER', 'ADMIN'].includes(role)) {
      const userStations = user?.stations || (user?.stationId ? [user.stationId] : []);
      if (userStations.length > 0 && task.stationId && !userStations.includes(task.stationId)) {
        throw new ForbiddenError('You can only access tasks in your assigned stations');
      }
    }
    return task;
  }

  async updateTaskStatus(taskId, status, user) {
    const ref = db.collection('cleaningTasks').doc(taskId);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Task not found');

    const allowedStatuses = ['pending', 'assigned', 'in_progress', 'completed', 'approved', 'rejected', 'resubmitted'];
    if (!allowedStatuses.includes(status)) {
      throw new ValidationError(`Invalid status: ${status}. Allowed: ${allowedStatuses.join(', ')}`);
    }

    const updates = { status, updatedAt: new Date().toISOString(), updatedBy: user.uid };
    if (status === 'in_progress') updates.startedAt = new Date().toISOString();
    if (status === 'completed') updates.completedAt = new Date().toISOString();
    if (status === 'approved') updates.approvedAt = new Date().toISOString();
    if (status === 'rejected') updates.rejectedAt = new Date().toISOString();
    if (status === 'resubmitted') updates.resubmittedAt = new Date().toISOString();

    await ref.update(updates);
    return { message: `Task ${status}`, taskId };
  }

  async assignTask(taskId, workerId, workerName, user) {
    const ref = db.collection('cleaningTasks').doc(taskId);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Task not found');
    await ref.update({
      workerId, workerName,
      assignedBy: user.uid, assignedByName: user.fullName || user.name || 'Unknown',
      updatedAt: new Date().toISOString()
    });
    return { message: 'Task assigned', taskId };
  }

  async approveTask(taskId, data, user) {
    const ref = db.collection('cleaningTasks').doc(taskId);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Task not found');
    const task = doc.data();
    if (task.status !== 'completed' && task.status !== 'resubmitted') {
      throw new ValidationError('Only completed or resubmitted tasks can be approved');
    }

    await ref.update({
      status: 'approved',
      approvedAt: new Date().toISOString(),
      approvedBy: user.uid,
      approvedByName: user.fullName || user.name || 'Unknown',
      supervisorNotes: data.remarks || '',
      updatedAt: new Date().toISOString()
    });
    return { message: 'Task approved', taskId };
  }

  async rejectTask(taskId, data, user) {
    const reason = data.reason || data;
    if (!reason || (typeof reason === 'string' && reason.trim() === '')) {
      throw new ValidationError('Rejection reason is required');
    }
    const ref = db.collection('cleaningTasks').doc(taskId);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Task not found');
    const task = doc.data();
    if (task.status !== 'completed' && task.status !== 'resubmitted') {
      throw new ValidationError('Only completed or resubmitted tasks can be rejected');
    }

    await ref.update({
      status: 'rejected',
      rejectedAt: new Date().toISOString(),
      rejectedBy: user.uid,
      rejectedByName: user.fullName || user.name || 'Unknown',
      rejectionReason: typeof reason === 'string' ? reason : reason.reason || '',
      supervisorNotes: data.remarks || '',
      updatedAt: new Date().toISOString()
    });
    return { message: 'Task rejected', taskId };
  }

  async getPendingReviewTasks(supervisorId, stationId) {
    const snapshot = await db.collection('cleaningTasks')
      .orderBy('updatedAt', 'desc').limit(300).get();
    let tasks = [];
    snapshot.forEach(doc => tasks.push({ id: doc.id, ...doc.data() }));
    tasks = tasks.filter(t => t.status === 'completed' || t.status === 'resubmitted');
    if (supervisorId) {
      tasks = tasks.filter(t => t.supervisorId === supervisorId);
    }
    if (stationId) {
      tasks = tasks.filter(t => t.stationId === stationId);
    }
    return { count: tasks.length, tasks };
  }

  async getWorkerTasks(workerId, date) {
    if (!workerId) throw new ValidationError('workerId is required');
    let q = db.collection('cleaningTasks').where('workerId', '==', workerId);
    const snapshot = await q.orderBy('updatedAt', 'desc').limit(100).get();
    let tasks = [];
    snapshot.forEach(doc => tasks.push({ id: doc.id, ...doc.data() }));
    if (date) {
      tasks = tasks.filter(t => t.date === date || t.scheduledDate === date);
    }
    tasks.sort((a, b) => ((a.scheduledTime || '00:00').localeCompare(b.scheduledTime || '00:00')));
    return { count: tasks.length, tasks };
  }

  async getAreaTasks(areaId, date, statusFilter) {
    if (!areaId) throw new ValidationError('areaId is required');
    let q = db.collection('cleaningTasks').where('areaId', '==', areaId);
    const snapshot = await q.orderBy('updatedAt', 'desc').limit(200).get();
    let tasks = [];
    snapshot.forEach(doc => tasks.push({ id: doc.id, ...doc.data() }));
    if (date) {
      tasks = tasks.filter(t => t.date === date || t.scheduledDate === date);
    }
    if (statusFilter) {
      tasks = tasks.filter(t => t.status === statusFilter);
    }
    tasks.sort((a, b) => ((a.scheduledTime || '00:00').localeCompare(b.scheduledTime || '00:00')));
    return { count: tasks.length, tasks };
  }

  async getDailyTasks(date, user) {
    if (!date) date = new Date().toISOString().split('T')[0];
    const role = (user?.role || '').toUpperCase();
    let q = db.collection('cleaningTasks').limit(500);
    if (!['SUPER_ADMIN', 'COMPANY_MASTER', 'RAILWAY_MASTER', 'ADMIN'].includes(role)) {
      const userStations = user?.stations || (user?.stationId ? [user.stationId] : []);
      if (userStations.length === 1) {
        q = q.where('stationId', '==', userStations[0]);
      } else if (userStations.length > 1) {
        q = q.where('stationId', 'in', userStations);
      }
    }
    const snapshot = await q.get();
    let tasks = [];
    snapshot.forEach(doc => tasks.push({ id: doc.id, ...doc.data() }));
    tasks = tasks.filter(t => t.date === date || t.scheduledDate === date);
    return { count: tasks.length, date, tasks };
  }

  async getSupervisorTasks(supervisorId, date, statusFilter, user) {
    if (!supervisorId) throw new ValidationError('supervisorId is required');
    const role = (user?.role || '').toUpperCase();
    if (!['SUPER_ADMIN', 'COMPANY_MASTER', 'RAILWAY_MASTER', 'ADMIN'].includes(role)) {
      const allowedSupervisorIds = [user?.uid];
      if (user?.contractId) {
        const supSnap = await db.collection('users').where('contractId', '==', user.contractId).where('role', '==', 'Contractor Supervisor').get();
        supSnap.forEach(d => allowedSupervisorIds.push(d.id));
      }
      if (!allowedSupervisorIds.includes(supervisorId)) {
        throw new ForbiddenError('You can only view tasks for supervisors in your contract');
      }
    }
    const snapshot = await db.collection('cleaningTasks')
      .where('supervisorId', '==', supervisorId)
      .get();
    let tasks = [];
    const now = new Date();
    snapshot.forEach(doc => {
      const t = { id: doc.id, ...doc.data() };
      const taskDate = t.date || t.scheduledDate || '';
      const taskTime = t.scheduledTime || '23:59';
      const taskDateTime = new Date(`${taskDate}T${taskTime}:00`);
      const actionableStatuses = ['pending', 'assigned', 'in_progress'];
      t.isOverdue = actionableStatuses.includes(t.status) && taskDateTime < now;
      t.isDue = actionableStatuses.includes(t.status) && !t.isOverdue;
      tasks.push(t);
    });
    if (date) {
      tasks = tasks.filter(t => t.date === date || t.scheduledDate === date);
    }
    if (statusFilter) {
      tasks = tasks.filter(t => t.status === statusFilter);
    }
    tasks.sort((a, b) => ((a.scheduledTime || '00:00').localeCompare(b.scheduledTime || '00:00')));
    return { count: tasks.length, tasks };
  }

  _resolveActivityForArea(areaId, areaData, data = {}) {
    const { areaActivities, activityType, taskTypeId, taskTypeName } = data;
    const perArea = areaActivities ? areaActivities[areaId] : null;
    if (perArea) {
      if (typeof perArea === 'string') {
        return {
          id: null,
          name: perArea,
          label: perArea.replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase())
        };
      }
      return {
        id: perArea.uid || perArea.id || taskTypeId || null,
        name: perArea.name || taskTypeName || '',
        label: perArea.label || (perArea.name ? perArea.name.replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase()) : taskTypeName || (areaData.areaType || 'Cleaning'))
      };
    }
    if (activityType) {
      return {
        id: taskTypeId || null,
        name: taskTypeName || activityType,
        label: activityType.replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase())
      };
    }
    return null;
  }

  _resolveActivitiesForArea(areaId, areaData, data = {}) {
    const perArea = data.areaActivities ? data.areaActivities[areaId] : null;
    if (Array.isArray(perArea)) {
      return perArea
        .filter(a => a && (typeof a === 'string' || a.uid || a.id || a.name || a.label))
        .map(a => this._resolveActivityForArea(areaId, areaData, { ...data, areaActivities: { [areaId]: a } }))
        .filter(Boolean);
    }
    const single = this._resolveActivityForArea(areaId, areaData, data);
    return single ? [single] : [];
  }

  async bulkGenerate(data, user) {
    const { areaIds, date, workerId, workerIds, zoneIds, supervisorId, frequency } = data;
    if (!areaIds || !Array.isArray(areaIds) || areaIds.length === 0) {
      throw new ValidationError('areaIds array is required');
    }
    const targetDate = date || new Date().toISOString().split('T')[0];
    let total = 0;
    const allTaskIds = [];

    // Resolve the supervisor if provided
    let assignedSupervisorId = null;
    let assignedSupervisorName = '';
    if (supervisorId) {
      const supDoc = await db.collection('users').doc(supervisorId).get();
      if (supDoc.exists) {
        const supData = supDoc.data();
        assignedSupervisorId = supervisorId;
        assignedSupervisorName = supData.fullName || supData.name || '';
      }
    }

    let assignedWorker = null;
    let assignedWorkers = [];
    if (workerIds && Array.isArray(workerIds) && workerIds.length > 0) {
      const workerDocs = await Promise.all(
        workerIds.map(wId => db.collection('users').doc(wId).get())
      );
      assignedWorkers = workerDocs
        .filter(d => d.exists)
        .map(d => ({ uid: d.id, ...d.data() }));
      if (assignedWorkers.length === 0) {
        throw new NotFoundError('None of the specified workers were found');
      }
    } else if (workerId) {
      const workerDoc = await db.collection('users').doc(workerId).get();
      if (!workerDoc.exists) {
        throw new NotFoundError(`Worker with ID ${workerId} not found`);
      }
      assignedWorker = { uid: workerDoc.id, ...workerDoc.data() };
    }

    const existingTaskKeys = new Set();
    const chunkSize = 10;
    for (let i = 0; i < areaIds.length; i += chunkSize) {
      const chunk = areaIds.slice(i, i + chunkSize);
      const existingTasksSnap = await db.collection('cleaningTasks')
        .where('date', '==', targetDate)
        .where('areaId', 'in', chunk)
        .select('workerId', 'areaId', 'scheduledTime', 'taskTypeId')
        .get();
      existingTasksSnap.forEach(doc => {
        const d = doc.data();
        existingTaskKeys.add(`${d.areaId}|${d.workerId}|${d.scheduledTime}|${d.taskTypeId || 'default'}`);
      });
    }

    for (const areaId of areaIds) {
      const [workersSnap, areaSnap] = await Promise.all([
        assignedWorker || assignedWorkers.length > 0 ? null : db.collection('areaWorkerAssignments').where('areaId', '==', areaId).where('isActive', '==', true).limit(200).get(),
        db.collection('areas').doc(areaId).get()
      ]);
      let areaDoc = areaSnap;
      if (!areaDoc.exists) {
        areaDoc = await db.collection('stationAreas').doc(areaId).get();
      }
      const areaData = areaDoc.exists ? areaDoc.data() : {};
      const activities = this._resolveActivitiesForArea(areaId, areaData, data);
      const taskActivities = activities.length > 0 ? activities : [null];
      const cleaningFrequency = frequency || areaData.cleaningFrequency || areaData.frequency || 'daily';
      const frequencyTimes = areaData.frequencyTimes || this._getDefaultFrequencyTimes(cleaningFrequency);
      const baseAreaName = areaData.areaName || areaData.name || '';
      const areaCode = areaData.areaCode || '';
      const mainArea = areaData.mainArea || '';

      const batch = db.batch();
      let batchCount = 0;

      // Determine the list of target zones for this area
      let targetZones = [null];
      if (zoneIds && Array.isArray(zoneIds) && zoneIds.length > 0) {
        const zoneDocs = await Promise.all(zoneIds.map(zId => db.collection('stationZones').doc(zId).get()));
        targetZones = zoneDocs
          .filter(doc => doc.exists && doc.data().areaId === areaId)
          .map(doc => ({ uid: doc.id, name: doc.data().zoneName || doc.data().name || '' }));
        if (targetZones.length === 0) {
          targetZones = [null];
        }
      }

      const buildTask = (workerInfo, zoneInfo, scheduledTime, activity) => {
        const taskRef = db.collection('cleaningTasks').doc();
        const displayAreaName = [mainArea, baseAreaName, zoneInfo?.name].filter(Boolean).join(' - ');
        const task = {
          uid: taskRef.id,
          stationId: workerInfo.stationId || '',
          platformId: workerInfo.platformId || null,
          areaId,
          areaName: displayAreaName,
          areaCode,
          mainArea,
          zoneId: zoneInfo ? zoneInfo.uid : null,
          zoneName: zoneInfo ? zoneInfo.name : null,
          workerId: workerInfo.workerId,
          workerName: workerInfo.workerName || 'Unknown',
          supervisorId: workerInfo.supervisorId,
          supervisorName: workerInfo.supervisorName || '',
          assignmentId: workerInfo.assignmentId || null,
          activityType: activity ? activity.label : (areaData.areaType || 'Cleaning'),
          taskTypeId: activity ? activity.id : null,
          taskTypeName: activity ? activity.name : null,
          frequency: cleaningFrequency,
          date: targetDate,
          scheduledDate: targetDate,
          scheduledTime,
          priority: areaData.priority || 3,
          shift: workerInfo.shift,
          status: 'pending',
          startedAt: null, completedAt: null,
          approvedAt: null, rejectedAt: null,
          beforePhoto: null, afterPhoto: null,
          gpsLat: null, gpsLng: null,
          supervisorNotes: null, rejectionReason: null,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: new Date().toISOString()
        };
        return { taskRef, task };
      };

      const processWorker = (workerInfo) => {
        for (const scheduledTime of frequencyTimes) {
          for (const zoneInfo of targetZones) {
            for (const activity of taskActivities) {
              const dupKey = `${areaId}|${workerInfo.workerId}|${scheduledTime}|${activity ? (activity.id || 'default') : 'default'}`;
              if (existingTaskKeys.has(dupKey)) continue;
              const { taskRef, task } = buildTask(workerInfo, zoneInfo, scheduledTime, activity);
              batch.set(taskRef, task);
              allTaskIds.push(taskRef.id);
              batchCount++;
            }
          }
        }
      };

      if (assignedWorkers.length > 0) {
        let workerIdx = 0;
        for (const scheduledTime of frequencyTimes) {
          for (const zoneInfo of targetZones) {
            const w = assignedWorkers[workerIdx % assignedWorkers.length];
            workerIdx++;
            for (const activity of taskActivities) {
              const dupKey = `${areaId}|${w.uid}|${scheduledTime}|${activity ? (activity.id || 'default') : 'default'}`;
              if (existingTaskKeys.has(dupKey)) continue;
              const { taskRef, task } = buildTask({
                workerId: w.uid,
                workerName: w.fullName || w.name || 'Unknown',
                stationId: areaData.stationId || w.stationId || '',
                platformId: areaData.platformId || null,
                supervisorId: assignedSupervisorId || areaData.supervisorId || null,
                supervisorName: assignedSupervisorName || areaData.supervisorName || '',
                shift: data.shift || areaData.defaultShift || 'morning',
              }, zoneInfo, scheduledTime, activity);
              batch.set(taskRef, task);
              allTaskIds.push(taskRef.id);
              batchCount++;
            }
          }
        }
      } else if (assignedWorker) {
        processWorker({
          workerId: assignedWorker.uid,
          workerName: assignedWorker.fullName || assignedWorker.name || 'Unknown',
          stationId: areaData.stationId || assignedWorker.stationId || '',
          platformId: areaData.platformId || null,
          supervisorId: assignedSupervisorId || areaData.supervisorId || null,
          supervisorName: assignedSupervisorName || areaData.supervisorName || '',
          shift: data.shift || areaData.defaultShift || 'morning',
        });
      } else if (workersSnap && workersSnap.size > 0) {
        workersSnap.forEach(workerDoc => {
          const assignment = workerDoc.data();
          processWorker({
            workerId: assignment.workerId,
            workerName: assignment.workerName,
            stationId: areaData.stationId || assignment.stationId,
            platformId: areaData.platformId || assignment.platformId || null,
            assignmentId: assignment.uid,
            supervisorId: assignedSupervisorId || areaData.supervisorId || null,
            supervisorName: assignedSupervisorName || areaData.supervisorName || '',
            shift: assignment.shift || areaData.defaultShift || 'morning',
          });
        });
      } else if (assignedSupervisorId) {
        processWorker({
          workerId: assignedSupervisorId,
          workerName: assignedSupervisorName || 'Supervisor',
          stationId: areaData.stationId || '',
          platformId: areaData.platformId || null,
          supervisorId: assignedSupervisorId,
          supervisorName: assignedSupervisorName || '',
          shift: data.shift || areaData.defaultShift || 'morning',
        });
      }

      if (batchCount > 0) {
        await batch.commit();
        total += batchCount;
      }
    }

    return { message: `Generated ${total} tasks across ${areaIds.length} areas for ${targetDate}`, count: total, taskIds: allTaskIds };
  }

  async generateTasksForDateRange(data, user) {
    const { areaIds, startDate, endDate, workerId } = data;
    if (!areaIds || !Array.isArray(areaIds) || areaIds.length === 0) {
      throw new ValidationError('areaIds array is required');
    }
    if (!startDate || !endDate) throw new ValidationError('startDate and endDate are required');
    const start = new Date(startDate);
    const end = new Date(endDate);
    if (start > end) throw new ValidationError('startDate must be before endDate');

    let total = 0;
    const allTaskIds = [];
    const current = new Date(start);

    while (current <= end) {
      const dateStr = current.toISOString().split('T')[0];
      const result = await this.bulkGenerate({ areaIds, date: dateStr, workerId, shift: data.shift, activityType: data.activityType, areaActivities: data.areaActivities, taskTypeId: data.taskTypeId, taskTypeName: data.taskTypeName }, user);
      total += result.count;
      allTaskIds.push(...result.taskIds);
      current.setDate(current.getDate() + 1);
    }

    return { message: `Generated ${total} tasks across ${areaIds.length} areas from ${startDate} to ${endDate}`, count: total, taskIds: allTaskIds };
  }
}

export const taskManagementService = new TaskManagementService();
