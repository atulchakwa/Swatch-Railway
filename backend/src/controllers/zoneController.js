import { zoneService } from '../services/zoneService.js';
import { asyncHandler } from '../middleware/errorHandler.js';

export const createZone = asyncHandler(async (req, res) => {
  const result = await zoneService.createZone(req.body);
  res.status(201).json(result);
});

export const listZones = asyncHandler(async (req, res) => {
  const result = await zoneService.getZones(req.query);
  res.status(200).json(result);
});

export const getZone = asyncHandler(async (req, res) => {
  const result = await zoneService.getZoneById(req.params.id);
  res.status(200).json(result);
});

export const updateZone = asyncHandler(async (req, res) => {
  const result = await zoneService.updateZone(req.params.id, req.body);
  res.status(200).json(result);
});

export const deleteZone = asyncHandler(async (req, res) => {
  const result = await zoneService.deleteZone(req.params.id);
  res.status(200).json(result);
});
