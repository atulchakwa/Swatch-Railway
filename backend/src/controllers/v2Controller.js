import { v2Service } from '../services/v2Service.js';
import { asyncHandler } from '../middleware/errorHandler.js';

export const getRunInstance = asyncHandler(async (req, res) => {
  const result = await v2Service.getRunInstance(req.params.runInstanceId);
  res.status(200).json(result);
});

export const listRunInstances = asyncHandler(async (req, res) => {
  const result = await v2Service.listRunInstances(req.user, req.query);
  res.status(200).json(result);
});

export const getCoachForm = asyncHandler(async (req, res) => {
  const result = await v2Service.getCoachForm(req.params.formId);
  res.status(200).json(result);
});

export const listCoachForms = asyncHandler(async (req, res) => {
  const result = await v2Service.listCoachForms(req.user, req.query);
  res.status(200).json(result);
});

export const getPremisesForm = asyncHandler(async (req, res) => {
  const result = await v2Service.getPremisesForm(req.params.formId);
  res.status(200).json(result);
});

export const listPremisesForms = asyncHandler(async (req, res) => {
  const result = await v2Service.listPremisesForms(req.user, req.query);
  res.status(200).json(result);
});

export const getCtsForm = asyncHandler(async (req, res) => {
  const result = await v2Service.getCtsForm(req.params.formId);
  res.status(200).json(result);
});

export const listCtsForms = asyncHandler(async (req, res) => {
  const result = await v2Service.listCtsForms(req.user, req.query);
  res.status(200).json(result);
});

export const getCleaningForm = asyncHandler(async (req, res) => {
  const result = await v2Service.getCleaningForm(req.params.uid);
  res.status(200).json(result);
});

export const listCleaningForms = asyncHandler(async (req, res) => {
  const result = await v2Service.listCleaningForms(req.user, req.query);
  res.status(200).json(result);
});

export const getTask = asyncHandler(async (req, res) => {
  const result = await v2Service.getTask(req.params.taskId);
  res.status(200).json(result);
});

export const listTasks = asyncHandler(async (req, res) => {
  const result = await v2Service.listTasks(req.user, req.query);
  res.status(200).json(result);
});

export const listTaskMasters = asyncHandler(async (req, res) => {
  const result = await v2Service.listTaskMasters(req.query);
  res.status(200).json(result);
});

export const createTaskMaster = asyncHandler(async (req, res) => {
  const result = await v2Service.createTaskMaster(req.body, req.user);
  res.status(201).json(result);
});

export const updateTaskMaster = asyncHandler(async (req, res) => {
  const result = await v2Service.updateTaskMaster(req.params.taskCode, req.body, req.user);
  res.status(200).json(result);
});

export const createAssignments = asyncHandler(async (req, res) => {
  const result = await v2Service.createAssignments(req.body, req.user);
  res.status(201).json(result);
});

export const getAssignments = asyncHandler(async (req, res) => {
  const result = await v2Service.getAssignments(req.params.runInstanceId);
  res.status(200).json(result);
});

export const getTasks = asyncHandler(async (req, res) => {
  const result = await v2Service.getTasks(req.params.runInstanceId, req.query);
  res.status(200).json(result);
});

export const submitTask = asyncHandler(async (req, res) => {
  const result = await v2Service.submitTask(req.body, req.user);
  res.status(200).json(result);
});

export const startTask = asyncHandler(async (req, res) => {
  const result = await v2Service.startTask(req.body, req.user);
  res.status(200).json(result);
});

export const verifyTask = asyncHandler(async (req, res) => {
  const result = await v2Service.verifyTask(req.body, req.user);
  res.status(200).json(result);
});

export const closeTask = asyncHandler(async (req, res) => {
  const result = await v2Service.closeTask(req.body, req.user);
  res.status(200).json(result);
});

export const reopenTask = asyncHandler(async (req, res) => {
  const result = await v2Service.reopenTask(req.body, req.user);
  res.status(200).json(result);
});

export const markNotApplicable = asyncHandler(async (req, res) => {
  const result = await v2Service.markNotApplicable(req.body, req.user);
  res.status(200).json(result);
});

export const updateTask = asyncHandler(async (req, res) => {
  const result = await v2Service.updateTask(req.params.taskInstanceId, req.body, req.user);
  res.status(200).json(result);
});

export const createEscalation = asyncHandler(async (req, res) => {
  const result = await v2Service.createEscalation(req.body, req.user);
  res.status(201).json(result);
});

export const resolveEscalation = asyncHandler(async (req, res) => {
  const result = await v2Service.resolveEscalation(req.params.escalationId, req.body, req.user);
  res.status(200).json(result);
});

export const listEscalations = asyncHandler(async (req, res) => {
  const result = await v2Service.listEscalations(req.query);
  res.status(200).json(result);
});

export const getAuditLogs = asyncHandler(async (req, res) => {
  const result = await v2Service.getAuditLogs(req.query);
  res.status(200).json(result);
});

export const getClosureTasks = asyncHandler(async (req, res) => {
  const result = await v2Service.getClosureTasks(req.params.runInstanceId);
  res.status(200).json(result);
});

export const completeClosureTask = asyncHandler(async (req, res) => {
  const result = await v2Service.completeClosureTask(req.body, req.user);
  res.status(200).json(result);
});

export const getWorkerMyTasks = asyncHandler(async (req, res) => {
  const result = await v2Service.getWorkerMyTasks(req.user.uid, req.query);
  res.status(200).json(result);
});

export const getJourneyTimeline = asyncHandler(async (req, res) => {
  const result = await v2Service.getJourneyTimeline(req.params.runInstanceId);
  res.status(200).json(result);
});
