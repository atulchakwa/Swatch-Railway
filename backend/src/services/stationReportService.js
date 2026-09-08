/*
 * Report generation uses stationId-only Firestore queries + in-memory date filtering
 * to avoid requiring composite indexes.
 */

import { db, admin } from '../database/index.js';
import { NotFoundError, ValidationError } from '../errors/index.js';
import { notificationService } from './notificationService.js';
import { autoEmailService } from './autoEmailService.js';
import logger from '../logger/index.js';

const DAILY_REPORT_TYPES = [
  'daily_attendance', 'daily_activity', 'daily_scorecard',
  'daily_complaint', 'daily_feedback', 'daily_supervisor_log',
  'daily_inspection', 'daily_petty_issue', 'missed_activity', 'archive_retrieval'
];
const MONTHLY_REPORT_TYPES = [
  'monthly_attendance', 'monthly_cleaning', 'monthly_scorecard',
  'monthly_complaint', 'monthly_feedback', 'monthly_billing', 'monthly_penalty',
  'monthly_performance', 'monthly_petty_issue'
];
const AUDIT_REPORT_TYPES = [
  'audit_user_activity', 'audit_image_archive', 'audit_rejected_forms',
  'audit_inspection_history', 'audit_data_modification'
];

class StationReportService {
  /* ==================================================================
     1. HELPERS
     ================================================================== */

  _getMonthEnd(year, month) {
    return String(new Date(parseInt(year), parseInt(month), 0).getDate()).padStart(2, '0');
  }

  async _getStationName(stationId) {
    const doc = await db.collection('stations').doc(stationId).get();
    if (!doc.exists) throw new NotFoundError('Station not found');
    return doc.data().stationName || '';
  }

  async _getFeedbackRecords(stationId) {
    const [sfSnap, pfSnap] = await Promise.all([
      db.collection('station_feedback').where('stationId', '==', stationId).get(),
      db.collection('passenger_feedback').where('stationId', '==', stationId).get(),
    ]);
    const gradeScores = { excellent: 10, very_good: 8, good: 6, average: 5, poor: 3 };
    // Normalize a stored rating onto the shared 1-5 report scale. Values above 5
    // are treated as 0-10 scores (e.g. passenger scores) and rescaled so the
    // reports can mix both sources consistently.
    const toReportScale = (v) => {
      const n = Number(v);
      if (Number.isNaN(n)) return 0;
      return n > 5 ? Math.round(n / 2) : n;
    };
    const records = [];
    sfSnap.forEach(d => {
      const r = d.data();
      const status = (r.moderationStatus || 'approved').toLowerCase();
      // Station feedback carries a native 1-5 rating; expose the fields the
      // report summaries rely on so they are counted correctly.
      records.push({
        ...r,
        rating: toReportScale(r.rating != null ? r.rating : r.overallRating),
        status: status === 'rejected' ? 'rejected' : (status === 'pending' || status === 'under_review' ? 'pending' : 'approved'),
        comment: r.comments || r.remark || '',
        remarks: r.comments || r.remark || '',
      });
    });
    pfSnap.forEach(d => {
      const r = d.data();
      const sections = r.sections || {};
      let expanded = false;
      for (const sec of Object.values(sections)) {
        const params = (sec && sec.parameters) || {};
        for (const [pk, pval] of Object.entries(params)) {
          const score = gradeScores[pval.grade];
          records.push({
            ...r,
            rating: score != null ? score / 2 : toReportScale(r.overallRating),
            category: pk,
            grade: pval.grade,
            status: 'approved',
            comment: pval.remark || r.comments || '',
            remarks: pval.remark || r.comments || '',
          });
          expanded = true;
        }
      }
      if (!expanded) {
        records.push({ ...r, rating: toReportScale(r.overallRating), category: 'overall', status: 'approved', comment: r.comments || '', remarks: r.comments || '' });
      }
    });
    return records;
  }

  async _storeReport(data) {
    const ref = db.collection('station_reports').doc();
    const now = new Date().toISOString();
    const report = { uid: ref.id, ...data, createdAt: now, updatedAt: now };
    await ref.set(report);
    return report;
  }

  async _notifyRecipients(reportType, stationId, recipients) {
    for (const userId of recipients) {
      await notificationService.createNotification(
        userId, `Report: ${reportType}`,
        `New ${reportType} report generated for station ${stationId}`,
        'report', null
      );
    }
  }

  /* ==================================================================
     2. EXISTING METHODS (unchanged)
     ================================================================== */

  async generateStationCleaningReport(stationId, month, year, user) {
    if (!stationId || !month || !year) throw new ValidationError('stationId, month, and year are required');
    const stationName = await this._getStationName(stationId);
    const monthPad = String(month).padStart(2, '0');
    const startDate = `${year}-${monthPad}-01`;
    const endDate = `${year}-${monthPad}-${this._getMonthEnd(year, month)}`;

    const [scorecardSnap, attendanceSnap, activitySnap, complaintSnap, inspectionSnap, formSnap] = await Promise.all([
      db.collection('daily_scorecards').where('stationId', '==', stationId).get(),
      db.collection('station_attendance').where('stationId', '==', stationId).get(),
      db.collection('station_daily_activities').where('stationId', '==', stationId).get(),
      db.collection('complaints').where('stationId', '==', stationId).get(),
      db.collection('inspections').where('stationId', '==', stationId).get(),
      db.collection('stationCleaningForms').where('stationId', '==', stationId).get(),
    ]);

    const scorecards = []; scorecardSnap.forEach(d => { const r = d.data(); if (r.date >= startDate && r.date <= endDate) scorecards.push(r); });
    const avgScore = scorecards.length > 0 ? Math.round(scorecards.reduce((s, c) => s + (c.overallStationScore || 0), 0) / scorecards.length) : 0;
    const attendance = []; attendanceSnap.forEach(d => { const r = d.data(); if (r.date >= startDate && r.date <= endDate) attendance.push(r); });
    const daysTracked = [...new Set(attendance.map(a => a.date))].length;
    const presentCount = attendance.filter(a => a.status === 'present' || a.status === 'late').length;
    const attendancePct = attendance.length > 0 ? Math.round((presentCount / attendance.length) * 100) : 0;
    const activities = []; activitySnap.forEach(d => { const r = d.data(); if (r.date >= startDate && r.date <= endDate) activities.push(r); });
    const completedActs = activities.filter(a => a.status === 'COMPLETED' || a.status === 'APPROVED').length;
    const completionRate = activities.length > 0 ? Math.round((completedActs / activities.length) * 100) : 0;
    const complaints = []; complaintSnap.forEach(d => complaints.push(d.data()));
    const complaintsInMonth = complaints.filter(c => { const d = c.createdAt || ''; return d >= startDate && d <= endDate + 'T23:59:59'; });
    const resolvedComplaints = complaintsInMonth.filter(c => c.status === 'CLOSED' || c.status === 'RAILWAY_VERIFIED').length;
    const inspections = []; inspectionSnap.forEach(d => inspections.push(d.data()));
    const forms = []; formSnap.forEach(d => { const r = d.data(); const ts = r.createdAt || ''; if (ts >= startDate && ts <= endDate + 'T23:59:59') forms.push(r); });
    const submittedForms = forms.filter(f => ['SUBMITTED', 'APPROVED', 'SCORED', 'LOCKED'].includes(f.status)).length;

    const report = await this._storeReport({
      stationId, stationName, reportType: 'monthly', month: parseInt(month), year: parseInt(year),
      summary: { averageCleanlinessScore: avgScore, scorecardDays: scorecards.length, attendanceDays: daysTracked, averageAttendance: attendancePct, totalManpowerEntries: attendance.length, totalActivities: activities.length, activityCompletionRate: completionRate, totalComplaints: complaintsInMonth.length, resolvedComplaints, complaintResolutionRate: complaintsInMonth.length > 0 ? Math.round((resolvedComplaints / complaintsInMonth.length) * 100) : 0, totalInspections: inspections.length, totalCleaningFormsSubmitted: submittedForms },
      generatedBy: user.uid, generatedByName: user.fullName || '', generatedAt: new Date().toISOString(),
    });
    return { message: 'Station cleaning report generated', uid: report.uid, report };
  }

