import express from 'express';
import { verifyToken } from '../middleware/auth.js';
import { requirePermission } from '../middleware/authorization.js';
import { PERMISSIONS } from '../permissions/roles.js';
import * as ctrl from '../controllers/pettyIssueController.js';

const router = express.Router();

router.post('/api/petty-issues', verifyToken, requirePermission(PERMISSIONS.MANAGE_PETTY_ISSUES), ctrl.create);
router.get('/api/petty-issues', verifyToken, requirePermission(PERMISSIONS.VIEW_PETTY_ISSUES), ctrl.list);
router.get('/api/petty-issues/summary/:stationId', verifyToken, requirePermission(PERMISSIONS.VIEW_PETTY_ISSUES), ctrl.summary);
router.get('/api/petty-issues/:uid', verifyToken, requirePermission(PERMISSIONS.VIEW_PETTY_ISSUES), ctrl.getById);
router.put('/api/petty-issues/:uid', verifyToken, requirePermission(PERMISSIONS.MANAGE_PETTY_ISSUES), ctrl.update);
router.delete('/api/petty-issues/:uid', verifyToken, requirePermission(PERMISSIONS.MANAGE_PETTY_ISSUES), ctrl.remove);
router.patch('/api/petty-issues/:uid/status', verifyToken, requirePermission(PERMISSIONS.MANAGE_PETTY_ISSUES), ctrl.updateStatus);
router.post('/api/petty-issues/:uid/resolve', verifyToken, requirePermission(PERMISSIONS.RESOLVE_PETTY_ISSUE), ctrl.resolve);
router.post('/api/petty-issues/:uid/close', verifyToken, requirePermission(PERMISSIONS.MANAGE_PETTY_ISSUES), ctrl.close);

export default router;
