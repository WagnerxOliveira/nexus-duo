import { describe, expect, it } from 'vitest';
import {
  CoopDuoScoringStrategy,
  HybridGamerScoringStrategy,
  applyFairnessDecay,
  computeDnaCosineSimilarity,
  computeWeightedGamesAffinity,
  generateCoopIcebreakers,
} from '@/core/algo/matchScoring';
import { DEMO_CURRENT_USER, DEMO_PROFILES } from '@/core/data/demoSeed';

describe('Match Scoring Strategies & Fairness Decay', () => {
  const clara = DEMO_PROFILES.find((p) => p.username === 'valkyrie')!;
  const bia = DEMO_PROFILES.find((p) => p.username === 'biacozy')!;
  const rafa = DEMO_PROFILES.find((p) => p.username === 'rafatank')!;

  it('ranks high shared-game + continuous-schedule profile strongly in HybridGamerScoringStrategy', () => {
    const hybrid = new HybridGamerScoringStrategy();
    const claraScore = hybrid.calculate(DEMO_CURRENT_USER, clara);
    const rafaScore = hybrid.calculate(DEMO_CURRENT_USER, rafa);

    expect(claraScore.strategyName).toBe('HybridGamerScoringStrategy');
    expect(claraScore.totalPercent).toBeGreaterThanOrEqual(75);
    expect(claraScore.totalPercent).toBeLessThanOrEqual(100);
    expect(claraScore.sharedGames.map((g) => g.slug)).toContain('valorant');
    expect(claraScore.overlapHoursTotal).toBeGreaterThanOrEqual(10);
    expect(claraScore.totalPercent).toBeGreaterThan(rafaScore.totalPercent);
  });

  it('switches behavior polymorphically with CoopDuoScoringStrategy (games & schedule weighted higher)', () => {
    const hybrid = new HybridGamerScoringStrategy();
    const coop = new CoopDuoScoringStrategy();

    const farTarget = { ...clara, distanceKm: 95 };
    const hybridResult = hybrid.calculate(DEMO_CURRENT_USER, farTarget);
    const coopResult = coop.calculate(DEMO_CURRENT_USER, farTarget);

    expect(coopResult.strategyName).toBe('CoopDuoScoringStrategy');
    // Coop strategy penalizes distance less (5% vs 15%) and rewards games+schedule more (80% vs 60%)
    expect(coopResult.totalPercent).toBeGreaterThanOrEqual(hybridResult.totalPercent);
  });

  it('applies anti-Pareto exposure fairness decay & ethical boosts', () => {
    const freshScore = applyFairnessDecay(0.85, {
      reciprocityProb: 0.7,
      dailyImpressions: 0,
      isVerified: true,
      isNewbie: true,
    });
    const overexposedScore = applyFairnessDecay(0.85, {
      reciprocityProb: 0.7,
      dailyImpressions: 50,
      isVerified: true,
      isNewbie: false,
    });

    expect(freshScore).toBeGreaterThan(overexposedScore);
  });

  it('computes DCG game priority weighting and DNA similarity accurately', () => {
    const identicalDna = computeDnaCosineSimilarity(
      DEMO_CURRENT_USER.gamerDna,
      DEMO_CURRENT_USER.gamerDna,
    );
    const differentDna = computeDnaCosineSimilarity(
      DEMO_CURRENT_USER.gamerDna,
      bia.gamerDna,
    );

    expect(identicalDna).toBeCloseTo(1, 4);
    expect(differentDna).toBeLessThan(identicalDna);

    const gamesAffinity = computeWeightedGamesAffinity(
      DEMO_CURRENT_USER.games,
      clara.games,
    );
    expect(gamesAffinity.sharedGames.length).toBeGreaterThanOrEqual(3);
    expect(gamesAffinity.score).toBeGreaterThan(0.5);
  });

  it('generates 3 personalized PT-BR Co-op Icebreakers referencing shared context', () => {
    const hybrid = new HybridGamerScoringStrategy();
    const breakdown = hybrid.calculate(DEMO_CURRENT_USER, clara);
    const icebreakers = generateCoopIcebreakers(DEMO_CURRENT_USER, clara, breakdown);

    expect(icebreakers).toHaveLength(3);
    expect(icebreakers[0]).toContain('Clara');
    expect(icebreakers[0]).toContain('Valorant');
  });
});
