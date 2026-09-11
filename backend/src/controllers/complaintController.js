import { complaintService } from '../services/complaintService.js';
import { asyncHandler } from '../middleware/errorHandler.js';

export const create = asyncHandler(async (req, res) => res.status(201).json(await complaintService.createComplaint(req.user, req.body)));
export const list = asyncHandler(async (req, res) => res.json(await complaintService.getComplaints(req.query, req.user)));
export const getById = asyncHandler(async (req, res) => res.json(await complaintService.getComplaintById(req.params.uid)));
export const assign = asyncHandler(async (req, res) => res.json(await complaintService.assignComplaint(req.params.uid, req.user, req.body)));
export const startProgress = asyncHandler(async (req, res) => res.json(await complaintService.startProgress(req.params.uid, req.user)));
export const resolve = asyncHandler(async (req, res) => res.json(await complaintService.resolveComplaint(req.params.uid, req.user, req.body)));
export const verify = asyncHandler(async (req, res) => res.json(await complaintService.verifyComplaint(req.params.uid, req.user)));
export const close = asyncHandler(async (req, res) => res.json(await complaintService.closeComplaint(req.params.uid, req.user)));
export const reopen = asyncHandler(async (req, res) => res.json(await complaintService.reopenComplaint(req.params.uid, req.user, req.body)));
export const reject = asyncHandler(async (req, res) => res.json(await complaintService.rejectComplaint(req.params.uid, req.user, req.body)));
export const resubmit = asyncHandler(async (req, res) => res.json(await complaintService.resubmitComplaint(req.params.uid, req.user, req.body)));
export const escalate = asyncHandler(async (req, res) => res.json(await complaintService.escalateComplaint(req.params.uid, req.user, req.body)));
export const checkSla = asyncHandler(async (req, res) => res.json(await complaintService.checkSlaBreaches()));
export const remove = asyncHandler(async (req, res) => res.json(await complaintService.deleteComplaint(req.params.uid)));
