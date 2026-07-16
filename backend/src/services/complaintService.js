import { db, admin } from '../database/index.js';
import { NotFoundError, ValidationError } from '../errors/index.js';
import { paginate } from '../utils/paginate.js';

const COMPLAINT_CATEGORIES = [
  'Broken Fittings', 'Damaged Dustbin', 'Leakage', 'Blocked Drain',
  'Damaged Tiles', 'Lighting Issue', 'Signage Issue', 'Damaged Fixture',
  'Plumbing', 'Electrical', 'Structure Damage', 'Hygiene Issue', 'Other'
];
const COMPLAINT_SEVERITIES = ['low', 'medium', 'high', 'critical'];

class ComplaintService {
  async createComplaint(userData, body) {
    const { stationId, category, severity, description, evidence } = body;
    if (!stationId || !category || !description) throw new ValidationError('stationId, category, and description are required');
    if (severity && !COMPLAINT_SEVERITIES.includes(severity)) throw new ValidationError(`severity must be one of: ${COMPLAINT_SEVERITIES.join(', ')}`);

    const ref = db.collection('complaints').doc();
    const slaHours = { low: 72, medium: 48, high: 24, critical: 12 };
    const sla = slaHours[severity || 'medium'];
    const targetClosure = new Date(Date.now() + sla * 3600000).toISOString();
    const now = new Date().toISOString();

    const data = {
      uid: ref.id, stationId, stationName: body.stationName || '',
      area: body.area || '', platformId: body.platformId || null,
      category, severity: severity || 'medium',
      description,
      photoUrl: body.photoUrl || evidence || null,
      latitude: body.latitude || null, longitude: body.longitude || null,
      status: 'REPORTED',
      slaDeadline: targetClosure, slaBreached: false, slaNotified: false,
      reportedBy: userData.uid, reportedByName: userData.fullName || '',
      assignedTo: null, assignedAt: null, assignedToName: null,
      targetClosureTime: targetClosure,
      actionTaken: null, closureProof: null, closurePhotoUrl: null,
      resolvedAt: null, resolvedBy: null,
      rejectionReason: null, rejectedBy: null, rejectedAt: null,
      reopenedCount: 0, reopenReason: null,
      escalatedTo: null, escalatedAt: null, escalationReason: null,
      verifiedBy: null, verifiedAt: null,
      closedBy: null, closedAt: null,
      history: [{ action: 'REPORTED', by: userData.uid, byName: userData.fullName || '', at: now, note: 'Complaint reported' }],
      createdBy: userData.uid, createdAt: now, updatedAt: now
    };
    await ref.set(data);
    return { message: 'Complaint created', uid: ref.id, complaint: data };
  }

  async getComplaints(query = {}) {
    const { stationId, status, severity, category, limit = 50, cursor } = query;
    let q = db.collection('complaints');
    if (stationId) q = q.where('stationId', '==', stationId);
    if (status) {
      const normalized = status.replace(/[A-Z]/g, letter => `_${letter}`).toUpperCase().replace(/^_/, '');
      q = q.where('status', '==', normalized);
    }
    if (severity) q = q.where('severity', '==', severity);
    if (category) q = q.where('category', '==', category);
    const result = await paginate(q, { limit, cursor, orderBy: 'createdAt', orderDir: 'desc' });
    return { count: result.items.length, complaints: result.items, pagination: result.pagination };
  }

  async getComplaintById(uid) {
    const doc = await db.collection('complaints').doc(uid).get();
    if (!doc.exists) throw new NotFoundError('Complaint not found');
    return { id: doc.id, ...doc.data() };
  }

  _addHistory(docRef, entry) {
    return docRef.update({
      history: admin.firestore.FieldValue.arrayUnion({
        ...entry,
        at: new Date().toISOString()
      })
    });
  }

  async assignComplaint(uid, userData, body) {
    const ref = db.collection('complaints').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Complaint not found');
    if (!['REPORTED', 'REOPENED'].includes(doc.data().status)) throw new ValidationError('Complaint must be REPORTED or REOPENED');
    if (!body.assignedTo) throw new ValidationError('assignedTo is required');
    const now = new Date().toISOString();
    await ref.update({ status: 'ASSIGNED', assignedTo: body.assignedTo, assignedToName: body.assignedToName || '', assignedAt: now, targetClosureTime: body.targetClosureTime || null, updatedAt: now });
    await this._addHistory(ref, { action: 'ASSIGNED', by: userData.uid, byName: userData.fullName || '', note: `Assigned to ${body.assignedToName || body.assignedTo}` });
    return { message: 'Complaint assigned', uid };
  }

  async startProgress(uid, userData) {
    const ref = db.collection('complaints').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Complaint not found');
    if (doc.data().status !== 'ASSIGNED') throw new ValidationError('Complaint must be ASSIGNED to start work');
    const now = new Date().toISOString();
    await ref.update({ status: 'IN_PROGRESS', startedAt: now, updatedAt: now });
    await this._addHistory(ref, { action: 'IN_PROGRESS', by: userData.uid, byName: userData.fullName || '', note: 'Work started' });
    return { message: 'Work started on complaint', uid };
  }

  async resolveComplaint(uid, userData, body) {
    const ref = db.collection('complaints').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Complaint not found');
    if (!['ASSIGNED', 'IN_PROGRESS', 'RESUBMITTED'].includes(doc.data().status)) throw new ValidationError('Complaint must be ASSIGNED, IN_PROGRESS, or RESUBMITTED');
    if (!body.actionTaken) throw new ValidationError('actionTaken is required');
    const now = new Date().toISOString();
    await ref.update({ status: 'RESOLVED', actionTaken: body.actionTaken, closureProof: body.closureProof || '', closurePhotoUrl: body.closurePhotoUrl || null, resolvedAt: now, resolvedBy: userData.uid, updatedAt: now });
    await this._addHistory(ref, { action: 'RESOLVED', by: userData.uid, byName: userData.fullName || '', note: body.actionTaken });
    return { message: 'Complaint resolved', uid };
  }

