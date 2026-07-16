import { geofenceService } from '../services/geofenceService.js';
import { asyncHandler } from '../middleware/errorHandler.js';

export const create = asyncHandler(async (req, res) => res.status(201).json(await geofenceService.createGeofence({ ...req.body, createdBy: req.user.uid })));
export const list = asyncHandler(async (req, res) => res.json(await geofenceService.getGeofences(req.query)));
export const getById = asyncHandler(async (req, res) => res.json(await geofenceService.getGeofenceById(req.params.uid)));
export const update = asyncHandler(async (req, res) => res.json(await geofenceService.updateGeofence(req.params.uid, req.body)));
export const remove = asyncHandler(async (req, res) => res.json(await geofenceService.deleteGeofence(req.params.uid)));
export const checkLocation = asyncHandler(async (req, res) => res.json(await geofenceService.isWithinGeofence(req.body.stationId, req.body.latitude, req.body.longitude)));
export const listAlerts = asyncHandler(async (req, res) => res.json(await geofenceService.getAlerts(req.query)));
export const resolveAlert = asyncHandler(async (req, res) => res.json(await geofenceService.resolveAlert(req.params.uid, req.user)));
