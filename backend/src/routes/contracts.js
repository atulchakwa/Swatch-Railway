import { Router } from 'express';
import { verifyToken } from '../middleware/auth.js';
import { requirePermission } from '../middleware/authorization.js';
import { PERMISSIONS } from '../permissions/roles.js';
import contractController from '../controllers/contractController.js';

const router = Router();

router.post('/api/contracts', verifyToken, requirePermission(PERMISSIONS.CREATE_CONTRACT), contractController.createContract);
router.put('/api/contracts/:uid', verifyToken, requirePermission(PERMISSIONS.UPDATE_CONTRACT), contractController.updateContract);
router.get('/api/contracts', verifyToken, requirePermission(PERMISSIONS.VIEW_CONTRACTS), contractController.getContracts);
router.get('/api/contracts/for-user-creation', verifyToken, contractController.getContractsForDropdown);
router.get('/api/contracts/:uid', verifyToken, requirePermission(PERMISSIONS.VIEW_CONTRACTS), contractController.getContractByUid);
router.get('/api/contracts/number/:contractNumber', verifyToken, requirePermission(PERMISSIONS.VIEW_CONTRACTS), contractController.getContractByNumber);
router.get('/api/contracts/by-entity/:entityId', verifyToken, requirePermission(PERMISSIONS.VIEW_CONTRACTS), contractController.getContractsByEntity);

export default router;
