/*
 * Task Execution billing engine (50% of the performance score).
 *
 * Payment is derived from ACTUAL CLEANING WORK VALUED BY AREA:
 *
 *   area sqft x rate per sqft  ->  one execution value
 *   AREA -> SQFT -> RATE -> FREQUENCY -> EXECUTION -> DAILY WORK VALUE
 *
 *   1. Daily Expected Work Value      = SUM over areas(sqft x rate x requiredExecutions)
 *   2. Daily Actual Execution Value   = SUM over areas(sqft x rate x completedExecutions)
 *   3. Task Execution Score           = actualExecutionValue / expectedWorkValue x 100
 *
 * The final performance score weights three categories (must total 100):
 *   - Task Execution      (50%)  <- value-weighted achievement
 *   - Railway Inspection  (20%)  <- avg overallScore of the day's inspections
 *   - Passenger Feedback  (30%)  <- avg overallRating / 5 * 100
 * Categories with no data for a day are treated as fully achieved (neutral),
 * mirroring the OBHS / monthly station-billing convention.
 *
 * Financial pipeline (act-of-work valued bill — the score is NEVER multiplied
 * into the work value; it only selects the contract's penalty/deduction rule):
 *   grossEligibleWorkValue = total actual execution value
 *   performancePenalty     = applied by the configured penalty slabs keyed off
 *                            the final performance score
 *   otherDeductions        = configurable contractual deductions
 *   deduction              = performancePenalty + otherDeductions
 *   netAmount              = grossEligibleWorkValue - deduction  (floor 0)
 *   netAmount -> GST -> totalPayable
 *
 * Area weightage is NOT used anywhere in this engine. Each scheduled cleaning
 * pass on a tender area is valued independently at its own sq.ft. x rate; the
 * number of required executions comes from the actual cleaningTasks records for
 * the day. There is NO individual task approval: a task is COMPLETED directly
 * by the contractor supervisor. Completed executions are counted from the day's
 * APPROVED shift summaries (the approval unit) — each approved summary's area
 * entries contribute their `times` to that area's completed executions, capped
 * at the number of tasks required for the area.
 */

import { db } from '../database/index.js';
import { NotFoundError, ValidationError } from '../errors/index.js';
import { auditService } from './auditService.js';
import { roundMoney, mulMoney } from '../utils/money.js';
import { computeContractDays } from '../utils/period.js';
import { performanceBillingService } from './performanceBillingService.js';

const round2 = (n) => Math.round((n + Number.EPSILON) * 100) / 100;
const clamp = (n, lo, hi) => Math.min(hi, Math.max(lo, n));

/* Inclusive list of yyyy-mm-dd dates from start to end (range billing). */
function eachDate(start, end) {
  const out = [];
  const s = new Date(`${String(start).slice(0, 10)}T00:00:00.000Z`);
  const e = new Date(`${String(end).slice(0, 10)}T00:00:00.000Z`);
  if (Number.isNaN(s.getTime()) || Number.isNaN(e.getTime()) || s > e) {
    throw new ValidationError('Invalid or inverted date range');
  }
  for (let d = new Date(s); d <= e; d.setUTCDate(d.getUTCDate() + 1)) {
    out.push(d.toISOString().slice(0, 10));
  }
  return out;
}

const DEFAULT_CATEGORIES = [
  { code: 'EXECUTION', name: 'Task Execution', maxMarks: 50, dataSource: 'execution', enabled: true, order: 1 },
  { code: 'INSPECTION', name: 'Railway Inspection', maxMarks: 20, dataSource: 'inspection', enabled: true, order: 2 },
  { code: 'FEEDBACK', name: 'Passenger Feedback', maxMarks: 30, dataSource: 'feedback', enabled: true, order: 3 },
];

/* ─────────────────────────── Pure calculation helpers ─────────────────────── */

/*
 * Collapse the day's cleaningTasks into per-area rows.
 * meta: { [areaId]: stationArea } with basicAreaSqFt/name/frequency/status.
 * config: billing_configs record (ratePerSqft, areaRateOverrides).
 * approvedSummaries: stationShiftSummaries with status 'approved' for the day.
 * Exercutions are NOT read from task status (tasks have no approval step);
 * they come from approved shift summary entries: each entry contributes its
 * `times` to its area's completed count, capped at the tasks required.
 * Unknown / inactive areas are excluded (a task on a removed area is not billed).
 */
