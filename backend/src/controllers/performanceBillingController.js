import { performanceBillingService } from '../services/performanceBillingService.js';
import { asyncHandler } from '../middleware/errorHandler.js';

export const getConfig = asyncHandler(async (req, res) => {
  const config = await performanceBillingService.getConfig(req.params.contractId);
  res.status(200).json({ config });
});

export const saveConfig = asyncHandler(async (req, res) => {
  const result = await performanceBillingService.saveConfig(req.params.contractId, req.body, req.user);
  res.status(200).json(result);
});

export const scorecard = asyncHandler(async (req, res) => {
  const result = await performanceBillingService.computeScorecard(req.query);
  res.status(200).json({ scorecard: result });
});

export const generateBill = asyncHandler(async (req, res) => {
  const result = await performanceBillingService.generateBill(req.user, req.body);
  res.status(201).json(result);
});

export const listBills = asyncHandler(async (req, res) => {
  const result = await performanceBillingService.listBills(req.query);
  res.status(200).json(result);
});

export const getBill = asyncHandler(async (req, res) => {
  const bill = await performanceBillingService.getBill(req.params.uid);
  res.status(200).json({ bill });
});

export const recalculateBill = asyncHandler(async (req, res) => {
  const result = await performanceBillingService.recalculateBill(req.user, req.params.uid);
  res.status(200).json(result);
});

export const submitBill = asyncHandler(async (req, res) => {
  const result = await performanceBillingService.submitBill(req.user, req.params.uid);
  res.status(200).json(result);
});

export const verifyBill = asyncHandler(async (req, res) => {
  const result = await performanceBillingService.verifyBill(req.user, req.params.uid);
  res.status(200).json(result);
});

export const approveBill = asyncHandler(async (req, res) => {
  const result = await performanceBillingService.approveBill(req.user, req.params.uid);
  res.status(200).json(result);
});

export const lockBill = asyncHandler(async (req, res) => {
  const result = await performanceBillingService.lockBill(req.user, req.params.uid);
  res.status(200).json(result);
});

export const reopenBill = asyncHandler(async (req, res) => {
  const result = await performanceBillingService.reopenBill(req.user, req.params.uid, req.body.reason);
  res.status(200).json(result);
});

export const updateRecoveries = asyncHandler(async (req, res) => {
  const result = await performanceBillingService.updateBillRecoveries(req.user, req.params.uid, req.body);
  res.status(200).json(result);
});

export const deleteBill = asyncHandler(async (req, res) => {
  await performanceBillingService.deleteBill(req.user, req.params.uid);
  res.status(200).json({ message: 'Bill deleted' });
});

export const recordPayment = asyncHandler(async (req, res) => {
  const result = await performanceBillingService.recordPayment(req.user, req.params.uid, req.body);
  res.status(200).json(result);
});

export const dashboard = asyncHandler(async (req, res) => {
  const result = await performanceBillingService.getDashboard(req.user, req.query);
  res.status(200).json(result);
});