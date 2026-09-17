import jwt from 'jsonwebtoken';
import { db } from '../database/index.js';
import { NotFoundError, ValidationError } from '../errors/index.js';
import config from '../config/index.js';
import { paginate } from '../utils/paginate.js';

const FEEDBACK_CATEGORIES = ['toilet_cleanliness', 'platform_cleanliness', 'waiting_room_cleanliness', 'garbage_dustbin', 'smell_odour', 'water_booth_cleanliness', 'staff_behaviour', 'other'];
const MODERATION_STATUSES = ['pending', 'approved', 'rejected'];

class StationFeedbackService {
  async sendOtp(body) {
    const { phone, stationId } = body;
    if (!phone) throw new ValidationError('Phone number is required');
    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    const phoneKey = `fb_otp_${phone}`;

    await db.collection('feedback_otps').doc(phoneKey).set({
      phone, otp, stationId: stationId || '', attempts: 0,
      expiresAt: new Date(Date.now() + 300000).toISOString(),
      createdAt: new Date().toISOString()
    });

    const TWO_FACTOR_API_KEY = config.sms.twoFactorApiKey;
    if (!TWO_FACTOR_API_KEY) throw new Error('2Factor API key not configured');
    const url = `https://2factor.in/API/V1/${TWO_FACTOR_API_KEY}/VOICE/${phone}/${otp}`;
    const axios = (await import('axios')).default;
    const response = await axios.get(url);
    if (response.data.Status === "Success") return { success: true, message: "OTP sent" };
    throw new ValidationError(response.data.Details || "Failed to send voice OTP via 2Factor");
  }

  async verifyOtp(body) {
    const { phone, otp } = body;
    if (!phone || !otp) throw new ValidationError("Phone and OTP are required.");
    const phoneKey = `fb_otp_${phone}`;
    const doc = await db.collection('feedback_otps').doc(phoneKey).get();
    if (!doc.exists) throw new ValidationError("OTP expired or not requested.");
    const data = doc.data();
    if (new Date(data.expiresAt) < new Date()) throw new ValidationError("OTP expired.");
    if (data.attempts >= 5) throw new ValidationError("Too many attempts.");
    if (data.otp !== otp) {
      await doc.ref.update({ attempts: data.attempts + 1 });
      throw new ValidationError("Invalid OTP.");
    }
    await doc.ref.delete();
    const token = jwt.sign({ phone, purpose: 'station_feedback' }, config.jwtSecret, { expiresIn: '1h' });
    return { success: true, message: "Verified.", token };
  }

  async submitFeedback(body) {
    const { stationId, areaId, category, rating, comments, phone, imageUrl } = body;
    if (!stationId || !category || rating === undefined) throw new ValidationError('stationId, category, and rating are required');
    if (!FEEDBACK_CATEGORIES.includes(category)) throw new ValidationError(`Invalid category. Must be one of: ${FEEDBACK_CATEGORIES.join(', ')}`);
    const ratingNum = Number(rating);
    if (isNaN(ratingNum) || ratingNum < 1 || ratingNum > 5) throw new ValidationError('Rating must be between 1 and 5');
    const stationDoc = await db.collection('stations').doc(stationId).get();
    if (!stationDoc.exists) throw new NotFoundError('Station not found');
    const ref = db.collection('station_feedback').doc();
    const data = { uid: ref.id, stationId, stationName: stationDoc.data().stationName || '', areaId: areaId || null, areaName: '', category, rating: ratingNum, comments: comments || '', phone: phone || '', imageUrl: imageUrl || '', isNegative: ratingNum <= 2, moderationStatus: 'pending', moderationAt: null, moderatedBy: null, createdAt: new Date().toISOString() };
    await ref.set(data);
    return { message: 'Feedback submitted', uid: ref.id, feedback: data };
  }

  async moderateFeedback(uid, userData, body) {
    const ref = db.collection('station_feedback').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Feedback not found');
    if (!MODERATION_STATUSES.includes(body.status)) throw new ValidationError('Status must be approved or rejected');
    await ref.update({ moderationStatus: body.status, moderationAt: new Date().toISOString(), moderatedBy: userData.uid, rejectionReason: body.reason || null });
    return { message: `Feedback ${body.status}` };
  }

