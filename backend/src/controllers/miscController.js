import { miscService } from '../services/miscService.js';
import { asyncHandler } from '../middleware/errorHandler.js';

export const health = asyncHandler(async (req, res) => {
  res.status(200).json({ status: 'ok', timestamp: new Date().toISOString() });
});

export const getDivisions = asyncHandler(async (req, res) => {
  const result = await miscService.getDivisions();
  res.status(200).json(result);
});

export const getDepots = asyncHandler(async (req, res) => {
  const result = await miscService.getDepots(req.query);
  res.status(200).json(result);
});

export const lookupPincode = asyncHandler(async (req, res) => {
  const result = await miscService.lookupPincode(req.query.pincode);
  res.status(200).json(result);
});

export const getEnumValues = asyncHandler(async (req, res) => {
  const result = await miscService.getEnumValues(req.params.enumName);
  res.status(200).json(result);
});
