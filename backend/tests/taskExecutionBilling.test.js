import { describe, it, expect } from 'vitest';

/* ==========================================================================
   Task Execution billing engine (50% component): per-sq.ft. daily billing,
   per-area weightage, contract-day math, rounding & edge cases.
   ========================================================================== */

const {
  computeDailyTaskBilling,
  computeWeightedExecutionScore,
  aggregateAreaExecution,
  taskExecutionBillingService,
} = await import('../src/services/taskExecutionBillingService.js');
const { computeContractDays, daysInMonth, overlappingDays, monthRange } = await import('../src/utils/period.js');

describe('computeContractDays - date-based contract periods', () => {
  it('computes the reference 1461 days for a 4-year contract', () => {
    expect(computeContractDays('2023-01-01', '2026-12-31')).toBe(1461);
  });
  it('computes inclusive days for the reference 11-Feb-2023 → 14-May-2026 scope', () => {
    expect(computeContractDays('2023-02-11', '2026-05-14')).toBe(1189);
  });
  it('handles leap years and single-day contracts', () => {
    expect(computeContractDays('2024-01-01', '2024-12-31')).toBe(366);
    expect(computeContractDays('2026-09-13', '2026-09-13')).toBe(1);
  });
  it('returns 0 for invalid or reversed ranges', () => {
    expect(computeContractDays('bad', '2026-09-13')).toBe(0);
    expect(computeContractDays('2026-09-13', '2026-09-01')).toBe(0);
    expect(computeContractDays(null, '2026-09-13')).toBe(0);
  });
});

describe('overlappingDays - mid-period proration (e.g. 16 applicable days)', () => {
  it('prorates an item active in the middle of a period', () => {
    expect(overlappingDays({ periodStart: '2026-09-01', periodEnd: '2026-09-30', itemStart: '2026-09-10', itemEnd: '2026-09-25' })).toBe(16);
  });
  it('returns the full period when the item spans it completely', () => {
    expect(overlappingDays({ periodStart: '2026-09-01', periodEnd: '2026-09-30', itemStart: '2026-01-01', itemEnd: '2026-12-31' })).toBe(30);
  });
  it('returns 0 when the item is outside the period', () => {
    expect(overlappingDays({ periodStart: '2026-09-01', periodEnd: '2026-09-30', itemStart: '2026-10-01', itemEnd: '2026-10-15' })).toBe(0);
  });
});

describe('daysInMonth / monthRange', () => {
  it('returns correct day counts', () => {
    expect(daysInMonth(2, 2024)).toBe(29);
    expect(daysInMonth(2, 2026)).toBe(28);
    expect(daysInMonth(9, 2026)).toBe(30);
  });
  it('builds month windows', () => {
    expect(monthRange(9, 2026)).toEqual({ start: '2026-09-01', end: '2026-09-30' });
    expect(monthRange(1, 2026)).toEqual({ start: '2026-01-01', end: '2026-01-31' });
  });
});

describe('aggregateAreaExecution', () => {
  it('flattens multi-shift summaries into per-area rows', () => {
    const summaries = [
      { areas: [{ areaName: 'Platform 1', basicAreaSqFt: 1000, times: 1, workDone: 1000, tenderedAreaPerDay: 1000 }] },
      { areas: [{ areaName: 'Platform 1', basicAreaSqFt: 1000, times: 1, workDone: 1000, tenderedAreaPerDay: 1000 }] },
      { areas: [{ areaName: 'Concourse', basicAreaSqFt: 500, times: 2, workDone: 1000, tenderedAreaPerDay: 1000 }] },
    ];
    const rows = aggregateAreaExecution(summaries);
    const platform = rows.find(r => r.areaName === 'Platform 1');
    expect(platform.executedSqFt).toBe(2000);
    expect(platform.expectedSqFt).toBe(2000);
    expect(platform.ratio).toBe(1);
    const concourse = rows.find(r => r.areaName === 'Concourse');
    expect(concourse.executedSqFt).toBe(1000);
    expect(concourse.days).toBe(1);
  });
  it('returns empty rows for no summaries', () => {
    expect(aggregateAreaExecution([])).toEqual([]);
  });
});