export function aggregateTaskAreaRows(tasks, meta = {}, config = {}, approvedSummaries = []) {
  const ratePerSqft = Number(config.ratePerSqft);
  const overrides = config.areaRateOverrides || {};
  const rateOf = (areaId) => {
    const o = overrides[areaId];
    if (o !== undefined && o !== null && o !== '' && !Number.isNaN(Number(o)) && Number(o) >= 0) return Number(o);
    return ratePerSqft;
  };
  const sqftOf = (a) => {
    const sqft = Number(a.basicAreaSqFt || a.areaSqFt || a.sqft || 0);
    return Number.isFinite(sqft) && sqft >= 0 ? sqft : 0;
  };

  const executedByArea = {};
  (approvedSummaries || []).forEach((summary) => {
    (summary.areas || []).forEach((entry) => {
      const areaId = entry.areaId;
      if (!areaId || !meta[areaId]) return;
      const times = Number(entry.times) || 0;
      executedByArea[areaId] = (executedByArea[areaId] || 0) + times;
    });
  });

  const rows = [];
  const rowMap = {};
  for (const t of tasks || []) {
    const areaId = t.areaId;
    const area = meta[areaId];
    if (!area) continue; // task belongs to an inactive/unknown area
    if (!rowMap[areaId]) {
      rowMap[areaId] = {
        areaId,
        areaName: t.areaName || area.areaName || area.name || '',
        mainArea: area.mainArea || '',
        areaSqft: sqftOf(area),
        ratePerSqft: rateOf(areaId),
        frequency: area.cleaningFrequency || area.frequencyType || '',
        required: 0,
        completed: 0,
      };
      rows.push(rowMap[areaId]);
    }
    rowMap[areaId].required += 1;
  }

  rows.forEach((r) => {
    r.completed = Math.min(r.required, Math.max(0, executedByArea[r.areaId] || 0));
    r.executedSqft = roundMoney(r.areaSqft * r.completed);
    r.expectedSqft = roundMoney(r.areaSqft * r.required);
    r.expectedValue = roundMoney(mulMoney(mulMoney(r.areaSqft, r.ratePerSqft), r.required));
    r.actualExecutionValue = roundMoney(mulMoney(mulMoney(r.areaSqft, r.ratePerSqft), r.completed));
    r.achievement = r.expectedSqft > 0 ? clamp(round2((r.executedSqft / r.expectedSqft) * 100), 0, 100) : null;
  });
  rows.sort((a, b) => (b.expectedValue || 0) - (a.expectedValue || 0));
  return rows;
}

/*
 * Daily task-execution bill (50% component). Pure, DB-free.
 * - areaRows: output of aggregateTaskAreaRows
 * - config:   billing_configs record (categories, penaltyRules, gstRate)
 * - inspection: { count, achievement }  (achievement may be null when no data)
 * - feedback:   { count, achievement }
 * - neutralMissing: treat categories with no data as fully achieved (default).
 */
