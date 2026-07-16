import { stationCleaningService } from '../services/stationCleaningService.js';
import { asyncHandler } from '../middleware/errorHandler.js';

export const createStationArea = asyncHandler(async (req, res) => {
  const result = await stationCleaningService.createStationArea(req.body);
  res.status(201).json(result);
});

export const updateStationArea = asyncHandler(async (req, res) => {
  const result = await stationCleaningService.updateStationArea(req.params.uid, req.body);
  res.status(200).json(result);
});

export const deleteStationArea = asyncHandler(async (req, res) => {
  const result = await stationCleaningService.deleteStationArea(req.params.uid);
  res.status(200).json(result);
});

export const listStationAreas = asyncHandler(async (req, res) => {
  const result = await stationCleaningService.listStationAreas(req.params.stationId, req.user);
  res.status(200).json(result);
});

export const getStationArea = asyncHandler(async (req, res) => {
  const result = await stationCleaningService.getStationArea(req.params.uid);
  res.status(200).json(result);
});

export const createStationZone = asyncHandler(async (req, res) => {
  const result = await stationCleaningService.createStationZone(req.body);
  res.status(201).json(result);
});

export const listStationZones = asyncHandler(async (req, res) => {
  const result = await stationCleaningService.listStationZones(req.params.stationId, req.query.areaId, req.user);
  res.status(200).json(result);
});

export const getStationZone = asyncHandler(async (req, res) => {
  const result = await stationCleaningService.getStationZone(req.params.uid);
  res.status(200).json(result);
});

export const updateStationZone = asyncHandler(async (req, res) => {
  const result = await stationCleaningService.updateStationZone(req.params.uid, req.body);
  res.status(200).json(result);
});

export const deleteStationZone = asyncHandler(async (req, res) => {
  const result = await stationCleaningService.deleteStationZone(req.params.uid);
  res.status(200).json(result);
});

export const mapContractor = asyncHandler(async (req, res) => {
  const result = await stationCleaningService.mapContractor(req.body);
  res.status(201).json(result);
});

export const listContractorMappings = asyncHandler(async (req, res) => {
  const result = await stationCleaningService.listContractorMappings(req.params.stationId, req.user);
  res.status(200).json(result);
});

export const getContractorMapping = asyncHandler(async (req, res) => {
  const result = await stationCleaningService.getContractorMapping(req.params.uid);
  res.status(200).json(result);
});

export const updateContractorMapping = asyncHandler(async (req, res) => {
  const result = await stationCleaningService.updateContractorMapping(req.params.uid, req.body);
  res.status(200).json(result);
});

export const deleteContractorMapping = asyncHandler(async (req, res) => {
  const result = await stationCleaningService.deleteContractorMapping(req.params.uid);
  res.status(200).json(result);
});

export const createSchedule = asyncHandler(async (req, res) => {
  const result = await stationCleaningService.createSchedule(req.body);
  res.status(201).json(result);
});

export const listSchedules = asyncHandler(async (req, res) => {
  const result = await stationCleaningService.listSchedules(req.params.stationId, req.user);
  res.status(200).json(result);
});

export const getSchedule = asyncHandler(async (req, res) => {
  const result = await stationCleaningService.getSchedule(req.params.uid);
  res.status(200).json(result);
});

export const updateSchedule = asyncHandler(async (req, res) => {
  const result = await stationCleaningService.updateSchedule(req.params.uid, req.body);
  res.status(200).json(result);
});

export const deleteSchedule = asyncHandler(async (req, res) => {
  const result = await stationCleaningService.deleteSchedule(req.params.uid);
  res.status(200).json(result);
});

export const createStationRun = asyncHandler(async (req, res) => {
  const result = await stationCleaningService.createStationRun(req.body, req.user);
  res.status(201).json({ success: true, data: result.data || result, message: result.message });
});

export const listStationRuns = asyncHandler(async (req, res) => {
  const result = await stationCleaningService.listStationRuns(req.query, req.user);
  res.status(200).json({ success: true, data: result.runs || result.data || [], count: result.count });
});

export const updateStationRun = asyncHandler(async (req, res) => {
  const result = await stationCleaningService.updateStationRun(req.params.runId, req.body);
  res.status(200).json({ success: true, data: result });
});

