import { passengerFeedbackService } from '../services/passengerFeedbackService.js';
import { asyncHandler } from '../middleware/errorHandler.js';

export const create = asyncHandler(async (req, res) => {
  const result = await passengerFeedbackService.createFeedback(req.user, req.body);
  res.status(201).json(result);
});

export const list = asyncHandler(async (req, res) => {
  res.json(await passengerFeedbackService.listFeedback(req.query));
});

export const getById = asyncHandler(async (req, res) => {
  res.json(await passengerFeedbackService.getFeedbackById(req.params.uid));
});

export const update = asyncHandler(async (req, res) => {
  res.json(await passengerFeedbackService.updateFeedback(req.params.uid, req.user, req.body));
});

export const remove = asyncHandler(async (req, res) => {
  res.json(await passengerFeedbackService.deleteFeedback(req.params.uid));
});

export const summary = asyncHandler(async (req, res) => {
  res.json(await passengerFeedbackService.getFeedbackSummary(req.params.stationId, req.query));
});