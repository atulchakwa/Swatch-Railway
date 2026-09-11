import { stationService } from '../services/stationService.js';
import { asyncHandler } from '../middleware/errorHandler.js';

export const list = asyncHandler(async (req, res) => {
  const result = await stationService.getStations(req.query, req.user);
  res.status(200).json(result);
});

export const getById = asyncHandler(async (req, res) => {
  const result = await stationService.getStationById(req.params.stationId);
  res.status(200).json(result);
});

export const create = asyncHandler(async (req, res) => {
  const result = await stationService.createStation(req.user, req.body);
  res.status(201).json(result);
});

export const update = asyncHandler(async (req, res) => {
  const result = await stationService.updateStation(req.params.stationId, req.user, req.body);
  res.status(200).json(result);
});

export const remove = asyncHandler(async (req, res) => {
  await stationService.deleteStation(req.params.stationId);
  res.status(200).json({ message: 'Station deleted successfully' });
});

export const search = asyncHandler(async (req, res) => {
  const result = await stationService.searchStations(req.query.q);
  res.status(200).json(result);
});

export const getByDivision = asyncHandler(async (req, res) => {
  const result = await stationService.getStationsByDivision(req.params.division);
  res.status(200).json(result);
});
