/*
 * Task Execution billing engine (50% billing component).
 *
 * - Per-area weightage configuration (railway department can increase/decrease
 *   a weightage; every change is versioned and audited).
 * - Per-sq.ft. execution billing: approved shift summaries carry per-area
 *   workDone (= basicAreaSqFt × times-cleaned) and tenderedAreaPerDay, so a
 *   day's bill is executed sq.ft. × rate per sq.ft.
 * - Daily task bills are stored and immutable once generated (historical
 *   consistency); regenerating for the same contract/station/date returns the
 *   existing bill instead of silently recomputing it.
 *
 * The calculation is monthly AND daily: the daily task bill is
 *   dailyBaseTask = contractValue / contractDays × 50%
 *   ratePerSqFt   = dailyBaseTask / Σ expected sq.ft. per day
 *   areaGross     = min(executedSqFt, expectedSqFt × excessAllowance) × ratePerSqFt
 * The monthly pack (stationBillingService) consumes the weighted execution
 * score derived from the same per-area rows.
 */

import { db } from '../database/index.js';
import { NotFoundError, ValidationError } from '../errors/index.js';
import { auditService } from './auditService.js';
import { roundMoney, ratioSafe, clampPct } from '../utils/money.js';
import { computeContractDays, monthRange, parseDate } from '../utils/period.js';

/* ─────────────────────────── Pure calculation helpers ─────────────────────── */

/* Flatten approved shift-summary areas into per-area aggregates. */
export function aggregateAreaExecution(approvedSummaries) {
  const rows = {};
  const push = (summary, area) => {
    const key = String(area.areaName || area.areaId || 'other').trim();
    const executed = parseFloat(area.workDone) || 0;
    const expected = parseFloat(area.tenderedAreaPerDay) || 0;
    if (!rows[key]) {
      rows[key] = {
        areaName: key,
        areaId: area.areaId || '',
        mainArea: area.mainArea || '',
        executedSqFt: 0,
        expectedSqFt: 0,
        times: 0,
        days: 0,
        cleaningFrequency: area.cleaningFrequency || '',
      };
    }
    rows[key].executedSqFt += executed;
    rows[key].expectedSqFt += expected;
    rows[key].times += parseInt(area.times, 10) || 0;
    rows[key].days += 1;
  };
  for (const summary of approvedSummaries || []) {
    for (const area of Array.isArray(summary.areas) ? summary.areas : []) push(summary, area);
  }
  const result = Object.values(rows);
  for (const r of result) r.ratio = r.expectedSqFt > 0 ? Math.min(r.executedSqFt / r.expectedSqFt, 1) : 1;
  return result;
}

/*
 * Weighted execution score (0-100) from per-area rows + weightage config.
 * weightages: { [areaName]: { weightage: number, ... } }. Uses configured
 * weightages when present, otherwise falls back to a flat (unweighted) ratio.
 */
export function computeWeightedExecutionScore(areaRows, weightageConfig = []) {
  const weightMap = {};
  for (const w of weightageConfig || []) {
    const name = String(w.areaName || '').trim();
    if (name) weightMap[name] = parseFloat(w.weightage) || 0;
  }
  const configured = Object.keys(weightMap).length > 0;
  let weightedSum = 0;
  let weightTotal = 0;
  let executedTotal = 0;
  let expectedTotal = 0;
  for (const row of areaRows || []) {
    executedTotal += row.executedSqFt || 0;
    expectedTotal += row.expectedSqFt || 0;
    const w = configured ? weightMap[row.areaName] : undefined;
    if (configured && w !== undefined) {
      weightedSum += w * (row.ratio || 1);
      weightTotal += w;
    }
  }
  let weightedScore = null;
  if (configured) {
    weightedScore = weightTotal > 0 ? clampPct((weightedSum / weightTotal) * 100) : null;
  } else if (expectedTotal > 0) {
    weightedScore = clampPct(Math.min(executedTotal / expectedTotal, 1) * 100);
  }
  return {
    configured,
    areaRows,
    executedSqFt: roundMoney(executedTotal),
    expectedSqFt: roundMoney(expectedTotal),
    weightedScore: weightedScore === null ? null : Math.round(weightedScore * 100) / 100,
  };
}