  async listFeedback(query = {}) {
    const { stationId, category, isNegative, rating, moderationStatus, startDate, endDate, limit = 50, cursor } = query;
    let q = db.collection('station_feedback');
    if (stationId) q = q.where('stationId', '==', stationId);
    if (category) q = q.where('category', '==', category);
    if (isNegative !== undefined) q = q.where('isNegative', '==', isNegative === 'true');
    if (rating) q = q.where('rating', '==', Number(rating));
    if (moderationStatus) q = q.where('moderationStatus', '==', moderationStatus);
    if (startDate) q = q.where('createdAt', '>=', startDate);
    if (endDate) q = q.where('createdAt', '<=', endDate + 'T23:59:59');
    const result = await paginate(q, { limit, cursor, orderBy: 'createdAt', orderDir: 'desc' });
    return { count: result.items.length, feedbacks: result.items, pagination: result.pagination };
  }

  async getFeedbackSummary(stationId, query = {}) {
    if (!stationId) throw new ValidationError('stationId is required');
    const { startDate, endDate } = query;
    let q = db.collection('station_feedback').where('stationId', '==', stationId);
    if (startDate) q = q.where('createdAt', '>=', startDate);
    if (endDate) q = q.where('createdAt', '<=', endDate + 'T23:59:59');
    const snapshot = await q.get();
    const feedbacks = []; snapshot.forEach(doc => feedbacks.push(doc.data()));
    const catBreakdown = {}; let totalRating = 0, negativeCount = 0;
    for (const fb of feedbacks) { totalRating += fb.rating || 0; if (fb.isNegative) negativeCount++; const cat = fb.category || 'other'; if (!catBreakdown[cat]) catBreakdown[cat] = { count: 0, totalRating: 0 }; catBreakdown[cat].count++; catBreakdown[cat].totalRating += fb.rating || 0; }
    for (const cat of Object.keys(catBreakdown)) { catBreakdown[cat].averageRating = catBreakdown[cat].count > 0 ? Math.round(catBreakdown[cat].totalRating / catBreakdown[cat].count * 10) / 10 : 0; }
    return { stationId, totalFeedback: feedbacks.length, averageRating: feedbacks.length > 0 ? Math.round(totalRating / feedbacks.length * 10) / 10 : 0, negativeCount, positiveCount: feedbacks.length - negativeCount, categoryBreakdown: catBreakdown };
  }

  async getStationQr(stationId, req) {
    if (!stationId) throw new ValidationError('stationId is required');
    const stationDoc = await db.collection('stations').doc(stationId).get();
    if (!stationDoc.exists) throw new NotFoundError('Station not found');
    const forwardedProto = req?.headers?.['x-forwarded-proto']?.split(',')[0]?.trim();
    const forwardedHost = req?.headers?.['x-forwarded-host']?.split(',')[0]?.trim();
    const host = forwardedHost || (req?.headers?.host) || process.env.APP_BASE_URL || 'https://swachhrailways.com';
    const protocol = forwardedProto || (req?.secure ? 'https' : 'http') || (host.startsWith('https') ? 'https' : 'http');
    const feedbackUrl = `${protocol}://${host.replace(/\/+$/, '')}/station-feedback?stationId=${encodeURIComponent(stationId)}&name=${encodeURIComponent(stationDoc.data().stationName || '')}&code=${encodeURIComponent(stationDoc.data().stationCode || '')}`;
    return { stationId, stationName: stationDoc.data().stationName, stationCode: stationDoc.data().stationCode, feedbackUrl };
  }

  async getStationBrief(stationId) {
    if (!stationId) throw new ValidationError('stationId is required');
    const stationDoc = await db.collection('stations').doc(stationId).get();
    if (!stationDoc.exists) throw new NotFoundError('Station not found');
    const data = stationDoc.data();
    return { stationId, stationName: data.stationName || '', stationCode: data.stationCode || '' };
  }
}

export const stationFeedbackService = new StationFeedbackService();
