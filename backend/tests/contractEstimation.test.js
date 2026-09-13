import { describe, it, expect } from 'vitest';

/* ==========================================================================
   Contract Estimation, Variation & SWO engine tests.
   ========================================================================== */

const {
  frequencyTimesPerDay,
  computeItemEstimate,
  computeVariationStatement,
  computeSwoValue,
  contractEstimationService,
} = await import('../src/services/contractEstimationService.js');

describe('frequencyTimesPerDay - configurable frequencies (never hardcoded)', () => {
  it('defaults to 1 per day', () => {
    expect(frequencyTimesPerDay({ type: 'daily', timesPerDay: 1 })).toBe(1);
  });
  it('supports multiple times per day / multiple shifts', () => {
    expect(frequencyTimesPerDay({ type: 'daily', timesPerDay: 3 })).toBe(3);
    expect(frequencyTimesPerDay({ type: 'twice_per_day', timesPerDay: 2 })).toBe(2);
  });
  it('supports weekly / monthly / periodic spreads', () => {
    expect(frequencyTimesPerDay({ type: 'weekly', timesPerWeek: 2 })).toBe(2 / 7);
    expect(frequencyTimesPerDay({ type: 'monthly', timesPerMonth: 2 })).toBe(2 / 30);
    expect(frequencyTimesPerDay({ type: 'periodic', timesPerPeriod: 3, periodDays: 15 })).toBe(3 / 15);
  });
  it('zeroes once / as-required executions', () => {
    expect(frequencyTimesPerDay({ type: 'once' })).toBe(0);
    expect(frequencyTimesPerDay({ type: 'as_required' })).toBe(0);
  });
});

describe('computeItemEstimate - area × frequency × rate', () => {
  it('computes the sq.ft. reference estimate', () => {
    // 50,000 sq.ft. @ 3 times/day @ ₹0.10 → cost/day = 15,000; 30 days → 450,000
    const r = computeItemEstimate({ quantity: 50000, frequency: { type: 'daily', timesPerDay: 3 }, rate: 0.1, contractDays: 365, applicableDays: 30 });
    expect(r.quantityPerDay).toBe(150000);
    expect(r.costPerDay).toBe(15000);
    expect(r.estimatedCost).toBe(450000);
  });

  it('computes contract-period cost from contract days', () => {
    const r = computeItemEstimate({ quantity: 1000, frequency: { type: 'daily', timesPerDay: 1 }, rate: 0.5, contractDays: 1189, applicableDays: 1189 });
    expect(r.costPerDay).toBe(500);
    expect(r.estimatedCost).toBe(594500); // 500 × 1189
  });

  it('treats pest/rodent control with treatments, not daily spread', () => {
    const r = computeItemEstimate({ quantity: 2000, frequency: { type: 'once' }, rate: 1.5, isPestControl: true, treatments: 6, contractDays: 1189, applicableDays: 1189 });
    expect(r.quantityPerDay).toBe(0);
    expect(r.estimatedCost).toBe(18000); // 2000 × 6 × 1.5
  });

  it('supports non-area system line items (System/Year)', () => {
    const r = computeItemEstimate({ quantity: 2, frequency: { type: 'once' }, rate: 50000, contractDays: 1461, applicableDays: 1461 });
    expect(r.estimatedCost).toBe(100000); // 2 systems × 50000
  });

  it('prorates mid-period items to their applicable days', () => {
    const r = computeItemEstimate({ quantity: 1000, frequency: { type: 'daily', timesPerDay: 1 }, rate: 10, contractDays: 365, applicableDays: 16 });
    expect(r.costPerDay).toBe(10000);
    expect(r.estimatedCost).toBe(160000); // not a full month
  });

  it('rejects negative quantity/rate', () => {
    expect(() => computeItemEstimate({ quantity: -5, rate: 1 })).toThrow();
    expect(() => computeItemEstimate({ quantity: 5, rate: -1 })).toThrow();
  });
});

describe('computeVariationStatement - original scope → savings → amended', () => {
  it('computes savings, additional work and recovery against the original value', () => {
    const r = computeVariationStatement({ originalContractValue: 1000000, executedOriginalValue: 800000, reductionValue: 200000, additionalWorkValue: 150000, excessExecutionValue: 50000, recoveryDeductions: 10000 });
    expect(r.savings).toBe(200000);
    expect(r.revisedScopeValue).toBe(800000);
    expect(r.amendedContractValue).toBe(1000000 - 200000 + 150000 + 50000 - 10000); // 990000
    expect(r.netVariation).toBe(-10000);
  });

  it('preserves the original when nothing changes', () => {
    const r = computeVariationStatement({ originalContractValue: 500000 });
    expect(r.amendedContractValue).toBe(500000);
  });

  it('clamps recovery/addition negatives and never goes below zero', () => {
    const r = computeVariationStatement({ originalContractValue: 100000, additionalWorkValue: -5, recoveryDeductions: 999999 });
    expect(r.amendedContractValue).toBe(0);
    expect(r.recoveryDeductions).toBe(999999);
  });

  it('clamps a reduction that exceeds the executed scope to the executed value', () => {
    // executedOriginalValue defaults to the original whenever it is omitted.
    const r = computeVariationStatement({ originalContractValue: 100000, reductionValue: 50000 });
    expect(r.savings).toBe(0); // nothing executed beyond scope → no headroom
    expect(r.revisedScopeValue).toBe(100000);
  });

  it('uses the explicit original contract value as the reduction baseline', () => {
    const r = computeVariationStatement({ originalContractValue: 1000000, executedOriginalValue: 750000, reductionValue: 300000 });
    expect(r.savings).toBe(250000); // capped at 1,000,000 − 750,000
    expect(r.revisedScopeValue).toBe(750000);
    expect(r.amendedContractValue).toBe(750000);
  });
});

describe('computeSwoValue - supplementary work orders', () => {
  it('sums explicit item amounts', () => {
    const r = computeSwoValue([{ quantity: 1, rate: 100 }, { amount: 250 }]);
    expect(r.totalValue).toBe(350);
  });
  it('derives amount from qty × rate, decimal-safe', () => {
    const r = computeSwoValue([{ description: 'Gutter cleaning', quantity: 100.5, rate: 0.25 }]);
    expect(r.totalValue).toBe(25.13);
  });
  it('returns zero for no items', () => {
    expect(computeSwoValue([]).totalValue).toBe(0);
  });
});

describe('contractEstimationService - method coverage', () => {
  it('exports the expected DB methods', () => {
    const expected = [
      'getEstimateItems', 'createEstimateItem', 'updateEstimateItem', 'deleteEstimateItem',
      'getVariations', 'createVariation',
      'getSWOs', 'createSWO', 'deleteSWO',
      'getAmendedContractValue', 'getPeriodContribution',
    ];
    for (const m of expected) {
      expect(typeof contractEstimationService[m], `Missing: ${m}`).toBe('function');
    }
  });
});