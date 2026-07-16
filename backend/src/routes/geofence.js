import { Router } from 'express';
import { verifyToken } from '../middleware/auth.js';
import { requirePermission } from '../middleware/authorization.js';
import { PERMISSIONS } from '../permissions/roles.js';
import * as geofenceController from '../controllers/geofenceController.js';

const router = Router();

router.post('/api/geofences', verifyToken, requirePermission(PERMISSIONS.MANAGE_GEOFENCES), geofenceController.create);
router.get('/api/geofences', verifyToken, requirePermission(PERMISSIONS.VIEW_GEOFENCES), geofenceController.list);
router.get('/api/geofences/:uid', verifyToken, requirePermission(PERMISSIONS.VIEW_GEOFENCES), geofenceController.getById);
router.put('/api/geofences/:uid', verifyToken, requirePermission(PERMISSIONS.MANAGE_GEOFENCES), geofenceController.update);
router.delete('/api/geofences/:uid', verifyToken, requirePermission(PERMISSIONS.MANAGE_GEOFENCES), geofenceController.remove);
router.post('/api/geofences/check', verifyToken, geofenceController.checkLocation);
router.get('/api/geofence-alerts', verifyToken, requirePermission(PERMISSIONS.VIEW_GEOFENCES), geofenceController.listAlerts);
router.post('/api/geofence-alerts/:uid/resolve', verifyToken, requirePermission(PERMISSIONS.MANAGE_GEOFENCES), geofenceController.resolveAlert);

export default router;
