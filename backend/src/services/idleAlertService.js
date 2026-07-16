import { db, admin } from '../database/index.js';
import { NotFoundError, ValidationError } from '../errors/index.js';
import logger from '../logger/index.js';

const DEFAULT_IDLE_THRESHOLD_MINUTES = 30;

class IdleAlertService {
  async getIdleConfig(stationId) {
    if (!stationId) return { thresholdMinutes: DEFAULT_IDLE_THRESHOLD_MINUTES };
    const doc = await db.collection('stationConfig').doc(stationId).get();
    if (!doc.exists) return { thresholdMinutes: DEFAULT_IDLE_THRESHOLD_MINUTES };
    return { thresholdMinutes: doc.data().idleThresholdMinutes || DEFAULT_IDLE_THRESHOLD_MINUTES, ...doc.data() };
  }

  async setIdleConfig(stationId, thresholdMinutes) {
    if (!stationId) throw new ValidationError('stationId is required');
    if (!thresholdMinutes || thresholdMinutes < 5) throw new ValidationError('thresholdMinutes must be at least 5');
    await db.collection('stationConfig').doc(stationId).set({ idleThresholdMinutes: thresholdMinutes, updatedAt: new Date().toISOString() }, { merge: true });
    return { message: `Idle threshold set to ${thresholdMinutes} minutes for station ${stationId}` };
  }

  async recordActivity(workerId, stationId, activityType, details = {}) {
    if (!workerId || !stationId) throw new ValidationError('workerId and stationId are required');
    const ref = db.collection('worker_activity_log').doc();
    await ref.set({
      uid: ref.id, workerId, stationId, activityType: activityType || 'ping',
      details, timestamp: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: new Date().toISOString()
    });
  }

  async getLastActivity(workerId) {
    const snapshot = await db.collection('worker_activity_log')
      .where('workerId', '==', workerId)
      .orderBy('createdAt', 'desc').limit(1).get();
    if (snapshot.empty) return null;
    return snapshot.docs[0].data();
  }

  async checkIdleAlertsForWorker(workerId, stationId) {
    const config = await this.getIdleConfig(stationId);
    const thresholdMs = config.thresholdMinutes * 60 * 1000;
    const lastActivity = await this.getLastActivity(workerId);
    if (!lastActivity) return null;
    const lastTime = new Date(lastActivity.createdAt).getTime();
    const now = Date.now();
    const idleDuration = now - lastTime;
    if (idleDuration < thresholdMs) return null;

    const existingAlerts = await db.collection('idle_alerts')
      .where('workerId', '==', workerId)
      .where('status', '==', 'OPEN')
      .where('stationId', '==', stationId)
      .limit(1).get();
    if (!existingAlerts.empty) return null;

    const ref = db.collection('idle_alerts').doc();
    const alert = {
      uid: ref.id, workerId, stationName: config.stationName || '',
      stationId, idleDurationMinutes: Math.round(idleDuration / 60000),
      thresholdMinutes: config.thresholdMinutes, alertType: 'idle_duration',
      status: 'OPEN',
      notifiedAt: null, resolvedAt: null, resolvedBy: null,
      createdAt: new Date().toISOString(), updatedAt: new Date().toISOString()
    };
    await ref.set(alert);
    logger.warn('IdleAlert', `Worker ${workerId} idle for ${Math.round(idleDuration / 60000)}m at station ${stationId}`);
    return alert;
  }

  async checkAllIdleAlerts() {
    const activeShifts = await db.collection('shifts')
      .where('status', '==', 'active').limit(100).get();
    let totalAlerts = 0;
    for (const shiftDoc of activeShifts.docs) {
      const shift = shiftDoc.data();
      const workers = shift.workers || [];
      for (const w of workers) {
        const alert = await this.checkIdleAlertsForWorker(w.uid, shift.stationId);
        if (alert) totalAlerts++;
      }
    }
    return { checked: activeShifts.size, alertsGenerated: totalAlerts };
  }

  async getAlerts(filters = {}) {
    let query = db.collection('idle_alerts');
    if (filters.stationId) query = query.where('stationId', '==', filters.stationId);
    if (filters.workerId) query = query.where('workerId', '==', filters.workerId);
    if (filters.status) query = query.where('status', '==', filters.status);
    const snapshot = await query.orderBy('createdAt', 'desc').limit(200).get();
    const alerts = [];
    snapshot.forEach(doc => alerts.push(doc.data()));
    return { count: alerts.length, alerts };
  }

  async resolveAlert(uid, userData) {
    const ref = db.collection('idle_alerts').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Idle alert not found');
    await ref.update({ status: 'RESOLVED', resolvedBy: userData.uid, resolvedAt: new Date().toISOString(), updatedAt: new Date().toISOString() });
    return { message: 'Idle alert resolved', uid };
  }
}

export const idleAlertService = new IdleAlertService();