/*
 * Daily task-execution bill (50% component).
 * expectedSqFtForRate = Σ per-day expected sq.ft across the whole contract set
 * of tender areas; here approximated from the day's approved areas when the
 * configured tender totals are absent. weightageConfig may carry a configured
 * ratePerSqFt override per area.
 */
export function computeDailyTaskBilling({
  annualValue = 0,
  contractDays = 1,
  approvedSummaries = [],
  weightageConfig = [],
  excessThreshold = 1,
  ratePerSqFtOverride = null,
}) {
  const rows = aggregateAreaExecution(approvedSummaries);
  const rateMap = {};
  for (const w of weightageConfig || []) {
    const name = String(w.areaName || '').trim();
    if (name && parseFloat(w.ratePerSqFt)) rateMap[name] = parseFloat(w.ratePerSqFt);
  }
  const dailyBaseTask = roundMoney((annualValue / contractDays) * 0.50);
  const expectedTotal = rows.reduce((s, r) => s + r.expectedSqFt, 0);
  const executedTotal = rows.reduce((s, r) => s + r.executedSqFt, 0);
  const derivedRate = expectedTotal > 0 ? dailyBaseTask / expectedTotal : 0;
  const excessAllowed = Math.max(parseFloat(excessThreshold) || 1, 0);

  let grossAmount = 0;
  let deduction = 0;
  const lines = rows.map((r) => {
    const rate = ratePerSqFtOverride !== null ? parseFloat(ratePerSqFtOverride) : (rateMap[r.areaName] || derivedRate);
    const billableSqFt = Math.min(r.executedSqFt, r.expectedSqFt * excessAllowed);
    const amount = roundMoney(billableSqFt * rate);
    const areaExpectedAmount = roundMoney(r.expectedSqFt * rate);
    const areaDeduction = areaExpectedAmount > amount ? roundMoney(areaExpectedAmount - amount) : 0;
    grossAmount += amount;
    deduction += areaDeduction;
    return {
      areaName: r.areaName,
      areaId: r.areaId,
      mainArea: r.mainArea,
      executedSqFt: r.executedSqFt,
      expectedSqFt: r.expectedSqFt,
      executionRatio: Math.round(r.ratio * 1000) / 1000,
      billableSqFt,
      ratePerSqFt: roundMoney(rate),
      areaAmount: amount,
      deduction: areaDeduction,
    };
  });
  grossAmount = roundMoney(grossAmount);
  deduction = roundMoney(deduction);
  const dayExecutionRate = expectedTotal > 0 ? roundMoney(Math.min(executedTotal / expectedTotal, 1) * 100) : null;
  return {
    rows: lines,
    dailyBaseTask,
    expectedSqFt: roundMoney(expectedTotal),
    executedSqFt: roundMoney(executedTotal),
    dayExecutionRate,
    grossAmount,
    deduction,
    netAmount: roundMoney(Math.max(grossAmount, 0)),
    excessAllowed: excessAllowed === 1 ? false : excessAllowed,
  };
}

/* ─────────────────────── Area weightage configuration ─────────────────────── */

class TaskExecutionBillingService {
  async getWeightages({ contractId, stationId, status = 'active' } = {}) {
    let query = db.collection('contract_area_weightages');
    if (status) query = query.where('status', '==', status);
    const snap = await query.get();
    const result = [];
    snap.forEach((doc) => {
      const d = doc.data();
      if (contractId && d.contractId !== contractId) return;
      if (stationId && d.stationId !== stationId) return;
      result.push({ id: doc.id, ...d });
    });
    result.sort((a, b) => (a.areaName || '').localeCompare(b.areaName || ''));
    const totalWeightage = result.reduce((s, r) => s + (parseFloat(r.weightage) || 0), 0);
    return { count: result.length, totalWeightage: roundMoney(totalWeightage), weightages: result };
  }

