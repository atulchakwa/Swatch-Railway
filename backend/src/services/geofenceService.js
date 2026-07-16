import { db, admin } from '../database/index.js';
import { NotFoundError, ValidationError } from '../errors/index.js';
import logger from '../logger/index.js';

class GeofenceService {
  async createGeofence(data) {
    const { stationId, name, centerLatitude, centerLongitude, radiusMeters, type, platformId, areaId } = data;
    if (!stationId || !name || centerLatitude == null || centerLongitude == null || !radiusMeters) {
      throw new ValidationError('stationId, name, centerLatitude, centerLongitude, and radiusMeters are required');
    }
    if (radiusMeters <= 0) throw new ValidationError('radiusMeters must be positive');

    const stationDoc = await db.collection('stations').doc(stationId).get();
    if (!stationDoc.exists) throw new NotFoundError('Station not found');

    const ref = db.collection('stationGeofences').doc();
    const geofence = {
      uid: ref.id, stationId, stationName: stationDoc.data().stationName || '',
      name, centerLatitude, centerLongitude, radiusMeters,
      type: type || 'station', platformId: platformId || null, areaId: areaId || null,
      isActive: true,
      createdBy: data.createdBy || null, createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };
    await ref.set(geofence);
    logger.info('GeofenceService', `Created geofence ${name} for station ${stationId}`);
    return { message: 'Geofence created', uid: ref.id };
  }

  async getGeofences(filters = {}) {
    let query = db.collection('stationGeofences');
    if (filters.stationId) query = query.where('stationId', '==', filters.stationId);
    if (filters.type) query = query.where('type', '==', filters.type);
    if (filters.isActive !== undefined) query = query.where('isActive', '==', filters.isActive);
    const snapshot = await query.limit(200).get();
    const geofences = [];
    snapshot.forEach(doc => geofences.push({ id: doc.id, ...doc.data() }));
    return { count: geofences.length, geofences };
  }

  async getGeofenceById(uid) {
    const doc = await db.collection('stationGeofences').doc(uid).get();
    if (!doc.exists) throw new NotFoundError('Geofence not found');
    return { id: doc.id, ...doc.data() };
  }

  async updateGeofence(uid, data) {
    const ref = db.collection('stationGeofences').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Geofence not found');
    const allowed = ['name', 'centerLatitude', 'centerLongitude', 'radiusMeters', 'type', 'platformId', 'areaId', 'isActive'];
    const updates = { updatedAt: admin.firestore.FieldValue.serverTimestamp() };
    for (const key of allowed) { if (data[key] !== undefined) updates[key] = data[key]; }
    await ref.update(updates);
    return { message: 'Geofence updated', uid };
  }

  async deleteGeofence(uid) {
    const ref = db.collection('stationGeofences').doc(uid);
    if (!(await ref.get()).exists) throw new NotFoundError('Geofence not found');
    await ref.update({ isActive: false, updatedAt: admin.firestore.FieldValue.serverTimestamp() });
    return { message: 'Geofence deactivated' };
  }

  haversineDistance(lat1, lon1, lat2, lon2) {
    const R = 6371000;
    const dLat = (lat2 - lat1) * Math.PI / 180;
    const dLon = (lon2 - lon1) * Math.PI / 180;
    const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
              Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
              Math.sin(dLon / 2) * Math.sin(dLon / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
  }

  async isWithinGeofence(stationId, latitude, longitude) {
    if (latitude == null || longitude == null) return { within: false, reason: 'No GPS coordinates' };
    const snapshot = await db.collection('stationGeofences')
      .where('stationId', '==', stationId)
      .where('isActive', '==', true)
      .limit(1).get();
    if (snapshot.empty) return { within: true, reason: 'No geofence configured' };
    const gf = snapshot.docs[0].data();
    const distance = this.haversineDistance(latitude, longitude, gf.centerLatitude, gf.centerLongitude);
    const within = distance <= gf.radiusMeters;
    return { within, distance: Math.round(distance), radius: gf.radiusMeters, geofenceName: gf.name, geofenceId: gf.uid };
  }

  async generateMovementAlert(stationId, workerId, workerName, latitude, longitude) {
    const check = await this.isWithinGeofence(stationId, latitude, longitude);
    if (check.within) return null;
    const ref = db.collection('geofence_alerts').doc();
    const alert = {
      uid: ref.id, stationId, workerId, workerName,
      latitude, longitude, distance: check.distance, radius: check.radius,
      geofenceName: check.geofenceName || '', geofenceId: check.geofenceId || '',
      alertType: 'movement_away', status: 'OPEN',
      notifiedAt: null, resolvedAt: null, resolvedBy: null,
      createdAt: new Date().toISOString(), updatedAt: new Date().toISOString()
    };
    await ref.set(alert);
    logger.warn('GeofenceAlert', `Worker ${workerName} (${workerId}) moved outside geofence at ${stationId}`);
    return { alert, check };
  }

  async getAlerts(filters = {}) {
    let query = db.collection('geofence_alerts');
    if (filters.stationId) query = query.where('stationId', '==', filters.stationId);
    if (filters.workerId) query = query.where('workerId', '==', filters.workerId);
    if (filters.status) query = query.where('status', '==', filters.status);
    if (filters.alertType) query = query.where('alertType', '==', filters.alertType);
    const snapshot = await query.orderBy('createdAt', 'desc').limit(200).get();
    const alerts = [];
    snapshot.forEach(doc => alerts.push(doc.data()));
    return { count: alerts.length, alerts };
  }

  async resolveAlert(uid, userData) {
    const ref = db.collection('geofence_alerts').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Alert not found');
    await ref.update({ status: 'RESOLVED', resolvedBy: userData.uid, resolvedAt: new Date().toISOString(), updatedAt: new Date().toISOString() });
    return { message: 'Alert resolved', uid };
  }
}

export const geofenceService = new GeofenceService();
