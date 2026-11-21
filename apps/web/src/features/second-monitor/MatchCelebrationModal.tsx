'use client';

import React from 'react';
import { Lock, MessageSquare, Sparkles, X } from 'lucide-react';
import type { GamerProfile, MatchRecord } from '@/core/domain/types';
import { AvatarArt } from '@/components/AvatarArt';

interface MatchCelebrationModalProps {
  currentUser: GamerProfile;
  match: MatchRecord;
  onSelectIcebreaker: (icebreaker: string) => Promise<void>;
  onOpenChat: () => void;
  onClose: () => void;
}

export function MatchCelebrationModal({
  currentUser,
  match,
  onSelectIcebreaker,
  onOpenChat,
  onClose,
}: MatchCelebrationModalProps) {
  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-labelledby="match-modal-title"
      data-testid="match-celebration-modal"
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 p-4 backdrop-blur-md"
    >
      <div className="nexus-holo-border relative w-full max-w-[500px] overflow-hidden rounded-[28px] bg-nexus-surface p-6 sm:p-8">
        <button
          type="button"
          onClick={onClose}
          aria-label="Fechar modal de match"
          className="absolute right-4 top-4 rounded-xl border border-white/10 bg-nexus-elevated p-2 text-nexus-text-secondary hover:text-white"
        >
          <X className="h-4 w-4" />
        </button>

        <div className="flex flex-col items-center text-center">
          <span className="inline-flex items-center gap-1.5 rounded-full border border-nexus-secondary/40 bg-nexus-secondary/15 px-3 py-1 text-xs font-semibold text-nexus-secondary">
            <Sparkles className="h-3.5 w-3.5" />
            Match Confirmado · E2EE Pronto
          </span>

          <h2
            id="match-modal-title"
            className="mt-3 bg-gradient-to-r from-nexus-primary via-nexus-secondary to-nexus-cyber bg-clip-text font-display text-3xl font-bold tracking-tight text-transparent sm:text-4xl"
          >
            IT&apos;S A DUO!
          </h2>

          {/* Converging avatars */}
          <div className="mt-5 flex items-center justify-center">
            <div className="rounded-2xl p-1 nexus-brand-gradient shadow-nexus-primary">
              <AvatarArt
                glyph={currentUser.avatarGlyph}
                displayName={currentUser.displayName}
                gradient={currentUser.avatarGradient}
                size="lg"
              />
            </div>
            <div className="-mx-3 z-10 flex h-12 w-12 items-center justify-center rounded-full border-2 border-nexus-surface bg-nexus-void shadow-nexus-match">
              <span className="nexus-tabular text-sm font-bold text-nexus-success">
                {match.compatibilityScore}%
              </span>
            </div>
            <div className="rounded-2xl p-1 nexus-brand-gradient shadow-nexus-match">
              <AvatarArt
                glyph={match.peer.avatarGlyph}
                displayName={match.peer.displayName}
                gradient={match.peer.avatarGradient}
                size="lg"
              />
            </div>
          </div>

          <p className="mt-4 max-w-[44ch] text-sm text-nexus-text-secondary">
            Você e <strong className="text-white">{match.peer.displayName}</strong>{' '}
            têm{' '}
            <span className="nexus-tabular font-semibold text-nexus-cyber">
              {match.overlapHoursTotal}h livres em comum
            </span>
            . Escolha um Co-op Icebreaker para abrir o chat cifrado agora:
          </p>
        </div>

        {/* 3 Clickable Co-op Icebreakers */}
        <div className="mt-5 space-y-2.5">
          {match.icebreakerPrompts.slice(0, 3).map((prompt, index) => (
            <button
              key={prompt}
              type="button"
              data-testid={`icebreaker-btn-${index}`}
              onClick={() => onSelectIcebreaker(prompt)}
              className="flex w-full items-start gap-3 rounded-2xl border border-white/10 bg-nexus-elevated p-3.5 text-left text-xs leading-relaxed text-nexus-text transition hover:border-nexus-primary/60 hover:bg-nexus-primary/15 sm:text-sm"
            >
              <MessageSquare className="mt-0.5 h-4 w-4 shrink-0 text-nexus-cyber" />
              <span>{prompt}</span>
            </button>
          ))}
        </div>

        <div className="mt-5 flex items-center justify-between gap-3 border-t border-white/[0.08] pt-4">
          <span className="inline-flex items-center gap-1.5 text-[11px] text-nexus-text-muted">
            <Lock className="h-3.5 w-3.5 text-nexus-success" />
            X25519 + AES-256-GCM
          </span>
          <button
            type="button"
            onClick={onOpenChat}
            className="rounded-xl nexus-brand-gradient px-4 py-2 text-xs font-semibold text-white shadow-nexus-primary"
          >
            Ir para o Chat
          </button>
        </div>
      </div>
    </div>
  );
}