  async getReportById(uid) {
    const doc = await db.collection('station_reports').doc(uid).get();
    if (!doc.exists) throw new NotFoundError('Report not found');
    return { id: doc.id, ...doc.data() };
  }

  async listReports(query = {}) {
    const { stationId, reportType, month, year, limit = 50 } = query;
    let q = db.collection('station_reports');
    if (stationId) q = q.where('stationId', '==', stationId);
    if (reportType) q = q.where('reportType', '==', reportType);
    if (month) q = q.where('month', '==', parseInt(month));
    if (year) q = q.where('year', '==', parseInt(year));
    const snapshot = await q.get();
    const reports = []; snapshot.forEach(doc => reports.push(doc.data()));
    reports.sort((a, b) => ((b.createdAt || '') > (a.createdAt || '') ? 1 : -1));
    const sliced = reports.slice(0, parseInt(limit));
    return { count: sliced.length, reports: sliced };
  }

  async getStationScoreTrend(stationId, months = 6) {
    if (!stationId) throw new ValidationError('stationId is required');
    const endDate = new Date(); const startDate = new Date();
    startDate.setMonth(startDate.getMonth() - months);
    const startStr = startDate.toISOString().split('T')[0];
    const snapshot = await db.collection('daily_scorecards').where('stationId', '==', stationId).get();
    const monthlyScores = {};
    snapshot.forEach(doc => {
      const d = doc.data();
      if (d.date < startStr) return;
      const monthKey = (d.date || '').substring(0, 7);
      if (!monthKey) return;
      if (!monthlyScores[monthKey]) monthlyScores[monthKey] = { total: 0, count: 0, grades: {} };
      monthlyScores[monthKey].total += d.overallStationScore || 0; monthlyScores[monthKey].count++;
      const g = d.grade || 'N/A'; monthlyScores[monthKey].grades[g] = (monthlyScores[monthKey].grades[g] || 0) + 1;
    });
    const trend = Object.entries(monthlyScores).map(([month, data]) => ({ month, averageScore: data.count > 0 ? Math.round(data.total / data.count) : 0, daysScored: data.count, gradeDistribution: data.grades })).sort((a, b) => a.month.localeCompare(b.month));
    return { stationId, months, trend };
  }

  async getStationComparison(division, month, year) {
    if (!division || !month || !year) throw new ValidationError('division, month, and year are required');
    const stationsSnap = await db.collection('stations').where('division', '==', division).where('active', '==', true).limit(200).get();
    const stationIds = []; stationsSnap.forEach(doc => stationIds.push({ id: doc.id, name: doc.data().stationName || '' }));
    const monthPad = String(month).padStart(2, '0');
    const startDate = `${year}-${monthPad}-01`; const endDate = `${year}-${monthPad}-${this._getMonthEnd(year, month)}`;
    const comparisons = [];
    for (const station of stationIds) {
      const scoreSnap = await db.collection('daily_scorecards').where('stationId', '==', station.id).get();
      if (!scoreSnap.empty) {
        let total = 0, count = 0;
        scoreSnap.forEach(d => {
          const r = d.data();
          if (r.date >= startDate && r.date <= endDate) { total += r.overallStationScore || 0; count++; }
        });
        if (count > 0) comparisons.push({ stationId: station.id, stationName: station.name, averageScore: Math.round(total / count), daysScored: count });
      }
    }
    comparisons.sort((a, b) => b.averageScore - a.averageScore);
    return { division, month, year, stationCount: comparisons.length, comparisons };
  }

  /* ==================================================================
     3. DAILY REPORTS (Section 10.1)
     ================================================================== */

  async generateDailyAttendanceReport(stationId, date, user) {
    const stationName = await this._getStationName(stationId);
    // Station-cleaning contracts write worker attendance (start/mid/end + face
    // verification) into station_cleaning_attendance. The generic attendance
    // service writes to station_attendance. Read both so the report is never empty.
    const [attSnap, scAttSnap] = await Promise.all([
      db.collection('station_attendance').where('stationId', '==', stationId).get(),
      db.collection('station_cleaning_attendance').where('stationId', '==', stationId).get(),
    ]);
    const records = []; attSnap.forEach(d => { const r = d.data(); if (r.date === date) records.push(r); });
    scAttSnap.forEach(d => { const r = d.data(); if (r.date === date) records.push(r); });

    // In station-cleaning contracts work is performed by contract supervisors,
    // so we enrich each supervisor's attendance with the activities they did.
    const tasksBySupervisor = {};
    try {
      const taskSnap = await db.collection('cleaningTasks')
        .where('stationId', '==', stationId)
        .where('scheduledDate', '==', date)
        .get();
      taskSnap.forEach(d => {
        const t = d.data();
        const supId = t.supervisorId || '';
        if (!supId) return;
        if (!tasksBySupervisor[supId]) tasksBySupervisor[supId] = [];
        tasksBySupervisor[supId].push({
          area: t.areaName || t.areaId || '',
          activity: t.taskTypeName || t.activityType || 'Cleaning',
          time: t.scheduledTime || '',
          status: t.status || '',
        });
      });
    } catch (_) { /* task enrichment is optional */ }

    const present = records.filter(r => ['present', 'PRESENT', 'half_day'].includes(r.status) || r.attendanceStatus === 'PRESENT').length;
    const late = records.filter(r => ['late', 'LATE'].includes(r.status) || r.attendanceStatus === 'LATE').length;
    const onLeave = records.filter(r => ['on_leave', 'ON_LEAVE'].includes(r.status) || r.attendanceStatus === 'ON_LEAVE').length;
    const absent = Math.max(0, records.length - present - late - onLeave);
    const reportRecords = records.map(r => {
      const start = r.startAttendance || {};
      const mid = r.midAttendance || {};
      const end = r.endAttendance || {};
      const st = r.status || r.attendanceStatus || '';
      return {
        supervisor: r.workerName || r.workerId || '',
        status: st,
        startMarked: r.isStartMarked ? 'Yes' : 'No',
        midMarked: r.isMidMarked ? 'Yes' : 'No',
        endMarked: r.isEndMarked ? 'Yes' : 'No',
        lateByMinutes: r.lateByMinutes || r.timingSnapshot?.lateByMinutes || 0,
        photo: start.photoUrl || mid.photoUrl || end.photoUrl || r.photoUrl || '',
        startPhoto: start.photoUrl || '',
        midPhoto: mid.photoUrl || '',
        endPhoto: end.photoUrl || '',
        activities: tasksBySupervisor[r.workerId] || [],
      };
    });
    const report = await this._storeReport({
      stationId, stationName, reportType: 'daily_attendance', date, month: parseInt(date.substring(5, 7)), year: parseInt(date.substring(0, 4)),
      summary: { totalExpected: records.length, present, late, absent, onLeave, attendancePct: records.length > 0 ? Math.round(present / records.length * 100) : 0, records: reportRecords },
      generatedBy: user.uid, generatedByName: user.fullName || '', generatedAt: new Date().toISOString(),
    });
    return report;
  }

  async generateDailyActivityReport(stationId, date, user) {
    const stationName = await this._getStationName(stationId);
    const snap = await db.collection('cleaningTasks').where('stationId', '==', stationId).where('scheduledDate', '==', date).get();
    const records = snap.docs.map(d => d.data());
    const nowTime = new Date().toLocaleTimeString('en-GB', { timeZone: 'Asia/Kolkata', hour: '2-digit', minute: '2-digit', hour12: false });
    const completed = records.filter(r => r.status === 'completed' || r.status === 'approved').length;
    const pending = records.filter(r => r.status === 'pending' || r.status === 'assigned').length;
    const inProgress = records.filter(r => r.status === 'in_progress').length;
    const rejected = records.filter(r => r.status === 'rejected').length;
    const resubmitted = records.filter(r => r.status === 'resubmitted').length;
    const cancelled = records.filter(r => r.status === 'cancelled').length;
    const overdue = records.filter(r => (r.status === 'pending' || r.status === 'assigned') && r.scheduledTime && r.scheduledTime < nowTime).length;
    const reportRecords = records.map(r => ({
      area: r.areaName || r.areaId || '',
      activity: r.taskTypeName || r.activityType || 'Cleaning',
      shift: r.shift || '', time: r.scheduledTime || '',
      status: r.status || '', supervisor: r.supervisorName || r.workerName || 'Supervisor', score: r.score != null ? r.score : '',
    }));
    const report = await this._storeReport({
      stationId, stationName, reportType: 'daily_activity', date, month: parseInt(date.substring(5, 7)), year: parseInt(date.substring(0, 4)),
      summary: { total: records.length, completed, pending, inProgress, overdue, rejected, resubmitted, cancelled, completionRate: records.length > 0 ? Math.round(completed / records.length * 100) : 0, records: reportRecords },
      generatedBy: user.uid, generatedByName: user.fullName || '', generatedAt: new Date().toISOString(),
    });
    return report;
  }

