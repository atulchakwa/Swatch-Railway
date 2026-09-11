import { Router } from 'express';
import { verifyToken } from '../middleware/auth.js';
import { requirePermission, requireMasterAccess } from '../middleware/authorization.js';
import { PERMISSIONS } from '../permissions/roles.js';
import * as areaController from '../controllers/areaController.js';

const router = Router();

router.post('/api/areas', verifyToken, requirePermission(PERMISSIONS.MANAGE_AREAS), areaController.create);
router.get('/api/areas', verifyToken, requirePermission(PERMISSIONS.VIEW_AREAS), areaController.list);
router.get('/api/areas/by-station/:stationId', verifyToken, requirePermission(PERMISSIONS.VIEW_AREAS), areaController.getByStation);
router.get('/api/areas/by-platform/:stationId/:platformId', verifyToken, requirePermission(PERMISSIONS.VIEW_AREAS), areaController.getByPlatform);
router.get('/api/areas/:uid', verifyToken, requirePermission(PERMISSIONS.VIEW_AREAS), areaController.getById);
router.put('/api/areas/:uid', verifyToken, requirePermission(PERMISSIONS.MANAGE_AREAS), areaController.update);
router.delete('/api/areas/:uid', verifyToken, requirePermission(PERMISSIONS.MANAGE_AREAS), areaController.remove);

// Admin level area management endpoints
router.get('/api/areas/master/dashboard', verifyToken, requirePermission(PERMISSIONS.VIEW_DASHBOARD), areaController.getMasterDashboard);
router.get('/api/areas/master/workers', verifyToken, requirePermission(PERMISSIONS.VIEW_AREA_ASSIGNMENTS), areaController.getAreaWorkers);
router.get('/api/areas/master/tasks', verifyToken, requirePermission(PERMISSIONS.VIEW_TASKS), areaController.getAreaTasks);
router.get('/api/areas/master/reports', verifyToken, requirePermission(PERMISSIONS.VIEW_REPORTS), areaController.getAreaReports);
router.post('/api/areas/master/assign-worker', verifyToken, requirePermission(PERMISSIONS.MANAGE_AREA_ASSIGNMENTS), areaController.assignWorkerToArea);
router.delete('/api/areas/master/unassign-worker/:workerId', verifyToken, requirePermission(PERMISSIONS.MANAGE_AREA_ASSIGNMENTS), areaController.unassignWorkerFromArea);
router.post('/api/areas/master/assign-platform', verifyToken, requirePermission(PERMISSIONS.MANAGE_AREA_ASSIGNMENTS), areaController.assignPlatformToArea);
router.delete('/api/areas/master/unassign-platform/:platformId', verifyToken, requirePermission(PERMISSIONS.MANAGE_AREA_ASSIGNMENTS), areaController.unassignPlatformFromArea);
router.post('/api/areas/master/generate-tasks-from-frequency', verifyToken, requirePermission(PERMISSIONS.GENERATE_TASKS), areaController.generateTasksFromFrequency);

// Areas within a platform
router.get('/api/areas/platform/:platformId/areas', verifyToken, requirePermission(PERMISSIONS.VIEW_AREAS), areaController.getAreasByPlatform);

// Master access endpoints
router.get('/api/areas/station/:stationId/areas', verifyToken, requirePermission(PERMISSIONS.VIEW_AREAS), areaController.getAreasByStation);
router.get('/api/areas/company/:companyId/areas', verifyToken, requireMasterAccess('COMPANY_MASTER'), areaController.getAreasByCompany);

export default router;