  async upsertWeightage(userData, body) {
    const { contractId, stationId, areaName, weightage } = body;
    if (!contractId || !stationId || !areaName) {
      throw new ValidationError('contractId, stationId, and areaName are required');
    }
    const w = parseFloat(weightage);
    if (weightage === undefined || weightage === null || Number.isNaN(w) || w < 0 || w > 100) {
      throw new ValidationError('weightage must be a percentage between 0 and 100');
    }
    const contractDoc = await db.collection('contracts').doc(contractId).get();
    if (!contractDoc.exists) throw new NotFoundError('Contract not found');

    const weightageValue = roundMoney(w);
    const tenderedAreaSqFt = parseFloat(body.tenderedAreaSqFt) || 0;
    const ratePerSqFt = body.ratePerSqFt !== undefined && body.ratePerSqFt !== null && body.ratePerSqFt !== ''
      ? roundMoney(parseFloat(body.ratePerSqFt))
      : null;
    const now = new Date().toISOString();

    const existingSnap = await db.collection('contract_area_weightages')
      .where('contractId', '==', contractId)
      .where('stationId', '==', stationId)
      .where('areaName', '==', String(areaName).trim())
      .limit(1)
      .get();

    if (existingSnap.empty) {
      const ref = db.collection('contract_area_weightages').doc();
      const data = {
        uid: ref.id,
        contractId,
        contractNumber: body.contractNumber || contractDoc.data().contractNumber || '',
        stationId,
        stationName: body.stationName || contractDoc.data().stationName || '',
        areaName: String(areaName).trim(),
        mainArea: body.mainArea || '',
        annexureItemNo: body.annexureItemNo !== undefined && body.annexureItemNo !== null && body.annexureItemNo !== ''
          ? parseInt(body.annexureItemNo, 10) || null
          : null,
        weightage: weightageValue,
        tenderedAreaSqFt,
        cleaningFrequency: body.cleaningFrequency || 'daily',
        boqTimesPerPeriod: parseInt(body.boqTimesPerPeriod, 10) || 0,
        ratePerSqFt,
        status: 'active',
        version: 1,
        history: [],
        createdBy: userData.uid,
        createdAt: now,
        updatedAt: now,
      };
      await ref.set(data);
      await auditService.logAudit('TASK_EXECUTION_WEIGHTAGE_CREATED', userData.uid, userData.fullName || 'User', ref.id, 'contract_area_weightages', `Area weightage ${areaName} created (${weightageValue}%)`);
      return { message: 'Area weightage created', uid: ref.id, weightage: data };
    }

    const ref = existingSnap.docs[0].ref;
    const current = existingSnap.docs[0].data();
    const history = Array.isArray(current.history) ? current.history : [];
    history.push({
      weightage: parseFloat(current.weightage) || 0,
      tenderedAreaSqFt: current.tenderedAreaSqFt || 0,
      ratePerSqFt: current.ratePerSqFt || null,
      changedBy: userData.uid,
      changedByName: userData.fullName || 'User',
      changedAt: current.updatedAt || now,
    });
    const updates = {
      weightage: weightageValue,
      version: (current.version || 1) + 1,
      history,
      updatedBy: userData.uid,
      updatedByName: userData.fullName || 'User',
      updatedAt: now,
    };
    if (tenderedAreaSqFt > 0) updates.tenderedAreaSqFt = tenderedAreaSqFt;
    if (body.mainArea !== undefined) updates.mainArea = body.mainArea || '';
    if (body.annexureItemNo !== undefined) updates.annexureItemNo = body.annexureItemNo === null || body.annexureItemNo === '' ? null : (parseInt(body.annexureItemNo, 10) || null);
    if (body.cleaningFrequency !== undefined) updates.cleaningFrequency = body.cleaningFrequency;
    if (parseInt(body.boqTimesPerPeriod, 10) > 0) updates.boqTimesPerPeriod = parseInt(body.boqTimesPerPeriod, 10);
    if (ratePerSqFt !== null) updates.ratePerSqFt = ratePerSqFt;
    await ref.update(updates);
    await auditService.logAudit('TASK_EXECUTION_WEIGHTAGE_UPDATED', userData.uid, userData.fullName || 'User', ref.id, 'contract_area_weightages', `Area weightage ${areaName} updated to ${weightageValue}% (v${(current.version || 1) + 1})`);
    return { message: 'Area weightage updated', uid: ref.id, version: (current.version || 1) + 1 };
  }

