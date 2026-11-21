'use client';

import React, { useState } from 'react';
import Link from 'next/link';
import {
  Award,
  Check,
  Clock,
  Copy,
  Gamepad2,
  MapPin,
  Share2,
  ShieldCheck,
  Sparkles,
} from 'lucide-react';
import { GG_BADGE_CATALOG, type GamerProfile } from '@/core/domain/types';
import { AvatarArt } from '@/components/AvatarArt';
import { GamerDnaBars, ScheduleHeatmapStrip } from '@/components/GamerDnaBars';

interface GamerDnaCardViewProps {
  profile: GamerProfile;
  matchPercent?: number;
}

export function GamerDnaCardView({
  profile,
  matchPercent = 94,
}: GamerDnaCardViewProps) {
  const [copied, setCopied] = useState(false);

  const shareUrl = `https://nexusduo.app/u/${profile.username}`;

  async function handleCopyShareLink() {
    try {
      if (typeof navigator !== 'undefined' && navigator.clipboard) {
        await navigator.clipboard.writeText(shareUrl);
      }
      setCopied(true);
      setTimeout(() => setCopied(false), 2400);
    } catch {
      setCopied(true);
      setTimeout(() => setCopied(false), 2400);
    }
  }

  return (
    <div className="mx-auto w-full max-w-[960px]">
      <div className="grid items-start gap-8 lg:grid-cols-12">
        {/* Collectible Holographic Card (9:16 editorial proportion) */}
        <div className="lg:col-span-6">
          <div
            data-testid="gamer-dna-card"
            className="nexus-holo-border relative overflow-hidden rounded-[28px] bg-nexus-surface"
          >
            {/* Subtle holographic top shimmer strip */}
            <div
              className="h-1.5 w-full"
              style={{
                background:
                  'linear-gradient(90deg, #8B5CF6 0%, #06B6D4 50%, #EC4899 100%)',
              }}
            />

            <div className="relative h-[280px] w-full">
              <AvatarArt
                glyph={profile.avatarGlyph}
                displayName={profile.displayName}
                gradient={profile.avatarGradient}
                size="card"
                className="h-full"
              />

              <div className="absolute left-4 right-4 top-4 flex items-center justify-between gap-2">
                <span className="inline-flex items-center gap-1.5 rounded-full border border-white/15 bg-nexus-void/80 px-3 py-1 text-[11px] font-semibold uppercase tracking-wider text-nexus-text backdrop-blur-md">
                  <Sparkles className="h-3 w-3 text-nexus-primary" />
                  Gamer DNA · 001
                </span>
                {profile.isLivenessVerified && (
                  <span className="inline-flex items-center gap-1 rounded-full border border-nexus-cyber/45 bg-nexus-void/80 px-2.5 py-1 text-xs font-semibold text-nexus-cyber backdrop-blur-md">
                    <ShieldCheck className="h-3.5 w-3.5" />
                    Verificado
                  </span>
                )}
              </div>

              <div className="nexus-scrim absolute inset-x-0 bottom-0 px-6 pb-5 pt-14">
                <span className="inline-flex rounded-full border border-nexus-primary/40 bg-nexus-primary/20 px-3 py-0.5 text-xs font-semibold text-white">
                  {profile.gamerDna.archetype}
                </span>
                <h1 className="mt-2 truncate font-display text-3xl font-bold tracking-tight text-white">
                  {profile.displayName}, {profile.age}
                </h1>
                <div className="mt-1 flex flex-wrap items-center gap-3 text-xs text-nexus-text-secondary">
                  <span className="nexus-tabular font-semibold text-nexus-cyber">
                    @{profile.username}
                  </span>
                  <span className="inline-flex items-center gap-1">
                    <MapPin className="h-3.5 w-3.5" />
                    {profile.cityLabel}
                  </span>
                </div>
              </div>
            </div>

            <div className="space-y-5 p-6">
              <p className="max-w-[58ch] text-sm leading-relaxed text-nexus-text-secondary">
                {profile.bio}
              </p>

              {/* Top Games */}
              <div>
                <h2 className="text-xs font-semibold uppercase tracking-widest text-nexus-text-muted">
                  Top Jogos & Selos OCR
                </h2>
                <div className="mt-2.5 flex flex-wrap gap-2">
                  {profile.games.map((game) => (
                    <div
                      key={game.id}
                      className="inline-flex items-center gap-2 rounded-xl border border-white/10 bg-nexus-elevated px-3 py-1.5 text-xs"
                    >
                      <Gamepad2 className="h-3.5 w-3.5 text-nexus-primary" />
                      <span className="font-semibold text-nexus-text">
                        {game.title}
                      </span>
                      {game.rankLabel && (
                        <span className="nexus-tabular rounded-md bg-white/[0.06] px-1.5 py-0.5 text-[11px] text-nexus-cyber">
                          {game.rankLabel}
                        </span>
                      )}
                      {game.isRankOcrVerified && (
                        <span
                          className="text-[10px] font-bold text-nexus-success"
                          title="Rank verificado via OCR"
                        >
                          OCR✓
                        </span>
                      )}
                    </div>
                  ))}
                </div>
              </div>

              {/* Prime Schedule */}
              <div className="rounded-2xl border border-white/[0.08] bg-nexus-elevated/70 p-4">
                <div className="mb-3 flex items-center justify-between gap-2">
                  <span className="inline-flex items-center gap-1.5 text-xs font-semibold text-nexus-text">
                    <Clock className="h-3.5 w-3.5 text-nexus-cyber" />
                    Horários Nobres
                  </span>
                  <span className="nexus-tabular text-xs text-nexus-cyber">
                    {profile.primeScheduleLabel}
                  </span>
                </div>
                <ScheduleHeatmapStrip scheduleHours={profile.scheduleHours} />
              </div>

              {/* Footer share barcode strip */}
              <div className="flex items-center justify-between gap-3 border-t border-white/[0.08] pt-4 text-xs">
                <span className="nexus-tabular text-nexus-text-muted">
                  nexusduo.app/u/{profile.username}
                </span>
                <span className="nexus-tabular font-bold text-nexus-success">
                  {matchPercent}% DUO POTENTIAL
                </span>
              </div>
            </div>
          </div>
        </div>

        {/* Right Showcase Panel: DNA Bars, GG Badges, Share & Match CTA */}
        <div className="space-y-5 lg:col-span-6">
          <div className="nexus-surface-card rounded-2xl p-6">
            <h2 className="font-display text-lg font-semibold text-nexus-text">
              Radar de Gamer DNA
            </h2>
            <p className="mt-1 text-xs text-nexus-text-secondary">
              Objetivo: {profile.gamerDna.relationshipGoal}
            </p>
            <div className="mt-4">
              <GamerDnaBars dna={profile.gamerDna} />
            </div>
          </div>

          <div className="nexus-surface-card rounded-2xl p-6">
            <div className="flex items-center justify-between gap-2">
              <h2 className="font-display text-lg font-semibold text-nexus-text">
                GG Badges (Fair Play)
              </h2>
              <Award className="h-5 w-5 text-nexus-warning" />
            </div>
            <div className="mt-4 flex flex-wrap gap-2.5">
              {profile.ggBadges.map((item) => {
                const meta = GG_BADGE_CATALOG[item.code];
                return (
                  <div
                    key={item.code}
                    className="inline-flex items-center gap-2 rounded-xl border border-white/10 bg-nexus-elevated px-3.5 py-2"
                  >
                    <span className="text-xs font-semibold text-nexus-text">
                      {meta.label}
                    </span>
                    <span className="nexus-tabular rounded-full bg-nexus-primary/20 px-2 py-0.5 text-xs font-bold text-nexus-primary">
                      ×{item.count}
                    </span>
                  </div>
                );
              })}
            </div>
          </div>

          <div className="nexus-surface-card rounded-2xl p-6">
            <h2 className="font-display text-lg font-semibold text-nexus-text">
              Prompt em Destaque
            </h2>
            <p className="mt-2 text-xs font-semibold uppercase tracking-wider text-nexus-primary">
              {profile.promptQuestion}
            </p>
            <p className="mt-2 text-sm leading-relaxed text-nexus-text-secondary">
              “{profile.promptAnswer}”
            </p>

            <div className="mt-6 flex flex-wrap gap-3">
              <Link
                href="/app"
                className="inline-flex flex-1 items-center justify-center gap-2 rounded-xl nexus-brand-gradient px-5 py-3 text-sm font-semibold text-white shadow-nexus-primary transition hover:opacity-95"
              >
                Dar Match no Web App
              </Link>
              <button
                type="button"
                onClick={handleCopyShareLink}
                className="inline-flex items-center justify-center gap-2 rounded-xl border border-white/15 bg-nexus-elevated px-4 py-3 text-sm font-semibold text-nexus-text transition hover:border-nexus-cyber/60"
              >
                {copied ? (
                  <>
                    <Check className="h-4 w-4 text-nexus-success" />
                    Link copiado!
                  </>
                ) : (
                  <>
                    <Share2 className="h-4 w-4 text-nexus-cyber" />
                    Copiar Link
                  </>
                )}
              </button>
            </div>

            <div className="mt-3 flex items-center justify-between rounded-xl border border-white/[0.06] bg-nexus-void/60 px-3.5 py-2 text-xs text-nexus-text-muted">
              <span className="truncate font-mono">{shareUrl}</span>
              <Copy className="h-3.5 w-3.5 shrink-0" />
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
