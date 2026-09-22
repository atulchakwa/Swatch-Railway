/**
 * Annexure-4B — Pure Contractual Rule Functions
 *
 * Contains the financially deterministic rules from Annexure-4B as PURE
 * functions so they can be unit-tested without any Firestore dependency.
 *
 * The service (`annexureBillingService.js`) delegates every financial
 * calculation to these helpers — there must be only one source of truth
 * for the contractual math.
 */

export const VALID_EXEC_STATUSES = ['COMPLETED', 'PARTIALLY_COMPLETED', 'NOT_COMPLETED', 'WAIVED', 'NOT_APPLICABLE'];
export const VALID_UNITS = ['sqft', 'sq.m', 'nos', 'meter', 'unit', 'liter', 'kg', 'set', 'lot'];

const EPS = 0.0001;

/** Total of an effective-weightage list (contract items or area allocations). */
export function sumWeightage(entries) {
  return entries.reduce((sum, e) => sum + (e.effectiveWeightage ?? e.allocatedWeightage ?? 0), 0);
}

/**
 * Contractual total validation warning (Task #18).
 * Never normalizes — only reports and warns.
 */
export function contractTotalWarning(total) {
  if (Math.abs(total - 100) <= EPS) return null;
  return `Contractual item weightages currently total ${total.toFixed(2)}%. Please verify the applicable contract. No automatic normalization has been applied.`;
}

/**
 * Daily Money Value — the contractual deduction formula:
 *   Annual Contract Value × Weightage ÷ 365
 */
export function dailyMoneyValue(annualContractValue, weightagePercent) {
  return (annualContractValue * (weightagePercent / 100)) / 365;
}

/** Deduction for N missed occurrences at a given daily money value. */
export function missedDeduction(dailyValue, missedCount) {
  return dailyValue * (missedCount || 0);
}

/**
 * Area allocation validation (Tasks #5 & #6).
 * SUM(areaWeightage) MUST NOT exceed the parent item's effective weightage.
 * Under-allocation is allowed (remaining weightage stays unallocated).
 *
 * Returns { valid, currentTotal, newTotal, remaining, error }.
 */
export function areaAllocationCheck(currentAllocated, addition, itemLimit, eps = EPS) {
  const currentTotal = round4(currentAllocated);
  const additionValue = round4(addition ?? 0);
  const newTotal = round4(currentTotal + additionValue);
  const remaining = round4(itemLimit - newTotal);
  if (newTotal > round4(itemLimit + eps)) {
    return {
      valid: false,
      currentTotal,
      newTotal,
      remaining: Math.max(remaining, 0),
      error: `Area-wise weightage cannot exceed the contractual weightage of this item. ` +
        `Current allocated: ${currentTotal.toFixed(2)}%, Attempting to add: ${additionValue.toFixed(2)}%, ` +
        `Item limit: ${itemLimit.toFixed(2)}%`,
    };
  }
  return { valid: true, currentTotal, newTotal, remaining, error: null };
}

/**
 * Validation when changing an existing area's weightage (update path).
 * Sums the OTHER active sibling areas + the new value.
 */
export function areaWeightageChangeCheck(othersCurrentTotal, newValue, itemLimit, eps = EPS) {
  return areaAllocationCheck(othersCurrentTotal, newValue, itemLimit, eps);
}

/** Whether an area-level weightage is negative. */
export function invalidNegativeWeightage(value) {
  return value < 0;
}

/**
 * Partial execution treatment (Task #15). We never invent proportional
 * deduction — we flag unless the contract explicitly allows it.
 */
export function partialDeductionNote(partialOccurrences, partialDeductionAllowed) {
  if (!partialOccurrences) return null;
  return partialDeductionAllowed
    ? 'Proportional deduction applied'
    : 'Contractual treatment required — flagged for review';
}

/**
 * Unavailable item → Item 1 weightage transfer (Task #16).
 * Item X's effective weightage moves to Item 1. Item X is NOT deleted —
 * its effective weightage becomes 0 and the transfer is recorded.
 */
export function transferUnavailableWeightage(itemEffectiveWeightage, item1EffectiveWeightage) {
  return {
    transferredWeightage: round4(itemEffectiveWeightage),
    item1After: round4(item1EffectiveWeightage + itemEffectiveWeightage),
  };
}

/**
 * New contractual work item (Task #17).
 * New item takes `newWeightage`; the SAME amount is deducted from Item 1.
 * Returns null when Item 1 has insufficient remaining weightage.
 */
export function addNewItemWeightage(item1EffectiveWeightage, newWeightage, eps = EPS) {
  const w = round4(newWeightage);
  if (item1EffectiveWeightage + eps < w) return null;
  return {
    newItemWeightage: w,
    item1After: round4(item1EffectiveWeightage - w),
  };
}

/** Rounding helper — keep full precision in intermediates, round for presentation. */
export function round4(value) {
  return parseFloat((value).toFixed(4));
}

export function round2(value) {
  return parseFloat((value).toFixed(2));
}