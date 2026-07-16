import { Router } from 'express';
import { verifyToken } from '../middleware/auth.js';
import { requirePermission } from '../middleware/authorization.js';
import { PERMISSIONS } from '../permissions/roles.js';
import * as zoneController from '../controllers/zoneController.js';

const router = Router();

router.post('/api/zones', verifyToken, requirePermission(PERMISSIONS.MANAGE_STATIONS), zoneController.createZone);
router.get('/api/zones', verifyToken, requirePermission(PERMISSIONS.VIEW_STATIONS), zoneController.listZones);
router.get('/api/zones/:id', verifyToken, requirePermission(PERMISSIONS.VIEW_STATIONS), zoneController.getZone);
router.put('/api/zones/:id', verifyToken, requirePermission(PERMISSIONS.MANAGE_STATIONS), zoneController.updateZone);
router.delete('/api/zones/:id', verifyToken, requirePermission(PERMISSIONS.MANAGE_STATIONS), zoneController.deleteZone);

export default router;