  async generateDailyScorecardReport(stationId, date, user) {
    const stationName = await this._getStationName(stationId);
    const snap = await db.collection('daily_scorecards').where('stationId', '==', stationId).get();
    const records = []; snap.forEach(d => { const r = d.data(); if (r.date === date) records.push(r); });
    const avg = records.length > 0 ? Math.round(records.reduce((s, r) => s + (r.overallStationScore || 0), 0) / records.length) : 0;
    const grades = records.reduce((acc, r) => { const g = r.grade || 'N/A'; acc[g] = (acc[g] || 0) + 1; return acc; }, {});
    const report = await this._storeReport({
      stationId, stationName, reportType: 'daily_scorecard', date, month: parseInt(date.substring(5, 7)), year: parseInt(date.substring(0, 4)),
      summary: { totalScorecards: records.length, averageScore: avg, gradeDistribution: grades },
      generatedBy: user.uid, generatedByName: user.fullName || '', generatedAt: new Date().toISOString(),
    });
    return report;
  }

  async generateDailyComplaintReport(stationId, date, user) {
    const stationName = await this._getStationName(stationId);
    const start = `${date}T00:00:00`; const end = `${date}T23:59:59`;
    const snap = await db.collection('complaints').where('stationId', '==', stationId).get();
    const records = []; snap.forEach(d => records.push(d.data()));
    const dayRecords = records.filter(r => { const c = r.createdAt || ''; return c >= start && c <= end; });
    const open = dayRecords.filter(r => ['OPEN', 'ASSIGNED', 'IN_PROGRESS'].includes(r.status)).length;
    const resolved = dayRecords.filter(r => ['CLOSED', 'RAILWAY_VERIFIED', 'RESOLVED'].includes(r.status)).length;
    const escalated = dayRecords.filter(r => r.status === 'ESCALATED').length;
    const categories = dayRecords.reduce((acc, r) => { const c = r.category || 'other'; acc[c] = (acc[c] || 0) + 1; return acc; }, {});
    const report = await this._storeReport({
      stationId, stationName, reportType: 'daily_complaint', date, month: parseInt(date.substring(5, 7)), year: parseInt(date.substring(0, 4)),
      summary: { total: dayRecords.length, open, resolved, escalated, categories },
      generatedBy: user.uid, generatedByName: user.fullName || '', generatedAt: new Date().toISOString(),
    });
    return report;
  }

  async generateDailyFeedbackReport(stationId, date, user) {
    const stationName = await this._getStationName(stationId);
    const records = await this._getFeedbackRecords(stationId);
    const dayRecords = records.filter(r => { const c = r.createdAt || ''; return c.startsWith(date); });
    const approved = dayRecords.filter(r => r.status === 'approved').length;
    const pendingMod = dayRecords.filter(r => r.status === 'pending').length;
    const ratings = dayRecords.filter(r => r.rating).map(r => r.rating);
    const avgRating = ratings.length > 0 ? (ratings.reduce((s, v) => s + v, 0) / ratings.length).toFixed(1) : 'N/A';
    const negativeFeedback = dayRecords.filter(r => (r.rating || 0) <= 2);
    const negativeTrends = negativeFeedback.reduce((acc, r) => {
      const cat = r.category || r.feedbackCategory || 'General';
      if (!acc[cat]) acc[cat] = { count: 0, comments: [] };
      acc[cat].count++;
      if (r.comment || r.remarks) acc[cat].comments.push(r.comment || r.remarks);
      return acc;
    }, {});
    const report = await this._storeReport({
      stationId, stationName, reportType: 'daily_feedback', date, month: parseInt(date.substring(5, 7)), year: parseInt(date.substring(0, 4)),
      summary: {
        total: dayRecords.length, approved, pendingModeration: pendingMod,
        averageRating: avgRating,
        ratingDistribution: dayRecords.reduce((acc, r) => { const v = r.rating || 0; acc[v] = (acc[v] || 0) + 1; return acc; }, {}),
        negativeCount: negativeFeedback.length, negativeRate: dayRecords.length > 0 ? Math.round(negativeFeedback.length / dayRecords.length * 100) : 0,
        negativeTrends: Object.entries(negativeTrends).map(([cat, data]) => ({ category: cat, count: data.count, sampleComments: data.comments.slice(0, 5) })),
      },
      generatedBy: user.uid, generatedByName: user.fullName || '', generatedAt: new Date().toISOString(),
    });
    return report;
  }

  async generateDailyInspectionReport(stationId, date, user) {
    const stationName = await this._getStationName(stationId);
    const start = `${date}T00:00:00`;
    const end = `${date}T23:59:59`;
    const snap = await db.collection('inspections').where('stationId', '==', stationId).get();
    const records = []; snap.forEach(d => records.push({ id: d.id, ...d.data() }));
    const dayRecords = records.filter(r => {
      const d = r.inspectionDate || r.scheduledDate || r.createdAt || '';
      return d >= start && d <= end;
    });
    const byType = dayRecords.reduce((acc, r) => {
      const t = r.inspectionType || 'unknown';
      if (!acc[t]) acc[t] = 0;
      acc[t]++;
      return acc;
    }, {});
    const byStatus = dayRecords.reduce((acc, r) => {
      const s = r.status || 'unknown';
      acc[s] = (acc[s] || 0) + 1;
      return acc;
    }, {});
    const totalDeficiencies = dayRecords.reduce((s, r) => s + (r.deficiencies?.length || 0), 0);
    const closedDeficiencies = dayRecords.reduce((s, r) => s + ((r.deficiencies || []).filter(d => d.status === 'CLOSED' || d.status === 'VERIFIED').length), 0);
    const inspectionDetails = dayRecords.map(r => ({
      id: r.id, inspectionType: r.inspectionType, status: r.status,
      inspectorName: r.inspectorName || r.inspectorId || '',
      overallScore: r.overallScore,
      remarks: r.remarks || r.remark || '',
      photos: r.photos || r.photoEvidence || [],
      deficiencies: (r.deficiencies || []).map(d => ({ area: d.area, status: d.status, remark: d.remark })),
    }));
    const report = await this._storeReport({
      stationId, stationName, reportType: 'daily_inspection', date, month: parseInt(date.substring(5, 7)), year: parseInt(date.substring(0, 4)),
      summary: {
        totalInspections: dayRecords.length, typeBreakdown: byType, statusBreakdown: byStatus,
        totalDeficiencies, closedDeficiencies, openDeficiencies: totalDeficiencies - closedDeficiencies,
        inspections: inspectionDetails,
      },
      generatedBy: user.uid, generatedByName: user.fullName || '', generatedAt: new Date().toISOString(),
    });
    return report;
  }

  async generateDailySupervisorLog(stationId, date, user) {
    const stationName = await this._getStationName(stationId);
    const snap = await db.collection('supervisor_daily_logs').where('stationId', '==', stationId).get();
    const logs = []; snap.forEach(d => { const r = d.data(); if (r.date === date) logs.push(r); });
    const submitted = logs.filter(l => l.status === 'SUBMITTED' || l.status === 'ACCEPTED').length;
    const draft = logs.filter(l => l.status === 'DRAFT').length;
    const report = await this._storeReport({
      stationId, stationName, reportType: 'daily_supervisor_log', date, month: parseInt(date.substring(5, 7)), year: parseInt(date.substring(0, 4)),
      summary: { totalLogs: logs.length, submitted, draft, issuesReported: logs.reduce((s, l) => s + ((l.issues || []).length), 0), materialUsed: logs.reduce((s, l) => s + (l.materialUsed || []).length, 0) },
      generatedBy: user.uid, generatedByName: user.fullName || '', generatedAt: new Date().toISOString(),
    });
    return report;
  }

