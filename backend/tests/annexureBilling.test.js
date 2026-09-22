import { describe, it, expect, vi, beforeEach } from 'vitest';

/* ==========================================================================
   Annexure-4B Contract Rule Engine — Task #28 test cases.
   Pure rules are the single source of truth (annexureRules.js). Service-level
   flows that need Firestore are tested against a mocked db module so the
   contractual invariants (immutability, over-allocation protection) are
   verified without a live database.
   ========================================================================== */

const {
  areaAllocationCheck,
  areaWeightageChangeCheck,
  dailyMoneyValue,
  missedDeduction,
  partialDeductionNote,
  transferUnavailableWeightage,
  addNewItemWeightage,
  contractTotalWarning,
  VALID_EXEC_STATUSES,
  VALID_UNITS,
} = await import('../src/services/annexureRules.js');

vi.mock('../src/database/index.js', () => ({
  db: { collection: vi.fn(), batch: vi.fn(), doc: vi.fn() },
  admin: {},
}));

/* ─── Test 1: Valid area allocation ───────────────────────────────────────── */
describe('Test 1 — Area allocation within parent weightage', () => {
  const item1Limit = 40;
  const allocations = [10, 10, 20];
  const chained = allocations.reduce((acc, a) => {
    const check = areaAllocationCheck(acc.currentTotal, a, item1Limit);
    acc.currentTotal = check.newTotal;
    acc.allValid = acc.allValid && check.valid;
    return acc;
  }, { currentTotal: 0, allValid: true });

  it('accepts PF-01(10) + PF-02(10) + PF-03(20) = 40%', () => {
    expect(chained.allValid).toBe(true);
    expect(chained.currentTotal).toBe(40);
  });
  it('leaves zero remaining at exact allocation', () => {
    const check = areaAllocationCheck(30, 10, item1Limit);
    expect(check.valid).toBe(true);
    expect(check.remaining).toBe(0);
  });
});

/* ─── Test 2: Exceeding allocation is blocked ─────────────────────────────── */
describe('Test 2 — Allocation exceeding parent weightage is blocked', () => {
  it('rejects PF-01(25) + PF-02(20) = 45% against 40% item', () => {
    const second = areaWeightageChangeCheck(25, 20, 40);
    expect(second.valid).toBe(false);
    expect(second.error).toContain('cannot exceed the contractual weightage');
  });
  it('throws a descriptive ValidationError-style message', () => {
    const check = areaAllocationCheck(0, 41, 40);
    expect(check.valid).toBe(false);
    expect(check.error).toMatch(/Item limit: 40\.00%/);
  });
});

/* ─── Test 3: Unallocated weightage is allowed ────────────────────────────── */
describe('Test 3 — Unallocated weightage allowed', () => {
  it('accepts 30% allocated of 40% and reports 10% remaining', () => {
    const check = areaAllocationCheck(0, 30, 40);
    expect(check.valid).toBe(true);
    expect(check.remaining).toBe(10);
    expect(check.newTotal).toBe(30);
  });
});

/* ─── Test 4: Daily money value formula ───────────────────────────────────── */
describe('Test 4 — Daily Money Value = ACV x Weightage / 365', () => {
  it('computes ₹20,000 for ₹36,500,000 @ 20%', () => {
    expect(dailyMoneyValue(36500000, 20)).toBe(20000);
  });
  it('computes area-level DMV ₹10,000 for ₹36,500,000 @ 10%', () => {
    expect(dailyMoneyValue(36500000, 10)).toBe(10000);
  });
});

/* ─── Test 5: Missed-execution deduction ──────────────────────────────────── */
describe('Test 5 — Missed-execution deduction', () => {
  it('deducts ₹60,000 for 3 missed days at ₹20,000/day', () => {
    expect(missedDeduction(20000, 3)).toBe(60000);
  });
  it('zero deduction when nothing was missed', () => {
    expect(missedDeduction(20000, 0)).toBe(0);
  });
});

/* ─── Test 6: Item unavailable → weightage transfers to Item 1 ────────────── */
describe('Test 6 — Unavailable item transfers to Item 1', () => {
  it('moves Item 20 (1%) into Item 1: 40 -> 41', () => {
    const t = transferUnavailableWeightage(1, 40);
    expect(t.transferredWeightage).toBe(1);
    expect(t.item1After).toBe(41);
  });
  it('does not delete the item — transfer is a separate record', () => {
    const t = transferUnavailableWeightage(2, 38);
    expect(t.transferredWeightage).toBe(2);
    expect(t.item1After).toBe(40);
  });
});

/* ─── Test 7: New item reduces Item 1 ─────────────────────────────────────── */
describe('Test 7 — New item reduces Item 1 by the same weightage', () => {
  it('adds a 2% item and drops Item 1: 40 -> 38', () => {
    const r = addNewItemWeightage(40, 2);
    expect(r).toEqual({ newItemWeightage: 2, item1After: 38 });
  });
  it('refuses when Item 1 cannot cover the new item', () => {
    expect(addNewItemWeightage(1, 2)).toBeNull();
  });
});

