import { Router } from 'express';
import { verifyToken } from '../middleware/auth.js';
import { requirePermission } from '../middleware/authorization.js';
import { PERMISSIONS } from '../permissions/roles.js';
import { asyncHandler } from '../middleware/errorHandler.js';
import { contractEstimationService } from '../services/contractEstimationService.js';

const router = Router();

// ─── Contract & Estimate items ───────────────────────────────────────────────
router.get('/api/contract-estimation/:contractId/estimate', verifyToken, requirePermission(PERMISSIONS.VIEW_CONTRACTS), asyncHandler(async (req, res) => res.json(await contractEstimationService.getEstimateItems({ contractId: req.params.contractId, stationId: req.query.stationId, status: req.query.status }))));
router.post('/api/contract-estimation/:contractId/items', verifyToken, requirePermission(PERMISSIONS.UPDATE_CONTRACT), asyncHandler(async (req, res) => res.status(201).json(await contractEstimationService.createEstimateItem(req.user, { ...req.body, contractId: req.params.contractId }))));
router.put('/api/contract-estimation/items/:uid', verifyToken, requirePermission(PERMISSIONS.UPDATE_CONTRACT), asyncHandler(async (req, res) => res.json(await contractEstimationService.updateEstimateItem(req.params.uid, req.user, req.body))));
router.delete('/api/contract-estimation/items/:uid', verifyToken, requirePermission(PERMISSIONS.UPDATE_CONTRACT), asyncHandler(async (req, res) => res.json(await contractEstimationService.deleteEstimateItem(req.params.uid, req.user))));

// ─── Variations / recovery statements ────────────────────────────────────────
router.get('/api/contract-estimation/:contractId/variations', verifyToken, requirePermission(PERMISSIONS.VIEW_CONTRACTS), asyncHandler(async (req, res) => res.json(await contractEstimationService.getVariations({ contractId: req.params.contractId }))));
router.post('/api/contract-estimation/:contractId/variations', verifyToken, requirePermission(PERMISSIONS.UPDATE_CONTRACT), asyncHandler(async (req, res) => res.status(201).json(await contractEstimationService.createVariation(req.user, { ...req.body, contractId: req.params.contractId }))));

// ─── Supplementary work orders ───────────────────────────────────────────────
router.get('/api/contract-estimation/:contractId/swos', verifyToken, requirePermission(PERMISSIONS.VIEW_CONTRACTS), asyncHandler(async (req, res) => res.json(await contractEstimationService.getSWOs({ contractId: req.params.contractId, status: req.query.status }))));
router.post('/api/contract-estimation/:contractId/swos', verifyToken, requirePermission(PERMISSIONS.UPDATE_CONTRACT), asyncHandler(async (req, res) => res.status(201).json(await contractEstimationService.createSWO(req.user, { ...req.body, contractId: req.params.contractId }))));
router.delete('/api/contract-estimation/swos/:uid', verifyToken, requirePermission(PERMISSIONS.UPDATE_CONTRACT), asyncHandler(async (req, res) => res.json(await contractEstimationService.deleteSWO(req.params.uid, req.user))));

// ─── Amended contract value + billing-period contribution ────────────────────
router.get('/api/contract-estimation/:contractId/amended', verifyToken, requirePermission(PERMISSIONS.VIEW_CONTRACTS), asyncHandler(async (req, res) => res.json(await contractEstimationService.getAmendedContractValue({ contractId: req.params.contractId }))));
router.get('/api/contract-estimation/:contractId/period-contribution', verifyToken, requirePermission(PERMISSIONS.VIEW_BILLING), asyncHandler(async (req, res) => res.json(await contractEstimationService.getPeriodContribution({ contractId: req.params.contractId, stationId: req.query.stationId, month: req.query.month, year: req.query.year }))));

export default router;