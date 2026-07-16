import express from 'express';
import { verifyToken } from '../middleware/auth.js';
import { requirePermission, requireStationAccess, requirePlatformAccess } from '../middleware/authorization.js';
import { validate } from '../middleware/validate.js';
import { createDeploymentSchema } from '../validations/schemas.js';
import { PERMISSIONS } from '../permissions/roles.js';
import * as deploymentController from '../controllers/deploymentController.js';

const router = express.Router();

router.post('/api/deployments', verifyToken, requirePermission(PERMISSIONS.MANAGE_DEPLOYMENTS), requireStationAccess, requirePlatformAccess, validate(createDeploymentSchema), deploymentController.create);
router.get('/api/deployments', verifyToken, requirePermission(PERMISSIONS.VIEW_DEPLOYMENTS), requireStationAccess, requirePlatformAccess, deploymentController.list);
router.get('/api/deployments/worker/:workerId/schedule', verifyToken, requirePermission(PERMISSIONS.VIEW_DEPLOYMENTS), requireStationAccess, requirePlatformAccess, deploymentController.workerSchedule);
router.get('/api/deployments/manpower-variance', verifyToken, requirePermission(PERMISSIONS.VIEW_DEPLOYMENTS), requireStationAccess, requirePlatformAccess, deploymentController.manpowerVariance);
router.get('/api/deployments/shift-wise-manpower', verifyToken, requirePermission(PERMISSIONS.VIEW_DEPLOYMENTS), requireStationAccess, requirePlatformAccess, deploymentController.shiftWiseManpower);
router.get('/api/deployments/:uid', verifyToken, requirePermission(PERMISSIONS.VIEW_DEPLOYMENTS), requireStationAccess, requirePlatformAccess, deploymentController.getById);
router.put('/api/deployments/:uid', verifyToken, requirePermission(PERMISSIONS.MANAGE_DEPLOYMENTS), requireStationAccess, requirePlatformAccess, deploymentController.update);
router.delete('/api/deployments/:uid', verifyToken, requirePermission(PERMISSIONS.MANAGE_DEPLOYMENTS), requireStationAccess, requirePlatformAccess, deploymentController.remove);

export default router;
