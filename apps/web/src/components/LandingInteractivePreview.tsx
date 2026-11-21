'use client';

import React, { useMemo, useState } from 'react';
import Link from 'next/link';
import {
  Clock,
  Gamepad2,
  Heart,
  Radio,
  ShieldCheck,
  Sparkles,
} from 'lucide-react';
import { DEMO_CURRENT_USER, DEMO_PROFILES } from '@/core/data/demoSeed';
import { HybridGamerScoringStrategy } from '@/core/algo/matchScoring';
import { AvatarArt } from '@/components/AvatarArt';
import { MatchScoreRing } from '@/components/MatchScoreRing';

const FEATURED_USERNAMES = ['valkyrie', 'biacozy', 'kael_br'] as const;

export function LandingInteractivePreview() {
  const [selectedUsername, setSelectedUsername] =
    useState<(typeof FEATURED_USERNAMES)[number]>('valkyrie');
  const [likedNotice, setLikedNotice] = useState<string | null>(null);

  const strategy = useMemo(() => new HybridGamerScoringStrategy(), []);

  const activeProfile = useMemo(
    () =>
      DEMO_PROFILES.find((p) => p.username === selectedUsername) ??
      DEMO_PROFILES[0]!,
    [selectedUsername],
  );

  const score = useMemo(
    () => strategy.calculate(DEMO_CURRENT_USER, activeProfile),
    [strategy, activeProfile],
  );

  return (
    <div className="relative mx-auto w-full max-w-[440px]">
      {/* Profile switcher tabs */}
      <div className="mb-3 flex flex-wrap items-center justify-between gap-2">
        <span className="text-xs font-semibold uppercase tracking-widest text-nexus-text-muted">
          Preview · Daily Loot Drop
        </span>
        <div className="inline-flex rounded-full border border-white/10 bg-nexus-surface p-1">
          {FEATURED_USERNAMES.map((uname) => {
            const p = DEMO_PROFILES.find((item) => item.username === uname);
            const isSelected = uname === selectedUsername;
            return (
              <button
                key={uname}
                type="button"
                onClick={() => {
                  setSelectedUsername(uname);
                  setLikedNotice(null);
                }}
                className={`rounded-full px-3 py-1 text-xs font-semibold transition ${
                  isSelected
                    ? 'bg-nexus-primary text-white shadow-nexus-primary'
                    : 'text-nexus-text-secondary hover:text-white'
                }`}
              >
                {p?.displayName ?? uname}
              </button>
            );
          })}
        </div>
      </div>

      {/* Interactive Match Card */}
      <div className="nexus-holo-border overflow-hidden rounded-[24px] bg-nexus-surface">
        <div className="relative h-[320px] w-full">
          <AvatarArt
            glyph={activeProfile.avatarGlyph}
            displayName={activeProfile.displayName}
            gradient={activeProfile.avatarGradient}
            size="card"
            className="h-full"
          />

          {/* Top badges */}
          <div className="absolute left-4 right-4 top-4 flex items-start justify-between gap-3">
            <div className="flex flex-wrap items-center gap-2">
              <span className="inline-flex items-center gap-1.5 rounded-full border border-nexus-cyber/40 bg-nexus-void/80 px-3 py-1 text-xs font-semibold text-nexus-cyber backdrop-blur-md">
                <ShieldCheck className="h-3.5 w-3.5" />
                Liveness OK
              </span>
              <span className="inline-flex items-center gap-1.5 rounded-full border border-white/10 bg-nexus-void/75 px-3 py-1 text-xs font-medium text-nexus-text-secondary backdrop-blur-md">
                {activeProfile.distanceBucket}
              </span>
            </div>
            <MatchScoreRing percent={score.totalPercent} size="md" />
          </div>

          {/* Mandatory scrim over bottom 45% */}
          <div className="nexus-scrim absolute inset-x-0 bottom-0 px-5 pb-5 pt-16">
            <div className="flex items-end justify-between gap-2">
              <div className="min-w-0">
                <h3 className="truncate font-display text-2xl font-bold tracking-tight text-white">
                  {activeProfile.displayName}, {activeProfile.age}
                </h3>
                <p className="truncate text-sm text-nexus-text-secondary">
                  @{activeProfile.username} · {activeProfile.gamerDna.archetype}
                </p>
              </div>
              <Link
                href={`/u/${activeProfile.username}`}
                className="shrink-0 rounded-full border border-white/15 bg-white/5 px-3 py-1 text-xs font-semibold text-nexus-text hover:border-nexus-primary/60 hover:bg-nexus-primary/15"
              >
                Ver Card
              </Link>
            </div>

            <div className="mt-3 flex flex-wrap gap-2">
              <span className="inline-flex items-center gap-1.5 rounded-full border border-nexus-cyber/35 bg-nexus-cyber/15 px-2.5 py-1 text-xs font-semibold text-nexus-cyber">
                <Clock className="h-3.5 w-3.5" />
                <span className="nexus-tabular">
                  {score.overlapHoursTotal}h livres em comum
                </span>
              </span>
              {activeProfile.games.slice(0, 2).map((g) => (
                <span
                  key={g.id}
                  className="inline-flex items-center gap-1.5 rounded-full border border-white/10 bg-nexus-elevated/90 px-2.5 py-1 text-xs font-medium text-nexus-text"
                >
                  <Gamepad2 className="h-3 w-3 text-nexus-primary" />
                  {g.title}
                </span>
              ))}
            </div>
          </div>
        </div>

        {/* Bottom quick action bar */}
        <div className="border-t border-white/[0.08] bg-nexus-surface p-4">
          <p className="line-clamp-2 text-sm leading-relaxed text-nexus-text-secondary">
            “{activeProfile.promptAnswer}”
          </p>

          <div className="mt-4 flex flex-wrap items-center justify-between gap-2.5">
            <button
              type="button"
              onClick={() =>
                setLikedNotice(
                  `Super Duo simulado com ${activeProfile.displayName}! Abra o /app para iniciar o chat E2EE.`,
                )
              }
              className="flex min-w-0 flex-1 items-center justify-center gap-2 rounded-xl nexus-brand-gradient px-3.5 py-2.5 text-sm font-semibold text-white shadow-nexus-primary transition hover:opacity-95"
            >
              <Heart className="h-4 w-4 shrink-0" />
              <span className="truncate">Testar Super Duo</span>
            </button>
            <Link
              href="/app"
              className="inline-flex shrink-0 items-center gap-1.5 rounded-xl border border-white/10 bg-nexus-elevated px-3.5 py-2.5 text-sm font-semibold text-nexus-text transition hover:border-nexus-primary/50"
            >
              <Sparkles className="h-4 w-4 text-nexus-cyber" />
              Abrir /app
            </Link>
          </div>

          {likedNotice && (
            <p className="mt-3 rounded-xl border border-nexus-success/30 bg-nexus-success/10 px-3 py-2 text-xs text-nexus-success">
              {likedNotice}
            </p>
          )}
        </div>
      </div>

      {/* Floating Lobby "Duo Agora" mini-card */}
      <div className="nexus-glass mt-3 flex items-center justify-between gap-3 rounded-2xl px-4 py-3">
        <div className="flex min-w-0 items-center gap-3">
          <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl bg-nexus-cyber/15 text-nexus-cyber">
            <Radio className="h-4 w-4" />
          </span>
          <div className="min-w-0">
            <p className="truncate text-xs font-semibold text-nexus-text">
              Lobby “Duo Agora” · Valorant (Casual)
            </p>
            <p className="truncate text-xs text-nexus-text-secondary">
              Clara (@valkyrie) · Discord ·{' '}
              <span className="nexus-tabular text-nexus-cyber">1h 42m restantes</span>
            </p>
          </div>
        </div>
        <Link
          href="/app"
          className="shrink-0 rounded-lg border border-nexus-cyber/35 bg-nexus-cyber/10 px-2.5 py-1 text-xs font-semibold text-nexus-cyber hover:bg-nexus-cyber/20"
        >
          Entrar
        </Link>
      </div>
    </div>
  );
}