export function computeDailyTaskBilling({
  areaRows = [],
  config = {},
  inspection = null,
  feedback = null,
  neutralMissing = true,
}) {
  const requiredTotal = areaRows.reduce((s, r) => s + (r.required || 0), 0);
  const completedTotal = areaRows.reduce((s, r) => s + (r.completed || 0), 0);
  const expectedWorkValue = roundMoney(areaRows.reduce((s, r) => s + (r.expectedValue || 0), 0));
  const actualExecutionValue = roundMoney(areaRows.reduce((s, r) => s + (r.actualExecutionValue || 0), 0));
  const expectedSqFt = roundMoney(areaRows.reduce((s, r) => s + (r.expectedSqft || 0), 0));
  const executedSqFt = roundMoney(areaRows.reduce((s, r) => s + (r.executedSqft || 0), 0));
  const taskExecutionScore = expectedWorkValue > 0 ? clamp(round2((actualExecutionValue / expectedWorkValue) * 100), 0, 100) : null;
  const inspectionScore = inspection && inspection.count > 0 ? clamp(round2(inspection.achievement), 0, 100) : null;
  const feedbackScore = feedback && feedback.count > 0 ? clamp(round2(feedback.achievement), 0, 100) : null;

  const cats = (config.categories || DEFAULT_CATEGORIES)
    .filter((c) => c.enabled !== false)
    .sort((a, b) => (a.order || 0) - (b.order || 0));
  const categories = cats.map((c) => {
    let achievement = null;
    let notApplicable = false;
    let count = null;
    if (c.dataSource === 'execution') {
      achievement = taskExecutionScore;
      count = { required: requiredTotal, completed: completedTotal };
    } else if (c.dataSource === 'inspection') {
      count = inspection && inspection.count > 0 ? inspection.count : 0;
      achievement = inspectionScore;
    } else if (c.dataSource === 'feedback') {
      count = feedback && feedback.count > 0 ? feedback.count : 0;
      achievement = feedbackScore;
    }
    if (achievement === null) {
      notApplicable = true;
      achievement = neutralMissing ? 100 : 0;
    }
    const marks = round2(clamp(achievement, 0, 100) * ((Number(c.maxMarks) || 0) / 100));
    return {
      code: c.code, name: c.name, dataSource: c.dataSource, maxMarks: c.maxMarks,
      enabled: c.enabled !== false, achievement, marks, notApplicable, count,
    };
  });

  const overallScore = clamp(round2(categories.reduce((s, c) => s + c.marks, 0)), 0, 100);
  const grade = overallScore >= 90 ? 'A' : overallScore >= 80 ? 'B' : overallScore >= 70 ? 'C' : overallScore >= 60 ? 'D' : 'E';

  // Work value stays work value. The final score only picks the contract's
  // configured performance penalty/deduction rule; it is not multiplied into
  // the actual executed work value.
  const grossEligibleWorkValue = roundMoney(actualExecutionValue);
  const penalty = applyPenaltyRules(config.penaltyRules, overallScore, expectedWorkValue, grossEligibleWorkValue);
  const otherDeductions = roundMoney(Math.max(0, Number(config.otherDeductions) || 0));
  const deduction = roundMoney(penalty.totalPenalty + otherDeductions);
  const netAmount = roundMoney(Math.max(0, grossEligibleWorkValue - deduction));
  const gstRate = Number(config.gstRate) || 0;
  const gstAmount = roundMoney((netAmount * gstRate) / 100);
  const totalPayable = roundMoney(netAmount * (1 + gstRate / 100));

  return {
    expectedWorkValue,
    actualExecutionValue,
    grossAmount: actualExecutionValue,
    grossEligibleWorkValue,
    expectedSqFt,
    executedSqFt,
    taskExecutionScore,
    inspectionScore,
    feedbackScore,
    execution: { achievement: taskExecutionScore, required: requiredTotal, completed: completedTotal },
    areaRows,
    categories,
    inspection: inspection && inspection.count > 0
      ? { count: inspection.count, achievement: inspectionScore }
      : { count: 0, achievement: null },
    feedback: feedback && feedback.count > 0
      ? { count: feedback.count, achievement: feedbackScore }
      : { count: 0, achievement: null },
    overallScore,
    grade,
    performancePenaltyAmount: penalty.totalPenalty,
    otherDeductions,
    penalty,
    deduction,
    netAmount,
    gstRate,
    gstAmount,
    totalPayable,
  };
}

/* First matching enabled slab (score >= from AND score < to) wins. */
export function applyPenaltyRules(rules, overallScore, monthlyBase, eligibleAmount) {
  const enabled = (rules || []).filter((r) => r.enabled !== false).sort((a, b) => a.fromScore - b.fromScore);
  if (enabled.length === 0) return { applied: false, rows: [], totalPenalty: 0 };
  const match = enabled.find((r) => overallScore >= r.fromScore && overallScore < r.toScore) || enabled[enabled.length - 1];
  if (!match || match.action === 'NONE') return { applied: false, rows: [], totalPenalty: 0 };
  let amount = 0;
  if (match.action === 'PERCENT_OF_ELIGIBLE') amount = roundMoney((eligibleAmount * Number(match.value)) / 100);
  else if (match.action === 'PERCENT_OF_MONTHLY_BASE') amount = roundMoney((monthlyBase * Number(match.value)) / 100);
  else if (match.action === 'FIXED_AMOUNT') amount = roundMoney(Number(match.value) || 0);
  if (match.maxAmount && amount > Number(match.maxAmount)) amount = roundMoney(Number(match.maxAmount));
  return {
    applied: true,
    rows: [{
      uid: match.uid, name: match.name, action: match.action, value: match.value,
      fromScore: match.fromScore, toScore: match.toScore, amount,
    }],
    totalPenalty: amount,
  };
}