  async generateMissedActivityReport(stationId, date, user) {
    const stationName = await this._getStationName(stationId);
    const snap = await db.collection('station_daily_activities').where('stationId', '==', stationId).get();
    const records = []; snap.forEach(d => { const r = d.data(); if (r.date === date) records.push(r); });
    const now = new Date().toISOString();
    const overdue = records.filter(r => r.status === 'PENDING' && r.scheduledEnd && r.scheduledEnd < now);
    const delayed = records.filter(r => r.status === 'IN_PROGRESS' && r.scheduledEnd && r.scheduledEnd < now);
    const missed = records.filter(r => r.status === 'MISSED');
    // Overdue cleaning tasks: pending/assigned tasks whose scheduled time has passed.
    let overdueTasks = [];
    try {
      const taskSnap = await db.collection('cleaningTasks').where('stationId', '==', stationId).where('scheduledDate', '==', date).get();
      const nowHm = new Date().toLocaleTimeString('en-GB', { timeZone: 'Asia/Kolkata', hour: '2-digit', minute: '2-digit', hour12: false });
      taskSnap.forEach(d => {
        const t = d.data();
        if ((t.status === 'pending' || t.status === 'assigned') && t.scheduledTime && t.scheduledTime <= nowHm) {
          overdueTasks.push({
            taskId: t.uid, area: t.areaName || t.areaId || '',
            activity: t.taskTypeName || t.activityType || 'Cleaning',
            shift: t.shift || '', scheduledTime: t.scheduledTime,
            supervisor: t.supervisorName || t.workerName || '',
          });
        }
      });
    } catch (_) { /* optional */ }
    const totalIssues = overdue.length + delayed.length + missed.length + overdueTasks.length;
    const report = await this._storeReport({
      stationId, stationName, reportType: 'missed_activity', date, month: parseInt(date.substring(5, 7)), year: parseInt(date.substring(0, 4)),
      summary: {
        totalScheduled: records.length, totalIssues, missedCount: missed.length,
        overdueCount: overdue.length + overdueTasks.length, delayedCount: delayed.length,
        pendingTaskOverdueCount: overdueTasks.length,
        issueRate: (records.length + overdueTasks.length) > 0 ? Math.round(totalIssues / (records.length + overdueTasks.length) * 100) : 0,
        overdueActivities: overdue.map(m => ({ activityId: m.activityId, areaId: m.areaId, scheduledStart: m.scheduledStart, scheduledEnd: m.scheduledEnd, assignedWorkers: m.assignedWorkers })),
        delayedActivities: delayed.map(m => ({ activityId: m.activityId, areaId: m.areaId, scheduledStart: m.scheduledStart, scheduledEnd: m.scheduledEnd, assignedWorkers: m.assignedWorkers })),
        missedActivities: missed.map(m => ({ activityId: m.activityId, areaId: m.areaId, scheduledStart: m.scheduledStart, scheduledEnd: m.scheduledEnd, assignedWorkers: m.assignedWorkers })),
        overdueTasks,
      },
generatedBy: user.uid, generatedByName: user.fullName || '', generatedAt: new Date().toISOString(),
    });
    return report;
  }

  async generateDailyPettyIssueReport(stationId, date, user) {
    const stationName = await this._getStationName(stationId);
    const start = `${date}T00:00:00`; const end = `${date}T23:59:59`;
    const snap = await db.collection('petty_issues').where('stationId', '==', stationId).get();
    const dayRecords = []; snap.forEach(d => { const r = d.data(); const ts = r.reportedAt || r.createdAt || ''; if (ts >= start && ts <= end) dayRecords.push(r); });
    const open = dayRecords.filter(r => ['REPORTED', 'ASSIGNED', 'IN_PROGRESS'].includes(r.status));
    const resolved = dayRecords.filter(r => ['RESOLVED', 'CLOSED'].includes(r.status));
    const rejected = dayRecords.filter(r => r.status === 'REJECTED');
    const statusBreakdown = dayRecords.reduce((acc, r) => { acc[r.status || 'UNKNOWN'] = (acc[r.status || 'UNKNOWN'] || 0) + 1; return acc; }, {});
    const severityBreakdown = dayRecords.reduce((acc, r) => { acc[r.severity || 'medium'] = (acc[r.severity || 'medium'] || 0) + 1; return acc; }, {});
    const categoryBreakdown = dayRecords.reduce((acc, r) => { acc[r.category || 'other'] = (acc[r.category || 'other'] || 0) + 1; return acc; }, {});
    const report = await this._storeReport({
      stationId, stationName, reportType: 'daily_petty_issue', date, month: parseInt(date.substring(5, 7)), year: parseInt(date.substring(0, 4)),
      summary: {
        total: dayRecords.length, open: open.length, resolved: resolved.length, rejected: rejected.length,
        resolutionRate: dayRecords.length > 0 ? Math.round(resolved.length / dayRecords.length * 100) : 0,
        statusBreakdown, severityBreakdown, categoryBreakdown,
        issues: dayRecords.map(r => ({ uid: r.uid, category: r.category, description: r.description, areaId: r.areaId, platformId: r.platformId, severity: r.severity, status: r.status, reportedAt: r.reportedAt, reportedByName: r.reportedByName, resolvedAt: r.resolvedAt, photo: r.photo, gpsLatitude: r.gpsLatitude, gpsLongitude: r.gpsLongitude })),
      },
      generatedBy: user.uid, generatedByName: user.fullName || '', generatedAt: new Date().toISOString(),
    });
    return report;
  }

  /* ==================================================================
    4. MONTHLY REPORTS (Section 10.2)
     ================================================================== */

  async generateMonthlyAttendanceSummary(stationId, month, year, user) {
    const stationName = await this._getStationName(stationId);
    const monthPad = String(month).padStart(2, '0');
    const startDate = `${year}-${monthPad}-01`; const endDate = `${year}-${monthPad}-${this._getMonthEnd(year, month)}`;
    const [snap, scAttSnap, overtimeSnap] = await Promise.all([
      db.collection('station_attendance').where('stationId', '==', stationId).get(),
      db.collection('station_cleaning_attendance').where('stationId', '==', stationId).get(),
      db.collection('overtime_records').where('stationId', '==', stationId).get(),
    ]);
    const records = []; snap.forEach(d => { const r = d.data(); if (r.date >= startDate && r.date <= endDate) records.push(r); });
    scAttSnap.forEach(d => { const r = d.data(); if (r.date >= startDate && r.date <= endDate) records.push(r); });
    const overtime = []; overtimeSnap.forEach(d => { const r = d.data(); if (r.date >= startDate && r.date <= endDate) overtime.push(r); });
    const combinedRecords = records.map(r => ({ ...r, source: 'station_attendance' }));
    const isPresent = (r) => ['present', 'PRESENT', 'half_day'].includes(r.status) || r.attendanceStatus === 'PRESENT';
    const isLate = (r) => ['late', 'LATE'].includes(r.status) || r.attendanceStatus === 'LATE';
    const isLeave = (r) => ['on_leave', 'ON_LEAVE'].includes(r.status) || r.attendanceStatus === 'ON_LEAVE';
    const daysPresent = new Set(combinedRecords.filter(isPresent).map(r => r.date)).size;
    const totalDays = new Set(combinedRecords.map(r => r.date)).size;
    const workerMap = {}; combinedRecords.forEach(r => { const w = r.workerId; if (!w) return; if (!workerMap[w]) workerMap[w] = { supervisorName: r.workerName || '', present: 0, late: 0, leave: 0, total: 0 }; workerMap[w][isPresent(r) ? 'present' : isLate(r) ? 'late' : isLeave(r) ? 'leave' : 'total']++; workerMap[w].total++; });
    const totalOvertimeHours = overtime.reduce((s, o) => s + (o.hours || o.overtimeHours || 0), 0);
    const report = await this._storeReport({
      stationId, stationName, reportType: 'monthly_attendance', month, year, date: startDate,
      summary: { totalEntries: combinedRecords.length, totalSupervisors: Object.keys(workerMap).length, daysPresent, totalDays, attendancePct: totalDays > 0 ? Math.round(daysPresent / totalDays * 100) : 0, overtimeEntries: overtime.length, totalOvertimeHours, supervisorSummary: Object.entries(workerMap).map(([wid, stats]) => ({ supervisorId: wid, ...stats })) },
      generatedBy: user.uid, generatedByName: user.fullName || '', generatedAt: new Date().toISOString(),
    });
    return report;
  }

