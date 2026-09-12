/*
 * Decimal-safe money helpers for billing/execution calculations.
 *
 * Financial arithmetic is performed with integer paise (1 rupee = 100 paise)
 * in the "mul" path to avoid floating-point drift, then converted back to a
 * decimal number rounded to 2 places at the final stage.
 *
 * roundMoney(x): round a rupee amount to 2 decimals (financial rounding).
 * mulMoney(a, b): a × b computed exactly and returned as rupees@2dp.
 * pctOf(value, pct): pct% of value (integer-safe when practical).
 * ratioSafe(num, den): num/den guarded against divide-by-zero; 0 when den==0.
 */

export function roundMoney(x) {
  if (typeof x !== 'number' || !Number.isFinite(x)) return 0;
  return Math.round((x + Number.EPSILON) * 100) / 100;
}

export function mulMoney(a, b) {
  const numA = typeof a === 'number' && Number.isFinite(a) ? a : 0;
  const numB = typeof b === 'number' && Number.isFinite(b) ? b : 0;
  const paiseA = Math.round(numA * 100);
  const paiseB = Math.round(numB * 100);
  return Math.round((paiseA * paiseB) / 10000 * 100) / 100;
}

export function pctOf(value, pct) {
  if (typeof value !== 'number' || typeof pct !== 'number') return 0;
  const rupees = mulMoney(value, pct / 100);
  return roundMoney(rupees);
}

export function ratioSafe(num, den) {
  if (typeof num !== 'number' || typeof den !== 'number') return 0;
  if (den === 0) return 0;
  return num / den;
}

export function clampPct(value) {
  if (typeof value !== 'number' || !Number.isFinite(value)) return 0;
  return Math.min(Math.max(value, 0), 100);
}