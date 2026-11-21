/**
 * NEXUS DUO — WeeklyScheduleMask (168h in bigint[3]) & Continuous Co-op Window DP.
 *
 * Bit layout (hours 0..167, Mon 00:00 -> Sun 23:00):
 * - word 0: bits 0..63   (hours 0..63)
 * - word 1: bits 0..63   (hours 64..127)
 * - word 2: bits 0..39   (hours 128..167; top 24 bits masked to 0)
 *
 * Complexity:
 * - Bitwise intersection: O(1) (3 bigint operations)
 * - Continuous Window DP with Sunday->Monday wrap-around: O(168) time, O(1) auxiliary space.
 */

export const HOURS_PER_WEEK = 168;
export const DAYS_PT_BR = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'] as const;

const MASK_64 = (1n << 64n) - 1n;
const MASK_40 = (1n << 40n) - 1n;

export type ScheduleMaskTuple = readonly [bigint, bigint, bigint];

export interface ContinuousScheduleResult {
  /** Normalized score S_agenda in [0, 1] */
  score: number;
  /** Total overlapping free hours across the week */
  totalOverlapHours: number;
  /** Length in hours of every continuous overlapping block (with wrap-around merged) */
  continuousBlocks: readonly number[];
  /** Length of the longest continuous play window */
  longestBlockHours: number;
  /** Human-readable prime overlapping window label */
  primeWindowLabel: string;
}

export class WeeklyScheduleMask {
  private readonly words: ScheduleMaskTuple;

  private constructor(w0: bigint, w1: bigint, w2: bigint) {
    this.words = [w0 & MASK_64, w1 & MASK_64, w2 & MASK_40];
  }

  static empty(): WeeklyScheduleMask {
    return new WeeklyScheduleMask(0n, 0n, 0n);
  }

  static full(): WeeklyScheduleMask {
    return new WeeklyScheduleMask(MASK_64, MASK_64, MASK_40);
  }

  static fromMask(mask: ScheduleMaskTuple): WeeklyScheduleMask {
    return new WeeklyScheduleMask(mask[0], mask[1], mask[2]);
  }

  static fromHours(hours: readonly number[]): WeeklyScheduleMask {
    let w0 = 0n;
    let w1 = 0n;
    let w2 = 0n;

    for (const rawHour of hours) {
      if (!Number.isInteger(rawHour) || rawHour < 0 || rawHour >= HOURS_PER_WEEK) {
        throw new RangeError(
          `Schedule hour must be an integer in [0, 167], received: ${rawHour}`,
        );
      }
      if (rawHour < 64) {
        w0 |= 1n << BigInt(rawHour);
      } else if (rawHour < 128) {
        w1 |= 1n << BigInt(rawHour - 64);
      } else {
        w2 |= 1n << BigInt(rawHour - 128);
      }
    }

    return new WeeklyScheduleMask(w0, w1, w2);
  }

  /**
   * Builds a mask from day indices (0=Mon..6=Sun) and hour range [startHour, endHour).
   * Supports overnight ranges where endHour <= startHour (wraps to next day/week).
   */
  static fromDayWindow(
    days: readonly number[],
    startHour: number,
    endHour: number,
  ): WeeklyScheduleMask {
    const hours: number[] = [];
    for (const day of days) {
      if (day < 0 || day > 6) {
        throw new RangeError(`Day must be in [0, 6], received: ${day}`);
      }
      if (startHour < endHour) {
        for (let h = startHour; h < endHour; h += 1) {
          hours.push(day * 24 + h);
        }
      } else {
        for (let h = startHour; h < 24; h += 1) {
          hours.push(day * 24 + h);
        }
        const nextDay = (day + 1) % 7;
        for (let h = 0; h < endHour; h += 1) {
          hours.push(nextDay * 24 + h);
        }
      }
    }
    return WeeklyScheduleMask.fromHours(hours);
  }

  hasHour(hour: number): boolean {
    if (hour < 0 || hour >= HOURS_PER_WEEK) return false;
    if (hour < 64) {
      return ((this.words[0] >> BigInt(hour)) & 1n) === 1n;
    }
    if (hour < 128) {
      return ((this.words[1] >> BigInt(hour - 64)) & 1n) === 1n;
    }
    return ((this.words[2] >> BigInt(hour - 128)) & 1n) === 1n;
  }

  toggleHour(hour: number): WeeklyScheduleMask {
    if (!Number.isInteger(hour) || hour < 0 || hour >= HOURS_PER_WEEK) {
      throw new RangeError(`Schedule hour must be in [0, 167], received: ${hour}`);
    }
    let [w0, w1, w2] = this.words;
    if (hour < 64) {
      w0 ^= 1n << BigInt(hour);
    } else if (hour < 128) {
      w1 ^= 1n << BigInt(hour - 64);
    } else {
      w2 ^= 1n << BigInt(hour - 128);
    }
    return new WeeklyScheduleMask(w0, w1, w2);
  }

  intersect(other: WeeklyScheduleMask): WeeklyScheduleMask {
    return new WeeklyScheduleMask(
      this.words[0] & other.words[0],
      this.words[1] & other.words[1],
      this.words[2] & other.words[2],
    );
  }