  async generateMonthlyCleaningSummary(stationId, month, year, user) {
    const stationName = await this._getStationName(stationId);
    const monthPad = String(month).padStart(2, '0');
    const startDate = `${year}-${monthPad}-01`; const endDate = `${year}-${monthPad}-${this._getMonthEnd(year, month)}`;
    const [taskSnap, garbageSnap, pestSnap] = await Promise.all([
      db.collection('cleaningTasks').where('stationId', '==', stationId).get(),
      db.collection('garbage_collections').where('stationId', '==', stationId).get(),
      db.collection('pest_treatment_plans').where('stationId', '==', stationId).get(),
    ]);
    const tasks = []; taskSnap.forEach(d => { const r = d.data(); const d2 = r.scheduledDate || r.date || ''; if (d2 >= startDate && d2 <= endDate) tasks.push(r); });
    const garbageRecords = []; garbageSnap.forEach(d => { const r = d.data(); const d2 = r.collectionDate || ''; if (d2 >= startDate && d2 <= endDate) garbageRecords.push(r); });
    const pestRecords = []; pestSnap.forEach(d => pestRecords.push(d.data()));
    const inMonthPest = pestRecords.filter(p => { const d = p.scheduledDate || ''; return d >= startDate && d <= endDate; });
    const totalWet = garbageRecords.reduce((s, g) => s + (g.wetKg || 0), 0);
    const totalDry = garbageRecords.reduce((s, g) => s + (g.dryKg || 0), 0);
    const totalHazardous = garbageRecords.reduce((s, g) => s + (g.hazardousKg || 0), 0);
    const completedTasks = tasks.filter(t => t.status === 'completed' || t.status === 'approved');
    const areaPct = {};
    completedTasks.forEach(t => { areaPct[t.areaName || t.areaId] = (areaPct[t.areaName || t.areaId] || 0) + 1; });
    const totalCompleted = completedTasks.length;
    const report = await this._storeReport({
      stationId, stationName, reportType: 'monthly_cleaning', month, year, date: startDate,
      summary: { totalActivities: tasks.length, completedActivities: totalCompleted, completionRate: tasks.length > 0 ? Math.round(totalCompleted / tasks.length * 100) : 0, pendingActivities: tasks.filter(t => t.status === 'pending' || t.status === 'assigned').length, inProgress: tasks.filter(t => t.status === 'in_progress').length, garbageCollected: garbageRecords.length, wetWasteKg: totalWet, dryWasteKg: totalDry, hazardousWasteKg: totalHazardous, totalWasteKg: totalWet + totalDry + totalHazardous, pestTreatments: inMonthPest.length, areaCompletion: Object.entries(areaPct).map(([areaId, count]) => ({ areaId, completedCount: count })) },
      generatedBy: user.uid, generatedByName: user.fullName || '', generatedAt: new Date().toISOString(),
    });
    return report;
  }

  async generateMonthlyScorecardReport(stationId, month, year, user) {
    const stationName = await this._getStationName(stationId);
    const monthPad = String(month).padStart(2, '0');
    const startDate = `${year}-${monthPad}-01`; const endDate = `${year}-${monthPad}-${this._getMonthEnd(year, month)}`;
    const snap = await db.collection('daily_scorecards').where('stationId', '==', stationId).get();
    const records = []; snap.forEach(d => { const r = d.data(); if (r.date >= startDate && r.date <= endDate) records.push(r); });
    const scores = records.map(r => r.overallStationScore || 0);
    const avg = scores.length > 0 ? Math.round(scores.reduce((s, v) => s + v, 0) / scores.length) : 0;
    const max = scores.length > 0 ? Math.max(...scores) : 0;
    const min = scores.length > 0 ? Math.min(...scores) : 0;
    const gradesDist = records.reduce((acc, r) => { const g = r.grade || 'N/A'; acc[g] = (acc[g] || 0) + 1; return acc; }, {});
    const scoreRanges = { above90: 0, range81to90: 0, range71to80: 0, below70: 0 };
    scores.forEach(s => { if (s > 90) scoreRanges.above90++; else if (s >= 81) scoreRanges.range81to90++; else if (s >= 71) scoreRanges.range71to80++; else scoreRanges.below70++; });
    const report = await this._storeReport({
      stationId, stationName, reportType: 'monthly_scorecard', month, year, date: startDate,
      summary: { totalDays: records.length, averageScore: avg, highestScore: max, lowestScore: min, gradeDistribution: gradesDist, scoreRanges, scores: records.map(r => ({ date: r.date, score: r.overallStationScore, grade: r.grade })) },
      generatedBy: user.uid, generatedByName: user.fullName || '', generatedAt: new Date().toISOString(),
    });
    return report;
  }

  async generateMonthlyComplaintSummary(stationId, month, year, user) {
    const stationName = await this._getStationName(stationId);
    const monthPad = String(month).padStart(2, '0');
    const startDate = `${year}-${monthPad}-01`; const endDate = `${year}-${monthPad}-${this._getMonthEnd(year, month)}`;
    const snap = await db.collection('complaints').where('stationId', '==', stationId).get();
    const records = []; snap.forEach(d => records.push(d.data()));
    const inMonth = records.filter(r => { const c = r.createdAt || ''; return c >= startDate && c <= endDate + 'T23:59:59'; });
    const statusDist = inMonth.reduce((acc, r) => { acc[r.status] = (acc[r.status] || 0) + 1; return acc; }, {});
    const catDist = inMonth.reduce((acc, r) => { const c = r.category || 'other'; acc[c] = (acc[c] || 0) + 1; return acc; }, {});
    const slaBreached = inMonth.filter(r => r.slaDeadline && r.slaDeadline < new Date().toISOString() && !['CLOSED', 'RESOLVED', 'RAILWAY_VERIFIED'].includes(r.status)).length;
    const avgResolutionTime = inMonth.filter(r => r.resolvedAt).reduce((acc, r) => acc + (new Date(r.resolvedAt) - new Date(r.createdAt)) / 86400000, 0);
    const resolvedCount = inMonth.filter(r => r.resolvedAt).length;
    const report = await this._storeReport({
      stationId, stationName, reportType: 'monthly_complaint', month, year, date: startDate,
      summary: { total: inMonth.length, open: inMonth.filter(r => ['OPEN', 'ASSIGNED', 'IN_PROGRESS'].includes(r.status)).length, resolved: inMonth.filter(r => ['CLOSED', 'RESOLVED', 'RAILWAY_VERIFIED'].includes(r.status)).length, escalated: inMonth.filter(r => r.status === 'ESCALATED').length, slaBreached, statusDistribution: statusDist, categoryDistribution: catDist, avgResolutionDays: resolvedCount > 0 ? (avgResolutionTime / resolvedCount).toFixed(1) : 'N/A' },
      generatedBy: user.uid, generatedByName: user.fullName || '', generatedAt: new Date().toISOString(),
    });
    return report;
  }

  async generateMonthlyFeedbackSummary(stationId, month, year, user) {
    const stationName = await this._getStationName(stationId);
    const monthPad = String(month).padStart(2, '0');
    const startDate = `${year}-${monthPad}-01`;
    const records = await this._getFeedbackRecords(stationId);
    const endDate = `${year}-${monthPad}-${this._getMonthEnd(year, month)}`;
    const inMonth = records.filter(r => { const c = r.createdAt || ''; return c >= startDate && c <= endDate + 'T23:59:59'; });
    const ratings = inMonth.filter(r => r.rating).map(r => r.rating);
    const avgRating = ratings.length > 0 ? (ratings.reduce((s, v) => s + v, 0) / ratings.length).toFixed(1) : 'N/A';
    const catBreakdown = inMonth.reduce((acc, r) => { const c = r.category || 'General'; acc[c] = (acc[c] || 0) + 1; return acc; }, {});
    const report = await this._storeReport({
      stationId, stationName, reportType: 'monthly_feedback', month, year, date: startDate,
      summary: { total: inMonth.length, approved: inMonth.filter(r => r.status === 'approved').length, pending: inMonth.filter(r => r.status === 'pending').length, averageRating: avgRating, ratingDistribution: inMonth.reduce((acc, r) => { const v = String(r.rating || 0); acc[v] = (acc[v] || 0) + 1; return acc; }, {}), categoryBreakdown: catBreakdown },
      generatedBy: user.uid, generatedByName: user.fullName || '', generatedAt: new Date().toISOString(),
    });
    return report;
  }

