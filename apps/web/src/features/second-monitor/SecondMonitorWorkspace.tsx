'use client';

import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import Link from 'next/link';
import {
  Compass,
  Lock,
  MessageSquare,
  Radio,
  ShieldCheck,
  User,
} from 'lucide-react';
import type {
  CreateLobbyInput,
  DecryptedChatMessage,
  DiscoveryCandidate,
  DuoLobby,
  GamerProfile,
  GgBadgeCode,
  MatchRecord,
  SwipeAction,
} from '@/core/domain/types';
import {
  createNexusRepository,
  createScoringStrategy,
  type INexusRepository,
} from '@/core/data/repositories';
import { NexusLogo } from '@/components/NexusLogo';
import { AvatarArt } from '@/components/AvatarArt';
import { DiscoveryDeckView } from '@/features/second-monitor/DiscoveryDeckView';
import { MatchCelebrationModal } from '@/features/second-monitor/MatchCelebrationModal';
import { E2EEChatView } from '@/features/second-monitor/E2EEChatView';
import { DuoLobbyView } from '@/features/second-monitor/DuoLobbyView';
import { ProfileLgpdView } from '@/features/second-monitor/ProfileLgpdView';
import { RightContextPanel } from '@/features/second-monitor/RightContextPanel';

type ActiveTab = 'discover' | 'chat' | 'lobby' | 'profile';

