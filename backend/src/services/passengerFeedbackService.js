import { db } from '../database/index.js';
import { NotFoundError, ValidationError } from '../errors/index.js';
import { paginate } from '../utils/paginate.js';
import { auditService } from './auditService.js';
import otpStore from '../utils/otpStore.js';
import { notificationService } from '../notifications/index.js';

const OTP_PREFIX = 'PFB_';
const OTP_VERIFIED_PREFIX = 'PFB_VERIFIED_';
const OTP_TTL_MS = 10 * 60 * 1000; // verified-mobile grants last 10 minutes
const _isValidIndianMobile = (phone) => /^[6-9]\d{9}$/.test(String(phone || ''));

const _getISTDate = (date) => {
  const ist = new Date(date.getTime() + 5.5 * 60 * 60 * 1000);
  return ist.toISOString().split('T')[0];
};

const FEEDBACK_GRADES = ['excellent', 'very_good', 'good', 'average', 'poor'];
const GRADE_SCORES = { excellent: 10, very_good: 8, good: 6, average: 5, poor: 3 };

const _numericToGrade = (avg) => {
  if (avg >= 9) return 'excellent';
  if (avg >= 7) return 'very_good';
  if (avg >= 5.5) return 'good';
  if (avg >= 4) return 'average';
  return 'poor';
};

class PassengerFeedbackService {
  _flattenSections(sections) {
    const graded = [];
    const normalized = {};
    if (!sections || typeof sections !== 'object') return { graded, normalized };
    for (const [sectionKey, sec] of Object.entries(sections)) {
      if (!sec || typeof sec !== 'object') continue;
      const params = sec.parameters || sec;
      if (!params || typeof params !== 'object') continue;
      const normParams = {};
      for (const [pk, val] of Object.entries(params)) {
        if (val === null || val === undefined || val === '') continue;
        const entry = typeof val === 'string' ? { grade: val, remark: '' } : val;
        const grade = String(entry.grade ?? '').trim().toLowerCase();
        if (grade === '') continue;
        if (!FEEDBACK_GRADES.includes(grade)) {
          throw new ValidationError(`Invalid grade for ${sectionKey}.${pk}: ${grade}. Expected one of ${FEEDBACK_GRADES.join(', ')}`);
        }
        normParams[pk] = { grade, remark: entry.remark || '' };
        graded.push({ sectionKey, param: pk, grade });
      }
      if (Object.keys(normParams).length > 0) normalized[sectionKey] = { parameters: normParams };
    }
    return { graded, normalized };
  }

  _computeAggregates(sections) {
    const { graded } = this._flattenSections(sections);
    const scores = graded.map(g => GRADE_SCORES[g.grade]);
    const overallScore = scores.length > 0 ? scores.reduce((a, b) => a + b, 0) / scores.length : 0;
    const overallRating = parseFloat((overallScore / 2).toFixed(2));
    return {
      overallScore: parseFloat(overallScore.toFixed(2)),
      overallRating,
      overallGrade: _numericToGrade(overallScore),
      isNegative: overallRating <= 2,
    };
  }