  async generateMonthlyBillingReport(stationId, month, year, user) {
    const stationName = await this._getStationName(stationId);
    const monthPad = String(month).padStart(2, '0');
    const startDate = `${year}-${monthPad}-01`;
    const snap = await db.collection('station_billing_packs').where('stationId', '==', stationId).get();
    const records = []; snap.forEach(d => records.push(d.data()));
    const inMonth = records.filter(r => { const m = r.month || r.billingPeriod?.month; const y = r.year || r.billingPeriod?.year; return m == month && y == year; });
    const submitted = inMonth.filter(r => r.status === 'SUBMITTED' || r.status === 'APPROVED' || r.status === 'REJECTED').length;
    const approved = inMonth.filter(r => r.status === 'APPROVED').length;
    const totalValue = inMonth.reduce((s, r) => s + (r.totalPayableWithGst || r.totalAmount || 0), 0);
    const totalGst = inMonth.reduce((s, r) => s + (r.gstAmount || 0), 0);
    const payments = inMonth.filter(r => r.paymentStatus === 'paid' || r.paymentStatus === 'partial').length;
    const report = await this._storeReport({
      stationId, stationName, reportType: 'monthly_billing', month, year, date: startDate,
      summary: { totalPacks: inMonth.length, submitted, approved, rejected: inMonth.filter(r => r.status === 'REJECTED').length, draft: inMonth.filter(r => r.status === 'DRAFT').length, totalValue, totalGst, paymentsReceived: payments, pendingPayment: inMonth.length - payments },
      generatedBy: user.uid, generatedByName: user.fullName || '', generatedAt: new Date().toISOString(),
    });
    return report;
  }

  async generateMonthlyPenaltyReport(stationId, month, year, user) {
    const stationName = await this._getStationName(stationId);
    const monthPad = String(month).padStart(2, '0');
    const startDate = `${year}-${monthPad}-01`; const endDate = `${year}-${monthPad}-${this._getMonthEnd(year, month)}`;
    const [downtimeSnap, complaintSnap, scorecardSnap] = await Promise.all([
      db.collection('machine_downtime').where('stationId', '==', stationId).get(),
      db.collection('complaints').where('stationId', '==', stationId).get(),
      db.collection('daily_scorecards').where('stationId', '==', stationId).get(),
    ]);
    const downtimeRecords = []; downtimeSnap.forEach(d => { const r = d.data(); const ts = r.startTime || ''; if (ts >= startDate && ts <= endDate) downtimeRecords.push(r); });
    const complaints = []; complaintSnap.forEach(d => complaints.push(d.data()));
    const inMonthComplaints = complaints.filter(r => { const c = r.createdAt || ''; return c >= startDate && c <= endDate + 'T23:59:59'; });
    const slaBreaches = inMonthComplaints.filter(r => r.slaDeadline && r.slaDeadline < new Date().toISOString() && !['CLOSED', 'RESOLVED', 'RAILWAY_VERIFIED'].includes(r.status));
    const totalDowntimeHours = downtimeRecords.reduce((s, d) => s + (d.totalDowntimeHours || 0), 0);
    const totalDowntimePenalty = downtimeRecords.reduce((s, d) => s + (d.penaltyAmount || 0), 0);
    const scorecards = []; scorecardSnap.forEach(d => { const r = d.data(); if (r.date >= startDate && r.date <= endDate) scorecards.push(r); });
    const lowScoreDays = scorecards.filter(s => (s.overallStationScore || 0) < 70).length;
    const penaltyDueFromScorecards = lowScoreDays > 5 ? lowScoreDays * 100 : 0;
    const report = await this._storeReport({
      stationId, stationName, reportType: 'monthly_penalty', month, year, date: startDate,
      summary: { machineDowntimeIncidents: downtimeRecords.length, totalDowntimeHours, machinePenaltyAmount: totalDowntimePenalty, complaintSlaBreaches: slaBreaches.length, penaltyDueFromScorecards, totalPenaltyDue: totalDowntimePenalty + penaltyDueFromScorecards, lowScoreDays },
      generatedBy: user.uid, generatedByName: user.fullName || '', generatedAt: new Date().toISOString(),
    });
    return report;
  }

  async generateMonthlyPerformanceReport(stationId, month, year, user) {
    const stationName = await this._getStationName(stationId);
    const monthPad = String(month).padStart(2, '0');
    const startDate = `${year}-${monthPad}-01`;
    const endDate = `${year}-${monthPad}-${this._getMonthEnd(year, month)}`;
    const [attSnap, scAttSnap, actSnap, scoreSnap, compSnap] = await Promise.all([
      db.collection('station_attendance').where('stationId', '==', stationId).get(),
      db.collection('station_cleaning_attendance').where('stationId', '==', stationId).get(),
      db.collection('station_daily_activities').where('stationId', '==', stationId).get(),
      db.collection('daily_scorecards').where('stationId', '==', stationId).get(),
      db.collection('complaints').where('stationId', '==', stationId).get(),
    ]);
    const attRecords = []; attSnap.forEach(d => { const r = d.data(); if (r.date >= startDate && r.date <= endDate) attRecords.push(r); });
    scAttSnap.forEach(d => { const r = d.data(); if (r.date >= startDate && r.date <= endDate) attRecords.push(r); });
    const actRecords = []; actSnap.forEach(d => { const r = d.data(); if (r.date >= startDate && r.date <= endDate) actRecords.push(r); });
    const scoreRecords = []; scoreSnap.forEach(d => { const r = d.data(); if (r.date >= startDate && r.date <= endDate) scoreRecords.push(r); });
    const compRecords = []; compSnap.forEach(d => compRecords.push(d.data()));
    const feedRecords = await this._getFeedbackRecords(stationId);
    const inMonthComps = compRecords.filter(r => { const c = r.createdAt || ''; return c >= startDate && c <= endDate + 'T23:59:59'; });
    const inMonthFeed = feedRecords.filter(r => { const c = r.createdAt || ''; return c >= startDate && c <= endDate + 'T23:59:59'; });
    const presentLate = attRecords.filter(r => r.status === 'present' || r.status === 'late' || r.attendanceStatus === 'PRESENT' || r.attendanceStatus === 'LATE').length;
    const attPct = attRecords.length > 0 ? Math.round(presentLate / attRecords.length * 100) : 0;
    const completedActs = actRecords.filter(a => a.status === 'COMPLETED' || a.status === 'APPROVED').length;
    const completionRate = actRecords.length > 0 ? Math.round(completedActs / actRecords.length * 100) : 0;
    const avgScore = scoreRecords.length > 0 ? Math.round(scoreRecords.reduce((s, r) => s + (r.overallStationScore || 0), 0) / scoreRecords.length) : 0;
    const ratings = inMonthFeed.filter(r => r.rating).map(r => r.rating);
    const report = await this._storeReport({
      stationId, stationName, reportType: 'monthly_performance', month, year, date: startDate,
      summary: { attendanceRate: attPct, totalManpowerEntries: attRecords.length, activityCompletionRate: completionRate, totalActivities: actRecords.length, averageScorecardScore: avgScore, scorecardDays: scoreRecords.length, totalComplaints: inMonthComps.length, resolvedComplaints: inMonthComps.filter(r => ['CLOSED', 'RESOLVED', 'RAILWAY_VERIFIED'].includes(r.status)).length, totalFeedback: inMonthFeed.length, averageFeedbackRating: ratings.length > 0 ? (ratings.reduce((s, v) => s + v, 0) / ratings.length).toFixed(1) : 'N/A', overallPerformanceIndex: avgScore > 0 ? Math.round((attPct + completionRate + avgScore) / 3) : 0 },
      generatedBy: user.uid, generatedByName: user.fullName || '', generatedAt: new Date().toISOString(),
    });
    return report;
  }

