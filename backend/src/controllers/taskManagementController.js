import { taskManagementService } from '../services/taskManagementService.js';
import { asyncHandler } from '../middleware/errorHandler.js';

export const generateTasks = asyncHandler(async (req, res) => {
  const result = await taskManagementService.generateFrequencyBasedTasks(req.body.date);
  res.status(201).json(result);
});

export const list = asyncHandler(async (req, res) => {
  const result = await taskManagementService.getTasks(req.query, req.user);
  res.status(200).json(result);
});

export const getById = asyncHandler(async (req, res) => {
  const result = await taskManagementService.getTaskById(req.params.id);
  res.status(200).json(result);
});

export const updateStatus = asyncHandler(async (req, res) => {
  const result = await taskManagementService.updateTaskStatus(req.params.id, req.body.status, req.user);
  res.status(200).json(result);
});

export const assign = asyncHandler(async (req, res) => {
  const result = await taskManagementService.assignTask(req.params.id, req.body.workerId, req.body.workerName, req.user);
  res.status(200).json(result);
});

export const start = asyncHandler(async (req, res) => {
  const result = await taskManagementService.startTask(req.params.id, req.body, req.user);
  res.status(200).json(result);
});

export const complete = asyncHandler(async (req, res) => {
  const result = await taskManagementService.completeTask(req.params.id, req.body, req.user);
  res.status(200).json(result);
});

export const resubmit = asyncHandler(async (req, res) => {
  const result = await taskManagementService.resubmitTask(req.params.id, req.body, req.user);
  res.status(200).json(result);
});

export const approve = asyncHandler(async (req, res) => {
  const result = await taskManagementService.approveTask(req.params.id, req.body, req.user);
  res.status(200).json(result);
});

export const reject = asyncHandler(async (req, res) => {
  const result = await taskManagementService.rejectTask(req.params.id, req.body, req.user);
  res.status(200).json(result);
});

export const getWorkerTasks = asyncHandler(async (req, res) => {
  const result = await taskManagementService.getWorkerTasks(req.params.workerId, req.query.date);
  res.status(200).json(result);
});

export const getAreaTasks = asyncHandler(async (req, res) => {
  const result = await taskManagementService.getAreaTasks(req.params.areaId, req.query.date, req.query.status);
  res.status(200).json(result);
});

export const getSupervisorTasks = asyncHandler(async (req, res) => {
  const result = await taskManagementService.getSupervisorTasks(req.params.supervisorId, req.query.date, req.query.status);
  res.status(200).json(result);
});

export const getPendingReview = asyncHandler(async (req, res) => {
  const result = await taskManagementService.getPendingReviewTasks(req.query.supervisorId, req.query.stationId);
  res.status(200).json(result);
});

export const getDailyTasks = asyncHandler(async (req, res) => {
  const result = await taskManagementService.getDailyTasks(req.params.date);
  res.status(200).json(result);
});

export const bulkGenerate = asyncHandler(async (req, res) => {
  const result = await taskManagementService.bulkGenerate(req.body, req.user);
  res.status(201).json(result);
});

export const generateRange = asyncHandler(async (req, res) => {
  const result = await taskManagementService.generateTasksForDateRange(req.body, req.user);
  res.status(201).json(result);
});
