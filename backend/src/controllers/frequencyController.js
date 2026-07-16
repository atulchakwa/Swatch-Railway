import { frequencyService } from '../services/frequencyService.js';
import { asyncHandler } from '../middleware/errorHandler.js';

export const create = asyncHandler(async (req, res) => {
  const result = await frequencyService.createFrequency(req.user, req.body);
  res.status(201).json(result);
});

export const list = asyncHandler(async (req, res) => {
  const result = await frequencyService.getFrequencies(req.query);
  res.status(200).json(result);
});

export const getById = asyncHandler(async (req, res) => {
  const result = await frequencyService.getFrequencyById(req.params.uid);
  res.status(200).json(result);
});

export const update = asyncHandler(async (req, res) => {
  const result = await frequencyService.updateFrequency(req.params.uid, req.body);
  res.status(200).json(result);
});

export const remove = asyncHandler(async (req, res) => {
  await frequencyService.deleteFrequency(req.params.uid);
  res.status(200).json({ message: 'Frequency deleted successfully' });
});

// Frequency calculation and task generation endpoints
export const calculateFrequency = asyncHandler(async (req, res) => {
  const result = await frequencyService.calculateFrequency(req.body);
  res.status(200).json(result);
});

export const getAreaTasks = asyncHandler(async (req, res) => {
  const result = await frequencyService.getAreaTasks(req.params.areaId, req.query);
  res.status(200).json(result);
});

export const getTaskSystemReport = asyncHandler(async (req, res) => {
  const result = await frequencyService.getTaskSystemReport(req.query);
  res.status(200).json(result);
});

export const calculateTasksFromFrequency = asyncHandler(async (req, res) => {
  const { frequencyId, areaId, platformId, stationId, startDate, endDate } = req.body;
  const result = await frequencyService.calculateFrequency({
    frequencyId,
    areaId,
    platformId,
    stationId,
    startDate,
    endDate
  });
  res.status(200).json(result);
});

export const generateTasksFromFrequency = asyncHandler(async (req, res) => {
  const { frequencyId, areaId, platformId, stationId, startDate, endDate, assignedTo } = req.body;
  const result = await frequencyService.generateTasksFromFrequency(frequencyId, {
    areaId,
    platformId,
    stationId,
    startDate,
    endDate,
    assignedTo
  });
  res.status(201).json(result);
});

export const getFrequencySchedule = asyncHandler(async (req, res) => {
  const { frequencyId, areaId, platformId, stationId } = req.query;
  const result = await frequencyService.getFrequencySchedule(req.user, {
    frequencyId,
    areaId,
    platformId,
    stationId
  });
  res.status(200).json(result);
});