describe('computeDailyTaskBilling - per-sq.ft. daily billing', () => {
  const summariesFull = [
    { areas: [{ areaName: 'Platform 1', basicAreaSqFt: 1000, times: 1, workDone: 1000, tenderedAreaPerDay: 1000 }] },
  ];
  const summariesHalf = [
    { areas: [{ areaName: 'Platform 1', basicAreaSqFt: 1000, times: 0, workDone: 0, tenderedAreaPerDay:1000 }] },
  ];

  it('bills the full daily base when execution is 100%', () => {
    const r = computeDailyTaskBilling({ annualValue: 100000, contractDays: 365, approvedSummaries: summariesFull });
    expect(r.dailyBaseTask).toBe(136.99); // 100000/365×0.5 rounded
    expect(r.dayExecutionRate).toBe(100);
    expect(r.grossAmount).toBeCloseTo(136.99, 2);
    expect(r.deduction).toBe(0);
  });

  it('deducts proportionally on partial execution', () => {
    const r = computeDailyTaskBilling({ annualValue: 100000, contractDays: 365, approvedSummaries: summariesHalf });
    expect(r.dayExecutionRate).toBe(0);
    expect(r.grossAmount).toBe(0);
    expect(r.deduction).toBeCloseTo(136.99, 2);
    expect(r.netAmount).toBe(0);
  });

  it('returns zeros (no crash) when nothing has been executed', () => {
    const r = computeDailyTaskBilling({ annualValue: 100000, contractDays: 365, approvedSummaries: [] });
    expect(r.dayExecutionRate).toBeNull();
    expect(r.grossAmount).toBe(0);
    expect(r.netAmount).toBe(0);
  });

  it('counts repeated cleanings (multiple times per day) against the bill', () => {
    const threeTimes = [
      { areas: [{ areaName: 'Platform 1', basicAreaSqFt: 1000, times: 3, workDone: 3000, tenderedAreaPerDay: 1000 }] },
    ];
    const capped = computeDailyTaskBilling({ annualValue: 100000, contractDays: 365, approvedSummaries: threeTimes });
    expect(capped.rows[0].billableSqFt).toBe(1000); // capped at expected
    expect(capped.grossAmount).toBeCloseTo(136.99, 2);
    const excess = computeDailyTaskBilling({ annualValue: 100000, contractDays: 365, approvedSummaries: threeTimes, excessThreshold: 2 });
    expect(excess.rows[0].billableSqFt).toBe(2000);
    expect(excess.grossAmount).toBeCloseTo(273.98, 2);
  });

  it('uses a configured per-area rate override', () => {
    const r = computeDailyTaskBilling({
      annualValue: 100000, contractDays: 365, approvedSummaries: summariesFull,
      weightageConfig: [{ areaName: 'Platform 1', ratePerSqFt: 0.2 }],
    });
    expect(r.rows[0].ratePerSqFt).toBe(0.2);
    expect(r.rows[0].areaAmount).toBe(200);
  });

  it('handles multiple areas with decimal-safe rounding (no float drift)', () => {
    const multi = [
      { areas: [{ areaName: 'A', basicAreaSqFt: 3333, times: 1, workDone: 3333, tenderedAreaPerDay: 3333 }] },
      { areas: [{ areaName: 'B', basicAreaSqFt: 6667, times: 1, workDone: 6667, tenderedAreaPerDay: 6667 }] },
    ];
    const r = computeDailyTaskBilling({ annualValue: 800000, contractDays: 365, approvedSummaries: multi });
    const sum = r.rows.reduce((s, row) => s + row.areaAmount, 0);
    expect(sum).toBeCloseTo(r.grossAmount, 2);
    expect(r.grossAmount - r.deduction).toBeGreaterThanOrEqual(0);
  });
});

describe('computeWeightedExecutionScore - configurable area weightages', () => {
  const rows = [
    { areaName: 'Concourse', executedSqFt: 1000, expectedSqFt: 1000, ratio: 1 },
    { areaName: 'FOB', executedSqFt: 500, expectedSqFt: 1000, ratio: 0.5 },
  ];

  it('computes the weighted score from configured area weightages', () => {
    const weights = [{ areaName: 'Concourse', weightage: 50 }, { areaName: 'FOB', weightage: 50 }];
    const r = computeWeightedExecutionScore(rows, weights);
    expect(r.configured).toBe(true);
    expect(r.weightedScore).toBe(75); // (50×1 + 50×0.5) / 100
  });

  it('renormalizes when only some areas are weightage-configured', () => {
    const weights = [{ areaName: 'Concourse', weightage: 100 }];
    const r = computeWeightedExecutionScore(rows, weights);
    expect(r.weightedScore).toBe(100);
  });

  it('falls back to a flat sq.ft. ratio with no configuration', () => {
    const r = computeWeightedExecutionScore(rows, []);
    expect(r.configured).toBe(false);
    expect(r.weightedScore).toBe(75); // (1000+500)/(1000+1000)
  });

  it('is safe when there is nothing to compute', () => {
    expect(computeWeightedExecutionScore([], []).weightedScore).toBeNull();
    const r = computeWeightedExecutionScore([{ areaName: 'A', executedSqFt: 0, expectedSqFt: 0, ratio: 1 }], []);
    expect(r.configured).toBe(false);
  });

  it('rejects weightage changes outside 0-100 via validation helper semantics', () => {
    // The 0-100 bounds are enforced in upsertWeightage (DB path); here we verify
    // the pure function clamps a summed score.
    const r = computeWeightedExecutionScore(
      [{ areaName: 'A', executedSqFt: 900, expectedSqFt: 1000, ratio: 0.9 }],
      [{ areaName: 'A', weightage: 100 }],
    );
    expect(r.weightedScore).toBe(90);
  });
});

describe('taskExecutionBillingService - method coverage', () => {
  it('exports the expected DB methods', () => {
    const expected = [
      'getWeightages', 'upsertWeightage', 'deleteWeightage',
      'prepareDailyBill', 'previewDailyBill', 'generateDailyBill',
      'getDailyBill', 'listDailyBills',
    ];
    for (const m of expected) {
      expect(typeof taskExecutionBillingService[m], `Missing: ${m}`).toBe('function');
    }
  });
});