  async deleteWeightage(uid, userData) {
    const ref = db.collection('contract_area_weightages').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Area weightage not found');
    await ref.update({ status: 'inactive', updatedBy: userData.uid, updatedAt: new Date().toISOString() });
    await auditService.logAudit('TASK_EXECUTION_WEIGHTAGE_DEACTIVATED', userData.uid, userData.fullName || 'User', uid, 'contract_area_weightages', `Area weightage ${doc.data().areaName} deactivated`);
    return { message: 'Area weightage deactivated', uid };
  }

  /* ─────────────────────── Daily task execution billing ─────────────────────── */

  async _loadApprovedSummaries({ contractId, stationId, date, month, year }) {
    let query = db.collection('stationShiftSummaries').where('stationId', '==', stationId);
    let snapshot;
    try {
      snapshot = month && year
        ? await query.where('date', '>=', monthRange(month, year).start).where('date', '<=', monthRange(month, year).end).get()
        : await query.where('date', '==', date).get();
    } catch {
      snapshot = await query.get();
    }
    const approved = [];
    snapshot.forEach((doc) => {
      const r = doc.data();
      if (r.status !== 'approved') return;
      if (month && year) {
        const prefix = `${year}-${String(month).padStart(2, '0')}`;
        if (!(r.date || '').startsWith(prefix)) return;
      } else if (date && r.date !== date) {
        return;
      }
      approved.push({ id: doc.id, ...r });
    });
    return approved;
  }

  async _loadContractOrFail(contractId) {
    const doc = await db.collection('contracts').doc(contractId).get();
    if (!doc.exists) throw new NotFoundError('Contract not found');
    return { id: doc.id, ...doc.data() };
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
    if (!date || (contract.startDate && date < String(contract.startDate).slice(0, 10)) || (contract.endDate && date > String(contract.endDate).slice(0, 10))) {
      throw new ValidationError(`Date ${date} is outside the contract period`);
    }
    const approved = await this._loadApprovedSummaries({ contractId, stationId, date });
    const weightages = await this.getWeightages({ contractId, stationId });
    const calc = computeDailyTaskBilling({
      annualValue: contract.contractValue || 0,
      contractDays,
      approvedSummaries: approved,
      weightageConfig: weightages.weightages,
    });
    const weighted = computeWeightedExecutionScore(calc.rows, weightages.weightages);
    return {
      contractId,
      contractNumber: contract.contractNumber || '',
      stationId,
      stationName: contract.stationName || '',
      date,
      contractStartDate: contract.startDate || '',
      contractEndDate: contract.endDate || '',
      contractDays,
      summary: calc,
      weighted,
    };
  }

  async previewDailyBill(params) {
    return this.prepareDailyBill(params);
  }

  async generateDailyBill(userData, { contractId, stationId, date }) {
    const existingSnap = await db.collection('task_execution_daily_bills')
      .where('contractId', '==', contractId)
      .where('stationId', '==', stationId)
      .where('date', '==', date)
      .limit(1)
      .get();
    if (!existingSnap.empty) {
      const d = existingSnap.docs[0].data();
      await auditService.logAudit('TASK_EXECUTION_DAILY_BILL_REUSED', userData.uid, userData.fullName || 'User', existingSnap.docs[0].id, 'task_execution_daily_bills', `Existing daily task bill returned for ${date}`);
      return { message: 'Daily task bill already exists (returned as-is)', uid: existingSnap.docs[0].id, bill: d, reused: true };
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
    return { message: 'Daily task bill generated', uid: ref.id, bill, reused: false };
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

  async listDailyBills({ contractId, stationId, month, year } = {}) {
    const prefix = month && year ? `${year}-${String(month).padStart(2, '0')}` : null;
    const snap = await db.collection('task_execution_daily_bills').limit(1000).get();
    const bills = [];
    snap.forEach((doc) => {
      const d = doc.data();
      if (contractId && d.contractId !== contractId) return;
      if (stationId && d.stationId !== stationId) return;
      if (prefix && !(d.date || '').startsWith(prefix)) return;
      bills.push({ id: doc.id, ...d });
    });
    bills.sort((a, b) => (b.date || '').localeCompare(a.date || ''));
    const gross = bills.reduce((s, b) => s + (b.summary?.netAmount || 0), 0);
    return { count: bills.length, totalNetAmount: roundMoney(gross), bills };
  }
}

export const taskExecutionBillingService = new TaskExecutionBillingService();