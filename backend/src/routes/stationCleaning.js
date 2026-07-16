import { Router } from 'express';
import { verifyToken } from '../middleware/auth.js';
import { requirePermission, requireEntityAccess, requireStationAccess, requirePlatformAccess, requireAreaAccess } from '../middleware/authorization.js';
import { PERMISSIONS } from '../permissions/roles.js';
import { asyncHandler } from '../middleware/errorHandler.js';
import { stationCleaningService } from '../services/stationCleaningService.js';
import * as stationCleaning from '../controllers/stationCleaningController.js';
import * as stationCleaningAttendance from '../controllers/stationCleaningAttendanceController.js';

const router = Router();

// ─── Station Areas ────────────────────────────────────────────────────────────
router.post('/api/station-area/create', verifyToken, requirePermission(PERMISSIONS.MANAGE_AREAS), requireStationAccess, requireAreaAccess, stationCleaning.createStationArea);
router.get('/api/station-area/list/:stationId', verifyToken, requirePermission(PERMISSIONS.VIEW_AREAS), requireStationAccess, requireAreaAccess, stationCleaning.listStationAreas);
router.get('/api/station-area/:uid', verifyToken, requirePermission(PERMISSIONS.VIEW_AREAS), requireStationAccess, requireAreaAccess, stationCleaning.getStationArea);
router.put('/api/station-area/update/:uid', verifyToken, requirePermission(PERMISSIONS.MANAGE_AREAS), requireStationAccess, requireAreaAccess, stationCleaning.updateStationArea);
router.delete('/api/station-area/delete/:uid', verifyToken, requirePermission(PERMISSIONS.MANAGE_AREAS), requireStationAccess, requireAreaAccess, stationCleaning.deleteStationArea);

// ─── Station Zones ────────────────────────────────────────────────────────────
router.post('/api/station-zone/create', verifyToken, requirePermission(PERMISSIONS.MANAGE_AREAS), requireStationAccess, requireAreaAccess, stationCleaning.createStationZone);
router.get('/api/station-zone/list/:stationId', verifyToken, requirePermission(PERMISSIONS.VIEW_AREAS), requireStationAccess, requireAreaAccess, stationCleaning.listStationZones);
router.get('/api/station-zone/:uid', verifyToken, requirePermission(PERMISSIONS.VIEW_AREAS), requireStationAccess, requireAreaAccess, stationCleaning.getStationZone);
router.put('/api/station-zone/:uid', verifyToken, requirePermission(PERMISSIONS.MANAGE_AREAS), requireStationAccess, requireAreaAccess, stationCleaning.updateStationZone);
router.delete('/api/station-zone/:uid', verifyToken, requirePermission(PERMISSIONS.MANAGE_AREAS), requireStationAccess, requireAreaAccess, stationCleaning.deleteStationZone);

// ─── Contractor Mapping ───────────────────────────────────────────────────────
router.post('/api/station-contractor/map', verifyToken, requirePermission(PERMISSIONS.MANAGE_CONTRACTORS), requireStationAccess, requirePlatformAccess, stationCleaning.mapContractor);
router.get('/api/station-contractor/list/:stationId', verifyToken, requirePermission(PERMISSIONS.VIEW_CONTRACTORS), requireStationAccess, requirePlatformAccess, stationCleaning.listContractorMappings);
router.get('/api/station-contractor/:uid', verifyToken, requirePermission(PERMISSIONS.VIEW_CONTRACTORS), requireStationAccess, requirePlatformAccess, stationCleaning.getContractorMapping);
router.put('/api/station-contractor/:uid', verifyToken, requirePermission(PERMISSIONS.MANAGE_CONTRACTORS), requireStationAccess, requirePlatformAccess, stationCleaning.updateContractorMapping);
router.delete('/api/station-contractor/:uid', verifyToken, requirePermission(PERMISSIONS.MANAGE_CONTRACTORS), requireStationAccess, requirePlatformAccess, stationCleaning.deleteContractorMapping);

