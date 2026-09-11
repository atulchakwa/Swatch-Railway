import { contractService } from '../services/contractService.js';
import { asyncHandler } from '../middleware/errorHandler.js';

export const createContract = asyncHandler(async (req, res) => {
  const result = await contractService.createContract(req.user, req.body);
  res.status(201).json(result);
});

export const updateContract = asyncHandler(async (req, res) => {
  const result = await contractService.updateContract(req.user, req.params.uid, req.body);
  res.status(200).json(result);
});

export const getContracts = asyncHandler(async (req, res) => {
  const result = await contractService.getContracts(req.user, req.query);
  res.status(200).json(result);
});

export const getContractByUid = asyncHandler(async (req, res) => {
  const result = await contractService.getContractByUid(req.params.uid, req.user);
  res.status(200).json(result);
});

export const getContractByNumber = asyncHandler(async (req, res) => {
  const result = await contractService.getContractByNumber(req.params.contractNumber);
  res.status(200).json(result);
});

export const getContractsByEntity = asyncHandler(async (req, res) => {
  const result = await contractService.getContractsByEntity(req.params.entityId, req.query);
  res.status(200).json(result);
});

export const getContractsForDropdown = asyncHandler(async (req, res) => {
  const result = await contractService.getContractsForDropdown(req.user, req.query);
  res.status(200).json(result);
});

export default { createContract, updateContract, getContracts, getContractByUid, getContractByNumber, getContractsByEntity, getContractsForDropdown };