  union(other: WeeklyScheduleMask): WeeklyScheduleMask {
    return new WeeklyScheduleMask(
      this.words[0] | other.words[0],
      this.words[1] | other.words[1],
      this.words[2] | other.words[2],
    );
  }

  toBigIntTuple(): ScheduleMaskTuple {
    return [this.words[0], this.words[1], this.words[2]];
  }

  toStringTuple(): readonly [string, string, string] {
    return [
      this.words[0].toString(),
      this.words[1].toString(),
      this.words[2].toString(),
    ];
  }

  toHours(): number[] {
    const out: number[] = [];
    for (let h = 0; h < HOURS_PER_WEEK; h += 1) {
      if (this.hasHour(h)) {
        out.push(h);
      }
    }
    return out;
  }

  totalHours(): number {
    let count = 0;
    for (let h = 0; h < HOURS_PER_WEEK; h += 1) {
      if (this.hasHour(h)) {
        count += 1;
      }
    }
    return count;
  }
}

/**
 * Non-linear reward w(b) for continuous play blocks:
 * - Isolated 1-hour blocks do not qualify for meaningful co-op sessions (w(1) = 0).
 * - Blocks >= 2 hours get progressive bonus up to 6h to reward stable play sessions.
 */
export function rewardContinuousBlock(blockLength: number): number {
  if (blockLength < 2) {
    return 0;
  }
  const bonusFactor = 1 + 0.1 * Math.min(blockLength - 2, 4);
  return blockLength * bonusFactor;
}

function formatHourRange(startHourOfWeek: number, length: number): string {
  const normalizedStart = ((startHourOfWeek % HOURS_PER_WEEK) + HOURS_PER_WEEK) % HOURS_PER_WEEK;
  const dayIdx = Math.floor(normalizedStart / 24);
  const startClock = normalizedStart % 24;
  const endClock = (normalizedStart + length) % 24;
  const dayLabel = DAYS_PT_BR[dayIdx] ?? 'Seg';
  const pad = (n: number) => String(n).padStart(2, '0');
  if (length >= 24) {
    return `${dayLabel} · ${length}h seguidas`;
  }
  return `${dayLabel} ${pad(startClock)}h–${pad(endClock)}h`;
}

/**
 * Continuous Co-op Window DP over 168 circular hours (Sunday 23h -> Monday 00h wrap-around).
 * Runs in O(168) time and O(1) DP state variables.
 */
export function computeContinuousScheduleOverlap(
  scheduleA: WeeklyScheduleMask,
  scheduleB: WeeklyScheduleMask,
): ContinuousScheduleResult {
  const overlap = scheduleA.intersect(scheduleB);

  let totalOverlapHours = 0;
  let firstZeroIdx = -1;
  for (let t = 0; t < HOURS_PER_WEEK; t += 1) {
    if (overlap.hasHour(t)) {
      totalOverlapHours += 1;
    } else if (firstZeroIdx === -1) {
      firstZeroIdx = t;
    }
  }

  if (totalOverlapHours === 0) {
    return {
      score: 0,
      totalOverlapHours: 0,
      continuousBlocks: [],
      longestBlockHours: 0,
      primeWindowLabel: 'Sem janela em comum',
    };
  }

  // Full 168h overlap: single continuous circular block without double counting.
  if (firstZeroIdx === -1) {
    return {
      score: 1,
      totalOverlapHours: HOURS_PER_WEEK,
      continuousBlocks: [HOURS_PER_WEEK],
      longestBlockHours: HOURS_PER_WEEK,
      primeWindowLabel: 'Disponível 24/7 em comum',
    };
  }

  // Start circular DP immediately after a known 0-bit so Sunday->Monday blocks stay intact.
  const blocks: number[] = [];
  let dpCurrent = 0;
  let currentBlockStart = -1;
  let longestBlockHours = 0;
  let longestBlockStart = 0;

  for (let step = 0; step < HOURS_PER_WEEK; step += 1) {
    const t = (firstZeroIdx + 1 + step) % HOURS_PER_WEEK;
    if (overlap.hasHour(t)) {
      if (dpCurrent === 0) {
        currentBlockStart = t;
      }
      dpCurrent += 1;
    } else if (dpCurrent > 0) {
      blocks.push(dpCurrent);
      if (dpCurrent > longestBlockHours) {
        longestBlockHours = dpCurrent;
        longestBlockStart = currentBlockStart;
      }
      dpCurrent = 0;
    }
  }

  if (dpCurrent > 0) {
    blocks.push(dpCurrent);
    if (dpCurrent > longestBlockHours) {
      longestBlockHours = dpCurrent;
      longestBlockStart = currentBlockStart;
    }
  }

  let weightedSum = 0;
  for (const blockLen of blocks) {
    weightedSum += rewardContinuousBlock(blockLen);
  }

  const normalizedScore = Math.min(1, weightedSum / 10);

  return {
    score: Number(normalizedScore.toFixed(4)),
    totalOverlapHours,
    continuousBlocks: blocks,
    longestBlockHours,
    primeWindowLabel:
      longestBlockHours > 0
        ? formatHourRange(longestBlockStart, longestBlockHours)
        : 'Sem janela em comum',
  };
}