export function SecondMonitorWorkspace() {
  const repoRef = useRef<INexusRepository | null>(null);
  if (!repoRef.current) {
    repoRef.current = createNexusRepository();
  }
  const repo = repoRef.current;

  const [activeTab, setActiveTab] = useState<ActiveTab>('discover');
  const [strategyMode, setStrategyMode] = useState<'hybrid' | 'coop'>('hybrid');
  const [onlyVerifiedFilter, setOnlyVerifiedFilter] = useState(false);

  const [currentUser, setCurrentUser] = useState<GamerProfile | null>(null);
  const [candidates, setCandidates] = useState<DiscoveryCandidate[]>([]);
  const [matches, setMatches] = useState<MatchRecord[]>([]);
  const [selectedMatchId, setSelectedMatchId] = useState<string | null>(null);
  const [messages, setMessages] = useState<DecryptedChatMessage[]>([]);
  const [lobbies, setLobbies] = useState<DuoLobby[]>([]);
  const [celebrationMatch, setCelebrationMatch] = useState<MatchRecord | null>(
    null,
  );
  const [loading, setLoading] = useState(true);

  const loadWorkspace = useCallback(
    async (mode: 'hybrid' | 'coop', onlyVerified: boolean) => {
      const strategy = createScoringStrategy(mode);
      const [me, deck, currentMatches, activeLobbies] = await Promise.all([
        repo.getCurrentUser(),
        repo.getDiscoveryDeck(strategy, { onlyVerified }),
        repo.getMatches(),
        repo.getActiveLobbies(),
      ]);

      setCurrentUser(me);
      setCandidates(deck);
      setMatches(currentMatches);
      setLobbies(activeLobbies);

      setSelectedMatchId((prev) => {
        if (prev && currentMatches.some((m) => m.id === prev)) {
          return prev;
        }
        return currentMatches[0]?.id ?? null;
      });
      setLoading(false);
    },
    [repo],
  );

  useEffect(() => {
    void loadWorkspace(strategyMode, onlyVerifiedFilter);
  }, [loadWorkspace, strategyMode, onlyVerifiedFilter]);

  useEffect(() => {
    if (!selectedMatchId) {
      setMessages([]);
      return;
    }
    let cancelled = false;
    void repo.getMessages(selectedMatchId).then((loaded) => {
      if (!cancelled) {
        setMessages(loaded);
      }
    });
    return () => {
      cancelled = true;
    };
  }, [repo, selectedMatchId]);

  const activeMatch = useMemo(
    () => matches.find((m) => m.id === selectedMatchId) ?? null,
    [matches, selectedMatchId],
  );

  const contextProfile = useMemo(() => {
    if (activeTab === 'chat' && activeMatch) {
      return activeMatch.peer;
    }
    return candidates[0]?.profile ?? activeMatch?.peer ?? null;
  }, [activeTab, activeMatch, candidates]);

  const contextScore = useMemo(() => {
    if (!currentUser || !contextProfile) return null;
    const strategy = createScoringStrategy(strategyMode);
    return strategy.calculate(currentUser, contextProfile);
  }, [currentUser, contextProfile, strategyMode]);

  async function handleSwipe(
    targetId: string,
    action: SwipeAction,
    introNote?: string,
  ) {
    const result = await repo.swipeProfile(targetId, action, introNote);
    await loadWorkspace(strategyMode, onlyVerifiedFilter);
    if (result.matched && result.match) {
      setSelectedMatchId(result.match.id);
      setCelebrationMatch(result.match);
    }
  }

  async function handleResetDemoDeck() {
    repoRef.current = createNexusRepository();
    setCelebrationMatch(null);
    await loadWorkspace(strategyMode, onlyVerifiedFilter);
  }

  async function handleSendMessage(plaintext: string) {
    if (!selectedMatchId) return;
    await repo.sendMessage(selectedMatchId, plaintext, 'text');
    const updatedMessages = await repo.getMessages(selectedMatchId);
    const updatedMatches = await repo.getMatches();
    setMessages(updatedMessages);
    setMatches(updatedMatches);
  }

  async function handleSelectIcebreaker(prompt: string) {
    if (!celebrationMatch) return;
    const targetId = celebrationMatch.id;
    await repo.sendMessage(targetId, prompt, 'icebreaker');
    const updatedMessages = await repo.getMessages(targetId);
    const updatedMatches = await repo.getMatches();
    setSelectedMatchId(targetId);
    setMessages(updatedMessages);
    setMatches(updatedMatches);
    setCelebrationMatch(null);
    setActiveTab('chat');
  }

  async function handleCreateLobby(input: CreateLobbyInput) {
    await repo.createLobby(input);
    const activeLobbies = await repo.getActiveLobbies();
    setLobbies(activeLobbies);
  }

  async function handlePingLobbyHost(lobby: DuoLobby) {
    const existing = matches.find((m) => m.peer.id === lobby.hostId);
    if (existing) {
      setSelectedMatchId(existing.id);
      setActiveTab('chat');
      return;
    }
    const result = await repo.swipeProfile(
      lobby.hostId,
      'super_duo',
      `Vi sua lobby de ${lobby.gameTitle} no Duo Agora! Bora jogar?`,
    );
    await loadWorkspace(strategyMode, onlyVerifiedFilter);
    if (result.match) {
      setSelectedMatchId(result.match.id);
      setActiveTab('chat');
    }
  }

  async function handleGiveBadge(badge: GgBadgeCode) {
    if (!activeMatch) return;
    await repo.giveGgBadge(activeMatch.peer.id, activeMatch.id, badge);
    await loadWorkspace(strategyMode, onlyVerifiedFilter);
  }

  async function handleBlockPeer() {
    if (!activeMatch) return;
    await repo.blockPeer(activeMatch.peer.id);
    await loadWorkspace(strategyMode, onlyVerifiedFilter);
  }

  async function handleUpdateProfile(patch: Partial<GamerProfile>) {
    await repo.updateCurrentUserProfile(patch);
    await loadWorkspace(strategyMode, onlyVerifiedFilter);
  }

  const navItems: readonly {
    id: ActiveTab;
    label: string;
    icon: typeof Compass;
    badge?: number;
  }[] = [
    { id: 'discover', label: 'Deck', icon: Compass, badge: candidates.length },
    { id: 'chat', label: 'Chat', icon: MessageSquare, badge: matches.length },
    { id: 'lobby', label: 'Duo Agora', icon: Radio, badge: lobbies.length },
    { id: 'profile', label: 'Perfil', icon: User },
  ];

  if (loading || !currentUser) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-nexus-void text-nexus-text">
        <div className="flex flex-col items-center gap-3">
          <NexusLogo />
          <p className="text-xs text-nexus-text-secondary">
            Inicializando Cofre E2EE & Motor DP 168h...
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="flex min-h-screen w-full flex-col bg-nexus-void text-nexus-text lg:h-screen lg:flex-row lg:overflow-hidden">
      {/* Desktop Column 1: Navigation Rail (80px) */}
      <aside
        aria-label="Navegação Principal 2º Monitor"
        className="hidden w-[80px] shrink-0 flex-col items-center justify-between border-r border-white/[0.08] bg-nexus-surface py-4 lg:flex"
      >
        <div className="flex flex-col items-center gap-6">
          <Link href="/" title="Voltar para Landing Page">
            <NexusLogo compact />
          </Link>

          <nav className="flex flex-col items-center gap-2">
            {navItems.map((item) => {
              const Icon = item.icon;
              const active = activeTab === item.id;
              return (
                <button
                  key={item.id}
                  type="button"
                  data-testid={`nav-rail-${item.id}`}
                  onClick={() => setActiveTab(item.id)}
                  className={`relative flex h-12 w-12 flex-col items-center justify-center rounded-2xl transition ${
                    active
                      ? 'nexus-brand-gradient text-white shadow-nexus-primary'
                      : 'text-nexus-text-secondary hover:bg-nexus-elevated hover:text-white'
                  }`}
                  title={item.label}
                  aria-label={item.label}
                >
                  <Icon className="h-5 w-5" />
                  {item.badge !== undefined && item.badge > 0 && (
                    <span className="nexus-tabular absolute -right-1 -top-1 flex h-4 min-w-[16px] items-center justify-center rounded-full bg-nexus-cyber px-1 text-[10px] font-bold text-nexus-void">
                      {item.badge}
                    </span>
                  )}
                </button>
              );
            })}
          </nav>
        </div>

        <div className="flex flex-col items-center gap-2">
          <span
            className="rounded-lg border border-nexus-success/35 bg-nexus-success/10 px-2 py-1 text-[10px] font-bold text-nexus-success"
            title={
              repo.mode === 'demo'
                ? 'Modo Demo Local (sem Supabase URL configurada)'
                : 'Conectado ao Supabase Zero-Trust'
            }
          >
            {repo.mode === 'demo' ? 'DEMO' : 'LIVE'}
          </span>
          <AvatarArt
            glyph={currentUser.avatarGlyph}
            displayName={currentUser.displayName}
            gradient={currentUser.avatarGradient}
            size="sm"
            isOnline
          />
        </div>
      </aside>

      {/* Mobile / Tablet Top Header (< 1024px) */}
      <header className="sticky top-0 z-30 flex items-center justify-between gap-3 border-b border-white/[0.08] bg-nexus-void/90 px-4 py-3 backdrop-blur-xl lg:hidden">
        <Link href="/">
          <NexusLogo />
        </Link>
        <div className="flex items-center gap-2">
          <span className="inline-flex items-center gap-1 rounded-full border border-nexus-success/35 bg-nexus-success/10 px-2.5 py-1 text-[11px] font-semibold text-nexus-success">
            <Lock className="h-3 w-3" />
            E2EE · {repo.mode === 'demo' ? 'Demo' : 'Live'}
          </span>
        </div>
      </header>

      {/* Desktop Column 2: Matches & Active Lobbies Sidebar (320px) */}
      <aside
        aria-label="Matches e Lobbies Ativos"
        className="hidden w-[320px] shrink-0 flex-col border-r border-white/[0.08] bg-nexus-surface/65 lg:flex"
      >
        <div className="border-b border-white/[0.08] p-4">
          <div className="flex items-center justify-between">
            <h2 className="font-display text-sm font-bold uppercase tracking-wider text-nexus-text">
              Modo 2º Monitor
            </h2>
            <span className="inline-flex items-center gap-1 text-[11px] font-semibold text-nexus-success">
              <Lock className="h-3 w-3" />
              E2EE Ativo
            </span>
          </div>
          <p className="mt-1 text-xs text-nexus-text-muted">
            Olá, {currentUser.displayName} · {matches.length} Duos · {lobbies.length}{' '}
            Lobbies
          </p>
        </div>

        {/* Matches List */}
        <div className="flex-1 overflow-y-auto p-3">
          <div className="mb-2 flex items-center justify-between px-1">
            <span className="text-[11px] font-semibold uppercase tracking-widest text-nexus-text-muted">
              Seus Matches (Chat E2EE)
            </span>
          </div>

          <div className="space-y-1.5">
            {matches.map((m) => {
              const selected = activeTab === 'chat' && selectedMatchId === m.id;
              return (
                <button
                  key={m.id}
                  type="button"
                  data-testid={`match-list-item-${m.peer.username}`}
                  onClick={() => {
                    setSelectedMatchId(m.id);
                    setActiveTab('chat');
                  }}
                  className={`flex w-full items-center gap-3 rounded-2xl border p-2.5 text-left transition ${
                    selected
                      ? 'border-nexus-primary/50 bg-nexus-primary/15'
                      : 'border-transparent hover:border-white/[0.08] hover:bg-nexus-elevated/70'
                  }`}
                >
                  <AvatarArt
                    glyph={m.peer.avatarGlyph}
                    displayName={m.peer.displayName}
                    gradient={m.peer.avatarGradient}
                    size="sm"
                    isOnline={m.peer.isOnlineNow}
                  />
                  <div className="min-w-0 flex-1">
                    <div className="flex items-center justify-between gap-2">
                      <span className="flex min-w-0 items-center gap-1 truncate text-sm font-semibold text-nexus-text">
                        <span className="truncate">{m.peer.displayName}</span>
                        {m.peer.isLivenessVerified && (
                          <ShieldCheck className="h-3.5 w-3.5 shrink-0 text-nexus-cyber" />
                        )}
                      </span>
                      <span className="nexus-tabular shrink-0 text-xs font-bold text-nexus-success">
                        {m.compatibilityScore}%
                      </span>
                    </div>
                    <p className="truncate text-xs text-nexus-text-secondary">
                      {m.lastMessagePreview ?? m.sharedGameTitles.join(' · ')}
                    </p>
                  </div>
                </button>
              );
            })}
          </div>

          {/* Quick Duo Agora Lobbies Strip */}
          <div className="mt-6">
            <div className="mb-2 flex items-center justify-between px-1">
              <span className="inline-flex items-center gap-1.5 text-[11px] font-semibold uppercase tracking-widest text-nexus-cyber">
                <Radio className="h-3 w-3" />
                Duo Agora ({lobbies.length})
              </span>
              <button
                type="button"
                onClick={() => setActiveTab('lobby')}
                className="text-[11px] font-semibold text-nexus-primary hover:underline"
              >
                Ver todas
              </button>
            </div>

            <div className="space-y-2">
              {lobbies.slice(0, 3).map((lobby) => (
                <button
                  key={lobby.id}
                  type="button"
                  onClick={() => setActiveTab('lobby')}
                  className="w-full rounded-xl border border-white/[0.08] bg-nexus-elevated/60 p-3 text-left transition hover:border-nexus-cyber/45"
                >
                  <div className="flex items-center justify-between gap-2">
                    <span className="truncate text-xs font-bold text-nexus-text">
                      {lobby.gameTitle} · {lobby.hostDisplayName}
                    </span>
                    <span className="nexus-tabular shrink-0 text-[11px] font-semibold text-nexus-cyber">
                      {lobby.mode}
                    </span>
                  </div>
                  <p className="mt-1 truncate text-[11px] text-nexus-text-secondary">
                    {lobby.notes}
                  </p>
                </button>
              ))}
            </div>
          </div>
        </div>
      </aside>

      {/* Main Stage (Column 3 on Desktop, Full Width on Mobile) */}
      <main className="nexus-aura-bg min-w-0 flex-1 overflow-y-auto px-4 pb-24 pt-5 sm:px-6 lg:pb-6 lg:pt-6">
        {/* Mobile Quick Match Selector when on Chat tab */}
        {activeTab === 'chat' && matches.length > 0 && (
          <div className="mb-3 flex gap-2 overflow-x-auto pb-1 lg:hidden">
            {matches.map((m) => (
              <button
                key={m.id}
                type="button"
                onClick={() => setSelectedMatchId(m.id)}
                className={`inline-flex shrink-0 items-center gap-2 rounded-full border px-3 py-1.5 text-xs font-semibold ${
                  selectedMatchId === m.id
                    ? 'border-nexus-primary bg-nexus-primary/20 text-white'
                    : 'border-white/10 bg-nexus-surface text-nexus-text-secondary'
                }`}
              >
                <span>{m.peer.displayName}</span>
                <span className="nexus-tabular text-nexus-success">
                  {m.compatibilityScore}%
                </span>
              </button>
            ))}
          </div>
        )}

        {activeTab === 'discover' && (
          <DiscoveryDeckView
            currentUser={currentUser}
            candidates={candidates}
            onSwipe={handleSwipe}
            onResetDeck={handleResetDemoDeck}
            strategyMode={strategyMode}
            onChangeStrategy={setStrategyMode}
          />
        )}

        {activeTab === 'chat' && (
          <E2EEChatView
            currentUser={currentUser}
            match={activeMatch}
            messages={messages}
            onSendMessage={handleSendMessage}
            onGiveBadge={handleGiveBadge}
            onBlockPeer={handleBlockPeer}
          />
        )}

        {activeTab === 'lobby' && (
          <DuoLobbyView
            lobbies={lobbies}
            onCreateLobby={handleCreateLobby}
            onPingHost={handlePingLobbyHost}
          />
        )}

        {activeTab === 'profile' && (
          <ProfileLgpdView
            currentUser={currentUser}
            repoMode={repo.mode}
            onlyVerifiedFilter={onlyVerifiedFilter}
            onToggleOnlyVerified={setOnlyVerifiedFilter}
            onUpdateProfile={handleUpdateProfile}
            onExportLgpd={() => repo.exportLgpdData()}
            onDeleteAccount={async () => {
              await repo.deleteAccount();
              await loadWorkspace(strategyMode, onlyVerifiedFilter);
            }}
          />
        )}
      </main>

      {/* Ultrawide Column 4 (>= 1440px): Gamer DNA & E2EE Details Panel */}
      <RightContextPanel
        currentUser={currentUser}
        targetProfile={contextProfile}
        scoreBreakdown={contextScore}
      />

      {/* Mobile Bottom Navigation (< 1024px) */}
      <nav
        aria-label="Navegação Mobile"
        className="nexus-glass fixed inset-x-3 bottom-3 z-40 grid grid-cols-4 gap-1 rounded-2xl p-1.5 lg:hidden"
      >
        {navItems.map((item) => {
          const Icon = item.icon;
          const active = activeTab === item.id;
          return (
            <button
              key={item.id}
              type="button"
              data-testid={`nav-mobile-${item.id}`}
              onClick={() => setActiveTab(item.id)}
              className={`flex flex-col items-center justify-center gap-0.5 rounded-xl py-2 text-[11px] font-semibold transition ${
                active
                  ? 'nexus-brand-gradient text-white shadow-nexus-primary'
                  : 'text-nexus-text-secondary hover:text-white'
              }`}
            >
              <Icon className="h-4 w-4" />
              <span className="truncate">{item.label}</span>
            </button>
          );
        })}
      </nav>

      {/* "IT'S A DUO!" Match Celebration Modal */}
      {celebrationMatch && (
        <MatchCelebrationModal
          currentUser={currentUser}
          match={celebrationMatch}
          onSelectIcebreaker={handleSelectIcebreaker}
          onOpenChat={() => {
            setCelebrationMatch(null);
            setActiveTab('chat');
          }}
          onClose={() => setCelebrationMatch(null)}
        />
      )}
    </div>
  );
}
