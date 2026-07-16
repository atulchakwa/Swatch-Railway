import { db, admin } from '../database/index.js';
import { NotFoundError, ValidationError } from '../errors/index.js';

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
      const platformId = assignment.platformId || area.platformId || null;
      const supervisorId = area.supervisorId || assignment.supervisorId || null;

      const batch = db.batch();
      let batchCount = 0;

      for (const scheduledTime of frequencyTimes) {
        const taskRef = db.collection('cleaningTasks').doc();
        const task = {
          uid: taskRef.id,
          stationId: area.stationId || assignment.stationId,
          platformId,
          areaId: assignment.areaId,
          areaName,
          areaCode,
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
      case 'shift_wise': return ['06:00', '14:00', '22:00'];
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

    if (!data.afterPhoto) throw new ValidationError('After photo is required to complete task');

    const updates = {
      status: 'completed',
      completedAt: new Date().toISOString(),
      afterPhoto: data.afterPhoto,
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

    if (!data.afterPhoto) throw new ValidationError('After photo is required to resubmit');

    const updates = {
      status: 'resubmitted',
      resubmittedAt: new Date().toISOString(),
      afterPhoto: data.afterPhoto,
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
    const snapshot = await db.collection('cleaningTasks').limit(300).get();
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

    let filtered = tasks;
    if (stationId) filtered = filtered.filter(t => t.stationId === stationId);
    if (platformId) filtered = filtered.filter(t => t.platformId === platformId);
    if (areaId) filtered = filtered.filter(t => t.areaId === areaId);
    if (workerId) filtered = filtered.filter(t => t.workerId === workerId);
    if (status) filtered = filtered.filter(t => t.status === status);
    if (supervisorId) filtered = filtered.filter(t => t.supervisorId === supervisorId);
    if (includeOverdue === 'true') filtered = filtered.filter(t => t.isOverdue);
    if (date) {
      filtered = filtered.filter(t => t.date === date || t.scheduledDate === date);
    }
    if (startDate) {
      filtered = filtered.filter(t => (t.date || t.scheduledDate || '') >= startDate);
    }
    if (endDate) {
      filtered = filtered.filter(t => (t.date || t.scheduledDate || '') <= endDate);
    }

    filtered.sort((a, b) => {
      const aTime = a.createdAt ? new Date(a.createdAt).getTime() : 0;
      const bTime = b.createdAt ? new Date(b.createdAt).getTime() : 0;
      return bTime - aTime;
    });

    return { count: filtered.length, tasks: filtered };
  }

  async getTaskById(taskId) {
    const doc = await db.collection('cleaningTasks').doc(taskId).get();
    if (!doc.exists) throw new NotFoundError('Task not found');
    return { id: doc.id, ...doc.data() };
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

  async getDailyTasks(date) {
    if (!date) date = new Date().toISOString().split('T')[0];
    const snapshot = await db.collection('cleaningTasks').limit(500).get();
    let tasks = [];
    snapshot.forEach(doc => tasks.push({ id: doc.id, ...doc.data() }));
    tasks = tasks.filter(t => t.date === date || t.scheduledDate === date);
    return { count: tasks.length, date, tasks };
  }

  async getSupervisorTasks(supervisorId, date, statusFilter) {
    if (!supervisorId) throw new ValidationError('supervisorId is required');
    let q = db.collection('cleaningTasks').where('supervisorId', '==', supervisorId);
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

  async bulkGenerate(data, user) {
    const { areaIds, date, workerId, zoneIds } = data;
    if (!areaIds || !Array.isArray(areaIds) || areaIds.length === 0) {
      throw new ValidationError('areaIds array is required');
    }
    const targetDate = date || new Date().toISOString().split('T')[0];
    let total = 0;
    const allTaskIds = [];

    let assignedWorker = null;
    if (workerId) {
      const workerDoc = await db.collection('users').doc(workerId).get();
      if (!workerDoc.exists) {
        throw new NotFoundError(`Worker with ID ${workerId} not found`);
      }
      assignedWorker = { uid: workerDoc.id, ...workerDoc.data() };
    }

    for (const areaId of areaIds) {
      const [workersSnap, areaSnap] = await Promise.all([
        assignedWorker ? null : db.collection('areaWorkerAssignments').where('areaId', '==', areaId).where('isActive', '==', true).limit(200).get(),
        db.collection('areas').doc(areaId).get()
      ]);
      let areaDoc = areaSnap;
      if (!areaDoc.exists) {
        areaDoc = await db.collection('stationAreas').doc(areaId).get();
      }
      const areaData = areaDoc.exists ? areaDoc.data() : {};
      const cleaningFrequency = areaData.cleaningFrequency || areaData.frequency || 'daily';
      const frequencyTimes = areaData.frequencyTimes || this._getDefaultFrequencyTimes(cleaningFrequency);
      const baseAreaName = areaData.areaName || areaData.name || '';
      const areaCode = areaData.areaCode || '';

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

      if (assignedWorker) {
        for (const scheduledTime of frequencyTimes) {
          for (const zoneInfo of targetZones) {
            const taskRef = db.collection('cleaningTasks').doc();
            const displayAreaName = zoneInfo ? `${baseAreaName} - ${zoneInfo.name}` : baseAreaName;
            const task = {
              uid: taskRef.id,
              stationId: areaData.stationId || assignedWorker.stationId || '',
              platformId: areaData.platformId || null,
              areaId,
              areaName: displayAreaName,
              areaCode,
              zoneId: zoneInfo ? zoneInfo.uid : null,
              zoneName: zoneInfo ? zoneInfo.name : null,
              workerId: assignedWorker.uid,
              workerName: assignedWorker.fullName || assignedWorker.name || 'Unknown',
              supervisorId: areaData.supervisorId || null,
              assignmentId: null,
              activityType: areaData.areaType || 'Cleaning',
              frequency: cleaningFrequency,
              date: targetDate,
              scheduledDate: targetDate,
              scheduledTime,
              priority: areaData.priority || 3,
              shift: data.shift || areaData.defaultShift || 'morning',
              status: 'pending',
              startedAt: null, completedAt: null,
              approvedAt: null, rejectedAt: null,
              beforePhoto: null, afterPhoto: null,
              gpsLat: null, gpsLng: null,
              supervisorNotes: null, rejectionReason: null,
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
              updatedAt: new Date().toISOString()
            };
            batch.set(taskRef, task);
            allTaskIds.push(taskRef.id);
            batchCount++;
          }
        }
      } else if (workersSnap) {
        workersSnap.forEach(workerDoc => {
          const assignment = workerDoc.data();
          for (const scheduledTime of frequencyTimes) {
            for (const zoneInfo of targetZones) {
              const taskRef = db.collection('cleaningTasks').doc();
              const displayAreaName = zoneInfo ? `${baseAreaName} - ${zoneInfo.name}` : baseAreaName;
              const task = {
                uid: taskRef.id,
                stationId: areaData.stationId || assignment.stationId,
                platformId: areaData.platformId || assignment.platformId || null,
                areaId,
                areaName: displayAreaName,
                areaCode,
                zoneId: zoneInfo ? zoneInfo.uid : null,
                zoneName: zoneInfo ? zoneInfo.name : null,
                workerId: assignment.workerId,
                workerName: assignment.workerName,
                supervisorId: areaData.supervisorId || null,
                assignmentId: assignment.uid,
                activityType: areaData.areaType || 'Cleaning',
                frequency: cleaningFrequency,
                date: targetDate,
                scheduledDate: targetDate,
                scheduledTime,
                priority: areaData.priority || 3,
                shift: assignment.shift || areaData.defaultShift || 'morning',
                status: 'pending',
                startedAt: null, completedAt: null,
                approvedAt: null, rejectedAt: null,
                beforePhoto: null, afterPhoto: null,
                gpsLat: null, gpsLng: null,
                supervisorNotes: null, rejectionReason: null,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                updatedAt: new Date().toISOString()
              };
              batch.set(taskRef, task);
              allTaskIds.push(taskRef.id);
              batchCount++;
            }
          }
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
      const result = await this.bulkGenerate({ areaIds, date: dateStr, workerId, shift: data.shift }, user);
      total += result.count;
      allTaskIds.push(...result.taskIds);
      current.setDate(current.getDate() + 1);
    }

    return { message: `Generated ${total} tasks across ${areaIds.length} areas from ${startDate} to ${endDate}`, count: total, taskIds: allTaskIds };
  }
}

export const taskManagementService = new TaskManagementService();
