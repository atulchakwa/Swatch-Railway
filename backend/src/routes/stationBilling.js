import { Router } from 'express';
import { verifyToken } from '../middleware/auth.js';
import { asyncHandler } from '../middleware/errorHandler.js';
import { stationBillingService } from '../services/stationBillingService.js';

const router = Router();

router.post('/api/station-billing/generate', verifyToken, asyncHandler(async (req, res) => res.status(201).json(await stationBillingService.generateBillingSupportPack(req.user, req.body))));
router.get('/api/station-billing', verifyToken, asyncHandler(async (req, res) => res.json(await stationBillingService.listPacks(req.query))));
router.get('/api/station-billing/:uid', verifyToken, asyncHandler(async (req, res) => res.json(await stationBillingService.getPackById(req.params.uid))));
router.patch('/api/station-billing/:uid/compliance', verifyToken, asyncHandler(async (req, res) => res.json(await stationBillingService.updateCompliance(req.params.uid, req.body.checklist, req.user))));
router.post('/api/station-billing/:uid/submit', verifyToken, asyncHandler(async (req, res) => res.json(await stationBillingService.submitPack(req.params.uid, req.user))));
router.post('/api/station-billing/:uid/approve', verifyToken, asyncHandler(async (req, res) => res.json(await stationBillingService.approvePack(req.params.uid, req.user))));
router.post('/api/station-billing/:uid/reject', verifyToken, asyncHandler(async (req, res) => res.json(await stationBillingService.rejectPack(req.params.uid, req.body.reason, req.user))));
router.post('/api/station-billing/:uid/payment', verifyToken, asyncHandler(async (req, res) => res.json(await stationBillingService.recordPayment(req.params.uid, req.user, req.body))));
router.put('/api/station-billing/:uid', verifyToken, asyncHandler(async (req, res) => res.json(await stationBillingService.updatePack(req.params.uid, req.body, req.user))));
router.delete('/api/station-billing/:uid', verifyToken, asyncHandler(async (req, res) => res.json(await stationBillingService.deletePack(req.params.uid, req.user))));
router.post('/api/station-billing/:uid/return-to-draft', verifyToken, asyncHandler(async (req, res) => res.json(await stationBillingService.returnToDraft(req.params.uid, req.user))));
router.post('/api/station-billing/auto-generate-monthly', verifyToken, asyncHandler(async (req, res) => res.status(201).json(await stationBillingService.generateMonthlyBillingPacks(req.body.month, req.body.year, req.user))));

export default router;
