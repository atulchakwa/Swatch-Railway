import { idleAlertService } from '../services/idleAlertService.js';
import { asyncHandler } from '../middleware/errorHandler.js';

export const getConfig = asyncHandler(async (req, res) => res.json(await idleAlertService.getIdleConfig(req.query.stationId)));
export const setConfig = asyncHandler(async (req, res) => res.json(await idleAlertService.setIdleConfig(req.body.stationId, req.body.thresholdMinutes)));
export const listAlerts = asyncHandler(async (req, res) => res.json(await idleAlertService.getAlerts(req.query)));
export const resolveAlert = asyncHandler(async (req, res) => res.json(await idleAlertService.resolveAlert(req.params.uid, req.user)));
export const checkAll = asyncHandler(async (req, res) => res.json(await idleAlertService.checkAllIdleAlerts()));
export const recordActivity = asyncHandler(async (req, res) => res.json(await idleAlertService.recordActivity(req.user.uid, req.body.stationId, req.body.activityType, req.body.details)));
