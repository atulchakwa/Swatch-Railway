import { db, admin } from '../database/index.js';
import { NotFoundError, ValidationError } from '../errors/index.js';
import { auditService } from './auditService.js';

const CATEGORIES = ['broken_fittings', 'damaged_dustbin', 'leakage', 'blocked_drain', 'damaged_tiles', 'lighting_issue', 'signage_issue', 'damaged_fixture', 'other'];
const SEVERITIES = ['low', 'medium', 'high', 'critical'];
const STATUSES = ['REPORTED', 'ASSIGNED', 'IN_PROGRESS', 'RESOLVED', 'CLOSED', 'REJECTED'];

class PettyIssueService {
  async create(user, body) {
    const { stationId, category, description, areaId, platformId, severity, photo, gpsLatitude, gpsLongitude } = body;
    if (!stationId || !category || !description) throw new ValidationError('stationId, category, and description are required');
    if (!CATEGORIES.includes(category)) throw new ValidationError(`category must be one of: ${CATEGORIES.join(', ')}`);

    const stationDoc = await db.collection('stations').doc(stationId).get();
    if (!stationDoc.exists) throw new NotFoundError('Station not found');

    const ref = db.collection('petty_issues').doc();
    const now = new Date().toISOString();
    const data = {
      uid: ref.id, stationId, stationName: stationDoc.data().stationName || '',
      category, description, areaId: areaId || null, platformId: platformId || null,
      severity: SEVERITIES.includes(severity) ? severity : 'medium',
      photo: photo || null, gpsLatitude: gpsLatitude || null, gpsLongitude: gpsLongitude || null,
      status: 'REPORTED',
      remarks: body.remarks || '',
      assignedTo: null, assignedToName: null,
      reportedBy: user.uid, reportedByName: user.fullName || user.name || '',
      reportedAt: now, resolvedAt: null, resolvedBy: null, resolvedByName: null,
      closureHistory: [],
      createdAt: now, updatedAt: now,
    };
    await ref.set(data);
    await auditService.logAudit('PETTY_ISSUE_CREATED', user.uid, user.fullName || user.name || '', ref.id, 'petty_issues', `Petty issue reported: ${category} - ${description.substring(0, 80)}`);
    return { message: 'Petty issue reported', uid: ref.id, issue: data };
  }

  async list(query = {}) {
    const { stationId, category, severity, status, areaId, limit = 50 } = query;
    let q = db.collection('petty_issues');
    if (stationId) q = q.where('stationId', '==', stationId);
    if (category) q = q.where('category', '==', category);
    if (severity) q = q.where('severity', '==', severity);
    if (status) q = q.where('status', '==', status);
    if (areaId) q = q.where('areaId', '==', areaId);
    const snapshot = await q.limit(parseInt(limit)).get();
    const items = []; snapshot.forEach(d => items.push(d.data()));
    items.sort((a, b) => ((b.createdAt || '') > (a.createdAt || '') ? 1 : -1));
    return { count: items.length, issues: items };
  }

  async getById(uid) {
    const doc = await db.collection('petty_issues').doc(uid).get();
    if (!doc.exists) throw new NotFoundError('Petty issue not found');
    return { id: doc.id, ...doc.data() };
  }

  async updateStatus(uid, user, body) {
    const ref = db.collection('petty_issues').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Petty issue not found');
    const { status, remarks, assignedTo, assignedToName } = body;
    if (!status) throw new ValidationError('status is required');
    if (!STATUSES.includes(status)) throw new ValidationError(`status must be one of: ${STATUSES.join(', ')}`);

    const data = doc.data();
    const now = new Date().toISOString();
    const historyEntry = {
      fromStatus: data.status, toStatus: status,
      changedBy: user.uid, changedByName: user.fullName || user.name || '',
      remarks: remarks || '', timestamp: now,
    };

    const updates = {
      status, remarks: remarks !== undefined ? remarks : data.remarks,
      updatedAt: now,
      closureHistory: admin.firestore.FieldValue.arrayUnion(historyEntry),
    };
    if (assignedTo) { updates.assignedTo = assignedTo; updates.assignedToName = assignedToName || ''; }
    if (status === 'RESOLVED' || status === 'CLOSED') {
      updates.resolvedAt = now;
      updates.resolvedBy = user.uid;
      updates.resolvedByName = user.fullName || user.name || '';
    }
    await ref.update(updates);
    await auditService.logAudit('PETTY_ISSUE_STATUS_CHANGED', user.uid, user.fullName || user.name || '', uid, 'petty_issues', `Status ${data.status} → ${status}. Remarks: ${remarks || 'None'}`);
    return { message: 'Petty issue updated', uid, status };
  }

  async resolve(uid, user, body) {
    return this.updateStatus(uid, user, { ...body, status: 'RESOLVED' });
  }

  async close(uid, user, body) {
    return this.updateStatus(uid, user, { ...body, status: 'CLOSED' });
  }

  async update(uid, user, body) {
    const ref = db.collection('petty_issues').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Petty issue not found');
    const allowed = ['remarks', 'severity', 'assignedTo', 'assignedToName', 'photo'];
    const updates = {};
    for (const key of allowed) { if (body[key] !== undefined) updates[key] = body[key]; }
    updates.updatedAt = new Date().toISOString();
    if (Object.keys(updates).length <= 1) return { message: 'No changes', uid };
    await ref.update(updates);
    return { message: 'Petty issue updated', uid };
  }

  async delete(uid) {
    const ref = db.collection('petty_issues').doc(uid);
    if (!(await ref.get()).exists) throw new NotFoundError('Petty issue not found');
    await ref.update({ status: 'REJECTED', updatedAt: new Date().toISOString() });
    return { message: 'Petty issue cancelled' };
  }

  async getSummary(stationId) {
    if (!stationId) throw new ValidationError('stationId is required');
    const snapshot = await db.collection('petty_issues').where('stationId', '==', stationId).get();
    let total = 0;
    const byStatus = {};
    const bySeverity = {};
    const byCategory = {};
    snapshot.forEach(d => {
      const d2 = d.data();
      total++;
      byStatus[d2.status] = (byStatus[d2.status] || 0) + 1;
      bySeverity[d2.severity] = (bySeverity[d2.severity] || 0) + 1;
      byCategory[d2.category] = (byCategory[d2.category] || 0) + 1;
    });
    return { stationId, total, byStatus, bySeverity, byCategory };
  }
}

export const pettyIssueService = new PettyIssueService();
