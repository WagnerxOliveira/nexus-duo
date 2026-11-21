'use client';

import React, { useState } from 'react';
import Link from 'next/link';
import {
  Award,
  ChevronDown,
  ChevronUp,
  Clock,
  Gamepad2,
  Heart,
  MapPin,
  RotateCcw,
  ShieldCheck,
  Sparkles,
  X,
} from 'lucide-react';
import {
  GG_BADGE_CATALOG,
  type DiscoveryCandidate,
  type GamerProfile,
  type SwipeAction,
} from '@/core/domain/types';
import { AvatarArt } from '@/components/AvatarArt';
import { MatchScoreRing } from '@/components/MatchScoreRing';
import { GamerDnaBars, ScheduleHeatmapStrip } from '@/components/GamerDnaBars';

interface DiscoveryDeckViewProps {
  currentUser: GamerProfile;
  candidates: readonly DiscoveryCandidate[];
  onSwipe: (targetId: string, action: SwipeAction, introNote?: string) => Promise<void>;
  onResetDeck: () => void;
  strategyMode: 'hybrid' | 'coop';
  onChangeStrategy: (mode: 'hybrid' | 'coop') => void;
}

export function DiscoveryDeckView({
  currentUser,
  candidates,
  onSwipe,
  onResetDeck,
  strategyMode,
  onChangeStrategy,
}: DiscoveryDeckViewProps) {
  const [expanded, setExpanded] = useState(false);
  const [superNoteOpen, setSuperNoteOpen] = useState(false);
  const [superNote, setSuperNote] = useState('');
  const [busy, setBusy] = useState(false);

  const current = candidates[0];

  async function triggerSwipe(action: SwipeAction, note?: string) {
    if (!current || busy) return;
    setBusy(true);
    try {
      await onSwipe(current.profile.id, action, note);
      setExpanded(false);
      setSuperNoteOpen(false);
      setSuperNote('');
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="mx-auto flex w-full max-w-[560px] flex-col gap-4">
      {/* Top Bar: Daily Loot Drop + Strategy Switcher */}
      <div className="flex flex-wrap items-center justify-between gap-2">
        <div>
          <span className="text-[11px] font-semibold uppercase tracking-widest text-nexus-cyber">
            Daily Loot Drop
          </span>
          <h1 className="font-display text-xl font-bold tracking-tight text-nexus-text">
            Descoberta de Duos
          </h1>
        </div>

        <div
          className="inline-flex rounded-xl border border-white/10 bg-nexus-surface p-1 text-xs"
          role="group"
          aria-label="Estratégia de Scoring"
        >
          <button
            type="button"
            onClick={() => onChangeStrategy('hybrid')}
            className={`rounded-lg px-3 py-1.5 font-semibold transition ${
              strategyMode === 'hybrid'
                ? 'bg-nexus-primary text-white shadow-nexus-primary'
                : 'text-nexus-text-secondary hover:text-white'
            }`}
          >
            Híbrido
          </button>
          <button
            type="button"
            onClick={() => onChangeStrategy('coop')}
            className={`rounded-lg px-3 py-1.5 font-semibold transition ${
              strategyMode === 'coop'
                ? 'bg-nexus-cyber text-nexus-void shadow-nexus-cyber'
                : 'text-nexus-text-secondary hover:text-white'
            }`}
          >
            Co-op Agora
          </button>
        </div>
      </div>

      {!current ? (
        <div className="nexus-surface-card flex flex-col items-center justify-center rounded-[24px] p-10 text-center">
          <div className="flex h-14 w-14 items-center justify-center rounded-2xl bg-nexus-primary/15 text-nexus-primary">
            <Sparkles className="h-7 w-7" />
          </div>
          <h2 className="mt-4 font-display text-xl font-bold text-nexus-text">
            Loot Drop de hoje concluído!
          </h2>
          <p className="mt-2 max-w-[44ch] text-sm text-nexus-text-secondary">
            Você já avaliou todos os perfis curados da fila atual. Converse com seus
            matches no chat E2EE ou recarregue o deck demo para testar novamente.
          </p>
          <button
            type="button"
            onClick={onResetDeck}
            className="mt-6 inline-flex items-center gap-2 rounded-xl nexus-brand-gradient px-5 py-2.5 text-sm font-semibold text-white shadow-nexus-primary"
          >
            <RotateCcw className="h-4 w-4" />
            Recarregar Deck Demo
          </button>
        </div>
      ) : (
        <article
          data-testid="discovery-card"
          className="nexus-holo-border overflow-hidden rounded-[24px] bg-nexus-surface"
        >
          {/* Editorial Hero Portrait + Scrim */}
          <div className="relative h-[340px] w-full sm:h-[370px]">
            <AvatarArt
              glyph={current.profile.avatarGlyph}
              displayName={current.profile.displayName}
              gradient={current.profile.avatarGradient}
              size="card"
              className="h-full"
            />

            {/* Top Floating Badges */}
            <div className="absolute left-4 right-4 top-4 flex items-start justify-between gap-2">
              <div className="flex flex-wrap items-center gap-2">
                {current.profile.isLivenessVerified && (
                  <span className="inline-flex items-center gap-1 rounded-full border border-nexus-cyber/45 bg-nexus-void/80 px-2.5 py-1 text-xs font-semibold text-nexus-cyber backdrop-blur-md">
                    <ShieldCheck className="h-3.5 w-3.5" />
                    Player Verificado
                  </span>
                )}
                {current.profile.isOnlineNow && (
                  <span className="inline-flex items-center gap-1.5 rounded-full border border-nexus-success/40 bg-nexus-void/80 px-2.5 py-1 text-xs font-semibold text-nexus-success backdrop-blur-md">
                    <span className="h-2 w-2 rounded-full bg-nexus-success" />
                    Online
                  </span>
                )}
              </div>

              <MatchScoreRing percent={current.score.totalPercent} size="md" />
            </div>

            {/* Mandatory Scrim over bottom 45% */}
            <div className="nexus-scrim absolute inset-x-0 bottom-0 px-5 pb-5 pt-16">
              <div className="flex items-end justify-between gap-3">
                <div className="min-w-0">
                  <h2 className="truncate font-display text-2xl font-bold tracking-tight text-white">
                    {current.profile.displayName}, {current.profile.age}
                  </h2>
                  <div className="mt-0.5 flex flex-wrap items-center gap-2 text-xs text-nexus-text-secondary">
                    <span className="inline-flex items-center gap-1">
                      <MapPin className="h-3.5 w-3.5 text-nexus-primary" />
                      {current.profile.distanceBucket} · {current.profile.cityLabel}
                    </span>
                  </div>
                </div>

                <Link
                  href={`/u/${current.profile.username}`}
                  className="shrink-0 rounded-full border border-white/15 bg-white/10 px-3 py-1 text-xs font-semibold text-white backdrop-blur-md hover:border-nexus-primary/60"
                >
                  @{current.profile.username}
                </Link>
              </div>

              {/* Shared Games + Continuous DP Schedule Badge */}
              <div className="mt-3 flex flex-wrap gap-2">
                <span
                  data-testid="schedule-overlap-badge"
                  className="inline-flex items-center gap-1.5 rounded-full border border-nexus-cyber/40 bg-nexus-cyber/15 px-3 py-1 text-xs font-semibold text-nexus-cyber"
                >
                  <Clock className="h-3.5 w-3.5" />
                  <span className="nexus-tabular">
                    {current.score.overlapHoursTotal}h livres em comum
                  </span>
                </span>

                {(current.score.sharedGames.length > 0
                  ? current.score.sharedGames
                  : current.profile.games.slice(0, 2)
                ).map((game) => (
                  <span
                    key={game.id}
                    className="inline-flex items-center gap-1.5 rounded-full border border-nexus-primary/35 bg-nexus-primary/15 px-2.5 py-1 text-xs font-semibold text-white"
                  >
                    <Gamepad2 className="h-3 w-3 text-nexus-primary" />
                    {game.title}
                  </span>
                ))}
              </div>
            </div>
          </div>

          {/* Card Body: Bio + Expandable Deep Profile */}
          <div className="space-y-4 p-5">
            <p className="max-w-[60ch] text-sm leading-relaxed text-nexus-text-secondary">
              {current.profile.bio}
            </p>

            <div className="rounded-2xl border border-white/[0.08] bg-nexus-elevated/70 p-3.5">
              <p className="text-[11px] font-semibold uppercase tracking-wider text-nexus-primary">
                {current.profile.promptQuestion}
              </p>
              <p className="mt-1 text-sm text-nexus-text">
                “{current.profile.promptAnswer}”
              </p>
            </div>

            <button
              type="button"
              onClick={() => setExpanded((prev) => !prev)}
              className="flex w-full items-center justify-between rounded-xl border border-white/[0.08] bg-nexus-void/50 px-3.5 py-2 text-xs font-semibold text-nexus-text-secondary transition hover:text-white"
            >
              <span>
                {expanded
                  ? 'Ocultar Gamer DNA, OCR & Horários DP'
                  : 'Ver Gamer DNA, Ranks OCR & Grade de Horários'}
              </span>
              {expanded ? (
                <ChevronUp className="h-4 w-4" />
              ) : (
                <ChevronDown className="h-4 w-4" />
              )}
            </button>

            {expanded && (
              <div className="space-y-4 border-t border-white/[0.08] pt-4">
                <div>
                  <h3 className="mb-2 text-xs font-semibold uppercase tracking-wider text-nexus-text-muted">
                    Gamer DNA · {current.profile.gamerDna.archetype}
                  </h3>
                  <GamerDnaBars dna={current.profile.gamerDna} compact />
                </div>

                <div>
                  <div className="mb-2 flex items-center justify-between text-xs">
                    <span className="font-semibold text-nexus-text-muted">
                      Sobreposição DP (Ciano = em comum)
                    </span>
                    <span className="nexus-tabular text-nexus-cyber">
                      Maior janela: {current.score.longestContinuousBlockHours}h ·{' '}
                      {current.score.primeOverlapLabel}
                    </span>
                  </div>
                  <ScheduleHeatmapStrip
                    scheduleHours={current.profile.scheduleHours}
                    overlapWithHours={currentUser.scheduleHours}
                  />
                </div>

                <div className="flex flex-wrap gap-2">
                  {current.profile.ggBadges.map((b) => (
                    <span
                      key={b.code}
                      className="inline-flex items-center gap-1.5 rounded-lg border border-white/10 bg-nexus-elevated px-2.5 py-1 text-xs text-nexus-text"
                    >
                      <Award className="h-3.5 w-3.5 text-nexus-warning" />
                      {GG_BADGE_CATALOG[b.code].label}
                      <span className="nexus-tabular text-nexus-primary">
                        ×{b.count}
                      </span>
                    </span>
                  ))}
                </div>
              </div>
            )}

            {/* Optional Super Duo quick note */}
            {superNoteOpen && (
              <div className="space-y-2 rounded-2xl border border-nexus-primary/40 bg-nexus-primary/10 p-3.5">
                <label
                  htmlFor="super-duo-note"
                  className="block text-xs font-semibold text-white"
                >
                  Convite Super Duo (criptografado E2EE ao dar match):
                </label>
                <input
                  id="super-duo-note"
                  type="text"
                  value={superNote}
                  onChange={(e) => setSuperNote(e.target.value)}
                  placeholder={`Ex.: Bora um ${current.score.sharedGames[0]?.title ?? 'co-op'} hoje às 21h?`}
                  className="w-full rounded-xl border border-white/15 bg-nexus-void/90 px-3 py-2 text-sm text-white placeholder:text-nexus-text-muted focus:border-nexus-cyber focus:outline-none"
                />
                <div className="flex justify-end gap-2">
                  <button
                    type="button"
                    onClick={() => setSuperNoteOpen(false)}
                    className="rounded-lg px-3 py-1.5 text-xs font-semibold text-nexus-text-secondary hover:text-white"
                  >
                    Cancelar
                  </button>
                  <button
                    type="button"
                    disabled={busy}
                    onClick={() => triggerSwipe('super_duo', superNote)}
                    className="rounded-lg nexus-brand-gradient px-3.5 py-1.5 text-xs font-semibold text-white"
                  >
                    Enviar Super Duo
                  </button>
                </div>
              </div>
            )}

            {/* Thumb Zone Action Bar */}
            <div className="grid grid-cols-3 gap-3 pt-1">
              <button
                type="button"
                data-testid="action-pass"
                disabled={busy}
                onClick={() => triggerSwipe('pass')}
                className="flex items-center justify-center gap-2 rounded-2xl border border-white/10 bg-nexus-elevated py-3.5 text-sm font-semibold text-nexus-text-secondary transition hover:border-nexus-danger/50 hover:text-nexus-danger disabled:opacity-50"
                aria-label="Passar perfil"
              >
                <X className="h-5 w-5" />
                <span>Passar</span>
              </button>

              <button
                type="button"
                data-testid="action-super-duo"
                disabled={busy}
                onClick={() => setSuperNoteOpen((prev) => !prev)}
                className="flex items-center justify-center gap-2 rounded-2xl border border-nexus-cyber/40 bg-nexus-cyber/15 py-3.5 text-sm font-semibold text-nexus-cyber transition hover:bg-nexus-cyber/25 disabled:opacity-50"
                aria-label="Enviar Super Duo"
              >
                <Gamepad2 className="h-5 w-5" />
                <span>Super Duo</span>
              </button>

              <button
                type="button"
                data-testid="action-like"
                disabled={busy}
                onClick={() => triggerSwipe('like')}
                className="flex items-center justify-center gap-2 rounded-2xl nexus-brand-gradient py-3.5 text-sm font-semibold text-white shadow-nexus-match transition hover:opacity-95 disabled:opacity-50"
                aria-label="Curtir perfil"
              >
                <Heart className="h-5 w-5" />
                <span>Curtir</span>
              </button>
            </div>
          </div>
        </article>
      )}
    </div>
  );
}
