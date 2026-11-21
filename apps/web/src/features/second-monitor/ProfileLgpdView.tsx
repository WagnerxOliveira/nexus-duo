'use client';

import React, { useState } from 'react';
import Link from 'next/link';
import {
  Check,
  Clock,
  Download,
  ExternalLink,
  KeyRound,
  ShieldCheck,
  Trash2,
} from 'lucide-react';
import type { GamerProfile, LgpdExportPayload } from '@/core/domain/types';
import { DAYS_PT_BR, WeeklyScheduleMask } from '@/core/algo/scheduleDp';

interface ProfileLgpdViewProps {
  currentUser: GamerProfile;
  repoMode: 'supabase' | 'demo';
  onlyVerifiedFilter: boolean;
  onToggleOnlyVerified: (next: boolean) => void;
  onUpdateProfile: (patch: Partial<GamerProfile>) => Promise<void>;
  onExportLgpd: () => Promise<LgpdExportPayload>;
  onDeleteAccount: () => Promise<void>;
}

const QUICK_WINDOWS = [
  { label: 'Manhã (09h–12h)', start: 9, end: 12 },
  { label: 'Tarde (15h–18h)', start: 15, end: 18 },
  { label: 'Noite (20h–00h)', start: 20, end: 24 },
  { label: 'Madrugada (00h–02h)', start: 0, end: 2 },
] as const;

