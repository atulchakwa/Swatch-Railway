/*
 * Area Weightage -> Daily Money Value -> Rate -> Billing Deduction model (ECR).
 *
 * There is NO item-weightage hierarchy and NO automatic sqft/count/equal
 * allocation. The ONLY source of allocation is the admin-entered Area
 * Weightage % for every billable area. The sum must equal 100%.
 *
 *   Daily Contract Value   = Annual Contract Value / Contract Days
 *   Area Daily Money Value = (Annual Contract Value x Area Weightage) / 100 / Contract Days
 *   Area Rate per SqFt     = Area Daily Money Value / Area SqFt   (READ-ONLY)
 *   Per-Execution Value    = Area Daily Money Value / Required Executions
 *   Missed-Exec Deduction  = Per-Execution Value x Missed Executions
 *
 * Contract Days are the inclusive days of the actual contract period (e.g. a
 * 14-day contract divides the ACV by 14). When no contract period is known the
 * model falls back to 365 days.
 *
 * The rate is always DERIVED from the daily money value and is never a
 * manually entered default. Money values are rounded to 2dp; the rate is
 * kept at 4dp so rounding does not create billing inaccuracies.
 */

import { ValidationError } from '../errors/index.js';

export const WEIGHTAGE_TOLERANCE = 0.01;

const round2 = (n) => Math.round((n + Number.EPSILON) * 100) / 100;
const round4 = (n) => Math.round((n + Number.EPSILON) * 10000) / 10000;

/** Daily Contract Value = Annual Contract Value / Contract Days (default 365). */
export function dailyContractValue(annualContractValue, contractDays = 365) {
  const acv = Number(annualContractValue) || 0;
  const days = Number(contractDays) > 0 ? Number(contractDays) : 365;
  return round2(acv / days);
}

/** Area Daily Money Value = (ACV x weightage) / 100 / Contract Days (default 365). */
export function areaDailyMoneyValue(annualContractValue, weightage, contractDays = 365) {
  const acv = Number(annualContractValue) || 0;
  const w = Number(weightage) || 0;
  const days = Number(contractDays) > 0 ? Number(contractDays) : 365;
  return round2((acv * w) / 100 / days);
}

/** Area Rate per SqFt = Area Daily Money Value / Area SqFt (read-only, 4dp). */
export function areaRatePerSqFt(areaDailyValue, sqft) {
  const d = Number(areaDailyValue) || 0;
  const s = Number(sqft) || 0;
  if (d <= 0 || s <= 0) return 0;
  return round4(d / s);
}

/** Per-Execution Value = Area Daily Money Value / Required Executions. */
export function perExecutionValue(areaDailyValue, requiredExecutions) {
  const d = Number(areaDailyValue) || 0;
  const r = Number(requiredExecutions) || 0;
  if (d <= 0 || r <= 0) return 0;
  return round2(d / r);
}

/** Missed-Execution Deduction = Per-Execution Value x Missed Executions. */
export function executionDeduction(perExec, missed) {
  const p = Number(perExec) || 0;
  const m = Number(missed) || 0;
  if (p <= 0 || m <= 0) return 0;
  return round2(p * m);
}

/**
 * Validate a weightage map:
 *  - every value must be 0..100
 *  - when any weightages exist, they must total 100% (tolerance 0.01)
 *  - when `areas` is provided, every active (billable) area must have an entry
 * Returns nothing; throws ValidationError on failure.
 */
export function validateAreaWeightages(weightages, areas = []) {
  if (!weightages || typeof weightages !== 'object') {
    throw new ValidationError('Area weightages must be a map of areaId to percentage');
  }
  const entries = Object.entries(weightages);
  for (const [areaId, val] of entries) {
    const n = Number(val);
    if (Number.isNaN(n) || n < 0 || n > 100) {
      throw new ValidationError(`Weightage for area "${areaId}" must be between 0 and 100`);
    }
  }
  if (entries.length > 0) {
    const total = entries.reduce((s, [, v]) => s + Number(v), 0);
    if (Math.abs(total - 100) > WEIGHTAGE_TOLERANCE) {
      throw new ValidationError(`Area weightages must total exactly 100% (currently ${round2(total)}%)`);
    }
  }
  const billable = areas.filter((a) => {
    const status = String(a.status || 'active').toLowerCase();
    return status !== 'inactive' && status !== 'removed';
  });
  for (const a of billable) {
    const key = a.id || a.uid;
    if (key && (weightages[key] === undefined || weightages[key] === null || weightages[key] === '')) {
      throw new ValidationError(`Weightage is required for active area "${a.areaName || a.name || key}"`);
    }
  }
}

/**
 * Build a per-area weightage money view for a billing period.
 * Returns a row containing the derived values (rate is read-only, so the
 * backend always recalculates it rather than trusting a client value).
 */
export function buildWeightageAreaRow({ areaId, areaName, sqft, weightage, annualContractValue, requiredExecutions, completedExecutions, contractDays = 365 }) {
  const areaIdKey = String(areaId || '');
  const w = Number(weightage) || 0;
  const acv = Number(annualContractValue) || 0;
  const required = Number(requiredExecutions) || 0;
  const completed = Number(completedExecutions) || 0;
  const missed = Math.max(0, required - completed);
  const daily = areaDailyMoneyValue(acv, w, contractDays);
  const perExec = perExecutionValue(daily, required);
  const scheduledValue = round2(perExec * required); // full day's money value
  const actualExecutedValue = round2(perExec * completed);
  const deduction = executionDeduction(perExec, missed);
  return {
    areaId: areaIdKey,
    areaName: areaName || '',
    areaSqFt: Number(sqft) || 0,
    annualContractValue: acv,
    contractDays: Number(contractDays) > 0 ? Number(contractDays) : 365,
    dailyContractValue: dailyContractValue(acv, contractDays),
    areaWeightage: w,
    areaDailyMoneyValue: daily,
    ratePerSqFt: areaRatePerSqFt(daily, sqft),
    requiredExecutions: required,
    completedExecutions: completed,
    missedExecutions: missed,
    perExecutionValue: perExec,
    scheduledValue,
    actualExecutedValue,
    executionDeduction: deduction,
  };
}