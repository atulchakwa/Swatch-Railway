import { Router } from 'express';
import { verifyToken } from '../middleware/auth.js';
import { requirePermission } from '../middleware/authorization.js';
import { PERMISSIONS } from '../permissions/roles.js';
import { asyncHandler } from '../middleware/errorHandler.js';
import { executionSheetService } from '../services/executionSheetService.js';

const router = Router();

// ─── Template items ───────────────────────────────────────────────────────────
router.get('/api/execution-sheet/items', verifyToken, requirePermission(PERMISSIONS.VIEW_EXECUTION), asyncHandler(async (req, res) => res.json(await executionSheetService.getItems(req.query))));
router.get('/api/execution-sheet/items/:uid', verifyToken, requirePermission(PERMISSIONS.VIEW_EXECUTION), asyncHandler(async (req, res) => res.json(await executionSheetService.getItemById(req.params.uid))));
router.post('/api/execution-sheet/items', verifyToken, requirePermission(PERMISSIONS.MANAGE_EXECUTION), asyncHandler(async (req, res) => res.status(201).json(await executionSheetService.createItem(req.user, req.body))));
router.put('/api/execution-sheet/items/:uid', verifyToken, requirePermission(PERMISSIONS.MANAGE_EXECUTION), asyncHandler(async (req, res) => res.json(await executionSheetService.updateItem(req.params.uid, req.user, req.body))));
router.delete('/api/execution-sheet/items/:uid', verifyToken, requirePermission(PERMISSIONS.MANAGE_EXECUTION), asyncHandler(async (req, res) => res.json(await executionSheetService.deleteItem(req.params.uid, req.user))));

// ─── Daily execution logs ─────────────────────────────────────────────────────
router.get('/api/execution-sheet/daily', verifyToken, requirePermission(PERMISSIONS.VIEW_EXECUTION), asyncHandler(async (req, res) => res.json(await executionSheetService.getDailySheet(req.query))));
router.get('/api/execution-sheet/daily/list', verifyToken, requirePermission(PERMISSIONS.VIEW_EXECUTION), asyncHandler(async (req, res) => res.json(await executionSheetService.listDailyLogs(req.query))));
router.post('/api/execution-sheet/daily', verifyToken, requirePermission(PERMISSIONS.MANAGE_EXECUTION), asyncHandler(async (req, res) => res.status(201).json(await executionSheetService.saveDailySheet(req.user, req.body))));
router.post('/api/execution-sheet/daily/:uid/submit', verifyToken, requirePermission(PERMISSIONS.MANAGE_EXECUTION), asyncHandler(async (req, res) => res.json(await executionSheetService.submitDailySheet(req.params.uid, req.user))));

// ─── Monthly summary (50% billing component) ──────────────────────────────────
router.get('/api/execution-sheet/monthly', verifyToken, requirePermission(PERMISSIONS.VIEW_BILLING), asyncHandler(async (req, res) => res.json(await executionSheetService.getMonthlySummary(req.query))));

export default router;