export function ProfileLgpdView({
  currentUser,
  repoMode,
  onlyVerifiedFilter,
  onToggleOnlyVerified,
  onUpdateProfile,
  onExportLgpd,
  onDeleteAccount,
}: ProfileLgpdViewProps) {
  const [displayName, setDisplayName] = useState(currentUser.displayName);
  const [discordHandle, setDiscordHandle] = useState(currentUser.discordHandle);
  const [savedBanner, setSavedBanner] = useState(false);
  const [lgpdPreview, setLgpdPreview] = useState<string | null>(null);
  const [confirmDeleteOpen, setConfirmDeleteOpen] = useState(false);
  const [deletedBanner, setDeletedBanner] = useState(false);

  const mask = WeeklyScheduleMask.fromHours(currentUser.scheduleHours);

  async function toggleDayWindow(dayIdx: number, start: number, end: number) {
    let nextMask = mask;
    let allOn = true;
    for (let h = start; h < end; h += 1) {
      if (!nextMask.hasHour(dayIdx * 24 + h)) {
        allOn = false;
        break;
      }
    }
    for (let h = start; h < end; h += 1) {
      const hourIdx = dayIdx * 24 + h;
      const isSet = nextMask.hasHour(hourIdx);
      if (allOn && isSet) {
        nextMask = nextMask.toggleHour(hourIdx);
      } else if (!allOn && !isSet) {
        nextMask = nextMask.toggleHour(hourIdx);
      }
    }
    await onUpdateProfile({ scheduleHours: nextMask.toHours() });
  }

  async function handleSaveQuickOnboarding(e: React.FormEvent) {
    e.preventDefault();
    await onUpdateProfile({
      displayName: displayName.trim() || currentUser.displayName,
      discordHandle: discordHandle.trim() || currentUser.discordHandle,
    });
    setSavedBanner(true);
    setTimeout(() => setSavedBanner(false), 2400);
  }

  async function handleExportJson() {
    const payload = await onExportLgpd();
    const json = JSON.stringify(payload, null, 2);
    setLgpdPreview(json);

    if (typeof window !== 'undefined') {
      try {
        const blob = new Blob([json], { type: 'application/json' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `nexus-duo-lgpd-${currentUser.username}.json`;
        a.click();
        URL.revokeObjectURL(url);
      } catch {
        // Preview still displayed cleanly
      }
    }
  }

  async function handleConfirmDelete() {
    await onDeleteAccount();
    setConfirmDeleteOpen(false);
    setDeletedBanner(true);
  }

  return (
    <div
      data-testid="profile-lgpd-view"
      className="mx-auto flex w-full max-w-[780px] flex-col gap-5"
    >
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <span className="text-[11px] font-semibold uppercase tracking-widest text-nexus-cyber">
            Onboarding Rápido · Privacidade & LGPD
          </span>
          <h1 className="mt-1 font-display text-2xl font-bold text-nexus-text">
            Meu Perfil & Central LGPD
          </h1>
        </div>
        <Link
          href={`/u/${currentUser.username}`}
          className="inline-flex items-center gap-1.5 rounded-xl border border-nexus-primary/40 bg-nexus-primary/15 px-3.5 py-2 text-xs font-semibold text-white hover:bg-nexus-primary/25"
        >
          Ver Meu Gamer Card Público
          <ExternalLink className="h-3.5 w-3.5" />
        </Link>
      </div>

      {/* Quick Profile / Onboarding Edit */}
      <form
        onSubmit={handleSaveQuickOnboarding}
        className="nexus-surface-card space-y-4 rounded-[24px] p-5"
      >
        <div className="flex items-center justify-between gap-2">
          <h2 className="font-display text-base font-semibold text-nexus-text">
            Identidade Gamer ({repoMode === 'demo' ? 'Modo Demo Local' : 'Supabase Live'})
          </h2>
          <span className="inline-flex items-center gap-1 rounded-full border border-nexus-success/35 bg-nexus-success/10 px-2.5 py-0.5 text-xs font-semibold text-nexus-success">
            <ShieldCheck className="h-3.5 w-3.5" />
            18+ & Liveness Verificado
          </span>
        </div>

        <div className="grid gap-3 sm:grid-cols-2">
          <div>
            <label
              htmlFor="profile-display-name"
              className="mb-1 block text-xs font-medium text-nexus-text-secondary"
            >
              Nome de Exibição
            </label>
            <input
              id="profile-display-name"
              type="text"
              value={displayName}
              onChange={(e) => setDisplayName(e.target.value)}
              className="w-full rounded-xl border border-white/10 bg-nexus-void px-3.5 py-2 text-sm text-white focus:border-nexus-primary focus:outline-none"
            />
          </div>
          <div>
            <label
              htmlFor="profile-discord"
              className="mb-1 block text-xs font-medium text-nexus-text-secondary"
            >
              Discord Handle
            </label>
            <input
              id="profile-discord"
              type="text"
              value={discordHandle}
              onChange={(e) => setDiscordHandle(e.target.value)}
              className="w-full rounded-xl border border-white/10 bg-nexus-void px-3.5 py-2 text-sm text-white focus:border-nexus-primary focus:outline-none"
            />
          </div>
        </div>

        <div className="flex flex-wrap items-center justify-between gap-3 pt-1">
          <label className="inline-flex cursor-pointer items-center gap-2.5 text-xs text-nexus-text-secondary">
            <input
              type="checkbox"
              checked={onlyVerifiedFilter}
              onChange={(e) => onToggleOnlyVerified(e.target.checked)}
              className="h-4 w-4 rounded border-white/20 bg-nexus-void accent-nexus-cyber"
            />
            Mostrar apenas perfis com selo Selfie Liveness no Deck
          </label>

          <button
            type="submit"
            className="inline-flex items-center gap-2 rounded-xl nexus-brand-gradient px-4 py-2 text-xs font-semibold text-white shadow-nexus-primary"
          >
            {savedBanner ? (
              <>
                <Check className="h-3.5 w-3.5" />
                Salvo!
              </>
            ) : (
              'Salvar Alterações'
            )}
          </button>
        </div>
      </form>

      {/* Interactive WeeklyScheduleMask Editor */}
      <section className="nexus-surface-card space-y-4 rounded-[24px] p-5">
        <div className="flex flex-wrap items-center justify-between gap-2">
          <div>
            <h2 className="inline-flex items-center gap-2 font-display text-base font-semibold text-nexus-text">
              <Clock className="h-4 w-4 text-nexus-cyber" />
              Minha Agenda Semanal (Bitmask 168h)
            </h2>
            <p className="mt-0.5 text-xs text-nexus-text-secondary">
              Toque em qualquer bloco para recalcular instantaneamente o Match Score
              por Programação Dinâmica no Deck.
            </p>
          </div>
          <span className="nexus-tabular rounded-full bg-nexus-cyber/15 px-3 py-1 text-xs font-bold text-nexus-cyber">
            {mask.totalHours()}h/sem livres
          </span>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full min-w-[460px] border-separate border-spacing-1.5 text-center text-xs">
            <thead>
              <tr>
                <th className="text-left text-nexus-text-muted">Janela</th>
                {DAYS_PT_BR.map((d) => (
                  <th key={d} className="font-semibold text-nexus-text-secondary">
                    {d}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {QUICK_WINDOWS.map((win) => (
                <tr key={win.label}>
                  <td className="pr-2 text-left text-xs text-nexus-text-secondary">
                    {win.label}
                  </td>
                  {DAYS_PT_BR.map((day, dayIdx) => {
                    let active = true;
                    for (let h = win.start; h < win.end; h += 1) {
                      if (!mask.hasHour(dayIdx * 24 + h)) {
                        active = false;
                        break;
                      }
                    }
                    return (
                      <td key={day}>
                        <button
                          type="button"
                          onClick={() => toggleDayWindow(dayIdx, win.start, win.end)}
                          aria-label={`${day} ${win.label}`}
                          className={`h-8 w-full rounded-lg border text-[11px] font-semibold transition ${
                            active
                              ? 'border-nexus-cyber/60 bg-nexus-cyber/25 text-nexus-cyber'
                              : 'border-white/[0.08] bg-nexus-void/60 text-nexus-text-muted hover:border-white/20'
                          }`}
                        >
                          {active ? 'ON' : '—'}
                        </button>
                      </td>
                    );
                  })}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      {/* Central LGPD & E2EE Keys */}
      <section className="nexus-surface-card space-y-4 rounded-[24px] p-5">
        <div className="flex items-center gap-2">
          <KeyRound className="h-5 w-5 text-nexus-primary" />
          <h2 className="font-display text-base font-semibold text-nexus-text">
            Central LGPD & Chaves E2EE
          </h2>
        </div>

        <div className="rounded-xl border border-white/[0.08] bg-nexus-void/70 p-3.5">
          <p className="text-[11px] font-semibold uppercase tracking-wider text-nexus-text-muted">
            Chave Pública X25519 (32 bytes · Base64)
          </p>
          <p className="mt-1 break-all font-mono text-xs text-nexus-cyber">
            {currentUser.e2eePublicKeyB64}
          </p>
        </div>

        <div className="flex flex-wrap gap-3">
          <button
            type="button"
            data-testid="lgpd-export-button"
            onClick={handleExportJson}
            className="inline-flex items-center gap-2 rounded-xl border border-nexus-cyber/40 bg-nexus-cyber/10 px-4 py-2.5 text-xs font-semibold text-nexus-cyber transition hover:bg-nexus-cyber/20"
          >
            <Download className="h-4 w-4" />
            Exportar Meus Dados (JSON LGPD)
          </button>

          <button
            type="button"
            data-testid="lgpd-delete-trigger"
            onClick={() => setConfirmDeleteOpen(true)}
            className="inline-flex items-center gap-2 rounded-xl border border-nexus-danger/40 bg-nexus-danger/10 px-4 py-2.5 text-xs font-semibold text-nexus-danger transition hover:bg-nexus-danger/20"
          >
            <Trash2 className="h-4 w-4" />
            Excluir Conta Permanentemente
          </button>
        </div>

        {lgpdPreview && (
          <pre
            data-testid="lgpd-export-preview"
            className="max-h-52 overflow-auto rounded-xl border border-white/10 bg-nexus-void p-3.5 font-mono text-[11px] text-nexus-text-secondary"
          >
            {lgpdPreview}
          </pre>
        )}

        {confirmDeleteOpen && (
          <div className="rounded-2xl border border-nexus-danger/45 bg-nexus-danger/10 p-4">
            <p className="text-sm font-semibold text-white">
              Confirmar exclusão definitiva (LGPD Art. 18)?
            </p>
            <p className="mt-1 text-xs text-nexus-text-secondary">
              Esta ação apaga seu perfil, matches, lobbies e chaves locais do navegador.
            </p>
            <div className="mt-3 flex gap-2">
              <button
                type="button"
                onClick={() => setConfirmDeleteOpen(false)}
                className="rounded-lg border border-white/15 bg-nexus-surface px-3 py-1.5 text-xs font-semibold text-white"
              >
                Cancelar
              </button>
              <button
                type="button"
                data-testid="lgpd-delete-confirm"
                onClick={handleConfirmDelete}
                className="rounded-lg bg-nexus-danger px-3 py-1.5 text-xs font-semibold text-white"
              >
                Sim, Excluir Conta
              </button>
            </div>
          </div>
        )}

        {deletedBanner && (
          <p className="rounded-xl border border-nexus-warning/40 bg-nexus-warning/10 px-3.5 py-2.5 text-xs text-nexus-warning">
            Conta e dados locais purgados com sucesso conforme LGPD. Recarregue a página
            para iniciar uma nova sessão demo.
          </p>
        )}
      </section>
    </div>
  );
}
