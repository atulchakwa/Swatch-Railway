import { Router } from 'express';
import { verifyToken } from '../middleware/auth.js';
import { requirePermission, requireStationAccess, requirePlatformAccess, requireAreaAccess } from '../middleware/authorization.js';
import { PERMISSIONS } from '../permissions/roles.js';
import * as areaAssignmentController from '../controllers/areaAssignmentController.js';

const router = Router();

router.post('/api/area-assignments', verifyToken, requirePermission(PERMISSIONS.MANAGE_AREA_ASSIGNMENTS), requireStationAccess, requirePlatformAccess, requireAreaAccess, areaAssignmentController.create);
router.get('/api/area-assignments', verifyToken, requirePermission(PERMISSIONS.VIEW_AREA_ASSIGNMENTS), requireStationAccess, requirePlatformAccess, requireAreaAccess, areaAssignmentController.list);
router.get('/api/area-assignments/area/:areaId', verifyToken, requirePermission(PERMISSIONS.VIEW_AREA_ASSIGNMENTS), requireStationAccess, requirePlatformAccess, requireAreaAccess, areaAssignmentController.getAreaWorkers);
router.get('/api/area-assignments/worker/:workerId', verifyToken, requirePermission(PERMISSIONS.VIEW_AREA_ASSIGNMENTS), requireStationAccess, requirePlatformAccess, requireAreaAccess, areaAssignmentController.getWorkerAreas);
router.put('/api/area-assignments/:id', verifyToken, requirePermission(PERMISSIONS.MANAGE_AREA_ASSIGNMENTS), requireStationAccess, requirePlatformAccess, requireAreaAccess, areaAssignmentController.update);
router.put('/api/area-assignments/:id/deactivate', verifyToken, requirePermission(PERMISSIONS.MANAGE_AREA_ASSIGNMENTS), requireStationAccess, requirePlatformAccess, requireAreaAccess, areaAssignmentController.remove);
router.delete('/api/area-assignments/:id', verifyToken, requirePermission(PERMISSIONS.MANAGE_AREA_ASSIGNMENTS), requireStationAccess, requirePlatformAccess, requireAreaAccess, areaAssignmentController.remove);
router.post('/api/area-assignments/bulk', verifyToken, requirePermission(PERMISSIONS.MANAGE_AREA_ASSIGNMENTS), requireStationAccess, requirePlatformAccess, requireAreaAccess, areaAssignmentController.bulkAssign);

export default router;
