import { stationFeedbackService } from '../services/stationFeedbackService.js';
import { asyncHandler } from '../middleware/errorHandler.js';

export const sendOtp = asyncHandler(async (req, res) => res.json(await stationFeedbackService.sendOtp(req.body)));
export const verifyOtp = asyncHandler(async (req, res) => res.json(await stationFeedbackService.verifyOtp(req.body)));
export const submit = asyncHandler(async (req, res) => res.status(201).json(await stationFeedbackService.submitFeedback(req.body)));
export const list = asyncHandler(async (req, res) => res.json(await stationFeedbackService.listFeedback(req.query)));
export const summary = asyncHandler(async (req, res) => res.json(await stationFeedbackService.getFeedbackSummary(req.params.stationId, req.query)));
export const qrCode = asyncHandler(async (req, res) => res.json(await stationFeedbackService.getStationQr(req.params.stationId, req)));
export const stationBrief = asyncHandler(async (req, res) => res.json(await stationFeedbackService.getStationBrief(req.params.stationId)));
export const moderate = asyncHandler(async (req, res) => res.json(await stationFeedbackService.moderateFeedback(req.params.uid, req.user, req.body)));
