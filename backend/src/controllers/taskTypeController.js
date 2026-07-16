import { taskTypeService } from '../services/taskTypeService.js';
import { asyncHandler } from '../middleware/errorHandler.js';

export const createTaskType = asyncHandler(async (req, res) => {
  const result = await taskTypeService.createTaskType(req.body);
  res.status(201).json(result);
});

export const listTaskTypes = asyncHandler(async (req, res) => {
  const result = await taskTypeService.getTaskTypes(req.query);
  res.status(200).json(result);
});

export const updateTaskType = asyncHandler(async (req, res) => {
  const result = await taskTypeService.updateTaskType(req.params.id, req.body);
  res.status(200).json(result);
});

export const deleteTaskType = asyncHandler(async (req, res) => {
  const result = await taskTypeService.deleteTaskType(req.params.id);
  res.status(200).json(result);
});

export const seedTaskTypes = asyncHandler(async (req, res) => {
  const result = await taskTypeService.seedDefaultTaskTypes();
  res.status(200).json(result);
});
