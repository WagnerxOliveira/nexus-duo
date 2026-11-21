import type {
  GamerDna,
  GamerProfile,
  MatchScoreBreakdown,
  UserGame,
} from '@/core/domain/types';
import {
  WeeklyScheduleMask,
  computeContinuousScheduleOverlap,
} from '@/core/algo/scheduleDp';

export interface FairnessContext {
  reciprocityProb?: number; // 0..1
  dailyImpressions?: number; // >= 0
  isNewbie?: boolean;
  isVerified?: boolean;
  alphaReciprocity?: number;
  betaExposureDecay?: number;
}

export interface IMatchScoringStrategy {
  readonly strategyName: string;
  calculate(
    me: GamerProfile,
    target: GamerProfile,
    fairness?: FairnessContext,
  ): MatchScoreBreakdown;
}

function dcgWeight(priorityOrder: number): number {
  const zeroIndexed = Math.max(0, priorityOrder - 1);
  return 1 / Math.log2(zeroIndexed + 2);
}

function hasCompatiblePlatform(a: UserGame, b: UserGame): boolean {
  if (a.supportsCrossplay || b.supportsCrossplay) {
    return true;
  }
  const setB = new Set(b.platforms.map((p) => p.toLowerCase()));
  return a.platforms.some((p) => setB.has(p.toLowerCase()));
}

/**
 * Weighted LCS Dynamic Programming over primary genres of both players' top games.
 * Complexity: O(|G_u| * |G_v|) <= O(100) = O(1).
 */
export function computeWeightedGenreLcs(
  gamesA: readonly UserGame[],
  gamesB: readonly UserGame[],
): number {
  const genresA = gamesA.map((g) => (g.genres[0] ?? 'other').toLowerCase());
  const genresB = gamesB.map((g) => (g.genres[0] ?? 'other').toLowerCase());
  const m = genresA.length;
  const n = genresB.length;
  if (m === 0 || n === 0) return 0;

  const dp: number[][] = Array.from({ length: m + 1 }, () =>
    Array<number>(n + 1).fill(0),
  );

  for (let i = 1; i <= m; i += 1) {
    const row = dp[i];
    const prevRow = dp[i - 1];
    if (!row || !prevRow) continue;

    for (let j = 1; j <= n; j += 1) {
      if (genresA[i - 1] === genresB[j - 1]) {
        const w = (dcgWeight(i) + dcgWeight(j)) / 2;
        row[j] = (prevRow[j - 1] ?? 0) + w;
      } else {
        row[j] = Math.max(prevRow[j] ?? 0, row[j - 1] ?? 0);
      }
    }
  }

  let maxPossible = 0;
  const minLen = Math.min(m, n);
  for (let k = 1; k <= minLen; k += 1) {
    maxPossible += dcgWeight(k);
  }
  const best = dp[m]?.[n] ?? 0;
  return maxPossible > 0 ? Math.min(1, best / maxPossible) : 0;
}

export function computeWeightedGamesAffinity(
  meGames: readonly UserGame[],
  targetGames: readonly UserGame[],
): { score: number; sharedGames: UserGame[] } {
  if (meGames.length === 0 || targetGames.length === 0) {
    return { score: 0, sharedGames: [] };
  }

  const targetBySlug = new Map<string, UserGame>();
  for (const g of targetGames) {
    targetBySlug.set(g.slug.toLowerCase(), g);
  }

  let exactWeightedSum = 0;
  let maxWeightedSum = 0;
  const sharedGames: UserGame[] = [];

  for (const myGame of meGames) {
    const baseW = dcgWeight(myGame.priorityOrder);
    maxWeightedSum += baseW;
    const match = targetBySlug.get(myGame.slug.toLowerCase());
    if (match) {
      sharedGames.push(myGame);
      let multiplier = 1.0;
      if (hasCompatiblePlatform(myGame, match)) {
        multiplier += 0.15;
      }
      if (myGame.preferredMode === match.preferredMode) {
        multiplier += 0.15;
      }
      const pairW = (baseW + dcgWeight(match.priorityOrder)) / 2;
      exactWeightedSum += pairW * multiplier;
    }
  }

  const exactScore =
    maxWeightedSum > 0 ? Math.min(1, exactWeightedSum / maxWeightedSum) : 0;
  const genreLcsScore = computeWeightedGenreLcs(meGames, targetGames);
  const blended = Math.min(1, 0.72 * exactScore + 0.28 * genreLcsScore);

  return {
    score: Number(blended.toFixed(4)),
    sharedGames,
  };
}

export function computeDnaCosineSimilarity(a: GamerDna, b: GamerDna): number {
  const vecA = [
    a.competitive / 100,
    a.voiceCall / 100,
    a.coopFocus / 100,
    a.nightOwl / 100,
    a.intensity / 100,
  ];
  const vecB = [
    b.competitive / 100,
    b.voiceCall / 100,
    b.coopFocus / 100,
    b.nightOwl / 100,
    b.intensity / 100,
  ];

  // Combine cosine similarity with L1 proximity so all-zero/all-50 vectors still differentiate cleanly
  let dot = 0;
  let normA = 0;
  let normB = 0;
  let l1Diff = 0;

  for (let i = 0; i < vecA.length; i += 1) {
    const va = vecA[i] ?? 0;
    const vb = vecB[i] ?? 0;
    dot += va * vb;
    normA += va * va;
    normB += vb * vb;
    l1Diff += Math.abs(va - vb);
  }

  const cosine =
    normA > 0 && normB > 0 ? dot / (Math.sqrt(normA) * Math.sqrt(normB)) : 0;
  const normalizedCosine = (1 + cosine) / 2;
  const l1Proximity = Math.max(0, 1 - l1Diff / vecA.length);

  return Number((0.5 * normalizedCosine + 0.5 * l1Proximity).toFixed(4));
}

