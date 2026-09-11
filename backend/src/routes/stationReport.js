import { Router } from 'express';
import { verifyToken } from '../middleware/auth.js';
import * as ctrl from '../controllers/stationReportController.js';

const router = Router();

// Existing
router.post('/api/station-reports/generate', verifyToken, ctrl.generateReport);
router.get('/api/station-reports', verifyToken, ctrl.listReports);
router.get('/api/station-reports/score-trend', verifyToken, ctrl.getScoreTrend);
router.get('/api/station-reports/comparison', verifyToken, ctrl.getStationComparison);

// 10.1 Daily Reports
router.post('/api/station-reports/daily/attendance', verifyToken, ctrl.generateDailyAttendanceReport);
router.post('/api/station-reports/daily/activity', verifyToken, ctrl.generateDailyActivityReport);
router.post('/api/station-reports/daily/scorecard', verifyToken, ctrl.generateDailyScorecardReport);
router.post('/api/station-reports/daily/complaint', verifyToken, ctrl.generateDailyComplaintReport);
router.post('/api/station-reports/daily/feedback', verifyToken, ctrl.generateDailyFeedbackReport);
router.post('/api/station-reports/daily/supervisor-log', verifyToken, ctrl.generateDailySupervisorLogReport);
router.post('/api/station-reports/daily/inspection', verifyToken, ctrl.generateDailyInspectionReport);
router.post('/api/station-reports/daily/missed-activity', verifyToken, ctrl.generateMissedActivityReport);
router.post('/api/station-reports/archive-retrieval', verifyToken, ctrl.generateArchiveRetrievalReport);

// 10.2 Monthly Reports
router.post('/api/station-reports/monthly/attendance', verifyToken, ctrl.generateMonthlyAttendanceSummary);
router.post('/api/station-reports/monthly/cleaning', verifyToken, ctrl.generateMonthlyCleaningSummary);
router.post('/api/station-reports/monthly/scorecard', verifyToken, ctrl.generateMonthlyScorecardSummary);
router.post('/api/station-reports/monthly/complaint', verifyToken, ctrl.generateMonthlyComplaintSummary);
router.post('/api/station-reports/monthly/feedback', verifyToken, ctrl.generateMonthlyFeedbackSummary);
router.post('/api/station-reports/monthly/billing', verifyToken, ctrl.generateMonthlyBillingReport);
router.post('/api/station-reports/monthly/penalty', verifyToken, ctrl.generateMonthlyPenaltyReport);
router.post('/api/station-reports/monthly/performance', verifyToken, ctrl.generateMonthlyPerformanceReport);

// 10.3 Audit Reports
router.get('/api/station-reports/audit/user-activity', verifyToken, ctrl.generateUserActivityAudit);
router.get('/api/station-reports/audit/image-archive', verifyToken, ctrl.generateImageArchiveReport);
router.get('/api/station-reports/audit/rejected-forms', verifyToken, ctrl.generateRejectedFormsReport);
router.get('/api/station-reports/audit/inspection-history', verifyToken, ctrl.generateInspectionHistoryReport);
router.get('/api/station-reports/audit/data-modification', verifyToken, ctrl.generateDataModificationReport);

// Schedule management
router.post('/api/station-reports/schedule', verifyToken, ctrl.scheduleReport);
router.get('/api/station-reports/schedules', verifyToken, ctrl.listSchedules);
router.delete('/api/station-reports/schedule/:uid', verifyToken, ctrl.deleteSchedule);
router.post('/api/station-reports/schedules/execute', verifyToken, ctrl.executeScheduledReports);

// Report types (metadata)
router.get('/api/station-reports/types/daily', verifyToken, ctrl.getDailyReportTypes);
router.get('/api/station-reports/types/monthly', verifyToken, ctrl.getMonthlyReportTypes);
router.get('/api/station-reports/types/audit', verifyToken, ctrl.getAuditReportTypes);

// Auto-email dispatch triggers
router.post('/api/station-reports/auto-email/end-of-day', verifyToken, ctrl.dispatchEndOfDayReports);
router.post('/api/station-reports/auto-email/end-of-month', verifyToken, ctrl.dispatchEndOfMonthReports);
router.post('/api/station-reports/auto-email/daily', verifyToken, ctrl.dispatchDailyReport);
router.post('/api/station-reports/auto-email/monthly', verifyToken, ctrl.dispatchMonthlyReport);
router.post('/api/station-reports/auto-email/missed-activity', verifyToken, ctrl.dispatchMissedActivityAlert);
router.post('/api/station-reports/auto-email/rejected-form', verifyToken, ctrl.dispatchRejectedFormNotification);
router.post('/api/station-reports/auto-email/complaint-escalation', verifyToken, ctrl.dispatchComplaintEscalation);

// Param route must be last
router.get('/api/station-reports/:uid', verifyToken, ctrl.getReportById);

export default router;
