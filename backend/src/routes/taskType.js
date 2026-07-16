import { Router } from 'express';
import { verifyToken } from '../middleware/auth.js';
import { requirePermission } from '../middleware/authorization.js';
import { PERMISSIONS } from '../permissions/roles.js';
import * as taskTypeController from '../controllers/taskTypeController.js';

const router = Router();

router.post('/api/task-types', verifyToken, requirePermission(PERMISSIONS.MANAGE_FORMS), taskTypeController.createTaskType);
router.get('/api/task-types', verifyToken, requirePermission(PERMISSIONS.VIEW_FORMS), taskTypeController.listTaskTypes);
router.put('/api/task-types/:id', verifyToken, requirePermission(PERMISSIONS.MANAGE_FORMS), taskTypeController.updateTaskType);
router.delete('/api/task-types/:id', verifyToken, requirePermission(PERMISSIONS.MANAGE_FORMS), taskTypeController.deleteTaskType);
router.post('/api/task-types/seed', verifyToken, requirePermission(PERMISSIONS.MANAGE_FORMS), taskTypeController.seedTaskTypes);

export default router;
