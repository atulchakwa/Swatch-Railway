import { pettyIssueService } from '../services/pettyIssueService.js';
import { asyncHandler } from '../middleware/errorHandler.js';

export const create = asyncHandler(async (req, res) => res.status(201).json(await pettyIssueService.create(req.user, req.body)));
export const list = asyncHandler(async (req, res) => res.json(await pettyIssueService.list(req.query)));
export const getById = asyncHandler(async (req, res) => res.json(await pettyIssueService.getById(req.params.uid)));
export const update = asyncHandler(async (req, res) => res.json(await pettyIssueService.update(req.params.uid, req.user, req.body)));
export const remove = asyncHandler(async (req, res) => res.json(await pettyIssueService.delete(req.params.uid)));
export const updateStatus = asyncHandler(async (req, res) => res.json(await pettyIssueService.updateStatus(req.params.uid, req.user, req.body)));
export const resolve = asyncHandler(async (req, res) => res.json(await pettyIssueService.resolve(req.params.uid, req.user, req.body)));
export const close = asyncHandler(async (req, res) => res.json(await pettyIssueService.close(req.params.uid, req.user, req.body)));
export const summary = asyncHandler(async (req, res) => res.json(await pettyIssueService.getSummary(req.params.stationId)));