/* ───────────────────────── Daily task execution billing ───────────────────── */

class TaskExecutionBillingService {
  async _loadContractOrFail(contractId) {
    const doc = await db.collection('contracts').doc(contractId).get();
    if (!doc.exists) throw new NotFoundError('Contract not found');
    return { id: doc.id, ...doc.data() };
  }

  async _loadConfigOrFail(contractId) {
    const config = await performanceBillingService.getOrCreateConfig(contractId);
    const rate = Number(config.ratePerSqft);
    if (Number.isNaN(rate) || rate <= 0) {
      throw new ValidationError('Cleaning rate (₹/sqft per execution) is not configured. Set it in Billing Configuration → General.');
    }
    return config;
  }

  async _loadTasksForDate(stationId, date) {
    let tasks = [];
    try {
      const snap = await db.collection('cleaningTasks').where('stationId', '==', stationId).get();
      snap.forEach((d) => tasks.push({ id: d.id, ...d.data() }));
    } catch {
      /* keep empty */
    }
    return tasks.filter((t) => {
      const d = t.date || t.scheduledDate || '';
      return d === String(date);
    });
  }

  async _loadAllTasksForStation(stationId) {
    let tasks = [];
    try {
      const snap = await db.collection('cleaningTasks').where('stationId', '==', stationId).get();
      snap.forEach((d) => tasks.push({ id: d.id, ...d.data() }));
    } catch {
      /* keep empty */
    }
    return tasks;
  }

  async _loadAreas(stationId) {
    let areas = [];
    try {
      const snap = await db.collection('stationAreas').where('stationId', '==', stationId).get();
      snap.forEach((d) => areas.push({ id: d.id, uid: d.id, ...d.data() }));
    } catch {
      /* keep empty */
    }
    return areas.filter((a) => {
      const s = String(a.status || 'active').toLowerCase();
      return s !== 'inactive' && s !== 'removed';
    });
  }

  async _loadDayInspections(stationId, date) {
    const scores = [];
    try {
      const snap = await db.collection('inspections').where('stationId', '==', stationId).get();
      snap.forEach((d) => {
        const r = d.data();
        const day = String(r.inspectionDate || r.createdAt || '').substring(0, 10);
        if (day === String(date) && ['COMPLETED', 'APPROVED'].includes(r.status) && typeof r.overallScore === 'number' && Number.isFinite(r.overallScore)) {
          scores.push(r.overallScore);
        }
      });
    } catch {
      /* keep empty */
    }
    if (scores.length === 0) return { count: 0, achievement: null };
    return { count: scores.length, achievement: round2(scores.reduce((s, v) => s + v, 0) / scores.length) };
  }

  async _loadAllInspectionsForStation(stationId) {
    let list = [];
    try {
      const snap = await db.collection('inspections').where('stationId', '==', stationId).get();
      snap.forEach((d) => list.push(d.data()));
    } catch {
      /* keep empty */
    }
    return list;
  }

  async _loadDayFeedback(stationId, date) {
    const ratings = [];
    try {
      const snap = await db.collection('passenger_feedback').where('stationId', '==', stationId).get();
      snap.forEach((d) => {
        const r = d.data();
        if (r.status === 'CANCELLED') return;
        const day = String(r.createdAt || '').substring(0, 10);
        if (day === String(date) && typeof r.overallRating === 'number' && Number.isFinite(r.overallRating)) {
          ratings.push(clamp(r.overallRating, 0, 5));
        }
      });
    } catch {
      /* keep empty */
    }
    if (ratings.length === 0) return { count: 0, achievement: null };
    const avg = ratings.reduce((s, v) => s + v, 0) / ratings.length;
    return { count: ratings.length, achievement: round2((avg / 5) * 100) };
  }

