import { Router } from 'express';
import { verifyToken } from '../middleware/auth.js';
import { requirePermission } from '../middleware/authorization.js';
import { PERMISSIONS } from '../permissions/roles.js';
import { asyncHandler } from '../middleware/errorHandler.js';
import { taskExecutionBillingService } from '../services/taskExecutionBillingService.js';

const router = Router();

// ─── Daily task-execution billing (50% component) ────────────────────────────
router.get('/api/task-execution-billing/daily/preview', verifyToken, requirePermission(PERMISSIONS.VIEW_BILLING), asyncHandler(async (req, res) => res.json(await taskExecutionBillingService.previewDailyBill(req.query))));
router.get('/api/task-execution-billing/daily/preview/range', verifyToken, requirePermission(PERMISSIONS.VIEW_BILLING), asyncHandler(async (req, res) => res.json(await taskExecutionBillingService.previewDailyRange(req.query))));
router.post('/api/task-execution-billing/daily/generate', verifyToken, requirePermission(PERMISSIONS.GENERATE_BILLING), asyncHandler(async (req, res) => res.status(201).json(await taskExecutionBillingService.generateDailyBill(req.user, req.body))));
router.get('/api/task-execution-billing/daily', verifyToken, requirePermission(PERMISSIONS.VIEW_BILLING), asyncHandler(async (req, res) => res.json(await taskExecutionBillingService.getDailyBill(req.query))));
router.get('/api/task-execution-billing/daily/list', verifyToken, requirePermission(PERMISSIONS.VIEW_BILLING), asyncHandler(async (req, res) => res.json(await taskExecutionBillingService.listDailyBills(req.query))));

export default router;