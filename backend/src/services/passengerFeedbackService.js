import { db } from '../database/index.js';
import { NotFoundError, ValidationError } from '../errors/index.js';
import { paginate } from '../utils/paginate.js';
import { auditService } from './auditService.js';

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
  _processRatings(ratings) {
    const raw = ratings || {};
    if (typeof raw !== 'object' || Object.keys(raw).length === 0) {
      throw new ValidationError('At least one category rating is required');
    }
    const processed = {};
    for (const [key, val] of Object.entries(raw)) {
      const grade = String(val).trim().toLowerCase();
      if (!FEEDBACK_GRADES.includes(grade)) {
        throw new ValidationError(`Invalid grade for ${key}. Expected one of ${FEEDBACK_GRADES.join(', ')}`);
      }
      processed[key] = grade;
    }
    return processed;
  }

  _computeAggregates(ratings) {
    const scores = Object.values(ratings).map(g => GRADE_SCORES[g]);
    const overallScore = scores.reduce((a, b) => a + b, 0) / scores.length;
    const overallRating = parseFloat((overallScore / 2).toFixed(2));
    return {
      overallScore: parseFloat(overallScore.toFixed(2)),
      overallRating,
      overallGrade: _numericToGrade(overallScore),
      isNegative: overallRating <= 2,
    };
  }

  async createFeedback(userData, body) {
    const { stationId, pnr, passengerName, passengerPhone, journeyDate, ratings, comments } = body;
    if (!stationId) throw new ValidationError('stationId is required');
    if (!pnr || !String(pnr).trim()) throw new ValidationError('PNR number is required');

    const stationDoc = await db.collection('stations').doc(stationId).get();
    if (!stationDoc.exists) throw new NotFoundError('Station not found');

    const processed = this._processRatings(ratings);
    if (Object.keys(processed).length < 3) throw new ValidationError('At least 3 category ratings are required');

    const aggregates = this._computeAggregates(processed);

    const ref = db.collection('passenger_feedback').doc();
    const now = new Date().toISOString();
    const data = {
      uid: ref.id,
      stationId,
      stationName: stationDoc.data().stationName || '',
      pnr: String(pnr).trim().toUpperCase(),
      passengerName: passengerName || '',
      passengerPhone: passengerPhone || '',
      journeyDate: journeyDate || '',
      ratings: processed,
      ...aggregates,
      comments: comments || '',
      takenBy: { uid: userData.uid, name: userData.fullName || userData.name || '', role: userData.role || '' },
      status: 'SUBMITTED',
      date: _getISTDate(new Date()),
      createdAt: now,
      updatedAt: now,
    };
    await ref.set(data);
    await auditService.logAudit('PASSENGER_FEEDBACK_SUBMITTED', userData.uid, data.takenBy.name, ref.id, 'passenger_feedback', `Passenger feedback recorded for PNR ${data.pnr}. Rating: ${data.overallRating}, Grade: ${data.overallGrade}`);
    return { message: 'Passenger feedback recorded', uid: ref.id, feedback: data };
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
    const allowed = ['pnr', 'passengerName', 'passengerPhone', 'journeyDate', 'ratings', 'comments'];
    const updates = {};
    for (const key of allowed) {
      if (body[key] !== undefined) updates[key] = body[key];
    }
    if (updates.pnr !== undefined) updates.pnr = String(updates.pnr).trim().toUpperCase();
    if (updates.ratings !== undefined) {
      const processed = this._processRatings(updates.ratings);
      const current = doc.data().ratings || {};
      const merged = { ...current, ...processed };
      if (Object.keys(merged).length < 3) throw new ValidationError('At least 3 category ratings are required');
      updates.ratings = merged;
      Object.assign(updates, this._computeAggregates(merged));
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
      for (const [cat, grade] of Object.entries(fb.ratings || {})) {
        const score = GRADE_SCORES[grade] ?? 0;
        if (!catBreakdown[cat]) catBreakdown[cat] = { count: 0, totalRating: 0 };
        catBreakdown[cat].count++;
        catBreakdown[cat].totalRating += score;
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
      uniquePnrCount: new Set(filtered.map(f => f.pnr)).size,
      categoryBreakdown: catBreakdown,
    };
  }
}

export const passengerFeedbackService = new PassengerFeedbackService();