export function computeProximityScore(distanceKm: number): number {
  if (distanceKm <= 5) return 1;
  if (distanceKm >= 120) return 0.15;
  const decay = Math.exp(-distanceKm / 45);
  return Number(Math.max(0.15, Math.min(1, decay)).toFixed(4));
}

/**
 * Exposure Fairness RankScore inspired by Gale-Shapley / Anti-Pareto decay.
 */
export function applyFairnessDecay(
  baseTotalScore: number,
  context: FairnessContext = {},
): number {
  const alpha = context.alphaReciprocity ?? 0.25;
  const beta = context.betaExposureDecay ?? 0.04;
  const reciprocity = Math.max(0, Math.min(1, context.reciprocityProb ?? 0.5));
  const impressions = Math.max(0, context.dailyImpressions ?? 0);

  const reciprocityFactor = 1 + alpha * reciprocity;
  const exposureDecay = 1 / (1 + beta * impressions);
  const ethicalBoost =
    (context.isVerified ? 1.06 : 1.0) * (context.isNewbie ? 1.08 : 1.0);

  return Number(
    (baseTotalScore * reciprocityFactor * exposureDecay * ethicalBoost).toFixed(4),
  );
}

abstract class BaseMatchScoringStrategy implements IMatchScoringStrategy {
  abstract readonly strategyName: string;
  protected abstract readonly weights: {
    games: number;
    schedule: number;
    dna: number;
    proximity: number;
  };

  calculate(
    me: GamerProfile,
    target: GamerProfile,
    fairness?: FairnessContext,
  ): MatchScoreBreakdown {
    const gamesAffinity = computeWeightedGamesAffinity(me.games, target.games);
    const scheduleOverlap = computeContinuousScheduleOverlap(
      WeeklyScheduleMask.fromHours(me.scheduleHours),
      WeeklyScheduleMask.fromHours(target.scheduleHours),
    );
    const dnaScore = computeDnaCosineSimilarity(me.gamerDna, target.gamerDna);
    const proximityScore = computeProximityScore(target.distanceKm);

    const baseTotal =
      this.weights.games * gamesAffinity.score +
      this.weights.schedule * scheduleOverlap.score +
      this.weights.dna * dnaScore +
      this.weights.proximity * proximityScore;

    const clampedTotal = Math.max(0, Math.min(1, baseTotal));
    const rankScore = applyFairnessDecay(clampedTotal, {
      dailyImpressions: target.dailyImpressions,
      isNewbie: target.isNewbie,
      isVerified: target.isLivenessVerified,
      ...fairness,
    });

    return {
      strategyName: this.strategyName,
      totalPercent: Math.round(clampedTotal * 100),
      rankScore,
      gamesScore: gamesAffinity.score,
      scheduleScore: scheduleOverlap.score,
      dnaScore,
      proximityScore,
      sharedGames: gamesAffinity.sharedGames,
      overlapHoursTotal: scheduleOverlap.totalOverlapHours,
      longestContinuousBlockHours: scheduleOverlap.longestBlockHours,
      continuousBlocksCount: scheduleOverlap.continuousBlocks.length,
      primeOverlapLabel: scheduleOverlap.primeWindowLabel,
    };
  }
}

/**
 * Default Relationship + Gaming Strategy:
 * S_total = 0.35 * S_jogos + 0.25 * S_agenda + 0.25 * S_dna + 0.15 * S_proximidade
 */
export class HybridGamerScoringStrategy extends BaseMatchScoringStrategy {
  readonly strategyName = 'HybridGamerScoringStrategy';
  protected readonly weights = {
    games: 0.35,
    schedule: 0.25,
    dna: 0.25,
    proximity: 0.15,
  };
}

/**
 * Immediate Co-op Lobby Strategy ("Duo Agora"):
 * Prioritizes shared games & continuous play schedule over geographic distance.
 */
export class CoopDuoScoringStrategy extends BaseMatchScoringStrategy {
  readonly strategyName = 'CoopDuoScoringStrategy';
  protected readonly weights = {
    games: 0.45,
    schedule: 0.35,
    dna: 0.15,
    proximity: 0.05,
  };
}

/**
 * Deterministic zero-cost Co-op Icebreaker generator using shared games,
 * continuous schedule overlap, and Gamer DNA.
 */
export function generateCoopIcebreakers(
  me: GamerProfile,
  target: GamerProfile,
  breakdown: MatchScoreBreakdown,
): readonly string[] {
  const topSharedGame = breakdown.sharedGames[0]?.title ?? target.games[0]?.title ?? 'um co-op';
  const secondSharedGame = breakdown.sharedGames[1]?.title;
  const windowLabel =
    breakdown.overlapHoursTotal >= 2
      ? breakdown.primeOverlapLabel
      : 'essa semana à noite';

  const first = `Oi ${target.displayName}! Deu ${breakdown.totalPercent}% de Duo — topa um ${topSharedGame} na janela de ${windowLabel}?`;
  const second = secondSharedGame
    ? `Vi que você curte ${topSharedGame} e ${secondSharedGame}: hoje você está mais no modo tryhard ou chill sem tilt?`
    : target.gamerDna.voiceCall >= 60
      ? `Qual é a regra de ouro pra sobreviver em call jogando ${topSharedGame} com você?`
      : `Se a gente abrir um ${topSharedGame} hoje, você prefere chat tranquilo ou call no Discord?`;
  const third = `Sobre seu prompt ("${target.promptQuestion}"): adorei a resposta! Quando abre a próxima lobby?`;

  return [first, second, third];
}
