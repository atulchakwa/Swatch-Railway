import { db, admin } from '../database/index.js';
import { NotFoundError, ValidationError } from '../errors/index.js';
import { paginate } from '../utils/paginate.js';
import { auditService } from './auditService.js';

const INSPECTION_TYPES = ['daily', 'surprise', 'ad_hoc', 'complaint_based', 'monthly_review', 'routine', 'random', 'emergency', 'petty_issue_linked', 'cleanliness_scorecard'];
const RATING_LABELS = ['dirty', 'poor', 'average', 'good', 'excellent'];

class InspectionService {
  async createInspection(userData, body) {
    const { stationId, inspectionType, scheduledDate, templateId, inspectorId, remarks } = body;
    if (!stationId || !inspectionType) throw new ValidationError('stationId and inspectionType are required');
    if (!INSPECTION_TYPES.includes(inspectionType)) throw new ValidationError(`inspectionType must be one of: ${INSPECTION_TYPES.join(', ')}`);

    const stationDoc = await db.collection('stations').doc(stationId).get();
    if (!stationDoc.exists) throw new NotFoundError('Station not found');

    const template = templateId ? await db.collection('inspection_templates').doc(templateId).get() : null;
    const checklist = template?.exists ? template.data().checklistItems || [] : [];
    const templateName = template?.exists ? template.data().templateName : null;

    const ref = db.collection('inspections').doc();
    const data = {
      uid: ref.id, stationId, stationName: stationDoc.data().stationName || '',
      platformId: body.platformId || null, areaId: body.areaId || null,
      inspectionType, templateId: templateId || null, templateName,
      scheduledDate: scheduledDate || new Date().toISOString().split('T')[0],
      inspectorId: inspectorId || userData.uid, inspectorName: userData.fullName || userData.name || '',
      status: 'SCHEDULED', ratings: {}, overallScore: null, grade: null,
      checklist, checklistResults: [], remarks: remarks || '',
      photos: [], evidence: [], deficiencies: [],
      allDeficienciesClosed: true,
      createdBy: userData.uid, createdAt: new Date().toISOString(), updatedAt: new Date().toISOString()
    };
    await ref.set(data);
    await auditService.logAudit('INSPECTION_CREATED', userData.uid, userData.fullName || userData.name || '', ref.id, 'inspections', `Inspection created for station ${stationDoc.data().stationName || ''}`);
    return { message: 'Inspection created', uid: ref.id, inspection: data };
  }

  async getInspections(query = {}) {
    const { stationId, inspectionType, status, inspectorId, limit = 50, cursor } = query;
    let q = db.collection('inspections');
    if (stationId) q = q.where('stationId', '==', stationId);
    if (inspectionType) q = q.where('inspectionType', '==', inspectionType);
    if (status) q = q.where('status', '==', status);
    if (inspectorId) q = q.where('inspectorId', '==', inspectorId);
    const result = await paginate(q, { limit, cursor, orderBy: 'createdAt', orderDir: 'desc' });
    return { count: result.items.length, inspections: result.items, pagination: result.pagination };
  }

  async getInspectionById(uid) {
    const doc = await db.collection('inspections').doc(uid).get();
    if (!doc.exists) throw new NotFoundError('Inspection not found');
    return { id: doc.id, ...doc.data() };
  }

  async updateInspection(uid, body) {
    const ref = db.collection('inspections').doc(uid);
    if (!(await ref.get()).exists) throw new NotFoundError('Inspection not found');
    const allowed = ['scheduledDate', 'inspectorId', 'inspectorName', 'remarks', 'status', 'templateId', 'checklist', 'checklistResults'];
    const updates = {};
    for (const key of allowed) { if (body[key] !== undefined) updates[key] = body[key]; }
    updates.updatedAt = new Date().toISOString();
    await ref.update(updates);
    return { message: 'Inspection updated', uid };
  }

  async deleteInspection(uid) {
    const ref = db.collection('inspections').doc(uid);
    if (!(await ref.get()).exists) throw new NotFoundError('Inspection not found');
    await ref.update({ status: 'CANCELLED', deletedAt: new Date().toISOString(), updatedAt: new Date().toISOString() });
    return { message: 'Inspection cancelled' };
  }

  async startInspection(uid, userData) {
    const ref = db.collection('inspections').doc(uid);
    if (!(await ref.get()).exists) throw new NotFoundError('Inspection not found');
    await ref.update({ status: 'IN_PROGRESS', startedAt: new Date().toISOString(), startedBy: userData.uid, updatedAt: new Date().toISOString() });
    await auditService.logAudit('INSPECTION_STARTED', userData.uid, userData.fullName || userData.name || '', uid, 'inspections', `Inspection started`);
    return { message: 'Inspection started', uid };
  }