  async generateMonthlyPettyIssueReport(stationId, month, year, user) {
    const stationName = await this._getStationName(stationId);
    const monthPad = String(month).padStart(2, '0');
    const startDate = `${year}-${monthPad}-01`; const endDate = `${year}-${monthPad}-${this._getMonthEnd(year, month)}`;
    const snap = await db.collection('petty_issues').where('stationId', '==', stationId).get();
    const inMonth = []; snap.forEach(d => { const r = d.data(); const ts = r.reportedAt || r.createdAt || ''; const d2 = ts.split('T')[0]; if (d2 >= startDate && d2 <= endDate) inMonth.push(r); });
    const open = inMonth.filter(r => ['REPORTED', 'ASSIGNED', 'IN_PROGRESS'].includes(r.status));
    const resolved = inMonth.filter(r => ['RESOLVED', 'CLOSED'].includes(r.status));
    const rejected = inMonth.filter(r => r.status === 'REJECTED');
    const statusBreakdown = inMonth.reduce((acc, r) => { acc[r.status || 'UNKNOWN'] = (acc[r.status || 'UNKNOWN'] || 0) + 1; return acc; }, {});
    const severityBreakdown = inMonth.reduce((acc, r) => { acc[r.severity || 'medium'] = (acc[r.severity || 'medium'] || 0) + 1; return acc; }, {});
    const categoryBreakdown = inMonth.reduce((acc, r) => { acc[r.category || 'other'] = (acc[r.category || 'other'] || 0) + 1; return acc; }, {});
    const avgResolutionDays = resolved.filter(r => r.resolvedAt).reduce((acc, r) => acc + (new Date(r.resolvedAt) - new Date(r.reportedAt || r.createdAt)) / 86400000, 0);
    const resolvedWithTs = resolved.filter(r => r.resolvedAt).length;
    const report = await this._storeReport({
      stationId, stationName, reportType: 'monthly_petty_issue', month, year, date: startDate,
      summary: {
        total: inMonth.length, open: open.length, resolved: resolved.length, rejected: rejected.length,
        resolutionRate: inMonth.length > 0 ? Math.round(resolved.length / inMonth.length * 100) : 0,
        avgResolutionDays: resolvedWithTs > 0 ? (avgResolutionDays / resolvedWithTs).toFixed(1) : 'N/A',
        statusBreakdown, severityBreakdown, categoryBreakdown,
      },
      generatedBy: user.uid, generatedByName: user.fullName || '', generatedAt: new Date().toISOString(),
    });
    return report;
  }

  /* ==================================================================
     5. AUDIT REPORTS (Section 10.3)
     ================================================================== */

  async generateUserActivityAudit(query, user) {
    const { startDate, endDate, userId, action, limit = 200 } = query;
    let q = db.collection('audit_evidence').orderBy('timestamp', 'desc').limit(parseInt(limit));
    if (startDate) q = q.where('timestamp', '>=', new Date(startDate));
    if (endDate) q = q.where('timestamp', '<=', new Date(endDate));
    if (userId) q = q.where('userId', '==', userId);
    if (action) q = q.where('action', '==', action);
    const snap = await q.get();
    const records = []; snap.forEach(d => records.push({ id: d.id, ...d.data() }));
    const now = new Date().toISOString();
    const report = await this._storeReport({
      stationId: 'all', stationName: 'All Stations',
      reportType: 'audit_user_activity', date: now.split('T')[0], month: new Date().getMonth() + 1, year: new Date().getFullYear(),
      query: { startDate, endDate, userId, action },
      summary: { totalRecords: records.length, records },
      generatedBy: user.uid, generatedByName: user.fullName || '',
    });
    return report;
  }

  async generateImageArchiveReport(query, user) {
    const { startDate, endDate, stationId, evidenceType, limit = 200 } = query;
    let q = db.collection('evidence_metadata').where('deleted', '==', false).limit(parseInt(limit));
    if (stationId) q = q.where('stationId', '==', stationId);
    if (evidenceType) q = q.where('evidenceType', '==', evidenceType);
    const snap = await q.get();
    let records = []; snap.forEach(d => records.push(d.data()));
    if (startDate) records = records.filter(r => r.uploadedAt >= startDate);
    if (endDate) records = records.filter(r => r.uploadedAt <= endDate + 'T23:59:59');
    const totalSize = records.reduce((s, r) => s + (r.compressedSize || r.originalSize || 0), 0);
    const now = new Date().toISOString();
    const report = await this._storeReport({
      stationId: stationId || 'all', stationName: stationId ? await this._getStationName(stationId) : 'All Stations',
      reportType: 'audit_image_archive', date: now.split('T')[0], month: new Date().getMonth() + 1, year: new Date().getFullYear(),
      query: { startDate, endDate, stationId, evidenceType },
      summary: { totalImages: records.length, totalStorageMB: (totalSize / (1024 * 1024)).toFixed(2), images: records.map(r => ({ id: r.uid, stationId: r.stationId, evidenceType: r.evidenceType, uploadedAt: r.uploadedAt, fileSize: r.compressedSize || r.originalSize, url: r.url })) },
      generatedBy: user.uid, generatedByName: user.fullName || '',
    });
    return report;
  }

  async generateRejectedFormsReport(query, user) {
    const { startDate, endDate, limit = 200 } = query;
    const collections = ['stationCleaningForms', 'station_feedback', 'scorecards', 'complaints', 'supervisor_daily_logs'];
    const allRejected = [];
    for (const collName of collections) {
      const snap = await db.collection(collName).where('status', '==', 'REJECTED').limit(parseInt(limit) / collections.length).get();
      snap.forEach(d => allRejected.push({ collection: collName, id: d.id, ...d.data() }));
    }
    let filtered = allRejected;
    if (startDate) filtered = filtered.filter(r => r.updatedAt >= startDate);
    if (endDate) filtered = filtered.filter(r => r.updatedAt <= endDate + 'T23:59:59');
    const now = new Date().toISOString();
    const report = await this._storeReport({
      stationId: 'all', stationName: 'All Stations',
      reportType: 'audit_rejected_forms', date: now.split('T')[0], month: new Date().getMonth() + 1, year: new Date().getFullYear(),
      query: { startDate, endDate },
      summary: { totalRejected: filtered.length, forms: filtered.map(r => ({ collection: r.collection, formId: r.id, stationId: r.stationId, reason: r.rejectionReason || r.reason || 'N/A', rejectedAt: r.updatedAt, rejectedBy: r.rejectedBy })) },
      generatedBy: user.uid, generatedByName: user.fullName || '',
    });
    return report;
  }

  async generateInspectionHistoryReport(query, user) {
    const { stationId, startDate, endDate, inspectorId, limit = 200 } = query;
    let q = db.collection('inspections').orderBy('createdAt', 'desc').limit(parseInt(limit));
    if (stationId) q = q.where('stationId', '==', stationId);
    if (inspectorId) q = q.where('inspectorId', '==', inspectorId);
    const snap = await q.get();
    let records = []; snap.forEach(d => records.push({ id: d.id, ...d.data() }));
    if (startDate) records = records.filter(r => r.inspectionDate >= startDate || r.scheduledDate >= startDate);
    if (endDate) records = records.filter(r => r.inspectionDate <= endDate || r.scheduledDate <= endDate);
    const now = new Date().toISOString();
    const report = await this._storeReport({
      stationId: stationId || 'all', stationName: stationId ? await this._getStationName(stationId) : 'All Stations',
      reportType: 'audit_inspection_history', date: now.split('T')[0], month: new Date().getMonth() + 1, year: new Date().getFullYear(),
      query: { stationId, startDate, endDate, inspectorId },
      summary: { totalInspections: records.length, inspections: records.map(r => ({ id: r.id, stationId: r.stationId, inspectionType: r.inspectionType, inspector: r.inspectorName || r.inspectorId, date: r.inspectionDate || r.scheduledDate, status: r.status, score: r.overallScore, deficiencies: (r.deficiencies || []).length })) },
      generatedBy: user.uid, generatedByName: user.fullName || '',
    });
    return report;
  }

