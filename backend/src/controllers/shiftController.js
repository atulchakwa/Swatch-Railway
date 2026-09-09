import { shiftService } from '../services/shiftService.js';
import { asyncHandler } from '../middleware/errorHandler.js';

export const create = asyncHandler(async (req, res) => {
  const result = await shiftService.createShift(req.user, req.body);
  res.status(201).json(result);
});

export const list = asyncHandler(async (req, res) => {
  const result = await shiftService.getShifts(req.query);
  res.status(200).json(result);
});

export const getById = asyncHandler(async (req, res) => {
  const result = await shiftService.getShiftById(req.params.uid);
  res.status(200).json(result);
});

export const update = asyncHandler(async (req, res) => {
  const result = await shiftService.updateShift(req.params.uid, req.body);
  res.status(200).json(result);
});

export const remove = asyncHandler(async (req, res) => {
  await shiftService.deleteShift(req.params.uid);
  res.status(200).json({ message: 'Shift deleted successfully' });
});

export const assignSupervisor = asyncHandler(async (req, res) => {
  const result = await shiftService.assignSupervisor(req.params.uid, req.body.supervisorId);
  res.status(200).json(result);
});

export const assignWorker = asyncHandler(async (req, res) => {
  const result = await shiftService.assignWorker(req.params.uid, req.body.workerId);
  res.status(200).json(result);
});

export const removeAssignment = asyncHandler(async (req, res) => {
  const result = await shiftService.removeAssignment(req.params.uid, req.params.userId);
  res.status(200).json(result);
});

export const reassignWorkerShift = asyncHandler(async (req, res) => {
  const result = await shiftService.reassignWorkerShift(req.body, req.user);
  res.status(200).json(result);
});
