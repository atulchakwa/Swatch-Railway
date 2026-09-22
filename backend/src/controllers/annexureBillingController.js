/**
 * Annexure-4B Billing Controller
 */
import { annexureBillingService } from '../services/annexureBillingService.js';
import { asyncHandler } from '../middleware/errorHandler.js';

// ─── Contract Items ──────────────────────────────────────────────────────────

export const seedContractItems = asyncHandler(async (req, res) => {
  const { contractId } = req.params;
  const result = await annexureBillingService.seedContractItems(contractId, req.user);
  res.status(201).json(result);
});

export const getContractItems = asyncHandler(async (req, res) => {
  const { contractId } = req.params;
  const result = await annexureBillingService.getContractItems(contractId, req.user);
  res.status(200).json(result);
});

export const getContractItemById = asyncHandler(async (req, res) => {
  const result = await annexureBillingService.getContractItemById(req.params.itemId);
  res.status(200).json(result);
});

export const updateContractItem = asyncHandler(async (req, res) => {
  const result = await annexureBillingService.updateContractItem(req.params.itemId, req.body, req.user);
  res.status(200).json(result);
});

export const markItemUnavailable = asyncHandler(async (req, res) => {
  const { reason } = req.body;
  const result = await annexureBillingService.markItemUnavailable(req.params.itemId, req.user, reason);
  res.status(200).json(result);
});

export const addNewContractItem = asyncHandler(async (req, res) => {
  const { contractId } = req.params;
  const result = await annexureBillingService.addNewContractItem(contractId, req.body, req.user);
  res.status(201).json(result);
});

export const getWeightageTransfers = asyncHandler(async (req, res) => {
  const { contractId } = req.params;
  const result = await annexureBillingService.getWeightageTransfers(contractId);
  res.status(200).json(result);
});

export const getMasterItems = asyncHandler(async (req, res) => {
  const result = annexureBillingService.getMasterItems();
  res.status(200).json(result);
});

export const validateContractWeightage = asyncHandler(async (req, res) => {
  const { contractId } = req.params;
  const result = await annexureBillingService.validateContractWeightage(contractId);
  res.status(200).json(result);
});

// ─── Area Components ─────────────────────────────────────────────────────────

export const addAreaComponent = asyncHandler(async (req, res) => {
  const { itemId } = req.params;
  const result = await annexureBillingService.addAreaComponent(itemId, req.body, req.user);
  res.status(201).json(result);
});

export const updateAreaComponent = asyncHandler(async (req, res) => {
  const result = await annexureBillingService.updateAreaComponent(req.params.areaId, req.body, req.user);
  res.status(200).json(result);
});

export const deleteAreaComponent = asyncHandler(async (req, res) => {
  const result = await annexureBillingService.deleteAreaComponent(req.params.areaId, req.user);
  res.status(200).json(result);
});

export const getAreasForItem = asyncHandler(async (req, res) => {
  const result = await annexureBillingService.getAreasForItem(req.params.itemId);
  res.status(200).json(result);
});

// ─── Executions ──────────────────────────────────────────────────────────────

export const recordExecution = asyncHandler(async (req, res) => {
  const result = await annexureBillingService.recordExecution(req.body, req.user);
  res.status(201).json(result);
});

export const updateExecution = asyncHandler(async (req, res) => {
  const result = await annexureBillingService.updateExecution(req.params.executionId, req.body, req.user);
  res.status(200).json(result);
});

export const getExecutions = asyncHandler(async (req, res) => {
  const result = await annexureBillingService.getExecutions(req.query);
  res.status(200).json(result);
});

// ─── Billing / Deductions ────────────────────────────────────────────────────

export const calculateBillingDeductions = asyncHandler(async (req, res) => {
  const { contractId, billingStart, billingEnd } = req.body;
  const result = await annexureBillingService.calculateBillingDeductions(contractId, billingStart, billingEnd, req.user);
  res.status(201).json(result);
});

export const finalizeBillingDeductions = asyncHandler(async (req, res) => {
  const { contractId, billingStart, billingEnd } = req.body;
  const result = await annexureBillingService.finalizeBillingDeductions(contractId, billingStart, billingEnd, req.user);
  res.status(200).json(result);
});

export const getBillingDeductions = asyncHandler(async (req, res) => {
  const result = await annexureBillingService.getBillingDeductions(req.query);
  res.status(200).json(result);
});

export const getBillingSummary = asyncHandler(async (req, res) => {
  const { contractId } = req.params;
  const { billingStart, billingEnd } = req.query;
  const result = await annexureBillingService.getBillingSummary(contractId, billingStart, billingEnd);
  res.status(200).json(result);
});