  async generateDataModificationReport(query, user) {
    const { startDate, endDate, userId, limit = 200 } = query;
    let q = db.collection('audit_evidence').where('action', 'in', ['UPDATE', 'DELETE', 'DATA_MODIFICATION']).orderBy('timestamp', 'desc').limit(parseInt(limit));
    if (startDate) q = q.where('timestamp', '>=', new Date(startDate));
    if (endDate) q = q.where('timestamp', '<=', new Date(endDate));
    if (userId) q = q.where('userId', '==', userId);
    const snap = await q.get();
    const records = []; snap.forEach(d => records.push({ id: d.id, ...d.data() }));
    const now = new Date().toISOString();
    const report = await this._storeReport({
      stationId: 'all', stationName: 'All Stations',
      reportType: 'audit_data_modification', date: now.split('T')[0], month: new Date().getMonth() + 1, year: new Date().getFullYear(),
      query: { startDate, endDate, userId },
      summary: { totalModifications: records.length, modifications: records.map(r => ({ id: r.id, userId: r.userId, userName: r.userName, action: r.action, details: r.details, timestamp: r.timestamp })) },
      generatedBy: user.uid, generatedByName: user.fullName || '',
    });
    return report;
  }

  /* ==================================================================
     6. ARCHIVE RETRIEVAL REPORT
     ================================================================== */

  async generateArchiveRetrievalReport(stationId, startDate, endDate, user) {
    const stationName = await this._getStationName(stationId);
    const collections = ['stationCleaningForms', 'inspections', 'daily_scorecards',
      'station_daily_activities', 'station_feedback', 'complaints', 'supervisor_daily_logs'];
    const allRecords = [];
    for (const collName of collections) {
      let q = db.collection(collName).where('stationId', '==', stationId).limit(1000);
      const snap = await q.get();
      snap.forEach(d => {
        const data = d.data();
        const ts = data.createdAt || data.date || data.updatedAt || '';
        if (ts && ts >= startDate && ts <= (endDate + 'T23:59:59')) {
          allRecords.push({ collection: collName, id: d.id, ...data });
        }
      });
    }
    const byCollection = allRecords.reduce((acc, r) => {
      acc[r.collection] = (acc[r.collection] || 0) + 1;
      return acc;
    }, {});
    const report = await this._storeReport({
      stationId, stationName, reportType: 'archive_retrieval',
      date: startDate, month: parseInt(startDate.substring(5, 7)), year: parseInt(startDate.substring(0, 4)),
      query: { startDate, endDate },
      summary: {
        totalRecords: allRecords.length, startDate, endDate,
        collectionBreakdown: byCollection,
        records: allRecords.map(r => ({
          collection: r.collection, id: r.id, type: r.reportType || r.inspectionType || r.status || r.formType || 'N/A',
          date: r.createdAt || r.date || r.updatedAt || '',
          summary: JSON.stringify(r).substring(0, 200),
        })),
      },
      generatedBy: user.uid, generatedByName: user.fullName || '', generatedAt: new Date().toISOString(),
    });
    return report;
  }

  /* ==================================================================
     7. SCHEDULED / AUTO-EMAIL
     ================================================================== */

  async scheduleReport(reportType, cronExpression, recipients, parameters) {
    if (!DAILY_REPORT_TYPES.includes(reportType) && !MONTHLY_REPORT_TYPES.includes(reportType) && !AUDIT_REPORT_TYPES.includes(reportType)) {
      throw new ValidationError(`Invalid report type: ${reportType}`);
    }
    if (!recipients || !Array.isArray(recipients) || recipients.length === 0) {
      throw new ValidationError('At least one recipient required');
    }
    const ref = db.collection('report_schedules').doc();
    const schedule = {
      uid: ref.id, reportType, cronExpression, recipients, parameters: parameters || {},
      nextRunAt: null, lastRunAt: null, active: true,
      createdAt: new Date().toISOString(), updatedAt: new Date().toISOString(),
    };
    await ref.set(schedule);
    logger.info('StationReport', `Report schedule created: ${ref.id} type=${reportType}`);
    return schedule;
  }

  async listSchedules(query = {}) {
    const { active, reportType, limit = 50 } = query;
    let q = db.collection('report_schedules').orderBy('createdAt', 'desc').limit(parseInt(limit));
    if (active !== undefined) q = q.where('active', '==', active === 'true');
    if (reportType) q = q.where('reportType', '==', reportType);
    const snap = await q.get();
    const schedules = []; snap.forEach(d => schedules.push(d.data()));
    return { count: schedules.length, schedules };
  }

  async deleteSchedule(uid) {
    const doc = await db.collection('report_schedules').doc(uid).get();
    if (!doc.exists) throw new NotFoundError('Schedule not found');
    await doc.ref.delete();
    return { message: 'Schedule deleted' };
  }

  async executeScheduledReports() {
    const snap = await db.collection('report_schedules').where('active', '==', true).limit(50).get();
    const results = [];
    for (const doc of snap.docs) {
      const schedule = doc.data();
      try {
        const user = { uid: 'system', fullName: 'System', role: 'SUPER_ADMIN' };
        const dateStr = new Date().toISOString().split('T')[0];
        const month = new Date().getMonth() + 1;
        const year = new Date().getFullYear();
        const params = { stationId: schedule.parameters?.stationId, date: dateStr, month, year, ...schedule.parameters };

        if (schedule.reportType.startsWith('daily_') || schedule.reportType === 'missed_activity') {
          const fnMap = { daily_attendance: 'generateDailyAttendanceReport', daily_activity: 'generateDailyActivityReport', daily_scorecard: 'generateDailyScorecardReport', daily_complaint: 'generateDailyComplaintReport', daily_feedback: 'generateDailyFeedbackReport', daily_inspection: 'generateDailyInspectionReport', daily_supervisor_log: 'generateDailySupervisorLog', daily_petty_issue: 'generateDailyPettyIssueReport', missed_activity: 'generateMissedActivityReport', archive_retrieval: 'generateArchiveRetrievalReport' };
          if (fnMap[schedule.reportType]) {
            if (schedule.reportType === 'archive_retrieval') {
              await this[fnMap[schedule.reportType]](params.stationId, params.date, params.date, user);
            } else {
              await this[fnMap[schedule.reportType]](params.stationId, params.date, user);
            }
            if (schedule.reportType !== 'archive_retrieval') {
              await autoEmailService.dispatchDailyReport(schedule.reportType, params.stationId, params.date);
            }
          }
        } else if (schedule.reportType.startsWith('monthly_')) {
          const fnMap = { monthly_attendance: 'generateMonthlyAttendanceSummary', monthly_cleaning: 'generateMonthlyCleaningSummary', monthly_scorecard: 'generateMonthlyScorecardReport', monthly_complaint: 'generateMonthlyComplaintSummary', monthly_feedback: 'generateMonthlyFeedbackSummary', monthly_billing: 'generateMonthlyBillingReport', monthly_penalty: 'generateMonthlyPenaltyReport', monthly_performance: 'generateMonthlyPerformanceReport', monthly_petty_issue: 'generateMonthlyPettyIssueReport' };
          await this[fnMap[schedule.reportType]](params.stationId, params.month, params.year, user);
          await autoEmailService.dispatchMonthlyReport(schedule.reportType, params.stationId, params.month, params.year);
        } else if (schedule.reportType.startsWith('audit_')) {
          const auditFnMap = {
            audit_user_activity: 'generateUserActivityAudit',
            audit_image_archive: 'generateImageArchiveReport',
            audit_rejected_forms: 'generateRejectedFormsReport',
            audit_inspection_history: 'generateInspectionHistoryReport',
            audit_data_modification: 'generateDataModificationReport',
          };
          const fnName = auditFnMap[schedule.reportType];
          if (fnName) await this[fnName](params, user);
        }

        if (schedule.recipients) {
          await this._notifyRecipients(schedule.reportType, params.stationId || 'all', schedule.recipients);
        }
        await doc.ref.update({ lastRunAt: new Date().toISOString(), updatedAt: new Date().toISOString() });
        results.push({ scheduleId: schedule.uid, status: 'executed' });
      } catch (err) {
        logger.error('StationReport', `Schedule execution failed: ${schedule.uid}`, err.message);
        results.push({ scheduleId: schedule.uid, status: 'failed', error: err.message });
      }
    }
    return { executed: results.length, results };
  }

  async getDailyReportTypes() { return DAILY_REPORT_TYPES; }
  async getMonthlyReportTypes() { return MONTHLY_REPORT_TYPES; }
  async getAuditReportTypes() { return AUDIT_REPORT_TYPES; }
}

export const stationReportService = new StationReportService();