  async createFeedback(userData, body) {
    const { stationId, pnr, passengerName, passengerPhone, journeyDate, sections, comments, phoneVerified } = body;
    if (!stationId) throw new ValidationError('stationId is required');

    const hasPnr = !!(pnr && String(pnr).trim());
    const hasPhone = !!(passengerPhone && String(passengerPhone).trim());
    let verificationMethod = 'pnr';
    if (!hasPnr) {
      // OTP-verified mobile path: passengerPhone + phoneVerified must be present.
      if (!hasPhone) throw new ValidationError('PNR number or a verified mobile number is required');
      if (phoneVerified !== true) throw new ValidationError('Please verify the mobile number with OTP before submitting feedback');
      const verifiedKey = `${OTP_VERIFIED_PREFIX}${String(passengerPhone).trim()}`;
      const granted = await otpStore.get(verifiedKey);
      if (!granted) throw new ValidationError('Mobile number is not verified. Please request and enter the OTP first.');
      await otpStore.delete(verifiedKey); // one-time use
      verificationMethod = 'otp';
    }

    const stationDoc = await db.collection('stations').doc(stationId).get();
    if (!stationDoc.exists) throw new NotFoundError('Station not found');

    const { graded, normalized } = this._flattenSections(sections);
    if (graded.length < 3) throw new ValidationError('At least 3 parameter ratings are required');

    const aggregates = this._computeAggregates(normalized);

    const ref = db.collection('passenger_feedback').doc();
    const now = new Date().toISOString();
    const data = {
      uid: ref.id,
      stationId,
      stationName: stationDoc.data().stationName || '',
      pnr: hasPnr ? String(pnr).trim().toUpperCase() : '',
      passengerName: passengerName || '',
      passengerPhone: hasPhone ? String(passengerPhone).trim() : '',
      journeyDate: journeyDate || '',
      sections: normalized,
      ...aggregates,
      comments: comments || '',
      verificationMethod,
      takenBy: { uid: userData.uid, name: userData.fullName || userData.name || '', role: userData.role || '' },
      status: 'SUBMITTED',
      date: _getISTDate(new Date()),
      createdAt: now,
      updatedAt: now,
    };
    await ref.set(data);
    await auditService.logAudit('PASSENGER_FEEDBACK_SUBMITTED', userData.uid, data.takenBy.name, ref.id, 'passenger_feedback', `Passenger feedback recorded via ${verificationMethod}. Rating: ${data.overallRating}, Grade: ${data.overallGrade}`);
    return { message: 'Passenger feedback recorded', uid: ref.id, feedback: data };
  }

  // Sends a 6-digit OTP to the passenger's mobile for feedback verification.
  async sendOtp(phone) {
    if (!_isValidIndianMobile(phone)) {
      throw new ValidationError('Enter a valid 10-digit mobile number');
    }
    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    await otpStore.set(`${OTP_PREFIX}${String(phone).trim()}`, otp);
    await notificationService.sendOtpSms(String(phone).trim(), otp);
    return { success: true, message: 'OTP has been sent to the mobile number.' };
  }

  // Verifies the OTP and grants a short-lived verified-mobile token.
  async verifyOtp(phone, otp) {
    if (!_isValidIndianMobile(phone)) throw new ValidationError('Enter a valid 10-digit mobile number');
    if (!otp || !String(otp).trim()) throw new ValidationError('OTP is required');
    const key = `${OTP_PREFIX}${String(phone).trim()}`;
    const stored = await otpStore.get(key);
    if (!stored) throw new ValidationError('OTP expired or not requested. Please request a new OTP.');
    if (String(stored).trim() !== String(otp).trim()) {
      throw new ValidationError('Invalid OTP. Please check and try again.');
    }
    await otpStore.delete(key);
    const verifiedKey = `${OTP_VERIFIED_PREFIX}${String(phone).trim()}`;
    await db.collection('_otpStore').doc(verifiedKey).set({
      value: 'verified',
      createdAt: new Date().toISOString(),
      expireAt: new Date(Date.now() + OTP_TTL_MS).toISOString(),
    });
    return { success: true, message: 'Mobile number verified. You can now submit feedback.', verified: true, phone: String(phone).trim() };
  }

  async listFeedback(query = {}) {
    const { stationId, pnr, date, status, limit = 50, cursor } = query;
    let q = db.collection('passenger_feedback');
    if (stationId) q = q.where('stationId', '==', stationId);
    if (pnr) q = q.where('pnr', '==', String(pnr).trim().toUpperCase());
    if (date) q = q.where('date', '==', date);
    if (status) q = q.where('status', '==', status);
    const result = await paginate(q, { limit, cursor, orderBy: 'createdAt', orderDir: 'desc' });
    return { count: result.items.length, feedbacks: result.items, pagination: result.pagination };
  }

