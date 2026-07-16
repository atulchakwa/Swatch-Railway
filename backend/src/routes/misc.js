import express from 'express';
import { verifyToken } from '../middleware/auth.js';
import * as miscController from '../controllers/miscController.js';

const router = express.Router();

router.get('/api/health', miscController.health);
router.get('/api/divisions', verifyToken, miscController.getDivisions);
router.get('/api/depots', verifyToken, miscController.getDepots);
router.get('/api/pincode', verifyToken, miscController.lookupPincode);
router.get('/api/enums/:enumName', verifyToken, miscController.getEnumValues);

export default router;
