'use client';

import React from 'react';
import Link from 'next/link';
import { Clock, ExternalLink, Gamepad2, Lock, ShieldCheck } from 'lucide-react';
import type { GamerProfile, MatchScoreBreakdown } from '@/core/domain/types';
import { GamerDnaBars, ScheduleHeatmapStrip } from '@/components/GamerDnaBars';

interface RightContextPanelProps {
  currentUser: GamerProfile;
  targetProfile: GamerProfile | null;
  scoreBreakdown: MatchScoreBreakdown | null;
}

export function RightContextPanel({
  currentUser,
  targetProfile,
  scoreBreakdown,
}: RightContextPanelProps) {
  if (!targetProfile) {
    return (
      <aside className="hidden w-[300px] shrink-0 flex-col gap-4 border-l border-white/[0.08] bg-nexus-surface/50 p-4 min-[1440px]:flex">
        <div className="nexus-elevated-card rounded-2xl p-4 text-xs text-nexus-text-secondary">
          Selecione um perfil no Deck ou um Match para inspecionar o Gamer DNA e a
          sobreposição DP em tempo real.
        </div>
      </aside>
    );
  }

  return (
    <aside
      aria-label="Detalhes do Gamer DNA"
      className="hidden w-[310px] shrink-0 flex-col gap-4 overflow-y-auto border-l border-white/[0.08] bg-nexus-surface/40 p-4 min-[1440px]:flex"
    >
      <div className="flex items-center justify-between gap-2">
        <span className="text-[11px] font-semibold uppercase tracking-widest text-nexus-cyber">
          Detalhes do Duo
        </span>
        <Link
          href={`/u/${targetProfile.username}`}
          className="inline-flex items-center gap-1 text-xs font-semibold text-nexus-primary hover:underline"
        >
          Card
          <ExternalLink className="h-3 w-3" />
        </Link>
      </div>

      <div className="nexus-elevated-card space-y-2 rounded-2xl p-4">
        <div className="flex items-center justify-between gap-2">
          <h3 className="truncate font-display text-base font-bold text-nexus-text">
            {targetProfile.displayName}
          </h3>
          {targetProfile.isLivenessVerified && (
            <ShieldCheck className="h-4 w-4 shrink-0 text-nexus-cyber" />
          )}
        </div>
        <p className="text-xs font-semibold text-nexus-primary">
          {targetProfile.gamerDna.archetype}
        </p>
        <p className="text-xs text-nexus-text-secondary">
          {targetProfile.gamerDna.relationshipGoal}
        </p>
      </div>

      {scoreBreakdown && (
        <div className="nexus-elevated-card space-y-3 rounded-2xl p-4">
          <div className="flex items-center justify-between text-xs">
            <span className="font-semibold text-nexus-text">Score Breakdown</span>
            <span className="nexus-tabular font-bold text-nexus-success">
              {scoreBreakdown.totalPercent}%
            </span>
          </div>
          <div className="grid grid-cols-2 gap-2 text-[11px]">
            <div className="rounded-xl bg-nexus-void/70 p-2.5">
              <span className="text-nexus-text-muted">Jogos DCG</span>
              <p className="nexus-tabular mt-0.5 text-sm font-bold text-nexus-primary">
                {Math.round(scoreBreakdown.gamesScore * 100)}%
              </p>
            </div>
            <div className="rounded-xl bg-nexus-void/70 p-2.5">
              <span className="text-nexus-text-muted">Agenda DP</span>
              <p className="nexus-tabular mt-0.5 text-sm font-bold text-nexus-cyber">
                {Math.round(scoreBreakdown.scheduleScore * 100)}%
              </p>
            </div>
            <div className="rounded-xl bg-nexus-void/70 p-2.5">
              <span className="text-nexus-text-muted">Gamer DNA</span>
              <p className="nexus-tabular mt-0.5 text-sm font-bold text-nexus-secondary">
                {Math.round(scoreBreakdown.dnaScore * 100)}%
              </p>
            </div>
            <div className="rounded-xl bg-nexus-void/70 p-2.5">
              <span className="text-nexus-text-muted">Maior Janela</span>
              <p className="nexus-tabular mt-0.5 text-sm font-bold text-nexus-success">
                {scoreBreakdown.longestContinuousBlockHours}h
              </p>
            </div>
          </div>
        </div>
      )}

      <div className="nexus-elevated-card space-y-3 rounded-2xl p-4">
        <span className="text-xs font-semibold text-nexus-text">Gamer DNA</span>
        <GamerDnaBars dna={targetProfile.gamerDna} compact />
      </div>

      <div className="nexus-elevated-card space-y-3 rounded-2xl p-4">
        <div className="flex items-center justify-between text-xs">
          <span className="inline-flex items-center gap-1 font-semibold text-nexus-text">
            <Clock className="h-3.5 w-3.5 text-nexus-cyber" />
            Agenda (168h)
          </span>
          <span className="nexus-tabular text-[11px] text-nexus-cyber">
            {scoreBreakdown?.overlapHoursTotal ?? 0}h em comum
          </span>
        </div>
        <ScheduleHeatmapStrip
          scheduleHours={targetProfile.scheduleHours}
          overlapWithHours={currentUser.scheduleHours}
        />
      </div>

      <div className="nexus-elevated-card space-y-2 rounded-2xl p-4">
        <span className="inline-flex items-center gap-1.5 text-xs font-semibold text-nexus-text">
          <Gamepad2 className="h-3.5 w-3.5 text-nexus-primary" />
          Biblioteca & Ranks OCR
        </span>
        <div className="space-y-1.5">
          {targetProfile.games.map((g) => (
            <div
              key={g.id}
              className="flex items-center justify-between gap-2 rounded-lg bg-nexus-void/60 px-2.5 py-1.5 text-xs"
            >
              <span className="truncate font-medium text-nexus-text">{g.title}</span>
              <span className="nexus-tabular shrink-0 text-[11px] text-nexus-cyber">
                {g.rankLabel ?? g.preferredMode}
              </span>
            </div>
          ))}
        </div>
      </div>

      <div className="nexus-elevated-card space-y-1.5 rounded-2xl p-4">
        <span className="inline-flex items-center gap-1.5 text-xs font-semibold text-nexus-success">
          <Lock className="h-3.5 w-3.5" />
          Fingerprint E2EE (X25519)
        </span>
        <p className="break-all font-mono text-[10px] text-nexus-text-muted">
          {targetProfile.e2eePublicKeyB64}
        </p>
      </div>
    </aside>
  );
}
