import { db, admin } from '../database/index.js';
import { NotFoundError, ValidationError } from '../errors/index.js';
import { paginate } from '../utils/paginate.js';
import { auditService } from './auditService.js';

const INSPECTION_TYPES = ['schedule', 'surprise'];
const GRADE_LABELS = ['excellent', 'very_good', 'good', 'average', 'poor'];
const GRADE_ORDER = { excellent: 10, very_good: 8, good: 6, average: 5, poor: 3 };

const SECTIONS_CONFIG = {
  floor: { displayName: 'Floor', parameters: ['shineLevel', 'dustLevel', 'footMarks', 'panGhutkaStains', 'birdDroppings'] },
  stairs: { displayName: 'Stairs', parameters: ['shineLevel', 'dustLevel', 'footMarks', 'panGhutkaStains', 'birdDroppings'] },
  wallCladdings: { displayName: 'Wall & Claddings', parameters: ['shineLevel', 'dustLevel', 'panGhutkaStains', 'birdDroppings'] },
  steelWorks: { displayName: 'Steel Works', parameters: ['shineLevel', 'birdDroppings', 'fingerPalmMarks', 'dustLevel', 'waterHardnessMarks'] },
  glassWorks: { displayName: 'Glass Works', parameters: ['birdDroppings', 'fingerPalmMarks', 'dustLevel'] },
  escalators: { displayName: 'Escalators', parameters: ['birdDroppings', 'fingerPalmMarks', 'dustLevel'] },
  toilets: { displayName: 'Toilets', parameters: ['mirrors', 'washBasins', 'wcSeats', 'floor', 'odour'] },
};

function _numericToGrade(avg) {
  if (avg >= 9) return 'excellent';
  if (avg >= 7) return 'very_good';
  if (avg >= 5.5) return 'good';
  if (avg >= 4) return 'average';
  return 'poor';
}

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
    const initialSections = {};
    for (const [sectionKey, sectionConfig] of Object.entries(SECTIONS_CONFIG)) {
      const params = {};
      for (const paramKey of sectionConfig.parameters) {
        params[paramKey] = { grade: null, remark: '' };
      }
      initialSections[sectionKey] = { parameters: params, sectionScore: null, sectionGrade: null };
    }
    const data = {
      uid: ref.id, stationId, stationName: stationDoc.data().stationName || '',
      platformId: body.platformId || null, areaId: body.areaId || null,
      inspectionType, templateId: templateId || null, templateName,
      scheduledDate: scheduledDate || new Date().toISOString().split('T')[0],
      inspectorId: inspectorId || userData.uid, inspectorName: userData.fullName || userData.name || '',
      status: 'SCHEDULED', sections: initialSections, overallScore: null, overallGrade: null,
      checklist, checklistResults: [], remarks: remarks || '',
      photos: [], evidence: [], deficiencies: [],
      allDeficienciesClosed: true,
      createdBy: userData.uid, createdAt: new Date().toISOString(), updatedAt: new Date().toISOString()
    };
    await ref.set(data);
    await auditService.logAudit('INSPECTION_CREATED', userData.uid, userData.fullName || userData.name || '', ref.id, 'inspections', `Inspection created for station ${stationDoc.data().stationName || ''}`);
    return { message: 'Inspection created', uid: ref.id, inspection: data };
  }

  async getInspections(query = {}, user) {
    const { stationId, inspectionType, status, inspectorId, date, limit = 50, cursor } = query;
    let q = db.collection('inspections');
    if (user && user.stationId && !stationId) {
      q = q.where('stationId', '==', user.stationId);
    } else if (stationId) {
      q = q.where('stationId', '==', stationId);
    }
    if (inspectionType) q = q.where('inspectionType', '==', inspectionType);
    if (status) q = q.where('status', '==', status);
    if (inspectorId) q = q.where('inspectorId', '==', inspectorId);
    if (date) q = q.where('scheduledDate', '==', date);
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
    const { sections, photos, remarks, checklistResults } = body;
    if (!sections || typeof sections !== 'object') throw new ValidationError('sections object is required');

    const processedSections = {};
    let allParamCount = 0, allParamTotal = 0;

    for (const [sectionKey, sectionConfig] of Object.entries(SECTIONS_CONFIG)) {
      const userSection = sections[sectionKey];
      const params = {};
      let sectionTotal = 0, sectionCount = 0;

      for (const paramKey of sectionConfig.parameters) {
        const rawGrade = userSection?.parameters?.[paramKey]?.grade;
        const gradeVal = rawGrade ? String(rawGrade).toLowerCase() : null;
        const numericGrade = GRADE_ORDER[gradeVal];
        if (numericGrade !== undefined) {
          const remark = userSection?.parameters?.[paramKey]?.remark || '';
          params[paramKey] = { grade: gradeVal, remark, score: numericGrade };
          sectionTotal += numericGrade;
          sectionCount++;
          allParamTotal += numericGrade;
          allParamCount++;
        } else {
          params[paramKey] = { grade: null, remark: '', score: null };
        }
      }

      const sectionAvg = sectionCount > 0 ? sectionTotal / sectionCount : 0;
      const sectionScore = sectionCount > 0 ? Math.round((sectionTotal / sectionCount) * 10) : null;
      const sectionGrade = _numericToGrade(sectionAvg);

      processedSections[sectionKey] = {
        parameters: params,
        sectionScore,
        sectionGrade,
      };
    }

    const overallScore = allParamCount > 0 ? Math.round((allParamTotal / allParamCount) * 10) : 0;
    const overallGrade = _numericToGrade(allParamCount > 0 ? allParamTotal / allParamCount : 0);

    const updates = {
      sections: processedSections,
      overallScore,
      overallGrade,
      photos: photos || [],
      checklistResults: checklistResults || [],
      remarks: remarks || '',
      status: 'COMPLETED',
      completedAt: new Date().toISOString(),
      completedBy: userData.uid,
      updatedAt: new Date().toISOString(),
    };
    await ref.update(updates);
    await db.collection('inspection_scores').add({ inspectionId: uid, stationId: doc.data().stationId, overallScore, grade: overallGrade, scoredAt: new Date().toISOString() });
    await auditService.logAudit('INSPECTION_RATINGS_SUBMITTED', userData.uid, userData.fullName || userData.name || '', uid, 'inspections', `Ratings submitted. Score: ${overallScore} (${overallGrade})`);
    return { message: 'Ratings submitted', uid, overallScore, grade: overallGrade, sections: processedSections };
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
    const snapshot = await db.collection('inspection_scores').where('stationId', '==', stationId).get();
    let total = 0, count = 0;
    const grades = { excellent: 0, very_good: 0, good: 0, average: 0, poor: 0 };
    const scores = [];
    snapshot.forEach(doc => { const d = doc.data(); total += d.overallScore || 0; count++; if (grades[d.grade] !== undefined) grades[d.grade]++; scores.push({ score: d.overallScore, grade: d.grade, date: d.scoredAt }); });
    scores.sort((a, b) => ((b.date || '') > (a.date || '') ? 1 : -1));
    return { stationId, averageScore: count > 0 ? Math.round(total / count) : 0, totalInspections: count, gradeDistribution: grades, recentScores: scores.slice(0, 30) };
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
