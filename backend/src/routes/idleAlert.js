import { Router } from 'express';
import { verifyToken } from '../middleware/auth.js';
import { requirePermission } from '../middleware/authorization.js';
import { PERMISSIONS } from '../permissions/roles.js';
import * as idleAlertController from '../controllers/idleAlertController.js';

const router = Router();

router.get('/api/idle-alerts/config', verifyToken, requirePermission(PERMISSIONS.MANAGE_STATIONS), idleAlertController.getConfig);
router.post('/api/idle-alerts/config', verifyToken, requirePermission(PERMISSIONS.MANAGE_STATIONS), idleAlertController.setConfig);
router.get('/api/idle-alerts', verifyToken, requirePermission(PERMISSIONS.VIEW_STATIONS), idleAlertController.listAlerts);
router.post('/api/idle-alerts/:uid/resolve', verifyToken, requirePermission(PERMISSIONS.MANAGE_STATIONS), idleAlertController.resolveAlert);
router.post('/api/idle-alerts/check-all', verifyToken, requirePermission(PERMISSIONS.MANAGE_STATIONS), idleAlertController.checkAll);
router.post('/api/idle-alerts/activity', verifyToken, idleAlertController.recordActivity);

export default router;
