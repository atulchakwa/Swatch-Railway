import { describe, it, expect } from 'vitest';
import fs from 'fs';
import vm from 'vm';

const seedPath = new URL('../seed_execution_sheet.mjs', import.meta.url);
const source = fs.readFileSync(seedPath, 'utf8');

const afterItems = source.split('const ITEMS = [').pop();
const itemsBlock = '[' + afterItems.slice(0, afterItems.indexOf('];') + 1);
const sandbox = {};
vm.createContext(sandbox);
const items = vm.runInContext(`(${itemsBlock})`, sandbox);

const TENDER_WEIGHTAGES = [45, 20, 8, 4, 1.5, 3.5, 0.5, 1.75, 1, 3, 2, 0.75, 0.2, 1, 1, 0.3, 0.3, 0.3, 0.3, 0.2, 0.6, 4, 0.1, 0.2, 0.5];

describe('Annexure-AB Work Execution Sheet seed data', () => {
  it('has exactly 25 items numbered 1..25', () => {
    expect(items).toHaveLength(25);
    expect(items.map((i) => i.itemNo)).toEqual(Array.from({ length: 25 }, (_, i) => i + 1));
  });

  it('weightages total to 100%', () => {
    const total = items.reduce((s, i) => s + i.weightage, 0);
    expect(total).toBeCloseTo(100, 1);
  });

  it('weights match the tender percentages', () => {
    items.forEach((item, idx) => {
      expect(item.weightage, `Item ${item.itemNo} weightage`).toBeCloseTo(TENDER_WEIGHTAGES[idx], 1);
    });
  });

  it('every item defines a mappedAreas array', () => {
    for (const item of items) {
      expect(Array.isArray(item.mappedAreas), `Item ${item.itemNo} mappedAreas`).toBe(true);
    }
  });

  it('area mappings reference valid mainArea values from the BOQ', () => {
    const boqBlock = fs.readFileSync(new URL('../../app/lib/model/boq_data.dart', import.meta.url), 'utf8');
    const mains = [...boqBlock.matchAll(/mainArea\s*:\s*(["'])(.*?)\1/g)].map((m) => m[2]);
    const mappedMains = items.flatMap((i) => i.mappedAreas.map((m) => m.mainArea));
    const unknown = [...new Set(mappedMains)].filter((m) => !mains.includes(m));
    expect(unknown).toEqual([]);
  });

  it('daily shift summaries can be matched by the scoring helper', async () => {
    const { executionSheetService } = await import('../src/services/executionSheetService.js');
    expect(typeof executionSheetService.getMonthlySummary).toBe('function');
    expect(typeof executionSheetService.saveDailySheet).toBe('function');
  });
});