// ─── Schedules ────────────────────────────────────────────────────────────────
router.post('/api/station-schedule/create', verifyToken, requirePermission(PERMISSIONS.MANAGE_SCHEDULES), requireStationAccess, requirePlatformAccess, requireAreaAccess, stationCleaning.createSchedule);
router.get('/api/station-schedule/list/:stationId', verifyToken, requirePermission(PERMISSIONS.VIEW_SCHEDULES), requireStationAccess, requirePlatformAccess, requireAreaAccess, stationCleaning.listSchedules);
router.get('/api/station-schedule/:uid', verifyToken, requirePermission(PERMISSIONS.VIEW_SCHEDULES), requireStationAccess, requirePlatformAccess, requireAreaAccess, stationCleaning.getSchedule);
router.put('/api/station-schedule/:uid', verifyToken, requirePermission(PERMISSIONS.MANAGE_SCHEDULES), requireStationAccess, requirePlatformAccess, requireAreaAccess, stationCleaning.updateSchedule);
router.delete('/api/station-schedule/:uid', verifyToken, requirePermission(PERMISSIONS.MANAGE_SCHEDULES), requireStationAccess, requirePlatformAccess, requireAreaAccess, stationCleaning.deleteSchedule);

// ─── Station Runs ─────────────────────────────────────────────────────────────
router.post('/api/station-runs', verifyToken, requirePermission(PERMISSIONS.MANAGE_RUNS), requireStationAccess, requirePlatformAccess, stationCleaning.createStationRun);
router.get('/api/station-runs', verifyToken, requirePermission(PERMISSIONS.VIEW_RUNS), requireStationAccess, requirePlatformAccess, stationCleaning.listStationRuns);
router.get('/api/station-runs/my-runs', verifyToken, requirePermission(PERMISSIONS.VIEW_RUNS), requireStationAccess, requirePlatformAccess, stationCleaning.getMyStationRuns);
router.get('/api/station-runs/worker/:workerId', verifyToken, requirePermission(PERMISSIONS.VIEW_RUNS), stationCleaning.getWorkerStationRuns);
router.get('/api/station-runs/supervisor/:supervisorId', verifyToken, requirePermission(PERMISSIONS.VIEW_RUNS), stationCleaning.getSupervisorStationRuns);
router.put('/api/station-runs/:runId', verifyToken, requirePermission(PERMISSIONS.MANAGE_RUNS), requireStationAccess, requirePlatformAccess, stationCleaning.updateStationRun);
router.delete('/api/station-runs/:runId', verifyToken, requirePermission(PERMISSIONS.MANAGE_RUNS), requireStationAccess, requirePlatformAccess, stationCleaning.deleteStationRun);

// ─── Station Tasks ────────────────────────────────────────────────────────────
router.post('/api/station-tasks/submit', verifyToken, requirePermission(PERMISSIONS.SUBMIT_TASKS), requireStationAccess, requirePlatformAccess, requireAreaAccess, stationCleaning.submitStationTask);
router.get('/api/station-tasks/pending-review', verifyToken, requirePermission(PERMISSIONS.VIEW_TASKS), requireStationAccess, requirePlatformAccess, stationCleaning.listPendingStationTasks);
router.get('/api/station-tasks/:taskId', verifyToken, requirePermission(PERMISSIONS.VIEW_TASKS), requireStationAccess, requirePlatformAccess, stationCleaning.getStationTask);
router.put('/api/station-tasks/:taskId', verifyToken, requirePermission(PERMISSIONS.MANAGE_RUNS), requireStationAccess, requirePlatformAccess, stationCleaning.updateStationTask);
router.delete('/api/station-tasks/:taskId', verifyToken, requirePermission(PERMISSIONS.MANAGE_RUNS), requireStationAccess, requirePlatformAccess, stationCleaning.deleteStationTask);

