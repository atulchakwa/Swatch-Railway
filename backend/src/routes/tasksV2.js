import { Router } from 'express';
import { verifyToken } from '../middleware/auth.js';
import { requirePermission } from '../middleware/authorization.js';
import { PERMISSIONS } from '../permissions/roles.js';
import * as taskManagementController from '../controllers/taskManagementController.js';
import * as taskController from '../controllers/taskController.js';

const router = Router();

// Old v1 paths (keep backward compat)
router.get('/api/tasks/pending-review', verifyToken, requirePermission(PERMISSIONS.VIEW_TASKS), taskController.pendingReview);
router.post('/api/tasks/generate', verifyToken, requirePermission(PERMISSIONS.GENERATE_TASKS), taskManagementController.generateTasks);
router.get('/api/tasks', verifyToken, requirePermission(PERMISSIONS.VIEW_TASKS), taskManagementController.list);
router.get('/api/tasks/worker/:workerId', verifyToken, requirePermission(PERMISSIONS.VIEW_TASKS), taskManagementController.getWorkerTasks);
router.get('/api/tasks/area/:areaId', verifyToken, requirePermission(PERMISSIONS.VIEW_TASKS), taskManagementController.getAreaTasks);
router.get('/api/tasks/date/:date', verifyToken, requirePermission(PERMISSIONS.VIEW_TASKS), taskManagementController.getDailyTasks);
router.get('/api/tasks/:id', verifyToken, requirePermission(PERMISSIONS.VIEW_TASKS), taskManagementController.getById);
router.put('/api/tasks/:id/status', verifyToken, requirePermission(PERMISSIONS.MANAGE_TASKS), taskManagementController.updateStatus);
router.post('/api/tasks/:id/assign', verifyToken, requirePermission(PERMISSIONS.MANAGE_TASKS), taskManagementController.assign);
router.post('/api/tasks/:id/start', verifyToken, requirePermission(PERMISSIONS.START_TASK), taskManagementController.start);
router.post('/api/tasks/:id/complete', verifyToken, requirePermission(PERMISSIONS.COMPLETE_TASK), taskManagementController.complete);
router.post('/api/tasks/:id/resubmit', verifyToken, requirePermission(PERMISSIONS.RESUBMIT_TASK), taskManagementController.resubmit);
router.post('/api/tasks/:id/approve', verifyToken, requirePermission(PERMISSIONS.APPROVE_TASK), taskManagementController.approve);
router.post('/api/tasks/:id/reject', verifyToken, requirePermission(PERMISSIONS.REJECT_TASK), taskManagementController.reject);
router.post('/api/tasks/bulk-generate', verifyToken, requirePermission(PERMISSIONS.GENERATE_TASKS), taskManagementController.bulkGenerate);

// New v2 paths (for frontend consistency)
router.get('/api/tasks-v2', verifyToken, requirePermission(PERMISSIONS.VIEW_TASKS), taskManagementController.list);
router.get('/api/tasks-v2/worker', verifyToken, requirePermission(PERMISSIONS.VIEW_TASKS), taskManagementController.list);
router.get('/api/tasks-v2/pending-review', verifyToken, requirePermission(PERMISSIONS.VIEW_TASKS), taskManagementController.getPendingReview);
router.get('/api/tasks-v2/supervisor/:supervisorId', verifyToken, requirePermission(PERMISSIONS.VIEW_TASKS), taskManagementController.getSupervisorTasks);
router.post('/api/tasks-v2/generate', verifyToken, requirePermission(PERMISSIONS.GENERATE_TASKS), taskManagementController.bulkGenerate);
router.post('/api/tasks-v2/:id/start', verifyToken, requirePermission(PERMISSIONS.START_TASK), taskManagementController.start);
router.post('/api/tasks-v2/:id/complete', verifyToken, requirePermission(PERMISSIONS.COMPLETE_TASK), taskManagementController.complete);
router.post('/api/tasks-v2/:id/resubmit', verifyToken, requirePermission(PERMISSIONS.RESUBMIT_TASK), taskManagementController.resubmit);
router.post('/api/tasks-v2/:id/approve', verifyToken, requirePermission(PERMISSIONS.APPROVE_TASK), taskManagementController.approve);
router.post('/api/tasks-v2/:id/reject', verifyToken, requirePermission(PERMISSIONS.REJECT_TASK), taskManagementController.reject);
router.post('/api/tasks-v2/generate-range', verifyToken, requirePermission(PERMISSIONS.GENERATE_TASKS), taskManagementController.generateRange);
router.get('/api/tasks-v2/:id', verifyToken, requirePermission(PERMISSIONS.VIEW_TASKS), taskManagementController.getById);

export default router;
