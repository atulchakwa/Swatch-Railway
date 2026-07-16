import { db } from '../database/index.js';
import { NotFoundError, ValidationError } from '../errors/index.js';
import { paginate } from '../utils/paginate.js';

const VALID_FREQUENCY_TYPES = [
  'once_per_day', 'twice_per_day', 'three_times_per_day',
  'every_six_hours', 'hourly', 'shift_wise', 'weekly', 'fortnightly',
  'monthly', 'as_and_when_required'
];

class FrequencyService {
  async createFrequency(userData, body) {
    const { frequencyName, frequencyType, timesPerDay, daysBetween, description } = body;
    if (!frequencyName) throw new ValidationError('frequencyName is required');

    const ref = db.collection('frequencies').doc();
    const data = {
      uid: ref.id,
      frequencyName,
      frequencyType: frequencyType || 'other',
      timesPerDay: timesPerDay || 0,
      daysBetween: daysBetween || 0,
      description: description || '',
      status: 'active',
      createdBy: userData.uid,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    };
    await ref.set(data);
    return { message: 'Frequency created', uid: ref.id, frequency: data };
  }

  async getFrequencies(query = {}) {
    const { status, limit = 50, cursor } = query;
    let firestoreQuery = db.collection('frequencies');
    if (status) firestoreQuery = firestoreQuery.where('status', '==', status);
    const result = await paginate(firestoreQuery, { limit, cursor, orderBy: 'frequencyName', orderDir: 'asc' });
    return { count: result.items.length, frequencies: result.items, pagination: result.pagination };
  }

  async getFrequencyById(uid) {
    const doc = await db.collection('frequencies').doc(uid).get();
    if (!doc.exists) throw new NotFoundError('Frequency not found');
    return { id: doc.id, ...doc.data() };
  }

  async updateFrequency(uid, body) {
    const ref = db.collection('frequencies').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Frequency not found');
    const updates = {};
    const allowed = ['frequencyName', 'frequencyType', 'timesPerDay', 'daysBetween', 'description', 'status'];
    for (const key of allowed) {
      if (body[key] !== undefined) updates[key] = body[key];
    }
    updates.updatedAt = new Date().toISOString();
    await ref.update(updates);
    return { message: 'Frequency updated', uid };
  }

  async deleteFrequency(uid) {
    const ref = db.collection('frequencies').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Frequency not found');
    await ref.update({ status: 'inactive', deletedAt: new Date().toISOString(), updatedAt: new Date().toISOString() });
    return { message: 'Frequency deactivated' };
  }

  // Frequency calculation and task generation
  async calculateFrequency(data) {
    const { frequencyId, areaId, platformId, stationId, startDate, endDate } = data;
    
    if (!frequencyId) throw new ValidationError('frequencyId is required');
    
    const freqDoc = await db.collection('frequencies').doc(frequencyId).get();
    if (!freqDoc.exists) throw new NotFoundError('Frequency not found');
    
    const freqData = freqDoc.data();
    const start = startDate ? new Date(startDate) : new Date();
    const end = endDate ? new Date(endDate) : new Date(start.getTime() + 30 * 24 * 60 * 60 * 1000); // 30 days default
    
    let tasks = [];
    const freqType = freqData.frequencyType;
    const timesPerDay = freqData.timesPerDay || 1;
    const daysBetween = freqData.daysBetween || 1;
    
    let currentDate = new Date(start);
    while (currentDate <= end) {
      for (let i = 0; i < timesPerDay; i++) {
        const taskDate = new Date(currentDate);
        taskDate.setHours(taskDate.getHours() + (i * Math.floor(24 / timesPerDay)));
        
        tasks.push({
          scheduledAt: new Date(taskDate),
          areaId,
          platformId,
          stationId,
          frequencyId,
          frequencyType: freqType,
          status: 'pending'
        });
      }
      
      currentDate.setDate(currentDate.getDate() + daysBetween);
    }
    
    return {
      frequencyId,
      frequencyName: freqData.frequencyName,
      frequencyType: freqType,
      totalTasks: tasks.length,
      tasks,
      period: { start: start.toISOString(), end: end.toISOString() }
    };
  }

  async getAreaTasks(areaId, query = {}) {
    const { limit = 50, cursor, status } = query;
    let firestoreQuery = db.collection('tasks').where('areaId', '==', areaId);
    
    if (status) firestoreQuery = firestoreQuery.where('status', '==', status);
    firestoreQuery = firestoreQuery.orderBy('scheduledAt', 'desc');
    
    const result = await paginate(firestoreQuery, { limit, cursor });
    return { count: result.items.length, tasks: result.items, pagination: result.pagination };
  }

