import { asyncHandler } from '../middleware/errorHandler.js';
import { stationCleaningAttendanceService } from '../services/stationCleaningAttendanceService.js';

export const markAttendance = asyncHandler(async (req, res) => {
  const result = await stationCleaningAttendanceService.markAttendance(req.user, req.body);
  res.status(200).json(result);
});

export const getAttendanceStatus = asyncHandler(async (req, res) => {
  const { runInstanceId, workerId } = req.query;
  const uid = workerId || req.user.uid;
  const result = await stationCleaningAttendanceService.getAttendanceStatus(runInstanceId, uid);
  res.json(result);
});

export const listAttendance = asyncHandler(async (req, res) => {
  const result = await stationCleaningAttendanceService.listAttendance({
    ...req.query,
    callerId: req.user.uid,
    role: req.user.role
  });
  res.json(result);
});

export const reportAttendanceIssue = asyncHandler(async (req, res) => {
  const result = await stationCleaningAttendanceService.reportAttendanceIssue(req.user, req.body);
  res.status(201).json(result);
});

export const getAttendanceExceptions = asyncHandler(async (req, res) => {
  const result = await stationCleaningAttendanceService.getAttendanceExceptions(req.query);
  res.json(result);
});

export const takeAttendanceExceptionAction = asyncHandler(async (req, res) => {
  const result = await stationCleaningAttendanceService.takeActionOnException(req.body);
  res.json(result);
});
