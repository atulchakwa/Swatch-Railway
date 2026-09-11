import { platformService } from '../services/platformService.js';
import { asyncHandler } from '../middleware/errorHandler.js';

export const create = asyncHandler(async (req, res) => {
  const result = await platformService.createPlatform(req.user, req.body);
  res.status(201).json(result);
});

export const list = asyncHandler(async (req, res) => {
  const result = await platformService.getPlatforms(req.query);
  res.status(200).json(result);
});

export const getById = asyncHandler(async (req, res) => {
  const result = await platformService.getPlatformById(req.params.uid);
  res.status(200).json(result);
});

export const update = asyncHandler(async (req, res) => {
  const result = await platformService.updatePlatform(req.params.uid, req.body);
  res.status(200).json(result);
});

export const remove = asyncHandler(async (req, res) => {
  await platformService.deletePlatform(req.params.uid);
  res.status(200).json({ message: 'Platform deleted successfully' });
});

export const getByStation = asyncHandler(async (req, res) => {
  const result = await platformService.getPlatformsByStation(req.params.stationId);
  res.status(200).json(result);
});

// Platform-specific endpoints
export const getMasterDashboard = asyncHandler(async (req, res) => {
  const result = await platformService.getMasterDashboard(req.user);
  res.status(200).json(result);
});

export const getPlatformAreas = asyncHandler(async (req, res) => {
  const result = await platformService.getPlatformAreas(req.params.uid);
  res.status(200).json(result);
});

export const getPlatformWorkers = asyncHandler(async (req, res) => {
  const result = await platformService.getPlatformWorkers(req.params.uid);
  res.status(200).json(result);
});

export const getPlatformTasks = asyncHandler(async (req, res) => {
  const result = await platformService.getPlatformTasks(req.params.uid, req.query);
  res.status(200).json(result);
});

export const getPlatformReports = asyncHandler(async (req, res) => {
  const result = await platformService.getPlatformReports(req.params.uid, req.query);
  res.status(200).json(result);
});

export const assignWorkerToPlatform = asyncHandler(async (req, res) => {
  const result = await platformService.assignWorkerToPlatform(req.params.uid, req.body);
  res.status(200).json(result);
});

export const unassignWorkerFromPlatform = asyncHandler(async (req, res) => {
  const result = await platformService.unassignWorkerFromPlatform(req.params.uid, req.params.workerId);
  res.status(200).json(result);
});

export const assignAreaToPlatform = asyncHandler(async (req, res) => {
  const result = await platformService.assignAreaToPlatform(req.params.uid, req.body);
  res.status(200).json(result);
});

export const unassignAreaFromPlatform = asyncHandler(async (req, res) => {
  const result = await platformService.unassignAreaFromPlatform(req.params.uid, req.params.areaId);
  res.status(200).json(result);
});

// Generate tasks from frequency
export const generateTasksFromFrequency = asyncHandler(async (req, res) => {
  const result = await platformService.generateTasksFromFrequency(req.params.uid, req.body, req.user);
  res.status(200).json(result);
});

// Zone master can also access platform endpoints
export const getZonePlatforms = asyncHandler(async (req, res) => {
  const result = await platformService.getZonePlatforms(req.user);
  res.status(200).json(result);
});

export const getPlatformsByZone = asyncHandler(async (req, res) => {
  const result = await platformService.getPlatformsByZone(req.params.zoneId);
  res.status(200).json(result);
});

export const getPlatformsByCompany = asyncHandler(async (req, res) => {
  const result = await platformService.getPlatformsByCompany(req.params.companyId);
  res.status(200).json(result);
});
