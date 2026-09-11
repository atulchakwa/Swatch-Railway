import express from 'express';
import { verifyToken } from '../middleware/auth.js';
import { requirePermission } from '../middleware/authorization.js';
import { validate } from '../middleware/validate.js';
import { createAreaSchema } from '../validations/schemas.js';
import { PERMISSIONS } from '../permissions/roles.js';
import * as areaController from '../controllers/areaController.js';

const router = express.Router();

router.post('/api/areas', verifyToken, requirePermission(PERMISSIONS.MANAGE_AREAS), validate(createAreaSchema), areaController.create);
router.post('/api/areas/configure', verifyToken, requirePermission(PERMISSIONS.MANAGE_AREAS), areaController.configure);
router.get('/api/areas', verifyToken, requirePermission(PERMISSIONS.VIEW_AREAS), areaController.list);
router.get('/api/areas/summary/:stationId', verifyToken, requirePermission(PERMISSIONS.VIEW_AREAS), areaController.getSummary);
router.get('/api/areas/by-hierarchy', verifyToken, requirePermission(PERMISSIONS.VIEW_AREAS), areaController.getByHierarchy);
router.get('/api/areas/by-station/:stationId', verifyToken, requirePermission(PERMISSIONS.VIEW_AREAS), areaController.getByStation);
router.get('/api/areas/by-platform/:platformId', verifyToken, requirePermission(PERMISSIONS.VIEW_AREAS), areaController.getByPlatform);
router.get('/api/areas/:uid', verifyToken, requirePermission(PERMISSIONS.VIEW_AREAS), areaController.getById);
router.put('/api/areas/:uid', verifyToken, requirePermission(PERMISSIONS.MANAGE_AREAS), areaController.update);
router.put('/api/areas/:uid/configure', verifyToken, requirePermission(PERMISSIONS.MANAGE_AREAS), areaController.update);
router.delete('/api/areas/:uid', verifyToken, requirePermission(PERMISSIONS.MANAGE_AREAS), areaController.remove);

export default router;