  async _loadAllFeedbackForStation(stationId) {
    let list = [];
    try {
      const snap = await db.collection('passenger_feedback').where('stationId', '==', stationId).get();
      snap.forEach((d) => list.push(d.data()));
    } catch {
      /* keep empty */
    }
    return list;
  }

  async _loadApprovedShiftSummaries(stationId, date) {
    let summaries = [];
    try {
      const snap = await db.collection('stationShiftSummaries').where('stationId', '==', stationId).get();
      snap.forEach((d) => summaries.push({ id: d.id, ...d.data() }));
    } catch {
      /* keep empty */
    }
    return summaries.filter((s) => {
      const approved = String(s.status || '').toLowerCase() === 'approved';
      return approved && String(s.date || '') === String(date);
    });
  }

  async _loadAllSummariesForStation(stationId) {
    let summaries = [];
    try {
      const snap = await db.collection('stationShiftSummaries').where('stationId', '==', stationId).get();
      snap.forEach((d) => summaries.push({ id: d.id, ...d.data() }));
    } catch {
      /* keep empty */
    }
    return summaries.filter((s) => String(s.status || '').toLowerCase() === 'approved');
  }

  async prepareDailyBill({ contractId, stationId, date }) {
    if (!contractId || !stationId || !date) {
      throw new ValidationError('contractId, stationId, and date are required');
    }
    const contract = await this._loadContractOrFail(contractId);
    const contractDays = computeContractDays(contract.startDate, contract.endDate);
    if (contractDays <= 0) {
      throw new ValidationError('Contract start/end dates are invalid; cannot determine contract days');
    }
    if ((contract.startDate && date < String(contract.startDate).slice(0, 10)) || (contract.endDate && date > String(contract.endDate).slice(0, 10))) {
      throw new ValidationError(`Date ${date} is outside the contract period`);
    }
    const config = await this._loadConfigOrFail(contractId);
    const [tasks, areas, summaries, inspection, feedback] = await Promise.all([
      this._loadTasksForDate(stationId, date),
      this._loadAreas(stationId),
      this._loadApprovedShiftSummaries(stationId, date),
      this._loadDayInspections(stationId, date),
      this._loadDayFeedback(stationId, date),
    ]);
    const areaMeta = {};
    areas.forEach((a) => { areaMeta[a.id || a.uid] = a; });
    const areaRows = aggregateTaskAreaRows(tasks, areaMeta, config, summaries);
    const calc = computeDailyTaskBilling({ areaRows, config, inspection, feedback });

    return {
      contractId,
      contractNumber: contract.contractNumber || '',
      stationId,
      stationName: contract.stationName || '',
      date,
      contractStartDate: contract.startDate || '',
      contractEndDate: contract.endDate || '',
      contractDays,
      ratePerSqft: Number(config.ratePerSqft),
      executionSource: 'approved_shift_summaries',
      approvedShiftSummaries: summaries.length,
      ...calc,
    };
  }

  async previewDailyBill(params) {
    return this.prepareDailyBill(params);
  }

