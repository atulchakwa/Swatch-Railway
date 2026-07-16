import { db, admin } from '../database/index.js';
import { NotFoundError, ValidationError } from '../errors/index.js';
import logger from '../logger/index.js';

class ZoneService {
  async createZone(data) {
    const { name, code, region } = data;
    if (!name) throw new ValidationError('Zone name is required');

    const existing = await db.collection('zones').where('name', '==', name).limit(1).get();
    if (!existing.empty) throw new ValidationError('Zone with this name already exists');

    const ref = db.collection('zones').doc();
    const zone = {
      uid: ref.id,
      name,
      code: code || name.substring(0, 3).toUpperCase(),
      region: region || null,
      status: 'active',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    await ref.set(zone);
    logger.info('ZoneService', `Zone created: ${name}`, { code, region });
    return { message: 'Zone created', zoneId: ref.id };
  }

  async getZones(filters = {}) {
    let query = db.collection('zones');
    if (filters.status) query = query.where('status', '==', filters.status);
    const snapshot = await query.limit(200).get();
    const zones = [];
    snapshot.forEach(doc => zones.push({ id: doc.id, ...doc.data() }));
    zones.sort((a, b) => (a.name || '').localeCompare(b.name || ''));
    return { count: zones.length, zones };
  }

  async getZoneById(id) {
    const doc = await db.collection('zones').doc(id).get();
    if (!doc.exists) throw new NotFoundError('Zone not found');
    return { zone: { id: doc.id, ...doc.data() } };
  }

  async updateZone(id, data) {
    const ref = db.collection('zones').doc(id);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Zone not found');

    const updateData = {};
    if (data.name !== undefined) updateData.name = data.name;
    if (data.code !== undefined) updateData.code = data.code;
    if (data.region !== undefined) updateData.region = data.region;
    if (data.status !== undefined) updateData.status = data.status;
    updateData.updatedAt = admin.firestore.FieldValue.serverTimestamp();

    await ref.update(updateData);
    logger.info('ZoneService', `Zone ${id} updated`);
    return { message: 'Zone updated' };
  }

  async deleteZone(id) {
    const ref = db.collection('zones').doc(id);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Zone not found');

    const activeDivisions = await db.collection('divisions')
      .where('zone', '==', id)
      .where('status', '==', 'active')
      .limit(1).get();

    if (!activeDivisions.empty) {
      throw new ValidationError('Cannot delete zone: active divisions reference it');
    }

    const activeStations = await db.collection('stations')
      .where('zone', '==', id)
      .where('active', '==', true)
      .limit(1).get();

    if (!activeStations.empty) {
      throw new ValidationError('Cannot delete zone: active stations reference it');
    }

    await ref.delete();
    logger.info('ZoneService', `Zone ${id} deleted`);
    return { message: 'Zone deleted' };
  }
}

export const zoneService = new ZoneService();
