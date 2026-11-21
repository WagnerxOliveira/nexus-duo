'use client';

import React, { useState } from 'react';
import {
  Award,
  Check,
  Copy,
  Eye,
  EyeOff,
  Gamepad2,
  Lock,
  Send,
  ShieldAlert,
  ShieldCheck,
  Terminal,
} from 'lucide-react';
import {
  GG_BADGE_CATALOG,
  type DecryptedChatMessage,
  type GamerProfile,
  type GgBadgeCode,
  type MatchRecord,
} from '@/core/domain/types';
import { AvatarArt } from '@/components/AvatarArt';

interface E2EEChatViewProps {
  currentUser: GamerProfile;
  match: MatchRecord | null;
  messages: readonly DecryptedChatMessage[];
  onSendMessage: (plaintext: string) => Promise<void>;
  onGiveBadge: (badge: GgBadgeCode) => Promise<void>;
  onBlockPeer: () => Promise<void>;
}

export function E2EEChatView({
  currentUser,
  match,
  messages,
  onSendMessage,
  onGiveBadge,
  onBlockPeer,
}: E2EEChatViewProps) {
  const [draft, setDraft] = useState('');
  const [sending, setSending] = useState(false);
  const [revealedIds, setRevealedIds] = useState<Record<string, boolean>>({});
  const [showCryptoInspector, setShowCryptoInspector] = useState(false);
  const [showBadgesDrawer, setShowBadgesDrawer] = useState(false);
  const [toast, setToast] = useState<string | null>(null);

  function flashToast(msg: string) {
    setToast(msg);
    setTimeout(() => setToast(null), 2600);
  }

  async function handleCopyHandle(label: string, value: string) {
    try {
      if (typeof navigator !== 'undefined' && navigator.clipboard) {
        await navigator.clipboard.writeText(value);
      }
    } catch {
      // Clipboard fallback
    }
    flashToast(`${label} copiado: ${value}`);
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    const trimmed = draft.trim();
    if (!trimmed || !match || sending) return;
    setSending(true);
    try {
      await onSendMessage(trimmed);
      setDraft('');
    } finally {
      setSending(false);
    }
  }

  if (!match) {
    return (
      <div className="nexus-surface-card flex h-full min-h-[420px] flex-col items-center justify-center rounded-[24px] p-8 text-center">
        <Lock className="h-10 w-10 text-nexus-primary" />
        <h2 className="mt-4 font-display text-xl font-bold text-nexus-text">
          Selecione um Duo para iniciar o Chat E2EE
        </h2>
        <p className="mt-2 max-w-[44ch] text-sm text-nexus-text-secondary">
          Cada conversa deriva uma chave de sessão exclusiva via X25519 + HKDF-SHA256
          e cifra mensagens com AES-256-GCM no seu navegador.
        </p>
      </div>
    );
  }

  const latestMessage = messages[messages.length - 1];

  return (
    <section
      data-testid="e2ee-chat-view"
      className="nexus-surface-card flex h-full min-h-[540px] flex-col overflow-hidden rounded-[24px]"
    >
      {/* Chat Header */}
      <header className="flex flex-wrap items-center justify-between gap-3 border-b border-white/[0.08] bg-nexus-elevated/60 px-4 py-3.5 sm:px-5">
        <div className="flex min-w-0 items-center gap-3">
          <AvatarArt
            glyph={match.peer.avatarGlyph}
            displayName={match.peer.displayName}
            gradient={match.peer.avatarGradient}
            size="sm"
            isOnline={match.peer.isOnlineNow}
          />
          <div className="min-w-0">
            <div className="flex items-center gap-1.5">
              <h2 className="truncate font-display text-base font-bold text-nexus-text">
                {match.peer.displayName}
              </h2>
              {match.peer.isLivenessVerified && (
                <ShieldCheck
                  className="h-4 w-4 shrink-0 text-nexus-cyber"
                  aria-label="Perfil verificado"
                />
              )}
              <span className="nexus-tabular rounded-full bg-nexus-success/15 px-2 py-0.5 text-[11px] font-bold text-nexus-success">
                {match.compatibilityScore}%
              </span>
            </div>
            <p className="flex items-center gap-1.5 truncate text-xs text-nexus-text-secondary">
              <Lock className="h-3 w-3 shrink-0 text-nexus-success" />
              <span>Criptografado de ponta a ponta (X25519 + AES-256-GCM)</span>
            </p>
          </div>
        </div>

        {/* Quick Gamer Actions */}
        <div className="flex flex-wrap items-center gap-2">
          <button
            type="button"
            onClick={() => handleCopyHandle('Discord', match.peer.discordHandle)}
            className="inline-flex items-center gap-1.5 rounded-xl border border-white/10 bg-nexus-surface px-2.5 py-1.5 text-xs font-semibold text-nexus-text transition hover:border-nexus-primary/60"
            title="Copiar Discord"
          >
            <Copy className="h-3.5 w-3.5 text-nexus-primary" />
            <span>Discord</span>
          </button>

          <button
            type="button"
            onClick={() => handleCopyHandle('Gamertag', match.peer.riotOrSteamTag)}
            className="inline-flex items-center gap-1.5 rounded-xl border border-white/10 bg-nexus-surface px-2.5 py-1.5 text-xs font-semibold text-nexus-text transition hover:border-nexus-cyber/60"
            title="Copiar Riot ID / Gamertag"
          >
            <Gamepad2 className="h-3.5 w-3.5 text-nexus-cyber" />
            <span className="hidden sm:inline">{match.peer.riotOrSteamTag}</span>
            <span className="sm:hidden">ID</span>
          </button>

          <button
            type="button"
            onClick={() => setShowBadgesDrawer((v) => !v)}
            className="inline-flex items-center gap-1.5 rounded-xl border border-nexus-warning/35 bg-nexus-warning/10 px-2.5 py-1.5 text-xs font-semibold text-nexus-warning transition hover:bg-nexus-warning/20"
            title="Enviar GG Badge pós-partida"
          >
            <Award className="h-3.5 w-3.5" />
            <span>GG</span>
          </button>

          <button
            type="button"
            onClick={() => setShowCryptoInspector((v) => !v)}
            className="inline-flex items-center gap-1 rounded-xl border border-white/10 bg-nexus-surface p-1.5 text-nexus-text-secondary hover:text-nexus-cyber"
            title="Inspecionar payload cifrado E2EE"
            aria-label="Inspecionar payload cifrado E2EE"
          >
            <Terminal className="h-4 w-4" />
          </button>

          <button
            type="button"
            onClick={async () => {
              await onBlockPeer();
              flashToast(`${match.peer.displayName} bloqueado com segurança.`);
            }}
            className="inline-flex items-center gap-1 rounded-xl border border-nexus-danger/30 bg-nexus-danger/10 p-1.5 text-nexus-danger hover:bg-nexus-danger/20"
            title="Bloquear e desfazer match"
            aria-label="Bloquear usuário"
          >
            <ShieldAlert className="h-4 w-4" />
          </button>
        </div>
      </header>

      {/* Toast Feedback */}
      {toast && (
        <div className="flex items-center gap-2 border-b border-nexus-success/25 bg-nexus-success/10 px-4 py-2 text-xs font-medium text-nexus-success">
          <Check className="h-3.5 w-3.5 shrink-0" />
          <span>{toast}</span>
        </div>
      )}

      {/* Optional GG Badges Award Drawer */}
      {showBadgesDrawer && (
        <div className="border-b border-white/[0.08] bg-nexus-void/70 px-4 py-3">
          <p className="text-xs font-semibold text-nexus-text">
            Reconheça {match.peer.displayName} após a partida (GG Badges):
          </p>
          <div className="mt-2 flex flex-wrap gap-2">
            {(Object.keys(GG_BADGE_CATALOG) as GgBadgeCode[]).map((code) => {
              const meta = GG_BADGE_CATALOG[code];
              return (
                <button
                  key={code}
                  type="button"
                  onClick={async () => {
                    await onGiveBadge(code);
                    setShowBadgesDrawer(false);
                    flashToast(`GG Badge "${meta.label}" enviada para ${match.peer.displayName}!`);
                  }}
                  className="rounded-xl border border-white/10 bg-nexus-elevated px-3 py-1.5 text-xs font-semibold text-nexus-text transition hover:border-nexus-warning/60 hover:text-nexus-warning"
                >
                  + {meta.label}
                </button>
              );
            })}
          </div>
        </div>
      )}

      {/* Optional E2EE Technical Inspector */}
      {showCryptoInspector && latestMessage && (
        <div className="border-b border-nexus-cyber/25 bg-nexus-void/85 px-4 py-3 font-mono text-[11px] text-nexus-text-secondary">
          <p className="font-semibold text-nexus-cyber">
            Inspeção Criptográfica (Última Mensagem · AES-256-GCM)
          </p>
          <p className="mt-1 truncate">
            nonce_b64: <span className="text-nexus-text">{latestMessage.nonceB64}</span>
          </p>
          <p className="truncate">
            ciphertext_b64:{' '}
            <span className="text-nexus-text">{latestMessage.ciphertextB64}</span>
          </p>
          <p className="truncate">
            aad: <span className="text-nexus-success">{match.id}:{latestMessage.senderId}</span>
          </p>
        </div>
      )}

      {/* Messages Feed */}
      <div className="flex-1 space-y-3 overflow-y-auto p-4 sm:p-5">
        <div className="mx-auto max-w-md rounded-2xl border border-nexus-success/20 bg-nexus-success/[0.06] px-4 py-2.5 text-center text-xs text-nexus-text-secondary">
          <Lock className="mx-auto mb-1 h-4 w-4 text-nexus-success" />
          Mensagens cifradas localmente no seu dispositivo. Nem o banco de dados consegue
          ler este histórico.
        </div>

        {messages.map((msg) => {
          const isMine = msg.senderId === currentUser.id;
          const isMedia = msg.msgType === 'image_blur';
          const isRevealed = Boolean(revealedIds[msg.id]);

          return (
            <div
              key={msg.id}
              data-testid="chat-message-item"
              className={`flex ${isMine ? 'justify-end' : 'justify-start'}`}
            >
              <div
                className={`max-w-[85%] rounded-2xl px-4 py-3 sm:max-w-[75%] ${
                  isMine
                    ? 'nexus-brand-gradient text-white shadow-nexus-primary'
                    : 'border border-white/[0.08] bg-nexus-elevated text-nexus-text'
                }`}
              >
                {isMedia ? (
                  <div className="space-y-2.5">
                    <div className="relative overflow-hidden rounded-xl border border-white/15 bg-nexus-void p-4">
                      <div
                        className={`flex h-28 flex-col items-center justify-center rounded-lg bg-gradient-to-br from-nexus-primary/40 via-nexus-cyber/30 to-nexus-secondary/35 p-3 text-center transition ${
                          isRevealed ? 'blur-0' : 'blur-md select-none'
                        }`}
                      >
                        <Gamepad2 className="h-6 w-6 text-white" />
                        <p className="mt-1.5 text-xs font-semibold text-white">
                          {msg.plaintext}
                        </p>
                      </div>
                      {!isRevealed && (
                        <div className="absolute inset-0 flex flex-col items-center justify-center bg-nexus-void/55 p-3 text-center">
                          <span className="text-xs font-semibold text-white">
                            Mídia protegida por Blur
                          </span>
                        </div>
                      )}
                    </div>
                    <button
                      type="button"
                      data-testid="toggle-media-blur"
                      onClick={() =>
                        setRevealedIds((prev) => ({
                          ...prev,
                          [msg.id]: !prev[msg.id],
                        }))
                      }
                      className="inline-flex items-center gap-1.5 rounded-lg border border-white/15 bg-nexus-void/60 px-3 py-1 text-xs font-semibold text-nexus-cyber hover:bg-nexus-void"
                    >
                      {isRevealed ? (
                        <>
                          <EyeOff className="h-3.5 w-3.5" />
                          Ocultar mídia
                        </>
                      ) : (
                        <>
                          <Eye className="h-3.5 w-3.5" />
                          Revelar mídia
                        </>
                      )}
                    </button>
                  </div>
                ) : (
                  <p className="whitespace-pre-wrap break-words text-sm leading-relaxed">
                    {msg.plaintext}
                  </p>
                )}

                <div
                  className={`mt-1.5 flex items-center justify-end gap-1.5 text-[10px] ${
                    isMine ? 'text-white/80' : 'text-nexus-text-muted'
                  }`}
                >
                  <Lock className="h-2.5 w-2.5" />
                  <span className="nexus-tabular">
                    {new Date(msg.createdAt).toLocaleTimeString('pt-BR', {
                      hour: '2-digit',
                      minute: '2-digit',
                    })}
                  </span>
                </div>
              </div>
            </div>
          );
        })}
      </div>

      {/* Message Input Bar */}
      <form
        onSubmit={handleSubmit}
        className="flex items-center gap-2.5 border-t border-white/[0.08] bg-nexus-surface p-3.5 sm:p-4"
      >
        <input
          type="text"
          data-testid="chat-message-input"
          value={draft}
          onChange={(e) => setDraft(e.target.value)}
          placeholder={`Mensagem E2EE para ${match.peer.displayName}...`}
          className="min-w-0 flex-1 rounded-xl border border-white/10 bg-nexus-void px-4 py-2.5 text-sm text-nexus-text placeholder:text-nexus-text-muted focus:border-nexus-primary focus:outline-none"
        />
        <button
          type="submit"
          data-testid="chat-send-button"
          disabled={sending || draft.trim().length === 0}
          className="inline-flex shrink-0 items-center gap-2 rounded-xl nexus-brand-gradient px-4 py-2.5 text-sm font-semibold text-white shadow-nexus-primary transition hover:opacity-95 disabled:opacity-50"
        >
          <Send className="h-4 w-4" />
          <span className="hidden sm:inline">Enviar</span>
        </button>
      </form>
    </section>
  );
}