  /* Consolidated live report for a date range (start..end inclusive). Loads the
     station data ONCE and computes a bill per day, so nothing is duplicated. */
  async previewDailyRange({ contractId, stationId, startDate, endDate }) {
    if (!contractId || !stationId || !startDate || !endDate) {
      throw new ValidationError('contractId, stationId, startDate, and endDate are required');
    }
    const contract = await this._loadContractOrFail(contractId);
    const contractDays = computeContractDays(contract.startDate, contract.endDate);
    if (contractDays <= 0) {
      throw new ValidationError('Contract start/end dates are invalid; cannot determine contract days');
    }
    const config = await this._loadConfigOrFail(contractId);
    const [tasks, areas, summaries, inspections, feedback] = await Promise.all([
      this._loadAllTasksForStation(stationId),
      this._loadAreas(stationId),
      this._loadAllSummariesForStation(stationId),
      this._loadAllInspectionsForStation(stationId),
      this._loadAllFeedbackForStation(stationId),
    ]);

    const areaMeta = {};
    areas.forEach((a) => { areaMeta[a.id || a.uid] = a; });
    const byDate = (date, list, keyFn) =>
      list.filter((x) => keyFn(x) === date);

    const bills = [];
    for (const date of eachDate(startDate, endDate)) {
      const dayTasks = byDate(date, tasks, (t) => t.date || t.scheduledDate || '');
      const daySummaries = byDate(date, summaries, (s) => String(s.date || ''));
      const dayInspection = (() => {
        const scores = byDate(date, inspections, (r) => String(r.inspectionDate || r.createdAt || '').substring(0, 10))
          .filter((r) => ['COMPLETED', 'APPROVED'].includes(r.status) && typeof r.overallScore === 'number' && Number.isFinite(r.overallScore))
          .map((r) => r.overallScore);
        if (scores.length === 0) return { count: 0, achievement: null };
        return { count: scores.length, achievement: round2(scores.reduce((s, v) => s + v, 0) / scores.length) };
      })();
      const dayFeedback = (() => {
        const ratings = byDate(date, feedback, (r) => String(r.createdAt || '').substring(0, 10))
          .filter((r) => r.status !== 'CANCELLED' && typeof r.overallRating === 'number' && Number.isFinite(r.overallRating))
          .map((r) => clamp(r.overallRating, 0, 5));
        if (ratings.length === 0) return { count: 0, achievement: null };
        return { count: ratings.length, achievement: round2((ratings.reduce((s, v) => s + v, 0) / ratings.length / 5) * 100) };
      })();

      const areaRows = aggregateTaskAreaRows(dayTasks, areaMeta, config, daySummaries);
      const calc = computeDailyTaskBilling({ areaRows, config, inspection: dayInspection, feedback: dayFeedback });
      bills.push({
        uid: '',
        contractId,
        contractNumber: contract.contractNumber || '',
        stationId,
        stationName: contract.stationName || '',
        date,
        contractStartDate: contract.startDate || '',
        contractEndDate: contract.endDate || '',
        contractDays,
        ratePerSqft: Number(config.ratePerSqft),
        executionSource: 'approved_shift_summaries',
        approvedShiftSummaries: daySummaries.length,
        status: 'preview',
        generatedByName: '',
        ...calc,
      });
    }
    bills.sort((a, b) => (b.date || '').localeCompare(a.date || ''));
    return this._summarizeBills(bills, { startDate, endDate });
  }

  /* A bill is only reusable when it is a complete current-shape record
     (includes the split work-value / penalty / deduction pipeline). */
  _isCompleteBill(doc) {
    return doc && Number.isFinite(Number(doc.netAmount))
      && Number.isFinite(Number(doc.grossEligibleWorkValue))
      && doc.status === 'generated';
  }

  async generateDailyBill(userData, { contractId, stationId, date, startDate, endDate }) {
    if (startDate && endDate) {
      return this.generateDailyBillRange(userData, { contractId, stationId, startDate, endDate });
    }
    return this._generateOneDay(userData, contractId, stationId, date);
  }

  /* Generate one stored daily bill for a single date without duplicates. */
  async _generateOneDay(userData, contractId, stationId, date) {
    const existingSnap = await db.collection('task_execution_daily_bills')
      .where('contractId', '==', contractId)
      .where('stationId', '==', stationId)
      .where('date', '==', date)
      .get();
    const existing = existingSnap.docs.find((d) => this._isCompleteBill(d.data()));
    if (existing) {
      const d = existing.data();
      await auditService.logAudit('TASK_EXECUTION_DAILY_BILL_REUSED', userData.uid, userData.fullName || 'User', existing.id, 'task_execution_daily_bills', `Existing daily task bill returned for ${date}`);
      return { message: 'Daily task bill already exists (returned as-is)', uid: existing.id, bill: d, reused: true, date };
    }
    // Drop any incomplete/legacy records for the date so they neither block a
    // fresh bill nor produce empty duplicate rows in the monthly report.
    const stale = existingSnap.docs.filter((d) => !this._isCompleteBill(d.data()));
    if (stale.length > 0) {
      await Promise.all(stale.map((d) => d.ref.delete()));
      await auditService.logAudit('TASK_EXECUTION_DAILY_BILL_STALE_REMOVED', userData.uid, userData.fullName || 'User', contractId, 'task_execution_daily_bills', `Removed ${stale.length} incomplete daily bill(s) for ${date}`);
    }

    const preview = await this.prepareDailyBill({ contractId, stationId, date });
    const ref = db.collection('task_execution_daily_bills').doc();
    const now = new Date().toISOString();
    const bill = {
      uid: ref.id,
      ...preview,
      status: 'generated',
      generatedBy: userData.uid,
      generatedByName: userData.fullName || 'User',
      generatedAt: now,
      createdAt: now,
      updatedAt: now,
    };
    await ref.set(bill);
    await auditService.logAudit('TASK_EXECUTION_DAILY_BILL_GENERATED', userData.uid, userData.fullName || 'User', ref.id, 'task_execution_daily_bills', `Daily task bill generated for ${date}`);
    return { message: 'Daily task bill generated', uid: ref.id, bill, reused: false, date };
  }

