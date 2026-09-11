import { areaService } from '../services/areaService.js';
import { asyncHandler } from '../middleware/errorHandler.js';

export const create = asyncHandler(async (req, res) => {
  const result = await areaService.createArea(req.user, req.body);
  res.status(201).json(result);
});

export const configure = asyncHandler(async (req, res) => {
  const result = await areaService.configureArea(req.user, req.body);
  res.status(200).json(result);
});

export const list = asyncHandler(async (req, res) => {
  const result = await areaService.getAreas(req.query);
  res.status(200).json(result);
});

export const getSummary = asyncHandler(async (req, res) => {
  const result = await areaService.getAreaSummary(req.params.stationId);
  res.status(200).json(result);
});

export const getById = asyncHandler(async (req, res) => {
  const result = await areaService.getAreaById(req.params.uid);
  res.status(200).json(result);
});

export const update = asyncHandler(async (req, res) => {
  const result = await areaService.updateArea(req.params.uid, req.body);
  res.status(200).json(result);
});

export const remove = asyncHandler(async (req, res) => {
  await areaService.deleteArea(req.params.uid);
  res.status(200).json({ message: 'Area deleted successfully' });
});

export const getByStation = asyncHandler(async (req, res) => {
  const result = await areaService.getAreasByStation(req.params.stationId, req.query.section);
  res.status(200).json(result);
});

export const getByPlatform = asyncHandler(async (req, res) => {
  const result = await areaService.getAreasByPlatform(req.params.platformId);
  res.status(200).json(result);
});

export const getByHierarchy = asyncHandler(async (req, res) => {
  const result = await areaService.getAreasByHierarchy(req.query);
  res.status(200).json(result);
});

// Area-specific endpoints
export const getMasterDashboard = asyncHandler(async (req, res) => {
  const result = await areaService.getMasterDashboard(req.user);
  res.status(200).json(result);
});

export const getAreaWorkers = asyncHandler(async (req, res) => {
  const result = await areaService.getAreaWorkers(req.params.uid);
  res.status(200).json(result);
});

export const getAreaTasks = asyncHandler(async (req, res) => {
  const result = await areaService.getAreaTasks(req.params.uid, req.query);
  res.status(200).json(result);
});

export const getAreaReports = asyncHandler(async (req, res) => {
  const result = await areaService.getAreaReports(req.params.uid, req.query);
  res.status(200).json(result);
});

export const assignWorkerToArea = asyncHandler(async (req, res) => {
  const result = await areaService.assignWorkerToArea(req.params.uid, req.body);
  res.status(200).json(result);
});

export const unassignWorkerFromArea = asyncHandler(async (req, res) => {
  const result = await areaService.unassignWorkerFromArea(req.params.uid, req.params.workerId);
  res.status(200).json(result);
});

export const assignPlatformToArea = asyncHandler(async (req, res) => {
  const result = await areaService.assignPlatformToArea(req.params.uid, req.body);
  res.status(200).json(result);
});

export const unassignPlatformFromArea = asyncHandler(async (req, res) => {
  const result = await areaService.unassignPlatformFromArea(req.params.uid, req.params.platformId);
  res.status(200).json(result);
});

export const generateTasksFromFrequency = asyncHandler(async (req, res) => {
  const result = await areaService.generateTasksFromFrequency(req.params.uid, req.body, req.user);
  res.status(200).json(result);
});

// Platform-based area access
export const getAreasByPlatform = asyncHandler(async (req, res) => {
  const result = await areaService.getAreasByPlatform(req.params.platformId);
  res.status(200).json(result);
});

// Master access endpoints
export const getAreasByStation = asyncHandler(async (req, res) => {
  const result = await areaService.getAreasByStation(req.params.stationId);
  res.status(200).json(result);
});

export const getAreasByCompany = asyncHandler(async (req, res) => {
  const result = await areaService.getAreasByCompany(req.params.companyId);
  res.status(200).json(result);
});
