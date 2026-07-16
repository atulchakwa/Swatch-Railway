import { db, admin } from '../database/index.js';
import { NotFoundError, ValidationError } from '../errors/index.js';
import logger from '../logger/index.js';

const DEFAULT_TASK_TYPES = [
  'sweeping', 'mopping', 'washing', 'toilet_cleaning', 'rag_picking',
  'garbage_collection', 'garbage_disposal', 'drain_cleaning',
  'consumable_refill', 'cobweb_removal', 'deep_cleaning'
];

class TaskTypeService {
  async seedDefaultTaskTypes() {
    const existing = await db.collection('taskTypes').limit(1).get();
    if (!existing.empty) return { message: 'Task types already seeded' };

    const batch = db.batch();
    let count = 0;
    for (const type of DEFAULT_TASK_TYPES) {
      const ref = db.collection('taskTypes').doc();
      batch.set(ref, {
        uid: ref.id,
        name: type,
        label: type.replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase()),
        category: 'cleaning',
        isActive: true,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      count++;
    }
    await batch.commit();
    logger.info('TaskTypeService', `Seeded ${count} default task types`);
    return { message: `Seeded ${count} default task types`, count };
  }

  async createTaskType(data) {
    const { name, label, category } = data;
    if (!name) throw new ValidationError('Task type name is required');

    const ref = db.collection('taskTypes').doc();
    const taskType = {
      uid: ref.id,
      name,
      label: label || name.replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase()),
      category: category || 'cleaning',
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };
    await ref.set(taskType);
    return { message: 'Task type created', taskTypeId: ref.id };
  }

  async getTaskTypes(filters = {}) {
    let query = db.collection('taskTypes');
    if (filters.category) query = query.where('category', '==', filters.category);
    if (filters.isActive !== undefined) query = query.where('isActive', '==', filters.isActive);
    const snapshot = await query.limit(200).get();
    const types = [];
    snapshot.forEach(doc => types.push({ id: doc.id, ...doc.data() }));
    types.sort((a, b) => (a.name || '').localeCompare(b.name || ''));
    return { count: types.length, taskTypes: types };
  }

  async updateTaskType(id, data) {
    const ref = db.collection('taskTypes').doc(id);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Task type not found');

    const updateData = {};
    if (data.name !== undefined) updateData.name = data.name;
    if (data.label !== undefined) updateData.label = data.label;
    if (data.category !== undefined) updateData.category = data.category;
    if (data.isActive !== undefined) updateData.isActive = data.isActive;
    updateData.updatedAt = admin.firestore.FieldValue.serverTimestamp();

    await ref.update(updateData);
    return { message: 'Task type updated' };
  }

  async deleteTaskType(id) {
    const ref = db.collection('taskTypes').doc(id);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Task type not found');
    await ref.update({ isActive: false, updatedAt: admin.firestore.FieldValue.serverTimestamp() });
    return { message: 'Task type deactivated' };
  }
}

export const taskTypeService = new TaskTypeService();
