import express from 'express';
import { verifyToken } from '../middleware/auth.js';
import { requirePermission } from '../middleware/authorization.js';
import { PERMISSIONS } from '../permissions/roles.js';
import * as stationFeedbackController from '../controllers/stationFeedbackController.js';

const router = express.Router();

router.post('/api/station-feedback/send-otp', stationFeedbackController.sendOtp);
router.post('/api/station-feedback/verify-otp', stationFeedbackController.verifyOtp);
router.post('/api/station-feedback/submit', stationFeedbackController.submit);
router.get('/api/station-feedback/version', stationFeedbackController.version);
router.get('/api/station-feedback/station/:stationId', stationFeedbackController.stationBrief);
router.get('/api/station-feedback/list', verifyToken, requirePermission(PERMISSIONS.VIEW_FORMS), stationFeedbackController.list);
router.get('/api/station-feedback/summary/:stationId', verifyToken, requirePermission(PERMISSIONS.VIEW_FORMS), stationFeedbackController.summary);
router.get('/api/station-feedback/qr/:stationId', verifyToken, requirePermission(PERMISSIONS.VIEW_FORMS), stationFeedbackController.qrCode);
router.post('/api/station-feedback/:uid/moderate', verifyToken, requirePermission(PERMISSIONS.MANAGE_FORMS), stationFeedbackController.moderate);

export default router;