export const getMyStationRuns = asyncHandler(async (req, res) => {
  const result = await stationCleaningService.getMyStationRuns(req.user.uid);
  res.status(200).json({ success: true, data: result.runs || result.data || [], count: result.count });
});

export const deleteStationRun = asyncHandler(async (req, res) => {
  const result = await stationCleaningService.deleteStationRun(req.params.runId);
  res.status(200).json({ success: true, data: result });
});

export const getWorkerStationRuns = asyncHandler(async (req, res) => {
  const result = await stationCleaningService.getWorkerStationRuns(req.params.workerId, req.user);
  res.status(200).json({ success: true, data: result.runs || result.data || [], count: result.count });
});

export const getSupervisorStationRuns = asyncHandler(async (req, res) => {
  const result = await stationCleaningService.getSupervisorStationRuns(req.params.supervisorId, req.user);
  res.status(200).json({ success: true, data: result.runs || result.data || [], count: result.count });
});

export const submitStationTask = asyncHandler(async (req, res) => {
  const result = await stationCleaningService.submitStationTask(req.body);
  res.status(201).json(result);
});

export const getStationTask = asyncHandler(async (req, res) => {
  const result = await stationCleaningService.getStationTask(req.params.taskId);
  res.status(200).json(result);
});

export const updateStationTask = asyncHandler(async (req, res) => {
  const result = await stationCleaningService.updateStationTask(req.params.taskId, req.body);
  res.status(200).json(result);
});

export const deleteStationTask = asyncHandler(async (req, res) => {
  const result = await stationCleaningService.deleteStationTask(req.params.taskId);
  res.status(200).json(result);
});

export const listPendingStationTasks = asyncHandler(async (req, res) => {
  const result = await stationCleaningService.listPendingStationTasks(req.query.runInstanceId);
  res.status(200).json(result);
});

export const createStationCleaningForm = asyncHandler(async (req, res) => {
  const result = await stationCleaningService.createStationCleaningForm(req.body, req.user);
  res.status(201).json(result);
});

export const submitStationCleaningForm = asyncHandler(async (req, res) => {
  const result = await stationCleaningService.submitStationCleaningForm(req.params.uid, req.body, req.user);
  res.status(200).json(result);
});

export const approveStationCleaningForm = asyncHandler(async (req, res) => {
  const result = await stationCleaningService.approveStationCleaningForm(req.params.uid, req.user);
  res.status(200).json(result);
});

export const rejectStationCleaningForm = asyncHandler(async (req, res) => {
  const result = await stationCleaningService.rejectStationCleaningForm(req.params.uid, req.body.reason, req.user);
  res.status(200).json(result);
});

export const scoreStationCleaningForm = asyncHandler(async (req, res) => {
  const { scoringData, totalScore, grade } = req.body;
  const result = await stationCleaningService.scoreStationCleaningForm(req.params.uid, scoringData, totalScore, grade, req.user);
  res.status(200).json(result);
});

export const lockStationCleaningForm = asyncHandler(async (req, res) => {
  const result = await stationCleaningService.lockStationCleaningForm(req.params.uid);
  res.status(200).json(result);
});

export const listStationCleaningForms = asyncHandler(async (req, res) => {
  const result = await stationCleaningService.listStationCleaningForms(req.query, req.user);
  res.status(200).json(result);
});

export const getStationCleaningFormDetail = asyncHandler(async (req, res) => {
  const result = await stationCleaningService.getStationCleaningFormDetail(req.params.uid);
  res.status(200).json(result);
});

export const getStationDashboard = asyncHandler(async (req, res) => {
  const result = await stationCleaningService.getStationDashboard(req.user);
  res.status(200).json(result);
});

// ─── Pest Control ─────────────────────────────────────────────────────────
export const recordPestControl = asyncHandler(async (req, res) => {
  const result = await stationCleaningService.recordPestControl(req.body, req.user);
  res.status(201).json({ success: true, message: 'Pest control record created', uid: result.uid, data: result.data });
});

export const listPestControl = asyncHandler(async (req, res) => {
  const result = await stationCleaningService.listPestControl(req.params.stationId, req.query, req.user);
  res.status(200).json({ success: true, count: result.length, data: result });
});

export const listAllPestControl = asyncHandler(async (req, res) => {
  const result = await stationCleaningService.listAllPestControl(req.query);
  res.status(200).json({ success: true, count: result.length, data: result });
});