  async getFeedbackById(uid) {
    const doc = await db.collection('passenger_feedback').doc(uid).get();
    if (!doc.exists) throw new NotFoundError('Feedback not found');
    return { id: doc.id, ...doc.data() };
  }

  async updateFeedback(uid, userData, body) {
    const ref = db.collection('passenger_feedback').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Feedback not found');
    const allowed = ['pnr', 'passengerName', 'passengerPhone', 'journeyDate', 'sections', 'comments'];
    const updates = {};
    for (const key of allowed) {
      if (body[key] !== undefined) updates[key] = body[key];
    }
    if (updates.pnr !== undefined) updates.pnr = String(updates.pnr).trim().toUpperCase();
    if (updates.sections !== undefined) {
      const { normalized } = this._flattenSections(updates.sections);
      const current = doc.data().sections || {};
      const { graded: mergedGraded, normalized: mergedNorm } = this._flattenSections({ ...current, ...normalized });
      if (mergedGraded.length < 3) throw new ValidationError('At least 3 parameter ratings are required');
      updates.sections = mergedNorm;
      Object.assign(updates, this._computeAggregates(mergedNorm));
    }
    updates.updatedAt = new Date().toISOString();
    await ref.update(updates);
    return { message: 'Feedback updated', uid };
  }

  async deleteFeedback(uid) {
    const ref = db.collection('passenger_feedback').doc(uid);
    if (!(await ref.get()).exists) throw new NotFoundError('Feedback not found');
    await ref.update({ status: 'CANCELLED', cancelledAt: new Date().toISOString(), updatedAt: new Date().toISOString() });
    return { message: 'Feedback cancelled' };
  }

  async getFeedbackSummary(stationId, query = {}) {
    if (!stationId) throw new ValidationError('stationId is required');
    const { startDate, endDate } = query;
    const snapshot = await db.collection('passenger_feedback').where('stationId', '==', stationId).get();
    const records = [];
    snapshot.forEach(doc => records.push(doc.data()));
    const filtered = records.filter(r => {
      if (r.status === 'CANCELLED') return false;
      const c = r.createdAt || '';
      if (startDate && c < startDate) return false;
      if (endDate && c > endDate + 'T23:59:59') return false;
      return true;
    });
    let totalRating = 0, negativeCount = 0;
    const catBreakdown = {};
    for (const fb of filtered) {
      totalRating += fb.overallRating || 0;
      if (fb.isNegative) negativeCount++;
      for (const [cat, val] of Object.entries(fb.sections || {})) {
        const params = (val && val.parameters) || {};
        for (const [pk, pval] of Object.entries(params)) {
          const score = GRADE_SCORES[pval.grade] ?? 0;
          if (!catBreakdown[pk]) catBreakdown[pk] = { count: 0, totalRating: 0 };
          catBreakdown[pk].count++;
          catBreakdown[pk].totalRating += score;
        }
      }
    }
    for (const cat of Object.keys(catBreakdown)) {
      catBreakdown[cat].averageRating = catBreakdown[cat].count > 0 ? Math.round(catBreakdown[cat].totalRating / catBreakdown[cat].count * 10) / 10 : 0;
    }
    const avg = filtered.length > 0 ? totalRating / filtered.length : 0;
    return {
      stationId,
      totalFeedback: filtered.length,
      averageRating: Math.round(avg * 10) / 10,
      overallScore: Math.round(avg * 2 * 10) / 10,
      overallGrade: _numericToGrade(avg * 2),
      negativeCount,
      positiveCount: filtered.length - negativeCount,
      uniquePnrCount: new Set(filtered.map(f => f.pnr || f.passengerPhone || '')).size,
      categoryBreakdown: catBreakdown,
    };
  }
}

export const passengerFeedbackService = new PassengerFeedbackService();