import express from 'express';
import { verifyToken } from '../middleware/auth.js';
import { requirePermission, requireStationAccess, requirePlatformAccess, requirePlatformMasterAccess, requireMasterAccess } from '../middleware/authorization.js';
import { validate } from '../middleware/validate.js';
import { createPlatformSchema } from '../validations/schemas.js';
import { PERMISSIONS } from '../permissions/roles.js';
import * as platformController from '../controllers/platformController.js';

const router = express.Router();

// Standard platform CRUD
router.post('/api/platforms', verifyToken, requirePermission(PERMISSIONS.MANAGE_PLATFORMS), requireStationAccess, validate(createPlatformSchema), platformController.create);
router.get('/api/platforms', verifyToken, requirePermission(PERMISSIONS.VIEW_PLATFORMS), requireStationAccess, platformController.list);
router.get('/api/platforms/by-station/:stationId', verifyToken, requirePermission(PERMISSIONS.VIEW_PLATFORMS), requireStationAccess, platformController.getByStation);
router.get('/api/platforms/:uid', verifyToken, requirePermission(PERMISSIONS.VIEW_PLATFORMS), requireStationAccess, platformController.getById);
router.put('/api/platforms/:uid', verifyToken, requirePermission(PERMISSIONS.MANAGE_PLATFORMS), requireStationAccess, platformController.update);
router.delete('/api/platforms/:uid', verifyToken, requirePermission(PERMISSIONS.MANAGE_PLATFORMS), requireStationAccess, platformController.remove);

// Platform Master specific endpoints (scoped to assigned platform)
router.get('/api/platforms/master/dashboard', verifyToken, requirePlatformMasterAccess, requirePlatformAccess, platformController.getMasterDashboard);
router.get('/api/platforms/master/areas', verifyToken, requirePlatformMasterAccess, requirePlatformAccess, platformController.getPlatformAreas);
router.get('/api/platforms/master/workers', verifyToken, requirePlatformMasterAccess, requirePlatformAccess, platformController.getPlatformWorkers);
router.get('/api/platforms/master/tasks', verifyToken, requirePlatformMasterAccess, requirePlatformAccess, platformController.getPlatformTasks);
router.get('/api/platforms/master/reports', verifyToken, requirePlatformMasterAccess, requirePlatformAccess, platformController.getPlatformReports);
router.post('/api/platforms/master/assign-area', verifyToken, requirePlatformMasterAccess, requirePlatformAccess, platformController.assignAreaToPlatform);
router.delete('/api/platforms/master/unassign-area/:areaId', verifyToken, requirePlatformMasterAccess, requirePlatformAccess, platformController.unassignAreaFromPlatform);

// Master access endpoints (Zone Master, Company Master, Super Admin)
router.get('/api/platforms/zone/:zoneId/platforms', verifyToken, requireMasterAccess('RAILWAY_MASTER'), platformController.getPlatformsByZone);
router.get('/api/platforms/company/:companyId/platforms', verifyToken, requireMasterAccess('COMPANY_MASTER'), platformController.getPlatformsByCompany);

export default router;
