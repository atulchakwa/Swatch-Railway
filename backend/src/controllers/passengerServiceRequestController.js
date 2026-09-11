import PassengerRequestService from '../services/passengerRequestService.js';
import { asyncHandler } from '../middleware/errorHandler.js';
import { verifyToken } from '../middleware/auth.js';
import { requirePermission } from '../middleware/authorization.js';
import { PERMISSIONS } from '../permissions/roles.js';
import { db } from '../database/index.js';

export const createFromTransmitter = asyncHandler(async (req, res) => {
  const deviceMac = req.headers['x-device-mac'];
  if (!deviceMac) {
    return res.status(400).json({ success: false, message: 'x-device-mac header required' });
  }

  const result = await PassengerRequestService.createFromTransmitter(req.body, deviceMac);
  res.status(201).json({ success: true, ...result });
});

export const acceptRequest = asyncHandler(async (req, res) => {
  const result = await PassengerRequestService.acceptRequest(req.params.requestId, req.user.uid);
  res.json({ success: true, ...result });
});

export const rejectRequest = asyncHandler(async (req, res) => {
  const { reason } = req.body;
  if (!reason) {
    return res.status(400).json({ success: false, message: 'Rejection reason required' });
  }
  const result = await PassengerRequestService.rejectRequest(req.params.requestId, req.user.uid, reason);
  res.json({ success: true, ...result });
});

export const handleDeviceEvent = asyncHandler(async (req, res) => {
  const deviceMac = req.headers['x-device-mac'];
  if (!deviceMac) {
    return res.status(400).json({ success: false, message: 'x-device-mac header required' });
  }
  
  const { requestId, buttonPressed } = req.body;
  if (!requestId || !buttonPressed) {
    return res.status(400).json({ success: false, message: 'requestId, buttonPressed required' });
  }
  
  const result = await PassengerRequestService.handleDeviceEvent(req.params.requestId, {
    deviceMac,
    buttonPressed: req.body.buttonPressed
  });
  res.json({ success: true, ...result });
});

export const getWorkerRequests = asyncHandler(async (req, res) => {
  const { status, limit = 50, cursor } = req.query;
  const result = await PassengerRequestService.getWorkerRequests(req.user.uid, { status, limit, cursor });
  res.json({ success: true, ...result });
});

export const getAllRequests = asyncHandler(async (req, res) => {
  const { status, trainNumber, startDate, endDate, limit = 50, cursor } = req.query;
  const result = await PassengerRequestService.getAllRequests({ status, trainNumber, startDate, endDate, limit, cursor });
  res.json({ success: true, ...result });
});

export const getTimingAnalytics = asyncHandler(async (req, res) => {
  const { trainNumber, startDate, endDate } = req.query;
  const result = await PassengerRequestService.getTimingAnalytics({ trainNumber, startDate, endDate });
  res.json({ success: true, ...result });
});

export const getRequestById = asyncHandler(async (req, res) => {
  const result = await PassengerRequestService.getById(req.params.requestId);
  res.json({ success: true, ...result });
});

export default {
  createFromTransmitter,
  acceptRequest,
  rejectRequest,
  handleDeviceEvent,
  getWorkerRequests,
  getAllRequests,
  getTimingAnalytics,
  getRequestById
};