  /* Generate (or reuse) a stored bill for every date in a range — one per date. */
  async generateDailyBillRange(userData, { contractId, stationId, startDate, endDate }) {
    if (!startDate || !endDate) {
      throw new ValidationError('startDate and endDate are required for range generation');
    }
    const dates = eachDate(startDate, endDate);
    const output = { generated: [], reused: [], failed: [] };
    for (const date of dates) {
      try {
        const r = await this._generateOneDay(userData, contractId, stationId, date);
        (r.reused ? output.reused : output.generated).push({ date, uid: r.uid });
      } catch (e) {
        output.failed.push({ date, error: (e && e.message) || String(e) });
      }
    }
    output.message = `Range billing done: ${output.generated.length} generated, ${output.reused.length} already existed (reused), ${output.failed.length} failed.`;
    return output;
  }

  async getDailyBill({ contractId, stationId, date }) {
    const snap = await db.collection('task_execution_daily_bills')
      .where('contractId', '==', contractId)
      .where('stationId', '==', stationId)
      .where('date', '==', date)
      .limit(1)
      .get();
    if (snap.empty) throw new NotFoundError('Daily task bill not found for this contract/station/date');
    return snap.docs[0].data();
  }

  async listDailyBills({ contractId, stationId, month, year, startDate, endDate } = {}) {
    const prefix = month && year ? `${year}-${String(month).padStart(2, '0')}` : null;
    const rangeMode = !prefix && startDate && endDate;
    const snap = await db.collection('task_execution_daily_bills').limit(1000).get();
    const bills = [];
    snap.forEach((doc) => {
      const d = doc.data();
      const day = String(d.date || '');
      if (contractId && d.contractId !== contractId) return;
      if (stationId && d.stationId !== stationId) return;
      if (prefix && !day.startsWith(prefix)) return;
      if (rangeMode && !(day >= String(startDate) && day <= String(endDate))) return;
      if (!Number.isFinite(Number(d.netAmount)) || !Number.isFinite(Number(d.grossEligibleWorkValue))) return; // skip incomplete/legacy records
      bills.push({ id: doc.id, ...d });
    });
    return this._summarizeBills(bills, { startDate, endDate, month, year });
  }

  _summarizeBills(bills, { startDate, endDate, month, year } = {}) {
    bills.sort((a, b) => (b.date || '').localeCompare(a.date || ''));
    const sum = (k) => roundMoney(bills.reduce((s, b) => s + (Number(b[k]) || 0), 0));
    const avg = (k) => {
      const present = bills.map((b) => Number(b[k])).filter((v) => Number.isFinite(v));
      return present.length > 0 ? round2(present.reduce((s, v) => s + v, 0) / present.length) : null;
    };
    return {
      count: bills.length,
      startDate: startDate || null,
      endDate: endDate || null,
      month: month ? Number(month) : null,
      year: year ? Number(year) : null,
      totalExpectedWorkValue: sum('expectedWorkValue'),
      totalActualExecutionValue: sum('actualExecutionValue'),
      totalGrossAmount: sum('grossAmount'),
      totalPerformancePenalty: sum('performancePenaltyAmount'),
      totalOtherDeductions: sum('otherDeductions'),
      totalDeduction: sum('deduction'),
      totalNetAmount: sum('netAmount'),
      avgTaskExecutionScore: avg('taskExecutionScore'),
      avgInspectionScore: avg('inspectionScore'),
      avgFeedbackScore: avg('feedbackScore'),
      avgFinalScore: avg('overallScore'),
      bills,
    };
  }
}

export const taskExecutionBillingService = new TaskExecutionBillingService();