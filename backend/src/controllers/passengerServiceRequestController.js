import { passengerRequestService } from '../services/passengerRequestService.js';
import { asyncHandler } from '../middleware/errorHandler.js';
import { verifyToken } from '../middleware/auth.js';
import { requirePermission } from '../middleware/authorization.js';
import { PERMISSIONS } from '../permissions/roles.js';

export const createFromTransmitter = asyncHandler(async (req, res) => {
  const { 'x-transmitter-key': transmitterKey } = req.headers;
  
  if (!transmitterKey) {
    return res.status(401).json({ success: false, message: 'Transmitter API key required' });
  }
  
  // Verify transmitter API key
  const { db } = require('../database/index.js');
  const transmitterDoc = await db.collection('transmitter_devices')
    .where('apiKey', '==', req.headers['x-transmitter-key'])
    .where('isActive', '==', true)
    .limit(1)
    .get();
  
  if (transmitterDoc.empty) {
    return res.status(401).json({ success: false, message: 'Invalid transmitter API key' });
  }
  
  req.transmitter = transmitterDoc.docs[0].data();
  req.transmitterId = transmitterDoc.docs[0].id;

  const result = await passengerRequestService.createFromTransmitter(req.body);
  res.status(201).json({ success: true, ...result });
});

export const acceptRequest = asyncHandler(async (req, res) => {
  const result = await passengerRequestService.acceptRequest(req.params.requestId, req.user.uid);
  res.json({ success: true, ...result });
});

export const rejectRequest = asyncHandler(async (req, res) => {
  const { reason } = req.body;
  if (!reason) {
    return res.status(400).json({ success: false, message: 'Rejection reason required' });
  }
  const result = await passengerRequestService.rejectRequest(req.params.requestId, req.user.uid, reason);
  res.json({ success: true, ...result });
});

export const handleDeviceEvent = asyncHandler(async (req, res) => {
  const transmitterId = req.headers['x-transmitter-id'];
  if (!transmitterId) {
    return res.status(400).json({ success: false, message: 'Transmitter ID required in header' });
  }
  
  const { requestId, buttonPressed, pressedBy, pressedAt } = req.body;
  if (!requestId || !buttonPressed || !pressedBy) {
    return res.status(400).json({ success: false, message: 'requestId, buttonPressed, pressedBy required' });
  }
  
  const result = await passengerRequestService.handleDeviceEvent(req.params.requestId, {
    transmitterId: req.headers['x-transmitter-id'],
    buttonPressed: req.body.buttonPressed,
    pressedBy: req.body.pressedBy,
    pressedAt: req.body.pressedAt
  });
  res.json({ success: true, ...result });
});

export const getWorkerRequests = asyncHandler(async (req, res) => {
  const { status, limit = 50, cursor } = req.query;
  const result = await passengerRequestService.getWorkerRequests(req.user.uid, { status, limit, cursor });
  res.json({ success: true, ...result });
});

export const getAllRequests = asyncHandler(async (req, res) => {
  const { status, trainNumber, startDate, endDate, limit = 50, cursor } = req.query;
  const result = await passengerRequestService.getAllRequests({ status, trainNumber, startDate, endDate, limit, cursor });
  res.json({ success: true, ...result });
});

export const getTimingAnalytics = asyncHandler(async (req, res) => {
  const { trainNumber, startDate, endDate } = req.query;
  const result = await passengerRequestService.getTimingAnalytics({ trainNumber, startDate, endDate });
  res.json({ success: true, ...result });
});

export const getRequestById = asyncHandler(async (req, res) => {
  const result = await passengerRequestService.getById(req.params.requestId);
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