// ─── Station Cleaning Forms ───────────────────────────────────────────────────
router.post('/api/station-cleaning-form/create', verifyToken, requirePermission(PERMISSIONS.SUBMIT_COACH_FORM), requireEntityAccess, requireStationAccess, requirePlatformAccess, requireAreaAccess, stationCleaning.createStationCleaningForm);
router.post('/api/station-cleaning-form/submit/:uid', verifyToken, requirePermission(PERMISSIONS.SUBMIT_COACH_FORM), requireStationAccess, requirePlatformAccess, requireAreaAccess, stationCleaning.submitStationCleaningForm);
router.post('/api/station-cleaning-form/approve/:uid', verifyToken, requirePermission(PERMISSIONS.APPROVE_FORM_MANPOWER), requireStationAccess, requirePlatformAccess, stationCleaning.approveStationCleaningForm);
router.post('/api/station-cleaning-form/reject/:uid', verifyToken, requirePermission(PERMISSIONS.REJECT_FORM), requireStationAccess, requirePlatformAccess, stationCleaning.rejectStationCleaningForm);
router.post('/api/station-cleaning-form/score/:uid', verifyToken, requirePermission(PERMISSIONS.SCORE_FORM), requireStationAccess, requirePlatformAccess, stationCleaning.scoreStationCleaningForm);
router.post('/api/station-cleaning-form/lock/:uid', verifyToken, requirePermission(PERMISSIONS.MANAGE_FORMS), requireStationAccess, requirePlatformAccess, stationCleaning.lockStationCleaningForm);
router.get('/api/station-cleaning-form/list', verifyToken, requirePermission(PERMISSIONS.VIEW_FORMS), requireStationAccess, requirePlatformAccess, stationCleaning.listStationCleaningForms);
router.get('/api/station-cleaning-form/details/:uid', verifyToken, requirePermission(PERMISSIONS.VIEW_FORMS), requireStationAccess, requirePlatformAccess, stationCleaning.getStationCleaningFormDetail);

// ─── Dashboard ────────────────────────────────────────────────────────────────
router.get('/api/station-dashboard', verifyToken, requirePermission(PERMISSIONS.VIEW_DASHBOARD), requireStationAccess, stationCleaning.getStationDashboard);

// ─── Pest Control ───────────────────────────────────────────────────────────
router.post('/api/station-pest-control/record', verifyToken, requirePermission(PERMISSIONS.MANAGE_PEST_CONTROL), requireEntityAccess, requireStationAccess, requirePlatformAccess, stationCleaning.recordPestControl);
router.get('/api/station-pest-control/list/:stationId', verifyToken, requirePermission(PERMISSIONS.VIEW_PEST_CONTROL), requireStationAccess, requirePlatformAccess, stationCleaning.listPestControl);
router.get('/api/station-pest-control/all', verifyToken, requirePermission(PERMISSIONS.VIEW_PEST_CONTROL), requireStationAccess, requirePlatformAccess, stationCleaning.listAllPestControl);
router.get('/api/station-pest-control/records', verifyToken, requirePermission(PERMISSIONS.VIEW_PEST_CONTROL), requireStationAccess, requirePlatformAccess, asyncHandler(async (req, res) => {
  const records = await stationCleaningService.listAllPestControl(req.query);
  res.json({ data: records || [] });
}));
router.put('/api/station-pest-control/:uid/review', verifyToken, requirePermission(PERMISSIONS.MANAGE_PEST_CONTROL), requireStationAccess, requirePlatformAccess, stationCleaning.reviewPestControl);
router.get('/api/station-pest-control/report', verifyToken, requirePermission(PERMISSIONS.VIEW_PEST_CONTROL), requireStationAccess, requirePlatformAccess, stationCleaning.pestControlReport);

// ─── Machine / Material Deployment ──────────────────────────────────────────
router.post('/api/station-machines/deploy', verifyToken, requirePermission(PERMISSIONS.MANAGE_MACHINES), requireEntityAccess, requireStationAccess, requirePlatformAccess, stationCleaning.deployMachine);
router.get('/api/station-machines/list', verifyToken, requirePermission(PERMISSIONS.VIEW_MACHINES), requireStationAccess, requirePlatformAccess, stationCleaning.listMachines);
router.put('/api/station-machines/:uid/return', verifyToken, requirePermission(PERMISSIONS.MANAGE_MACHINES), requireStationAccess, requirePlatformAccess, stationCleaning.returnMachine);
router.put('/api/station-machines/:uid/maintenance', verifyToken, requirePermission(PERMISSIONS.MANAGE_MACHINES), requireStationAccess, requirePlatformAccess, stationCleaning.maintenanceMachine);
router.get('/api/station-machines/report', verifyToken, requirePermission(PERMISSIONS.VIEW_MACHINES), requireStationAccess, requirePlatformAccess, stationCleaning.machineReport);