  async verifyComplaint(uid, userData) {
    const ref = db.collection('complaints').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Complaint not found');
    if (doc.data().status !== 'RESOLVED') throw new ValidationError('Complaint must be RESOLVED');
    const now = new Date().toISOString();
    await ref.update({ status: 'RAILWAY_VERIFIED', verifiedBy: userData.uid, verifiedAt: now, updatedAt: now });
    await this._addHistory(ref, { action: 'RAILWAY_VERIFIED', by: userData.uid, byName: userData.fullName || '', note: 'Verified by railway' });
    return { message: 'Complaint verified', uid };
  }

  async closeComplaint(uid, userData) {
    const ref = db.collection('complaints').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Complaint not found');
    if (doc.data().status !== 'RAILWAY_VERIFIED') throw new ValidationError('Complaint must be RAILWAY_VERIFIED');
    const now = new Date().toISOString();
    await ref.update({ status: 'CLOSED', closedBy: userData.uid, closedAt: now, updatedAt: now });
    await this._addHistory(ref, { action: 'CLOSED', by: userData.uid, byName: userData.fullName || '', note: 'Complaint closed' });
    return { message: 'Complaint closed', uid };
  }

  async reopenComplaint(uid, userData, body) {
    const ref = db.collection('complaints').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Complaint not found');
    if (!['CLOSED', 'RESOLVED'].includes(doc.data().status)) throw new ValidationError('Complaint must be CLOSED or RESOLVED');
    const current = doc.data();
    const now = new Date().toISOString();
    await ref.update({ status: 'REOPENED', reopenedCount: (current.reopenedCount || 0) + 1, reopenReason: body.reason || '', reopenedBy: userData.uid, reopenedAt: now, updatedAt: now });
    await this._addHistory(ref, { action: 'REOPENED', by: userData.uid, byName: userData.fullName || '', note: body.reason || 'Reopened' });
    return { message: 'Complaint reopened', uid };
  }

  async rejectComplaint(uid, userData, body) {
    const ref = db.collection('complaints').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Complaint not found');
    const currentStatus = doc.data().status;
    if (!['REPORTED', 'RESOLVED', 'RESUBMITTED'].includes(currentStatus)) {
      throw new ValidationError(`Complaint cannot be rejected. Current status: ${currentStatus}`);
    }
    if (!body.reason) throw new ValidationError('Rejection reason is required');
    const now = new Date().toISOString();
    await ref.update({ status: 'REJECTED', rejectionReason: body.reason, rejectedBy: userData.uid, rejectedAt: now, updatedAt: now });
    await this._addHistory(ref, { action: 'REJECTED', by: userData.uid, byName: userData.fullName || '', note: body.reason });
    return { message: 'Complaint rejected', uid };
  }

  async resubmitComplaint(uid, userData, body) {
    const ref = db.collection('complaints').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Complaint not found');
    if (doc.data().status !== 'REJECTED') throw new ValidationError('Only rejected complaints can be resubmitted');
    if (!body.actionTaken) throw new ValidationError('Updated action taken description is required for resubmission');
    const now = new Date().toISOString();
    await ref.update({
      status: 'RESUBMITTED',
      actionTaken: body.actionTaken,
      closureProof: body.closureProof || '',
      closurePhotoUrl: body.closurePhotoUrl || null,
      rejectionReason: null,
      resolvedAt: now, resolvedBy: userData.uid,
      updatedAt: now
    });
    await this._addHistory(ref, { action: 'RESUBMITTED', by: userData.uid, byName: userData.fullName || '', note: 'Resubmitted for review' });
    return { message: 'Complaint resubmitted', uid };
  }

  async escalateComplaint(uid, userData, body) {
    const ref = db.collection('complaints').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Complaint not found');
    if (!['ASSIGNED', 'IN_PROGRESS'].includes(doc.data().status)) throw new ValidationError('Only ASSIGNED or IN_PROGRESS complaints can be escalated');
    const now = new Date().toISOString();
    await ref.update({ status: 'ESCALATED', escalatedTo: body.escalatedTo, escalatedAt: now, escalationReason: body.reason || '', updatedAt: now });
    await this._addHistory(ref, { action: 'ESCALATED', by: userData.uid, byName: userData.fullName || '', note: body.reason || 'Escalated' });
    return { message: 'Complaint escalated', uid };
  }

  async checkSlaBreaches() {
    const now = new Date().toISOString();
    const snap = await db.collection('complaints').where('status', 'in', ['REPORTED', 'ASSIGNED', 'IN_PROGRESS']).get();
    let breached = 0;
    const batch = db.batch();
    snap.forEach(doc => {
      const d = doc.data();
      if (d.slaDeadline && d.slaDeadline < now && !d.slaBreached) {
        batch.update(doc.ref, { slaBreached: true, slaBreachedAt: now, updatedAt: now });
        breached++;
      }
    });
    if (breached > 0) await batch.commit();
    return { checked: snap.size, breached };
  }

  async deleteComplaint(uid) {
    const ref = db.collection('complaints').doc(uid);
    if (!(await ref.get()).exists) throw new NotFoundError('Complaint not found');
    await ref.update({ status: 'CLOSED', deletedAt: new Date().toISOString(), updatedAt: new Date().toISOString() });
    return { message: 'Complaint closed' };
  }
}

export const complaintService = new ComplaintService();