export const reviewPestControl = asyncHandler(async (req, res) => {
  const result = await stationCleaningService.reviewPestControl(req.params.uid, req.body, req.user);
  res.status(200).json({ success: true, message: `Pest control record ${result.status.toLowerCase()}` });
});

export const pestControlReport = asyncHandler(async (req, res) => {
  const result = await stationCleaningService.pestControlReport(req.query);
  res.status(200).json({ success: true, ...result });
});

// ─── Machine Deployment ────────────────────────────────────────────────────
export const deployMachine = asyncHandler(async (req, res) => {
  const result = await stationCleaningService.deployMachine(req.body, req.user);
  res.status(201).json({ success: true, message: 'Machine deployed', uid: result.uid, data: result.data });
});

export const listMachines = asyncHandler(async (req, res) => {
  const result = await stationCleaningService.listMachines(req.query, req.user);
  res.status(200).json({ success: true, count: result.length, data: result });
});

export const returnMachine = asyncHandler(async (req, res) => {
  const result = await stationCleaningService.returnMachine(req.params.uid, req.body, req.user);
  res.status(200).json({ success: true, message: 'Machine returned' });
});

export const maintenanceMachine = asyncHandler(async (req, res) => {
  const result = await stationCleaningService.maintenanceMachine(req.params.uid, req.body, req.user);
  res.status(200).json({ success: true, message: 'Machine marked for maintenance' });
});

export const machineReport = asyncHandler(async (req, res) => {
  const result = await stationCleaningService.machineReport(req.query);
  res.status(200).json({ success: true, ...result });
});

// ─── Garbage Disposal ──────────────────────────────────────────────────────
export const recordGarbageDisposal = asyncHandler(async (req, res) => {
  const result = await stationCleaningService.recordGarbageDisposal(req.body, req.user);
  res.status(201).json({ success: true, message: 'Garbage disposal recorded', uid: result.uid, data: result.data });
});

export const listGarbageRecords = asyncHandler(async (req, res) => {
  const result = await stationCleaningService.listGarbageRecords(req.query, req.user);
  res.status(200).json({ success: true, count: result.length, data: result });
});

export const garbageReport = asyncHandler(async (req, res) => {
  const result = await stationCleaningService.garbageReport(req.query);
  res.status(200).json({ success: true, ...result });
});

// ─── Station Cleaning Reports & Dashboards ────────────────────────────────
export const getWorkerDashboard = asyncHandler(async (req, res) => {
  res.json(await stationCleaningService.getWorkerDashboard(req.params.workerId, req.query));
});

export const getSupervisorDashboard = asyncHandler(async (req, res) => {
  res.json(await stationCleaningService.getSupervisorDashboard(req.params.supervisorId, req.query));
});

export const generateDailyReport = asyncHandler(async (req, res) => {
  const { stationId } = req.params;
  res.json(await stationCleaningService.generateDailyReport(stationId, req.query));
});

export const generateWeeklyReport = asyncHandler(async (req, res) => {
  const { stationId } = req.params;
  res.json(await stationCleaningService.generateWeeklyReport(stationId, req.query));
});

export const generateMonthlyReport = asyncHandler(async (req, res) => {
  const { stationId } = req.params;
  res.json(await stationCleaningService.generateMonthlyReport(stationId, req.query));
});

export const getScoreTrend = asyncHandler(async (req, res) => {
  const { stationId } = req.params;
  res.json(await stationCleaningService.getScoreTrend(stationId, req.query));
});

// ─── Area-Task Frequency (SRS #2) ──────────────────────────────────────────
export const createAreaTaskFrequency = asyncHandler(async (req, res) => {
  res.status(201).json(await stationCleaningService.createAreaTaskFrequency(req.body));
});

export const updateAreaTaskFrequency = asyncHandler(async (req, res) => {
  res.json(await stationCleaningService.updateAreaTaskFrequency(req.params.uid, req.body));
});

export const deleteAreaTaskFrequency = asyncHandler(async (req, res) => {
  res.json(await stationCleaningService.deleteAreaTaskFrequency(req.params.uid));
});

export const listAreaTaskFrequencies = asyncHandler(async (req, res) => {
  res.json(await stationCleaningService.listAreaTaskFrequencies(req.query));
});
