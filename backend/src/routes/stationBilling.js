import { Router } from 'express';
import { verifyToken } from '../middleware/auth.js';
import { requirePermission } from '../middleware/authorization.js';
import { PERMISSIONS } from '../permissions/roles.js';
import { asyncHandler } from '../middleware/errorHandler.js';
import { stationBillingService } from '../services/stationBillingService.js';

const router = Router();

router.post('/api/station-billing/generate', verifyToken, requirePermission(PERMISSIONS.GENERATE_BILLING), asyncHandler(async (req, res) => res.status(201).json(await stationBillingService.generateBillingSupportPack(req.user, req.body))));
router.get('/api/station-billing', verifyToken, requirePermission(PERMISSIONS.VIEW_BILLING), asyncHandler(async (req, res) => res.json(await stationBillingService.listPacks(req.query))));
router.get('/api/station-billing/:uid', verifyToken, requirePermission(PERMISSIONS.VIEW_BILLING), asyncHandler(async (req, res) => res.json(await stationBillingService.getPackById(req.params.uid))));
router.patch('/api/station-billing/:uid/compliance', verifyToken, requirePermission(PERMISSIONS.MANAGE_BILLING), asyncHandler(async (req, res) => res.json(await stationBillingService.updateCompliance(req.params.uid, req.body.checklist, req.user))));
router.post('/api/station-billing/:uid/submit', verifyToken, requirePermission(PERMISSIONS.MANAGE_BILLING), asyncHandler(async (req, res) => res.json(await stationBillingService.submitPack(req.params.uid, req.user))));
router.post('/api/station-billing/:uid/approve', verifyToken, requirePermission(PERMISSIONS.APPROVE_BILLING), asyncHandler(async (req, res) => res.json(await stationBillingService.approvePack(req.params.uid, req.user))));
router.post('/api/station-billing/:uid/reject', verifyToken, requirePermission(PERMISSIONS.APPROVE_BILLING), asyncHandler(async (req, res) => res.json(await stationBillingService.rejectPack(req.params.uid, req.body.reason, req.user))));
router.post('/api/station-billing/:uid/payment', verifyToken, requirePermission(PERMISSIONS.RECORD_PAYMENT), asyncHandler(async (req, res) => res.json(await stationBillingService.recordPayment(req.params.uid, req.user, req.body))));
router.put('/api/station-billing/:uid', verifyToken, requirePermission(PERMISSIONS.MANAGE_BILLING), asyncHandler(async (req, res) => res.json(await stationBillingService.updatePack(req.params.uid, req.body, req.user))));
router.delete('/api/station-billing/:uid', verifyToken, requirePermission(PERMISSIONS.MANAGE_BILLING), asyncHandler(async (req, res) => res.json(await stationBillingService.deletePack(req.params.uid, req.user))));
router.post('/api/station-billing/:uid/return-to-draft', verifyToken, requirePermission(PERMISSIONS.MANAGE_BILLING), asyncHandler(async (req, res) => res.json(await stationBillingService.returnToDraft(req.params.uid, req.user))));
router.post('/api/station-billing/auto-generate-monthly', verifyToken, requirePermission(PERMISSIONS.GENERATE_BILLING), asyncHandler(async (req, res) => res.status(201).json(await stationBillingService.generateMonthlyBillingPacks(req.body.month, req.body.year, req.user))));

export default router;
