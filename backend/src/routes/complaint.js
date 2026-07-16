import express from 'express';
import { verifyToken } from '../middleware/auth.js';
import { requirePermission } from '../middleware/authorization.js';
import { PERMISSIONS } from '../permissions/roles.js';
import * as complaintController from '../controllers/complaintController.js';

const router = express.Router();

router.post('/api/complaints', verifyToken, requirePermission(PERMISSIONS.CREATE_COMPLAINT), complaintController.create);
router.get('/api/complaints', verifyToken, requirePermission(PERMISSIONS.VIEW_COMPLAINTS), complaintController.list);
router.post('/api/complaints/:uid/assign', verifyToken, requirePermission(PERMISSIONS.MANAGE_COMPLAINTS), complaintController.assign);
router.post('/api/complaints/:uid/start', verifyToken, requirePermission(PERMISSIONS.MANAGE_COMPLAINTS), complaintController.startProgress);
router.post('/api/complaints/:uid/resolve', verifyToken, requirePermission(PERMISSIONS.MANAGE_COMPLAINTS), complaintController.resolve);
router.post('/api/complaints/:uid/verify', verifyToken, requirePermission(PERMISSIONS.MANAGE_COMPLAINTS), complaintController.verify);
router.post('/api/complaints/:uid/close', verifyToken, requirePermission(PERMISSIONS.MANAGE_COMPLAINTS), complaintController.close);
router.post('/api/complaints/:uid/reopen', verifyToken, requirePermission(PERMISSIONS.MANAGE_COMPLAINTS), complaintController.reopen);
router.post('/api/complaints/:uid/reject', verifyToken, requirePermission(PERMISSIONS.MANAGE_COMPLAINTS), complaintController.reject);
router.post('/api/complaints/:uid/resubmit', verifyToken, requirePermission(PERMISSIONS.MANAGE_COMPLAINTS), complaintController.resubmit);
router.post('/api/complaints/:uid/escalate', verifyToken, requirePermission(PERMISSIONS.MANAGE_COMPLAINTS), complaintController.escalate);
router.post('/api/complaints/check-sla', verifyToken, requirePermission(PERMISSIONS.MANAGE_COMPLAINTS), complaintController.checkSla);
router.get('/api/complaints/:uid', verifyToken, requirePermission(PERMISSIONS.VIEW_COMPLAINTS), complaintController.getById);
router.delete('/api/complaints/:uid', verifyToken, requirePermission(PERMISSIONS.MANAGE_COMPLAINTS), complaintController.remove);

export default router;