  async submitRatings(uid, userData, body) {
    const ref = db.collection('inspections').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Inspection not found');
    const { ratings, photos, remarks, checklistResults } = body;
    if (!ratings || typeof ratings !== 'object') throw new ValidationError('ratings object is required');
    const scores = {};
    let total = 0, count = 0;
    for (const [key, val] of Object.entries(ratings)) {
      const idx = RATING_LABELS.indexOf(String(val).toLowerCase());
      if (idx >= 0) { scores[key] = { label: val.toLowerCase(), score: idx + 1 }; total += idx + 1; count++; }
      else if (typeof val === 'number' && val >= 1 && val <= 5) { scores[key] = { label: RATING_LABELS[val - 1], score: val }; total += val; count++; }
    }
    const overallScore = count > 0 ? Math.round((total / count) * 20) : 0;
    const grade = overallScore >= 80 ? 'Excellent' : overallScore >= 60 ? 'Good' : overallScore >= 40 ? 'Average' : overallScore >= 20 ? 'Poor' : 'Dirty';
    const updates = { ratings: scores, overallScore, grade, photos: photos || [], checklistResults: checklistResults || [], remarks: remarks || '', status: 'COMPLETED', completedAt: new Date().toISOString(), completedBy: userData.uid, updatedAt: new Date().toISOString() };
    await ref.update(updates);
    await db.collection('inspection_scores').add({ inspectionId: uid, stationId: doc.data().stationId, overallScore, grade, scoredAt: new Date().toISOString() });
    await auditService.logAudit('INSPECTION_RATINGS_SUBMITTED', userData.uid, userData.fullName || userData.name || '', uid, 'inspections', `Ratings submitted. Score: ${overallScore} (${grade})`);
    return { message: 'Ratings submitted', uid, overallScore, grade, ratings: scores };
  }

  async approveInspection(uid, userData, body) {
    const ref = db.collection('inspections').doc(uid);
    if (!(await ref.get()).exists) throw new NotFoundError('Inspection not found');
    await ref.update({ status: 'APPROVED', approvedBy: userData.uid, approvedAt: new Date().toISOString(), approvalRemarks: body.remarks || '', updatedAt: new Date().toISOString() });
    await auditService.logAudit('INSPECTION_APPROVED', userData.uid, userData.fullName || userData.name || '', uid, 'inspections', `Inspection approved. Remarks: ${body.remarks || 'None'}`);
    return { message: 'Inspection approved', uid };
  }

  async rejectInspection(uid, userData, body) {
    const ref = db.collection('inspections').doc(uid);
    if (!(await ref.get()).exists) throw new NotFoundError('Inspection not found');
    if (!body.reason) throw new ValidationError('Rejection reason is required');
    await ref.update({ status: 'REJECTED', rejectedBy: userData.uid, rejectedAt: new Date().toISOString(), rejectionReason: body.reason, updatedAt: new Date().toISOString() });
    await auditService.logAudit('INSPECTION_REJECTED', userData.uid, userData.fullName || userData.name || '', uid, 'inspections', `Inspection rejected. Reason: ${body.reason}`);
    return { message: 'Inspection rejected', uid };
  }

  async resubmitInspection(uid, userData, body) {
    const ref = db.collection('inspections').doc(uid);
    if (!(await ref.get()).exists) throw new NotFoundError('Inspection not found');
    await ref.update({ status: 'RESUBMITTED', resubmittedBy: userData.uid, resubmittedAt: new Date().toISOString(), resubmissionRemarks: body.remarks || '', updatedAt: new Date().toISOString() });
    await auditService.logAudit('INSPECTION_RESUBMITTED', userData.uid, userData.fullName || userData.name || '', uid, 'inspections', `Inspection resubmitted`);
    return { message: 'Inspection resubmitted', uid };
  }

  async getScoreSummary(stationId) {
    if (!stationId) throw new ValidationError('stationId is required');
    const snapshot = await db.collection('inspection_scores').where('stationId', '==', stationId).orderBy('scoredAt', 'desc').limit(30).get();
    let total = 0, count = 0;
    const grades = { Excellent: 0, Good: 0, Average: 0, Poor: 0, Dirty: 0 };
    snapshot.forEach(doc => { const d = doc.data(); total += d.overallScore || 0; count++; if (grades[d.grade] !== undefined) grades[d.grade]++; });
    return { stationId, averageScore: count > 0 ? Math.round(total / count) : 0, totalInspections: count, gradeDistribution: grades, recentScores: [] };
  }

