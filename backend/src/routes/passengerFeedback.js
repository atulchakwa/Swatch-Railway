import express from 'express';
import { verifyToken } from '../middleware/auth.js';
import { requirePermission } from '../middleware/authorization.js';
import { PERMISSIONS } from '../permissions/roles.js';
import * as passengerFeedbackController from '../controllers/passengerFeedbackController.js';

const router = express.Router();

router.post('/api/passenger-feedback', verifyToken, requirePermission(PERMISSIONS.SUBMIT_FEEDBACK), passengerFeedbackController.create);
router.get('/api/passenger-feedback', verifyToken, requirePermission(PERMISSIONS.VIEW_FEEDBACK), passengerFeedbackController.list);
router.get('/api/passenger-feedback/summary/:stationId', verifyToken, requirePermission(PERMISSIONS.VIEW_FEEDBACK), passengerFeedbackController.summary);
router.get('/api/passenger-feedback/:uid', verifyToken, requirePermission(PERMISSIONS.VIEW_FEEDBACK), passengerFeedbackController.getById);
router.put('/api/passenger-feedback/:uid', verifyToken, requirePermission(PERMISSIONS.SUBMIT_FEEDBACK), passengerFeedbackController.update);
router.delete('/api/passenger-feedback/:uid', verifyToken, requirePermission(PERMISSIONS.SUBMIT_FEEDBACK), passengerFeedbackController.remove);

export default router;