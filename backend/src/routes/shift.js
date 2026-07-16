import express from 'express';
import { verifyToken } from '../middleware/auth.js';
import { requirePermission, requireStationAccess, requirePlatformAccess, requireAreaAccess } from '../middleware/authorization.js';
import { validate } from '../middleware/validate.js';
import { createShiftSchema } from '../validations/schemas.js';
import { PERMISSIONS } from '../permissions/roles.js';
import * as shiftController from '../controllers/shiftController.js';

const router = express.Router();

router.post('/api/shifts', verifyToken, requirePermission(PERMISSIONS.MANAGE_SHIFTS), requireStationAccess, requirePlatformAccess, requireAreaAccess, validate(createShiftSchema), shiftController.create);
router.get('/api/shifts', verifyToken, requirePermission(PERMISSIONS.VIEW_SHIFTS), requireStationAccess, requirePlatformAccess, requireAreaAccess, shiftController.list);
router.post('/api/shifts/:uid/assign-supervisor', verifyToken, requirePermission(PERMISSIONS.ASSIGN_SHIFT), requireStationAccess, requirePlatformAccess, requireAreaAccess, shiftController.assignSupervisor);
router.post('/api/shifts/:uid/assign-worker', verifyToken, requirePermission(PERMISSIONS.ASSIGN_SHIFT), requireStationAccess, requirePlatformAccess, requireAreaAccess, shiftController.assignWorker);
router.delete('/api/shifts/:uid/assignments/:userId', verifyToken, requirePermission(PERMISSIONS.ASSIGN_SHIFT), requireStationAccess, requirePlatformAccess, requireAreaAccess, shiftController.removeAssignment);
router.get('/api/shifts/:uid', verifyToken, requirePermission(PERMISSIONS.VIEW_SHIFTS), requireStationAccess, requirePlatformAccess, requireAreaAccess, shiftController.getById);
router.put('/api/shifts/:uid', verifyToken, requirePermission(PERMISSIONS.MANAGE_SHIFTS), requireStationAccess, requirePlatformAccess, requireAreaAccess, shiftController.update);
router.delete('/api/shifts/:uid', verifyToken, requirePermission(PERMISSIONS.MANAGE_SHIFTS), requireStationAccess, requirePlatformAccess, requireAreaAccess, shiftController.remove);

export default router;
