'use client';

import React, { useState } from 'react';
import {
  Clock,
  Gamepad2,
  Headphones,
  Plus,
  Radio,
  ShieldCheck,
} from 'lucide-react';
import type {
  CreateLobbyInput,
  DuoLobby,
  LobbyMode,
  VoicePreference,
} from '@/core/domain/types';
import { AvatarArt } from '@/components/AvatarArt';

interface DuoLobbyViewProps {
  lobbies: readonly DuoLobby[];
  onCreateLobby: (input: CreateLobbyInput) => Promise<void>;
  onPingHost: (lobby: DuoLobby) => void;
}

const MODE_LABELS: Record<LobbyMode, string> = {
  casual: 'Casual',
  ranked: 'Ranked',
  coop: 'Co-op',
  chill: 'Chill',
};

const VOICE_LABELS: Record<VoicePreference, string> = {
  discord: 'Call Discord',
  in_game: 'Voz no Jogo',
  text_only: 'Só Texto',
};

function formatRemainingTime(expiresAtIso: string): string {
  const diffMs = Math.max(0, new Date(expiresAtIso).getTime() - Date.now());
  const totalMinutes = Math.ceil(diffMs / 60_000);
  const hours = Math.floor(totalMinutes / 60);
  const minutes = totalMinutes % 60;
  if (hours <= 0) return `${minutes}m restantes`;
  return `${hours}h ${String(minutes).padStart(2, '0')}m restantes`;
}

