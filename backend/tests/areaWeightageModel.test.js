import { describe, it, expect } from "vitest";
import {
  dailyContractValue,
  areaDailyMoneyValue,
  areaRatePerSqFt,
  perExecutionValue,
  executionDeduction,
  validateAreaWeightages,
} from "../src/services/areaWeightageModel.js";

const ACV = 36500000;
const SQFT = 72416;

describe("areaWeightageModel - Ujjain money model (ECR-30 exact)", () => {
  it("ACV 36500000 -> daily contract value 100000", () => {
    expect(dailyContractValue(ACV)).toBe(100000);
  });
  it("daily & area daily divide by CONTRACT days, not 365 (14-day contract)", () => {
    expect(dailyContractValue(ACV, 14)).toBe(2607142.86);
    expect(areaDailyMoneyValue(ACV, 25, 14)).toBe(651785.71);
  });
  it("invalid contract days fall back to 365", () => {
    expect(dailyContractValue(ACV, 0)).toBe(100000);
    expect(areaDailyMoneyValue(ACV, 25, -5)).toBe(25000);
  });
  it("25% weightage -> area daily money value 25000", () => {
    expect(areaDailyMoneyValue(ACV, 25)).toBe(25000);
  });
  it("derived rate = 25000/72416 = 0.3452 (4dp, read-only)", () => {
    expect(areaRatePerSqFt(25000, SQFT)).toBeCloseTo(0.3452, 4);
  });
  it("per-execution value = 25000/4 = 6250", () => {
    expect(perExecutionValue(25000, 4)).toBe(6250);
  });
  it("execution deduction = 6250 x 1 missed", () => {
    expect(executionDeduction(6250, 1)).toBe(6250);
  });
  it("validates weightages: 0-100 each, sum 100", () => {
    expect(() => validateAreaWeightages({ a1: 101 })).toThrow();
    expect(() => validateAreaWeightages({ a1: -5 })).toThrow();
    expect(() => validateAreaWeightages({ a1: 60, a2: 40 })).not.toThrow();
    expect(() => validateAreaWeightages({ a1: 60, a2: 39.5 })).toThrow(/100/);
  });
});
