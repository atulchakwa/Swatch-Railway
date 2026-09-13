/*
 * Contract-period helpers. Contract days are always derived from the actual
 * start/end dates configured on the contract; the engine never hardcodes a
 * fixed number (e.g. 1461) for the whole contract.
 */

export function parseDate(value) {
  if (!value) return null;
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return null;
  return d;
}

/* Inclusive number of days between two ISO/date strings (end - start + 1). */
export function computeContractDays(startDate, endDate) {
  const start = parseDate(startDate);
  const end = parseDate(endDate);
  if (!start || !end) return 0;
  if (end.getTime() < start.getTime()) return 0;
  const msPerDay = 24 * 60 * 60 * 1000;
  return Math.round((end - start) / msPerDay) + 1;
}

/* Days in a month (1-12) for a given year. */
export function daysInMonth(month, year) {
  return new Date(parseInt(year, 10), parseInt(month, 10), 0).getDate();
}

/* Number of days in [itemStart, itemEnd] that fall inside [periodStart, periodEnd]. */
export function overlappingDays({ periodStart, periodEnd, itemStart, itemEnd }) {
  const ps = parseDate(periodStart);
  const pe = parseDate(periodEnd);
  const is = parseDate(itemStart);
  const ie = parseDate(itemEnd);
  if (!ps || !pe || !is || !ie) return 0;
  const start = is.getTime() > ps.getTime() ? is : ps;
  const end = ie.getTime() < pe.getTime() ? ie : pe;
  if (end < start) return 0;
  const msPerDay = 24 * 60 * 60 * 1000;
  return Math.round((end - start) / msPerDay) + 1;
}

/* Inclusive month window helpers: e.g. periodStart('2026','9') -> '2026-09-01'. */
export function monthRange(month, year) {
  const m = String(month).padStart(2, '0');
  const y = String(year);
  const last = daysInMonth(m, y);
  return { start: `${y}-${m}-01`, end: `${y}-${m}-${String(last).padStart(2, '0')}` };
}

export function dateOnly(value) {
  const d = parseDate(value);
  if (!d) return '';
  return d.toISOString().slice(0, 10);
}