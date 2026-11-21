import { describe, expect, it } from 'vitest';
import {
  HOURS_PER_WEEK,
  WeeklyScheduleMask,
  computeContinuousScheduleOverlap,
  rewardContinuousBlock,
} from '@/core/algo/scheduleDp';

describe('WeeklyScheduleMask & Continuous Co-op Window DP', () => {
  it('encapsulates 168 hours into bigint[3] without leaking bits above 167', () => {
    const full = WeeklyScheduleMask.full();
    expect(full.totalHours()).toBe(HOURS_PER_WEEK);
    const [w0, w1, w2] = full.toBigIntTuple();
    expect(w0).toBe((1n << 64n) - 1n);
    expect(w1).toBe((1n << 64n) - 1n);
    expect(w2).toBe((1n << 40n) - 1n);
    expect(full.hasHour(0)).toBe(true);
    expect(full.hasHour(63)).toBe(true);
    expect(full.hasHour(64)).toBe(true);
    expect(full.hasHour(127)).toBe(true);
    expect(full.hasHour(128)).toBe(true);
    expect(full.hasHour(167)).toBe(true);
    expect(full.hasHour(168)).toBe(false);
  });

  it('throws on out-of-range hour indices', () => {
    expect(() => WeeklyScheduleMask.fromHours([-1])).toThrow(RangeError);
    expect(() => WeeklyScheduleMask.fromHours([168])).toThrow(RangeError);
    expect(() => WeeklyScheduleMask.empty().toggleHour(200)).toThrow(RangeError);
  });

  it('returns score 0 for empty overlap', () => {
    const morning = WeeklyScheduleMask.fromDayWindow([0, 1, 2], 8, 12);
    const night = WeeklyScheduleMask.fromDayWindow([0, 1, 2], 20, 23);
    const result = computeContinuousScheduleOverlap(morning, night);

    expect(result.score).toBe(0);
    expect(result.totalOverlapHours).toBe(0);
    expect(result.continuousBlocks).toEqual([]);
    expect(result.longestBlockHours).toBe(0);
  });

  it('scores isolated 1-hour overlap blocks as 0 while rewarding >=2h continuous blocks', () => {
    const isolated = WeeklyScheduleMask.fromHours([10, 12, 14, 16, 18]);
    const isolatedResult = computeContinuousScheduleOverlap(isolated, isolated);

    expect(isolatedResult.totalOverlapHours).toBe(5);
    expect(isolatedResult.continuousBlocks).toEqual([1, 1, 1, 1, 1]);
    expect(isolatedResult.score).toBe(0);

    const continuous = WeeklyScheduleMask.fromHours([20, 21, 22, 23]);
    const continuousResult = computeContinuousScheduleOverlap(continuous, continuous);
    expect(continuousResult.totalOverlapHours).toBe(4);
    expect(continuousResult.continuousBlocks).toEqual([4]);
    expect(continuousResult.longestBlockHours).toBe(4);
    expect(continuousResult.score).toBeGreaterThan(0.4);
    expect(rewardContinuousBlock(4)).toBeGreaterThan(rewardContinuousBlock(2) * 2);
  });

  it('merges Sunday night -> Monday early morning wrap-around seamlessly in O(168)', () => {
    // Sunday 22h, 23h (hours 166, 167) + Monday 00h, 01h (hours 0, 1) => 4h continuous block!
    const sundayToMonday = WeeklyScheduleMask.fromHours([166, 167, 0, 1]);
    const result = computeContinuousScheduleOverlap(sundayToMonday, sundayToMonday);

    expect(result.totalOverlapHours).toBe(4);
    expect(result.continuousBlocks).toEqual([4]);
    expect(result.longestBlockHours).toBe(4);
    expect(result.primeWindowLabel).toBe('Dom 22h–02h');
    expect(result.score).toBeCloseTo(rewardContinuousBlock(4) / 10, 4);
  });

  it('handles full 168-hour week without double counting', () => {
    const full = WeeklyScheduleMask.full();
    const result = computeContinuousScheduleOverlap(full, full);

    expect(result.score).toBe(1);
    expect(result.totalOverlapHours).toBe(168);
    expect(result.continuousBlocks).toEqual([168]);
    expect(result.longestBlockHours).toBe(168);
  });
});
