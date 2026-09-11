import express from 'express';
import { verifyToken } from '../middleware/auth.js';
import * as runInstanceController from '../controllers/runInstanceController.js';

const router = express.Router();

router.post('/', verifyToken, runInstanceController.create);
router.put('/:runInstanceId', verifyToken, runInstanceController.update);
router.get('/', verifyToken, runInstanceController.list);
router.get('/train/:parentTrainId', verifyToken, runInstanceController.getByParentTrain);
router.delete('/:runInstanceId', verifyToken, runInstanceController.remove);
router.post('/:runInstanceId/activate', verifyToken, runInstanceController.activateJourney);
router.post('/:runInstanceId/complete', verifyToken, runInstanceController.completeJourney);
router.get('/active-run', verifyToken, runInstanceController.getActiveRunForWorker);

export default router;
