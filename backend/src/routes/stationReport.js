import { Router } from 'express';
import { verifyToken } from '../middleware/auth.js';
import { requirePermission, requireStationAccess, requireContractType } from '../middleware/authorization.js';
import { PERMISSIONS } from '../permissions/roles.js';
import * as ctrl from '../controllers/stationReportController.js';

const router = Router();

// Station-cleaning scope only. Mirrors stationCleaningRoutes: any authenticated
// user must belong to (or not conflict with) the station-cleaning contract and
// must hold the view_reports permission. Station-bearing routes additionally
// enforce station access below.
router.all('*', verifyToken, requireContractType('station_cleaning'), requirePermission(PERMISSIONS.VIEW_REPORTS));

// Existing
router.post('/api/station-reports/generate', verifyToken, requireStationAccess, ctrl.generateReport);
router.get('/api/station-reports', verifyToken, requireStationAccess, ctrl.listReports);
router.get('/api/station-reports/score-trend', verifyToken, requireStationAccess, ctrl.getScoreTrend);
router.get('/api/station-reports/comparison', verifyToken, ctrl.getStationComparison);

// 10.1 Daily Reports
router.post('/api/station-reports/daily/attendance', verifyToken, requireStationAccess, ctrl.generateDailyAttendanceReport);
router.post('/api/station-reports/daily/activity', verifyToken, requireStationAccess, ctrl.generateDailyActivityReport);
router.post('/api/station-reports/daily/scorecard', verifyToken, requireStationAccess, ctrl.generateDailyScorecardReport);
router.post('/api/station-reports/daily/complaint', verifyToken, requireStationAccess, ctrl.generateDailyComplaintReport);
router.post('/api/station-reports/daily/feedback', verifyToken, requireStationAccess, ctrl.generateDailyFeedbackReport);
router.post('/api/station-reports/daily/supervisor-log', verifyToken, requireStationAccess, ctrl.generateDailySupervisorLogReport);
router.post('/api/station-reports/daily/inspection', verifyToken, requireStationAccess, ctrl.generateDailyInspectionReport);
router.post('/api/station-reports/daily/petty-issue', verifyToken, requireStationAccess, ctrl.generateDailyPettyIssueReport);
router.post('/api/station-reports/daily/missed-activity', verifyToken, requireStationAccess, ctrl.generateMissedActivityReport);
router.post('/api/station-reports/archive-retrieval', verifyToken, requireStationAccess, ctrl.generateArchiveRetrievalReport);
router.post('/api/station-reports/range', verifyToken, requireStationAccess, ctrl.generateRangeReport);

// 10.2 Monthly Reports
router.post('/api/station-reports/monthly/attendance', verifyToken, requireStationAccess, ctrl.generateMonthlyAttendanceSummary);
router.post('/api/station-reports/monthly/cleaning', verifyToken, requireStationAccess, ctrl.generateMonthlyCleaningSummary);
router.post('/api/station-reports/monthly/scorecard', verifyToken, requireStationAccess, ctrl.generateMonthlyScorecardSummary);
router.post('/api/station-reports/monthly/complaint', verifyToken, requireStationAccess, ctrl.generateMonthlyComplaintSummary);
router.post('/api/station-reports/monthly/feedback', verifyToken, requireStationAccess, ctrl.generateMonthlyFeedbackSummary);
router.post('/api/station-reports/monthly/billing', verifyToken, requireStationAccess, ctrl.generateMonthlyBillingReport);
router.post('/api/station-reports/monthly/penalty', verifyToken, requireStationAccess, ctrl.generateMonthlyPenaltyReport);
router.post('/api/station-reports/monthly/performance', verifyToken, requireStationAccess, ctrl.generateMonthlyPerformanceReport);
router.post('/api/station-reports/monthly/petty-issue', verifyToken, requireStationAccess, ctrl.generateMonthlyPettyIssueReport);

// 10.3 Audit Reports
router.get('/api/station-reports/audit/user-activity', verifyToken, ctrl.generateUserActivityAudit);
router.get('/api/station-reports/audit/image-archive', verifyToken, requireStationAccess, ctrl.generateImageArchiveReport);
router.get('/api/station-reports/audit/rejected-forms', verifyToken, requireStationAccess, ctrl.generateRejectedFormsReport);
router.get('/api/station-reports/audit/inspection-history', verifyToken, requireStationAccess, ctrl.generateInspectionHistoryReport);
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
router.post('/api/station-reports/auto-email/end-of-day', verifyToken, requireStationAccess, ctrl.dispatchEndOfDayReports);
router.post('/api/station-reports/auto-email/end-of-month', verifyToken, requireStationAccess, ctrl.dispatchEndOfMonthReports);
router.post('/api/station-reports/auto-email/daily', verifyToken, requireStationAccess, ctrl.dispatchDailyReport);
router.post('/api/station-reports/auto-email/monthly', verifyToken, requireStationAccess, ctrl.dispatchMonthlyReport);
router.post('/api/station-reports/auto-email/missed-activity', verifyToken, requireStationAccess, ctrl.dispatchMissedActivityAlert);
router.post('/api/station-reports/auto-email/rejected-form', verifyToken, requireStationAccess, ctrl.dispatchRejectedFormNotification);
router.post('/api/station-reports/auto-email/complaint-escalation', verifyToken, requireStationAccess, ctrl.dispatchComplaintEscalation);

// Param route must be last
router.get('/api/station-reports/:uid', verifyToken, ctrl.getReportById);

export default router;