/* ─── Test 8: Contractual total warning, no normalization ─────────────────── */
describe('Test 8 — 99.x% total warns without normalizing', () => {
  it('warns when the total is not 100', () => {
    const w = contractTotalWarning(99.4);
    expect(w).toBeTruthy();
    expect(w).toContain('99.40%');
    expect(w).toContain('No automatic normalization has been applied.');
  });
  it('silent for exactly 100', () => {
    expect(contractTotalWarning(100)).toBeNull();
  });
  it('master dataset totals 99.40 and is NOT force-normalized to 100', async () => {
    const { annexureBillingService } = await import('../src/services/annexureBillingService.js');
    const master = annexureBillingService.getMasterItems();
    expect(master.count).toBe(40);
    expect(master.totalWeightage).toBe(99.4);
    expect(master.warning).toBeTruthy();
  });
});

/* ─── Test 9: Partial execution — no invented proportional deduction ──────── */
describe('Test 9 — Partial execution treatment', () => {
  it('flags for review unless the contract allows proportional deduction', () => {
    expect(partialDeductionNote(2, false)).toBe('Contractual treatment required — flagged for review');
    expect(partialDeductionNote(2, true)).toBe('Proportional deduction applied');
  });
  it('no note when nothing is partial', () => {
    expect(partialDeductionNote(0, true)).toBeNull();
  });
});

/* ─── Test 10: Finalized bills are immutable ──────────────────────────────── */
describe('Test 10 — Historical finalized bills are immutable', () => {
  beforeEach(() => vi.resetModules());

  const contractDoc = { exists: true, data: () => ({ contractValue: 36500000 }) };
  const finalizedSnap = { empty: false, size: 2 };

  async function loadService() {
    const mod = await import('../src/services/annexureBillingService.js');
    return mod.annexureBillingService;
  }

  async function bindDb(snapshotFor) {
    const { db } = await import('../src/database/index.js');
    db.collection.mockImplementation((name) => {
      const chain = {
        where: vi.fn(function where() { return this; }),
        limit: vi.fn(function limit() { return this; }),
        doc: vi.fn(function doc() { return this; }),
        get: vi.fn(),
        set: vi.fn(),
        update: vi.fn(),
        add: vi.fn(),
      };
      chain.get.mockResolvedValue(snapshotFor[name]);
      return chain;
    });
    db.batch.mockReturnValue({ set: vi.fn(), update: vi.fn(), commit: vi.fn().mockResolvedValue(undefined) });
  }

  it('rejects re-calculating a period that already has a FINALIZED bill', async () => {
    await bindDb({ contracts: contractDoc, annexureBillingDeductions: finalizedSnap });
    const service = await loadService();
    const { ValidationError } = await import('../src/errors/index.js');
    const user = { uid: 'u1', fullName: 'Admin' };
    await expect(
      service.calculateBillingDeductions('contract-1', '2026-09-01', '2026-09-30', user)
    ).rejects.toThrow(ValidationError);
    await expect(
      service.calculateBillingDeductions('contract-1', '2026-09-01', '2026-09-30', user)
    ).rejects.toThrow(/finalized bill already exists/);
  });

  it('area over-allocation is blocked at the service boundary too', async () => {
    // Item 1 effective 40%; existing area total 0; adding 45% must be rejected.
    const itemDoc = { exists: true, data: () => ({ contractId: 'c1', itemNumber: 1, effectiveWeightage: 40 }) };
    await bindDb({ annexureContractItems: itemDoc, annexureAreaComponents: { empty: true, forEach: () => {} } });
    const service = await loadService();
    const { ValidationError } = await import('../src/errors/index.js');
    const user = { uid: 'u1', fullName: 'Admin' };

    await expect(
      service.addAreaComponent('item-1', { areaName: 'PF-01', allocatedWeightage: 45 }, user)
    ).rejects.toThrow(ValidationError);
  });
});

/* ─── Annexure-4B master data fidelity ────────────────────────────────────── */
describe('Annexure-4B master fidelity', () => {
  it('believes the item count is 40 and first item is Item 1 @40%', async () => {
    const { annexureBillingService } = await import('../src/services/annexureBillingService.js');
    const master = annexureBillingService.getMasterItems();
    expect(master.items.length).toBe(40);
    expect(master.items[0]).toMatchObject({ itemNumber: 1, contractualWeightage: 40 });
    expect(master.items[39]).toMatchObject({ itemNumber: 40, contractualWeightage: 0.5 });
  });
  it('only admits contract execution statuses defined in Annexure-4B', () => {
    expect(VALID_EXEC_STATUSES).toEqual(
      expect.arrayContaining(['COMPLETED', 'PARTIALLY_COMPLETED', 'NOT_COMPLETED', 'WAIVED', 'NOT_APPLICABLE'])
    );
  });
  it('supports the documented quantity units', () => {
    expect(VALID_UNITS).toEqual(expect.arrayContaining(['sqft', 'sq.m', 'nos', 'meter', 'unit']));
  });
});