  async addDeficiency(uid, deficiency, user) {
    const ref = db.collection('inspections').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Inspection not found');
    if (!deficiency.area || !deficiency.description) throw new ValidationError('area and description are required');
    const defId = `DEF-${Date.now()}`;
    const now = new Date().toISOString();
    const newDef = { defId, area: deficiency.area, description: deficiency.description, severity: deficiency.severity || 'medium', assignedTo: deficiency.assignedTo || null, assignedToName: deficiency.assignedToName || '', closureStatus: 'OPEN', closureProof: null, closedAt: null, closedBy: null, addedBy: user.uid, addedByName: user.fullName || '', addedAt: now };
    await ref.update({ deficiencies: admin.firestore.FieldValue.arrayUnion(newDef), allDeficienciesClosed: false, updatedAt: now });
    await auditService.logAudit('INSPECTION_DEFICIENCY_ADDED', user.uid, user.fullName || '', uid, 'inspections', `Deficiency added: ${deficiency.description}`);
    return { message: 'Deficiency added', defId, deficiency: newDef };
  }

  async closeDeficiency(uid, defId, closureData, user) {
    const ref = db.collection('inspections').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Inspection not found');
    const defs = doc.data().deficiencies || [];
    const idx = defs.findIndex(d => d.defId === defId);
    if (idx === -1) throw new NotFoundError('Deficiency not found');
    defs[idx] = { ...defs[idx], closureStatus: 'CLOSED', closureProof: closureData.closureProof || '', closureRemarks: closureData.remarks || '', closedAt: new Date().toISOString(), closedBy: user.uid, closedByName: user.fullName || '' };
    await ref.update({ deficiencies: defs, allDeficienciesClosed: defs.every(d => d.closureStatus === 'CLOSED'), updatedAt: new Date().toISOString() });
    await auditService.logAudit('INSPECTION_DEFICIENCY_CLOSED', user.uid, user.fullName || '', uid, 'inspections', `Deficiency ${defId} closed`);
    return { message: 'Deficiency closed', defId };
  }

  async verifyDeficiencyClosure(uid, defId, user) {
    const ref = db.collection('inspections').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Inspection not found');
    const defs = doc.data().deficiencies || [];
    const idx = defs.findIndex(d => d.defId === defId);
    if (idx === -1) throw new NotFoundError('Deficiency not found');
    if (defs[idx].closureStatus !== 'CLOSED') throw new ValidationError('Deficiency must be CLOSED first');
    defs[idx] = { ...defs[idx], closureStatus: 'RAILWAY_VERIFIED', railwayVerifiedBy: user.uid, railwayVerifiedAt: new Date().toISOString() };
    await ref.update({ deficiencies: defs, updatedAt: new Date().toISOString() });
    await auditService.logAudit('INSPECTION_DEFICIENCY_VERIFIED', user.uid, user.fullName || '', uid, 'inspections', `Deficiency ${defId} closure verified`);
    return { message: 'Deficiency closure verified' };
  }

  async createTemplate(userData, body) {
    if (!body.templateName || !body.checklistItems) throw new ValidationError('templateName and checklistItems are required');
    const ref = db.collection('inspection_templates').doc();
    const data = { uid: ref.id, templateName: body.templateName, inspectionTypes: body.inspectionTypes || [], checklistItems: body.checklistItems, active: true, createdBy: userData.uid, createdAt: new Date().toISOString(), updatedAt: new Date().toISOString() };
    await ref.set(data);
    return { message: 'Template created', uid: ref.id, template: data };
  }

  async listTemplates() {
    const snap = await db.collection('inspection_templates').where('active', '==', true).get();
    return { count: snap.size, templates: snap.docs.map(d => d.data()) };
  }

  async getTemplateById(uid) {
    const doc = await db.collection('inspection_templates').doc(uid).get();
    if (!doc.exists) throw new NotFoundError('Template not found');
    return { id: doc.id, ...doc.data() };
  }

  async updateTemplate(uid, body) {
    const ref = db.collection('inspection_templates').doc(uid);
    if (!(await ref.get()).exists) throw new NotFoundError('Template not found');
    const allowed = ['templateName', 'inspectionTypes', 'checklistItems', 'active'];
    const updates = {};
    for (const key of allowed) { if (body[key] !== undefined) updates[key] = body[key]; }
    updates.updatedAt = new Date().toISOString();
    await ref.update(updates);
    return { message: 'Template updated', uid };
  }

  async deleteTemplate(uid) {
    const ref = db.collection('inspection_templates').doc(uid);
    if (!(await ref.get()).exists) throw new NotFoundError('Template not found');
    await ref.update({ active: false, updatedAt: new Date().toISOString() });
    return { message: 'Template deactivated' };
  }
}

export const inspectionService = new InspectionService();