export function DuoLobbyView({
  lobbies,
  onCreateLobby,
  onPingHost,
}: DuoLobbyViewProps) {
  const [gameTitle, setGameTitle] = useState('Valorant');
  const [mode, setMode] = useState<LobbyMode>('casual');
  const [voicePref, setVoicePref] = useState<VoicePreference>('discord');
  const [notes, setNotes] = useState('');
  const [creating, setCreating] = useState(false);

  async function handleCreate(e: React.FormEvent) {
    e.preventDefault();
    if (creating) return;
    setCreating(true);
    try {
      await onCreateLobby({
        gameTitle,
        mode,
        voicePref,
        notes: notes.trim() || 'Livre agora pelos próximos 90min, zero tilt!',
      });
      setNotes('');
    } finally {
      setCreating(false);
    }
  }

  return (
    <div data-testid="duo-lobby-view" className="mx-auto flex w-full max-w-[780px] flex-col gap-5">
      <div>
        <span className="inline-flex items-center gap-1.5 text-[11px] font-semibold uppercase tracking-widest text-nexus-cyber">
          <Radio className="h-3.5 w-3.5" />
          Efêmero · Auto-expira em 2 horas
        </span>
        <h1 className="mt-1 font-display text-2xl font-bold tracking-tight text-nexus-text">
          Lobby “Duo Agora”
        </h1>
        <p className="mt-1 max-w-[60ch] text-sm text-nexus-text-secondary">
          Jogadores compatíveis disponíveis neste momento. Abra sua lobby para chamar
          um Duo sem depender de conversa longa.
        </p>
      </div>

      {/* Create Lobby Card */}
      <form
        onSubmit={handleCreate}
        className="nexus-surface-card space-y-4 rounded-[24px] p-5"
      >
        <div className="flex items-center justify-between gap-2">
          <h2 className="font-display text-base font-semibold text-nexus-text">
            Abrir Minha Lobby (2h)
          </h2>
          <span className="nexus-tabular rounded-full border border-nexus-cyber/35 bg-nexus-cyber/10 px-2.5 py-0.5 text-[11px] font-semibold text-nexus-cyber">
            TTL: 120 min
          </span>
        </div>

        <div className="grid gap-3 sm:grid-cols-3">
          <div>
            <label
              htmlFor="lobby-game"
              className="mb-1 block text-xs font-medium text-nexus-text-secondary"
            >
              Jogo
            </label>
            <input
              id="lobby-game"
              data-testid="lobby-game-input"
              type="text"
              value={gameTitle}
              onChange={(e) => setGameTitle(e.target.value)}
              className="w-full rounded-xl border border-white/10 bg-nexus-void px-3 py-2 text-sm text-white focus:border-nexus-primary focus:outline-none"
              required
            />
          </div>

          <div>
            <label
              htmlFor="lobby-mode"
              className="mb-1 block text-xs font-medium text-nexus-text-secondary"
            >
              Modo
            </label>
            <select
              id="lobby-mode"
              value={mode}
              onChange={(e) => setMode(e.target.value as LobbyMode)}
              className="w-full rounded-xl border border-white/10 bg-nexus-void px-3 py-2 text-sm text-white focus:border-nexus-primary focus:outline-none"
            >
              <option value="casual">Casual</option>
              <option value="ranked">Ranked</option>
              <option value="coop">Co-op</option>
              <option value="chill">Chill</option>
            </select>
          </div>

          <div>
            <label
              htmlFor="lobby-voice"
              className="mb-1 block text-xs font-medium text-nexus-text-secondary"
            >
              Comunicação
            </label>
            <select
              id="lobby-voice"
              value={voicePref}
              onChange={(e) => setVoicePref(e.target.value as VoicePreference)}
              className="w-full rounded-xl border border-white/10 bg-nexus-void px-3 py-2 text-sm text-white focus:border-nexus-primary focus:outline-none"
            >
              <option value="discord">Call Discord</option>
              <option value="in_game">Voz no Jogo</option>
              <option value="text_only">Só Texto</option>
            </select>
          </div>
        </div>

        <div className="flex flex-col gap-3 sm:flex-row">
          <input
            type="text"
            data-testid="lobby-notes-input"
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            placeholder="Nota rápida (ex.: 2 partidas de Swiftplay sem rage)"
            className="min-w-0 flex-1 rounded-xl border border-white/10 bg-nexus-void px-3.5 py-2.5 text-sm text-white placeholder:text-nexus-text-muted focus:border-nexus-primary focus:outline-none"
          />
          <button
            type="submit"
            data-testid="lobby-create-button"
            disabled={creating}
            className="inline-flex shrink-0 items-center justify-center gap-2 rounded-xl nexus-brand-gradient px-5 py-2.5 text-sm font-semibold text-white shadow-nexus-primary transition hover:opacity-95 disabled:opacity-50"
          >
            <Plus className="h-4 w-4" />
            Criar Lobby Agora
          </button>
        </div>
      </form>

      {/* Active Lobbies Feed */}
      <div className="grid gap-4 sm:grid-cols-2">
        {lobbies.map((lobby) => (
          <article
            key={lobby.id}
            data-testid="lobby-card"
            className="nexus-surface-card flex flex-col justify-between gap-4 rounded-2xl p-5"
          >
            <div className="space-y-3">
              <div className="flex items-start justify-between gap-3">
                <div className="flex min-w-0 items-center gap-3">
                  <AvatarArt
                    glyph={lobby.hostDisplayName.slice(0, 2).toUpperCase()}
                    displayName={lobby.hostDisplayName}
                    gradient={lobby.hostGradient}
                    size="sm"
                    isOnline
                  />
                  <div className="min-w-0">
                    <div className="flex items-center gap-1.5">
                      <h3 className="truncate font-display text-sm font-bold text-nexus-text">
                        {lobby.hostDisplayName}
                      </h3>
                      {lobby.hostVerified && (
                        <ShieldCheck className="h-3.5 w-3.5 shrink-0 text-nexus-cyber" />
                      )}
                    </div>
                    <p className="truncate text-xs text-nexus-text-muted">
                      @{lobby.hostUsername}
                    </p>
                  </div>
                </div>
                <span className="nexus-tabular shrink-0 rounded-full bg-nexus-success/15 px-2.5 py-0.5 text-xs font-bold text-nexus-success">
                  {lobby.compatibilityPercent}%
                </span>
              </div>

              <div className="flex flex-wrap gap-2">
                <span className="inline-flex items-center gap-1.5 rounded-full border border-nexus-primary/35 bg-nexus-primary/15 px-2.5 py-1 text-xs font-semibold text-white">
                  <Gamepad2 className="h-3 w-3 text-nexus-primary" />
                  {lobby.gameTitle}
                </span>
                <span className="rounded-full border border-white/10 bg-nexus-elevated px-2.5 py-1 text-xs font-medium text-nexus-text-secondary">
                  {MODE_LABELS[lobby.mode]}
                </span>
                <span className="inline-flex items-center gap-1 rounded-full border border-white/10 bg-nexus-elevated px-2.5 py-1 text-xs font-medium text-nexus-text-secondary">
                  <Headphones className="h-3 w-3 text-nexus-cyber" />
                  {VOICE_LABELS[lobby.voicePref]}
                </span>
              </div>

              <p className="text-sm leading-relaxed text-nexus-text-secondary">
                “{lobby.notes}”
              </p>
            </div>

            <div className="flex items-center justify-between gap-2 border-t border-white/[0.08] pt-3">
              <span className="nexus-tabular inline-flex items-center gap-1.5 text-xs font-semibold text-nexus-cyber">
                <Clock className="h-3.5 w-3.5" />
                {formatRemainingTime(lobby.expiresAt)}
              </span>
              <button
                type="button"
                onClick={() => onPingHost(lobby)}
                className="rounded-xl border border-nexus-cyber/40 bg-nexus-cyber/10 px-3 py-1.5 text-xs font-semibold text-nexus-cyber transition hover:bg-nexus-cyber/20"
              >
                Chamar Duo
              </button>
            </div>
          </article>
        ))}
      </div>
    </div>
  );
}