// ─── Area-Task Frequency Mapping (SRS #2) ───────────────────────────────────
router.post('/api/station-area-task-frequency', verifyToken, requirePermission(PERMISSIONS.MANAGE_AREAS), requireStationAccess, requireAreaAccess, stationCleaning.createAreaTaskFrequency);
router.put('/api/station-area-task-frequency/:uid', verifyToken, requirePermission(PERMISSIONS.MANAGE_AREAS), requireStationAccess, requireAreaAccess, stationCleaning.updateAreaTaskFrequency);
router.delete('/api/station-area-task-frequency/:uid', verifyToken, requirePermission(PERMISSIONS.MANAGE_AREAS), requireStationAccess, requireAreaAccess, stationCleaning.deleteAreaTaskFrequency);
router.get('/api/station-area-task-frequency', verifyToken, requirePermission(PERMISSIONS.VIEW_AREAS), requireStationAccess, requireAreaAccess, stationCleaning.listAreaTaskFrequencies);

// ─── Garbage Disposal ───────────────────────────────────────────────────────
router.post('/api/station-garbage/record', verifyToken, requirePermission(PERMISSIONS.MANAGE_GARBAGE), requireEntityAccess, requireStationAccess, requirePlatformAccess, stationCleaning.recordGarbageDisposal);
router.get('/api/station-garbage/records', verifyToken, requirePermission(PERMISSIONS.VIEW_GARBAGE), requireStationAccess, requirePlatformAccess, stationCleaning.listGarbageRecords);
router.get('/api/station-garbage/report', verifyToken, requirePermission(PERMISSIONS.VIEW_GARBAGE), requireStationAccess, requirePlatformAccess, stationCleaning.garbageReport);

// ─── Worker Dashboard ─────────────────────────────────────────────────────
router.get('/api/station-cleaning/dashboard/worker/:workerId', verifyToken, requirePermission(PERMISSIONS.VIEW_DASHBOARD), requireStationAccess, stationCleaning.getWorkerDashboard);

// ─── Supervisor Dashboard ──────────────────────────────────────────────────
router.get('/api/station-cleaning/dashboard/supervisor/:supervisorId', verifyToken, requirePermission(PERMISSIONS.VIEW_DASHBOARD), requireStationAccess, stationCleaning.getSupervisorDashboard);

// ─── Cleaning Reports ──────────────────────────────────────────────────────
router.get('/api/station-cleaning/reports/daily/:stationId', verifyToken, requirePermission(PERMISSIONS.VIEW_REPORTS), requireStationAccess, stationCleaning.generateDailyReport);
router.get('/api/station-cleaning/reports/weekly/:stationId', verifyToken, requirePermission(PERMISSIONS.VIEW_REPORTS), requireStationAccess, stationCleaning.generateWeeklyReport);
router.get('/api/station-cleaning/reports/monthly/:stationId', verifyToken, requirePermission(PERMISSIONS.VIEW_REPORTS), requireStationAccess, stationCleaning.generateMonthlyReport);
router.get('/api/station-cleaning/reports/score-trend/:stationId', verifyToken, requirePermission(PERMISSIONS.VIEW_REPORTS), requireStationAccess, stationCleaning.getScoreTrend);

// ─── Attendance (3-step: start / mid / end, matching OBHS flow) ─────────
router.post('/api/station-cleaning/attendance', verifyToken, requirePermission(PERMISSIONS.SUBMIT_TASKS), stationCleaningAttendance.markAttendance);
router.get('/api/station-cleaning/attendance/status', verifyToken, stationCleaningAttendance.getAttendanceStatus);
router.get('/api/station-cleaning/attendance/list', verifyToken, stationCleaningAttendance.listAttendance);
router.post('/api/station-cleaning/attendance/report-issue', verifyToken, stationCleaningAttendance.reportAttendanceIssue);
router.get('/api/station-cleaning/attendance/exceptions', verifyToken, stationCleaningAttendance.getAttendanceExceptions);
router.post('/api/station-cleaning/attendance/exceptions/action', verifyToken, stationCleaningAttendance.takeAttendanceExceptionAction);

export default router;