  async generateTasksFromFrequency(frequencyId, data) {
    const { areaId, platformId, stationId, startDate, endDate, assignedTo } = data;
    
    if (!frequencyId) throw new ValidationError('frequencyId is required');
    if (!areaId) throw new ValidationError('areaId is required');
    
    const calculation = await this.calculateFrequency({ frequencyId, areaId, platformId, stationId, startDate, endDate });
    
    const batch = db.batch();
    const taskRefs = [];
    
    for (const task of calculation.tasks) {
      const taskRef = db.collection('tasks').doc();
      const taskData = {
        uid: taskRef.id,
        ...task,
        assignedTo: assignedTo || null,
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        createdBy: 'system' // Will be updated with actual user
      };
      batch.set(taskRef, taskData);
      taskRefs.push(taskRef.id);
    }
    
    await batch.commit();
    
    return {
      message: `Generated ${taskRefs.length} tasks from frequency`,
      frequencyId,
      areaId,
      taskIds: taskRefs,
      tasks: calculation.tasks
    };
  }

  async getFrequencySchedule(query = {}) {
    const { frequencyId, areaId, platformId, stationId } = query;
    
    if (!frequencyId) throw new ValidationError('frequencyId is required');
    
    const freqDoc = await db.collection('frequencies').doc(frequencyId).get();
    if (!freqDoc.exists) throw new NotFoundError('Frequency not found');
    
    const freqData = freqDoc.data();
    const startDate = query.startDate ? new Date(query.startDate) : new Date();
    const endDate = query.endDate ? new Date(query.endDate) : new Date(startDate.getTime() + 30 * 24 * 60 * 60 * 1000);
    
    // Filter by area/platform/station if provided
    const filter = { frequencyId };
    if (areaId) filter.areaId = areaId;
    if (platformId) filter.platformId = platformId;
    if (stationId) filter.stationId = stationId;
    
    const tasksSnapshot = await db.collection('tasks')
      .where('frequencyId', '==', frequencyId)
      .where('scheduledAt', '>=', startDate.toISOString())
      .where('scheduledAt', '<=', endDate.toISOString())
      .orderBy('scheduledAt', 'asc')
      .get();
    
    const tasks = tasksSnapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    
    // Filter by area/platform/station if provided
    const filteredTasks = tasks.filter(task => {
      if (areaId && task.areaId !== areaId) return false;
      if (platformId && task.platformId !== platformId) return false;
      if (stationId && task.stationId !== stationId) return false;
      return true;
    });
    
    return {
      frequencyId,
      frequencyName: freqData.frequencyName,
      frequencyType: freqData.frequencyType,
      totalTasks: filteredTasks.length,
      tasks: filteredTasks,
      period: { start: startDate.toISOString(), end: endDate.toISOString() }
    };
  }

  async getTaskSystemReport(query = {}) {
    const { startDate, endDate, areaId, platformId, stationId } = query;
    const start = startDate ? new Date(startDate) : new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
    const end = endDate ? new Date(endDate) : new Date();
    
    let firestoreQuery = db.collection('tasks')
      .where('scheduledAt', '>=', start.toISOString())
      .where('scheduledAt', '<=', end.toISOString());
    
    if (areaId) firestoreQuery = firestoreQuery.where('areaId', '==', areaId);
    if (platformId) firestoreQuery = firestoreQuery.where('platformId', '==', platformId);
    if (stationId) firestoreQuery = firestoreQuery.where('stationId', '==', stationId);
    
    const tasksSnapshot = await firestoreQuery.get();
    const tasks = tasksSnapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    
    // Group by frequency
    const frequencyStats = {};
    for (const task of tasks) {
      if (task.frequencyId) {
        if (!frequencyStats[task.frequencyId]) {
          frequencyStats[task.frequencyId] = { total: 0, completed: 0, pending: 0, overdue: 0 };
        }
        frequencyStats[task.frequencyId].total++;
        if (task.status === 'completed') frequencyStats[task.frequencyId].completed++;
        else if (task.status === 'pending') frequencyStats[task.frequencyId].pending++;
        else if (task.status === 'overdue') frequencyStats[task.frequencyId].overdue++;
      }
    }
    
    // Group by area
    const areaStats = {};
    for (const task of tasks) {
      if (task.areaId) {
        if (!areaStats[task.areaId]) {
          areaStats[task.areaId] = { total: 0, completed: 0, pending: 0, overdue: 0 };
        }
        areaStats[task.areaId].total++;
        if (task.status === 'completed') areaStats[task.areaId].completed++;
        else if (task.status === 'pending') areaStats[task.areaId].pending++;
        else if (task.status === 'overdue') areaStats[task.areaId].overdue++;
      }
    }
    
    return {
      period: { start: start.toISOString(), end: end.toISOString() },
      totalTasks: tasks.length,
      byStatus: {
        completed: tasks.filter(t => t.status === 'completed').length,
        pending: tasks.filter(t => t.status === 'pending').length,
        overdue: tasks.filter(t => t.status === 'overdue').length,
        in_progress: tasks.filter(t => t.status === 'in_progress').length
      },
      byFrequency: frequencyStats,
      byArea: areaStats
    };
  }
}

export const frequencyService = new FrequencyService();
