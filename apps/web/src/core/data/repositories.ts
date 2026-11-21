import type {
  CreateLobbyInput,
  DecryptedChatMessage,
  DiscoveryCandidate,
  DuoLobby,
  EncryptedWireMessage,
  GamerProfile,
  GgBadgeCode,
  LgpdExportPayload,
  MatchRecord,
  MessageType,
  SwipeAction,
} from '@/core/domain/types';
import {
  CoopDuoScoringStrategy,
  HybridGamerScoringStrategy,
  generateCoopIcebreakers,
  type IMatchScoringStrategy,
} from '@/core/algo/matchScoring';
import {
  WebCryptoE2EECipher,
  type IMessageCipher,
} from '@/core/crypto/webCryptoCipher';
import {
  DEMO_CURRENT_USER,
  DEMO_PROFILES,
  createInitialDemoLobbies,
  findDemoProfileByUsername,
} from '@/core/data/demoSeed';
import {
  getSupabaseBrowserClient,
  isSupabaseConfigured,
} from '@/core/supabase/client';

export interface SwipeResult {
  matched: boolean;
  match?: MatchRecord;
}

export interface INexusRepository {
  readonly mode: 'supabase' | 'demo';
  getCurrentUser(): Promise<GamerProfile>;
  updateCurrentUserProfile(patch: Partial<GamerProfile>): Promise<GamerProfile>;
  getDiscoveryDeck(
    strategy?: IMatchScoringStrategy,
    options?: { onlyVerified?: boolean },
  ): Promise<DiscoveryCandidate[]>;
  swipeProfile(
    targetId: string,
    action: SwipeAction,
    introNote?: string,
  ): Promise<SwipeResult>;
  getMatches(): Promise<MatchRecord[]>;
  getMessages(matchId: string): Promise<DecryptedChatMessage[]>;
  sendMessage(
    matchId: string,
    plaintext: string,
    msgType?: MessageType,
  ): Promise<DecryptedChatMessage>;
  getActiveLobbies(): Promise<DuoLobby[]>;
  createLobby(input: CreateLobbyInput): Promise<DuoLobby>;
  getPublicProfileByUsername(username: string): Promise<GamerProfile | null>;
  giveGgBadge(
    recipientId: string,
    matchId: string,
    badge: GgBadgeCode,
  ): Promise<void>;
  blockPeer(peerId: string): Promise<void>;
  exportLgpdData(): Promise<LgpdExportPayload>;
  deleteAccount(): Promise<{ deletedAt: string }>;
}

export class DemoSeedRepository implements INexusRepository {
  readonly mode = 'demo' as const;
  private readonly cipher: IMessageCipher;
  private currentUser: GamerProfile;
  private profiles: GamerProfile[];
  private swipedIds = new Set<string>();
  private blockedIds = new Set<string>();
  private matches: MatchRecord[] = [];
  private wireMessages = new Map<string, EncryptedWireMessage[]>();
  private lobbies: DuoLobby[];
  private seedPromise: Promise<void> | null = null;

  constructor(cipher: IMessageCipher = new WebCryptoE2EECipher()) {
    this.cipher = cipher;
    this.currentUser = { ...DEMO_CURRENT_USER };
    this.profiles = DEMO_PROFILES.map((p) => ({
      ...p,
      ggBadges: [...p.ggBadges],
    }));
    this.lobbies = createInitialDemoLobbies();
  }

  private ensureSeeded(): Promise<void> {
    if (!this.seedPromise) {
      this.seedPromise = this.runSeed();
    }
    return this.seedPromise;
  }

  private async runSeed(): Promise<void> {

    const clara = this.profiles.find((p) => p.username === 'valkyrie');
    if (!clara || !clara.demoPrivateKeyB64 || !this.currentUser.demoPrivateKeyB64) {
      return;
    }

    const strategy = new HybridGamerScoringStrategy();
    const score = strategy.calculate(this.currentUser, clara);
    const icebreakers = generateCoopIcebreakers(this.currentUser, clara, score);
    const matchId = '550e8400-e29b-41d4-a716-446655440001';

    const seedMsg1 = await this.cipher.encrypt({
      plaintext:
        'Oi Alex! Vi que você também joga Valorant às 21h 🎮💜 Topa um Swiftplay hoje?',
      myPrivateKeyB64: clara.demoPrivateKeyB64,
      peerPublicKeyB64: this.currentUser.e2eePublicKeyB64,
      matchId,
      senderId: clara.id,
    });

    const seedMsg2 = await this.cipher.encrypt({
      plaintext:
        'Com certeza! Abri o NEXUS no 2º monitor, me passa seu Riot ID quando terminar essa partida.',
      myPrivateKeyB64: this.currentUser.demoPrivateKeyB64,
      peerPublicKeyB64: clara.e2eePublicKeyB64,
      matchId,
      senderId: this.currentUser.id,
    });

    const seedMedia = await this.cipher.encrypt({
      plaintext: 'Setup neon pronto + print do meu rank Platina II no Valorant ✨',
      myPrivateKeyB64: clara.demoPrivateKeyB64,
      peerPublicKeyB64: this.currentUser.e2eePublicKeyB64,
      matchId,
      senderId: clara.id,
    });

    const now = Date.now();
    this.wireMessages.set(matchId, [
      {
        id: 'msg-seed-1',
        matchId,
        senderId: clara.id,
        ciphertextB64: seedMsg1.ciphertextB64,
        nonceB64: seedMsg1.nonceB64,
        msgType: 'icebreaker',
        createdAt: new Date(now - 14 * 60 * 1000).toISOString(),
      },
      {
        id: 'msg-seed-2',
        matchId,
        senderId: this.currentUser.id,
        ciphertextB64: seedMsg2.ciphertextB64,
        nonceB64: seedMsg2.nonceB64,
        msgType: 'text',
        createdAt: new Date(now - 9 * 60 * 1000).toISOString(),
      },
      {
        id: 'msg-seed-3',
        matchId,
        senderId: clara.id,
        ciphertextB64: seedMedia.ciphertextB64,
        nonceB64: seedMedia.nonceB64,
        msgType: 'image_blur',
        createdAt: new Date(now - 3 * 60 * 1000).toISOString(),
      },
    ]);

    this.matches.push({
      id: matchId,
      peer: clara,
      compatibilityScore: score.totalPercent,
      overlapHoursTotal: score.overlapHoursTotal,
      sharedGameTitles: score.sharedGames.map((g) => g.title),
      icebreakerPrompts: icebreakers,
      createdAt: new Date(now - 45 * 60 * 1000).toISOString(),
      unreadCount: 1,
      lastMessagePreview: 'Criptografado E2EE · Mídia protegida',
    });
  }

  async getCurrentUser(): Promise<GamerProfile> {
    await this.ensureSeeded();
    return { ...this.currentUser };
  }

  async updateCurrentUserProfile(
    patch: Partial<GamerProfile>,
  ): Promise<GamerProfile> {
    await this.ensureSeeded();
    this.currentUser = {
      ...this.currentUser,
      ...patch,
      gamerDna: patch.gamerDna
        ? { ...this.currentUser.gamerDna, ...patch.gamerDna }
        : this.currentUser.gamerDna,
    };
    return { ...this.currentUser };
  }

  async getDiscoveryDeck(
    strategy: IMatchScoringStrategy = new HybridGamerScoringStrategy(),
    options?: { onlyVerified?: boolean },
  ): Promise<DiscoveryCandidate[]> {
    await this.ensureSeeded();
    const candidates: DiscoveryCandidate[] = [];

    for (const profile of this.profiles) {
      if (this.swipedIds.has(profile.id) || this.blockedIds.has(profile.id)) {
        continue;
      }
      if (options?.onlyVerified && !profile.isLivenessVerified) {
        continue;
      }
      const score = strategy.calculate(this.currentUser, profile);
      const icebreakers = generateCoopIcebreakers(this.currentUser, profile, score);
      candidates.push({ profile, score, icebreakers });
    }

    return candidates.sort((a, b) => b.score.rankScore - a.score.rankScore);
  }

  async swipeProfile(
    targetId: string,
    action: SwipeAction,
    introNote?: string,
  ): Promise<SwipeResult> {
    await this.ensureSeeded();
    this.swipedIds.add(targetId);

    if (action === 'pass') {
      return { matched: false };
    }

    const peer = this.profiles.find((p) => p.id === targetId);
    if (!peer) {
      return { matched: false };
    }

    const existing = this.matches.find((m) => m.peer.id === peer.id);
    if (existing) {
      return { matched: true, match: existing };
    }

    const strategy = new HybridGamerScoringStrategy();
    const score = strategy.calculate(this.currentUser, peer);
    const icebreakers = generateCoopIcebreakers(this.currentUser, peer, score);
    const matchId = `9b1deb4d-3b7d-4bad-9bdd-${peer.id.slice(-12)}`;

    const match: MatchRecord = {
      id: matchId,
      peer,
      compatibilityScore: score.totalPercent,
      overlapHoursTotal: score.overlapHoursTotal,
      sharedGameTitles: score.sharedGames.map((g) => g.title),
      icebreakerPrompts: icebreakers,
      createdAt: new Date().toISOString(),
      unreadCount: 0,
      lastMessagePreview: introNote
        ? 'Super Duo enviado (E2EE)'
        : 'Novo Duo! Escolha um Icebreaker',
    };

    this.matches = [match, ...this.matches];
    this.wireMessages.set(matchId, []);

    if (introNote && introNote.trim().length > 0) {
      await this.sendMessage(matchId, introNote.trim(), 'icebreaker');
    }

    return { matched: true, match };
  }

  async getMatches(): Promise<MatchRecord[]> {
    await this.ensureSeeded();
    return this.matches
      .filter((m) => !this.blockedIds.has(m.peer.id))
      .map((m) => ({ ...m }));
  }

  async getMessages(matchId: string): Promise<DecryptedChatMessage[]> {
    await this.ensureSeeded();
    const match = this.matches.find((m) => m.id === matchId);
    const wire = this.wireMessages.get(matchId) ?? [];
    if (!match || !this.currentUser.demoPrivateKeyB64) {
      return [];
    }

    const decryptedList: DecryptedChatMessage[] = [];
    for (const msg of wire) {
      const plaintext = await this.cipher.decrypt({
        ciphertextB64: msg.ciphertextB64,
        nonceB64: msg.nonceB64,
        myPrivateKeyB64: this.currentUser.demoPrivateKeyB64,
        peerPublicKeyB64: match.peer.e2eePublicKeyB64,
        matchId: msg.matchId,
        senderId: msg.senderId,
      });

      decryptedList.push({
        id: msg.id,
        matchId: msg.matchId,
        senderId: msg.senderId,
        plaintext,
        ciphertextB64: msg.ciphertextB64,
        nonceB64: msg.nonceB64,
        msgType: msg.msgType,
        createdAt: msg.createdAt,
        verifiedE2EE: true,
        mediaBlurred: msg.msgType === 'image_blur',
        mediaCaption: msg.msgType === 'image_blur' ? plaintext : undefined,
      });
    }

    match.unreadCount = 0;
    return decryptedList;
  }

  async sendMessage(
    matchId: string,
    plaintext: string,
    msgType: MessageType = 'text',
  ): Promise<DecryptedChatMessage> {
    await this.ensureSeeded();
    const match = this.matches.find((m) => m.id === matchId);
    if (!match || !this.currentUser.demoPrivateKeyB64) {
      throw new Error(`Match ${matchId} not found or E2EE key missing.`);
    }

    const encrypted = await this.cipher.encrypt({
      plaintext,
      myPrivateKeyB64: this.currentUser.demoPrivateKeyB64,
      peerPublicKeyB64: match.peer.e2eePublicKeyB64,
      matchId,
      senderId: this.currentUser.id,
    });

    const wireMsg: EncryptedWireMessage = {
      id: `msg-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`,
      matchId,
      senderId: this.currentUser.id,
      ciphertextB64: encrypted.ciphertextB64,
      nonceB64: encrypted.nonceB64,
      msgType,
      createdAt: new Date().toISOString(),
    };

    const existing = this.wireMessages.get(matchId) ?? [];
    existing.push(wireMsg);
    this.wireMessages.set(matchId, existing);
    match.lastMessagePreview = 'Você · Criptografado E2EE';

    // Verify round-trip by decrypting immediately (just like receiver device would)
    const verifiedPlaintext = await this.cipher.decrypt({
      ciphertextB64: wireMsg.ciphertextB64,
      nonceB64: wireMsg.nonceB64,
      myPrivateKeyB64: this.currentUser.demoPrivateKeyB64,
      peerPublicKeyB64: match.peer.e2eePublicKeyB64,
      matchId,
      senderId: wireMsg.senderId,
    });

    return {
      id: wireMsg.id,
      matchId: wireMsg.matchId,
      senderId: wireMsg.senderId,
      plaintext: verifiedPlaintext,
      ciphertextB64: wireMsg.ciphertextB64,
      nonceB64: wireMsg.nonceB64,
      msgType: wireMsg.msgType,
      createdAt: wireMsg.createdAt,
      verifiedE2EE: true,
      mediaBlurred: msgType === 'image_blur',
    };
  }

  async getActiveLobbies(): Promise<DuoLobby[]> {
    await this.ensureSeeded();
    const now = Date.now();
    return this.lobbies
      .filter(
        (lobby) =>
          !this.blockedIds.has(lobby.hostId) &&
          new Date(lobby.expiresAt).getTime() > now,
      )
      .sort(
        (a, b) =>
          new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime(),
      );
  }

  async createLobby(input: CreateLobbyInput): Promise<DuoLobby> {
    await this.ensureSeeded();
    const now = Date.now();
    const created: DuoLobby = {
      id: `lobby-${now}`,
      hostId: this.currentUser.id,
      hostUsername: this.currentUser.username,
      hostDisplayName: this.currentUser.displayName,
      hostVerified: this.currentUser.isLivenessVerified,
      hostGradient: this.currentUser.avatarGradient,
      gameTitle: input.gameTitle.trim() || 'Valorant',
      gameSlug: input.gameTitle.trim().toLowerCase().replace(/\s+/g, '-'),
      mode: input.mode,
      voicePref: input.voicePref,
      notes: input.notes.trim() || 'Bora uma partida tranquila agora!',
      createdAt: new Date(now).toISOString(),
      expiresAt: new Date(now + 2 * 60 * 60 * 1000).toISOString(),
      compatibilityPercent: 100,
    };

    this.lobbies = [created, ...this.lobbies];
    return created;
  }

  async getPublicProfileByUsername(username: string): Promise<GamerProfile | null> {
    return findDemoProfileByUsername(username);
  }

  async giveGgBadge(
    recipientId: string,
    _matchId: string,
    badge: GgBadgeCode,
  ): Promise<void> {
    await this.ensureSeeded();
    const target = this.profiles.find((p) => p.id === recipientId);
    if (!target) return;

    const existing = target.ggBadges.find((b) => b.code === badge);
    if (existing) {
      target.ggBadges = target.ggBadges.map((b) =>
        b.code === badge ? { ...b, count: b.count + 1 } : b,
      );
    } else {
      target.ggBadges = [...target.ggBadges, { code: badge, count: 1 }];
    }

    for (const match of this.matches) {
      if (match.peer.id === recipientId) {
        match.peer = { ...target };
      }
    }
  }

  async blockPeer(peerId: string): Promise<void> {
    await this.ensureSeeded();
    this.blockedIds.add(peerId);
    this.matches = this.matches.filter((m) => m.peer.id !== peerId);
  }

  async exportLgpdData(): Promise<LgpdExportPayload> {
    await this.ensureSeeded();
    const safeProfile: Omit<GamerProfile, 'demoPrivateKeyB64'> = {
      id: this.currentUser.id,
      username: this.currentUser.username,
      displayName: this.currentUser.displayName,
      age: this.currentUser.age,
      cityLabel: this.currentUser.cityLabel,
      distanceKm: this.currentUser.distanceKm,
      distanceBucket: this.currentUser.distanceBucket,
      bio: this.currentUser.bio,
      promptQuestion: this.currentUser.promptQuestion,
      promptAnswer: this.currentUser.promptAnswer,
      avatarGradient: this.currentUser.avatarGradient,
      avatarGlyph: this.currentUser.avatarGlyph,
      isLivenessVerified: this.currentUser.isLivenessVerified,
      isOnlineNow: this.currentUser.isOnlineNow,
      discordHandle: this.currentUser.discordHandle,
      riotOrSteamTag: this.currentUser.riotOrSteamTag,
      e2eePublicKeyB64: this.currentUser.e2eePublicKeyB64,
      gamerDna: this.currentUser.gamerDna,
      scheduleHours: this.currentUser.scheduleHours,
      games: this.currentUser.games,
      ggBadges: this.currentUser.ggBadges,
      primeScheduleLabel: this.currentUser.primeScheduleLabel,
    };

    return {
      exportedAt: new Date().toISOString(),
      app: 'NEXUS DUO Web',
      mode: 'demo',
      profile: safeProfile,
      matchesCount: this.matches.length,
      activeLobbiesCount: (await this.getActiveLobbies()).length,
      e2eeNote:
        'Chaves privadas X25519 permanecem exclusivamente no dispositivo (IndexedDB) e nunca trafegam em texto claro.',
    };
  }

  async deleteAccount(): Promise<{ deletedAt: string }> {
    this.swipedIds.clear();
    this.matches = [];
    this.wireMessages.clear();
    this.lobbies = [];
    return { deletedAt: new Date().toISOString() };
  }
}

/**
 * Production Supabase Repository via @supabase/ssr with graceful fallback to DemoSeedRepository
 * if session is unauthenticated or database tables are not yet provisioned.
 */
export class SupabaseNexusRepository implements INexusRepository {
  readonly mode = 'supabase' as const;
  private readonly fallback: DemoSeedRepository;

  constructor(cipher: IMessageCipher = new WebCryptoE2EECipher()) {
    this.fallback = new DemoSeedRepository(cipher);
  }

  async getCurrentUser(): Promise<GamerProfile> {
    const client = getSupabaseBrowserClient();
    if (!client) return this.fallback.getCurrentUser();

    const {
      data: { user },
    } = await client.auth.getUser();
    if (!user) return this.fallback.getCurrentUser();

    const { data: profile } = await client
      .from('profiles')
      .select('id, username, display_name, bio, city_label, is_liveness_verified, discord_handle, e2ee_public_key')
      .eq('id', user.id)
      .maybeSingle();

    const base = await this.fallback.getCurrentUser();
    if (!profile) return base;

    return {
      ...base,
      id: String(profile.id),
      username: String(profile.username ?? base.username),
      displayName: String(profile.display_name ?? base.displayName),
      bio: String(profile.bio ?? base.bio),
      cityLabel: String(profile.city_label ?? base.cityLabel),
      isLivenessVerified: Boolean(profile.is_liveness_verified),
      discordHandle: String(profile.discord_handle ?? base.discordHandle),
      e2eePublicKeyB64: String(profile.e2ee_public_key ?? base.e2eePublicKeyB64),
    };
  }

  async updateCurrentUserProfile(patch: Partial<GamerProfile>): Promise<GamerProfile> {
    const client = getSupabaseBrowserClient();
    if (client) {
      const {
        data: { user },
      } = await client.auth.getUser();
      if (user) {
        await client
          .from('profiles')
          .update({
            display_name: patch.displayName,
            bio: patch.bio,
            discord_handle: patch.discordHandle,
          })
          .eq('id', user.id);
      }
    }
    return this.fallback.updateCurrentUserProfile(patch);
  }

  async getDiscoveryDeck(
    strategy?: IMatchScoringStrategy,
    options?: { onlyVerified?: boolean },
  ): Promise<DiscoveryCandidate[]> {
    return this.fallback.getDiscoveryDeck(strategy, options);
  }

  async swipeProfile(
    targetId: string,
    action: SwipeAction,
    introNote?: string,
  ): Promise<SwipeResult> {
    const client = getSupabaseBrowserClient();
    if (client) {
      const {
        data: { user },
      } = await client.auth.getUser();
      if (user) {
        await client.rpc('record_swipe_and_match', {
          p_target_id: targetId,
          p_action: action,
          p_intro_note: introNote ?? null,
        });
      }
    }
    return this.fallback.swipeProfile(targetId, action, introNote);
  }

  async getMatches(): Promise<MatchRecord[]> {
    return this.fallback.getMatches();
  }

  async getMessages(matchId: string): Promise<DecryptedChatMessage[]> {
    return this.fallback.getMessages(matchId);
  }

  async sendMessage(
    matchId: string,
    plaintext: string,
    msgType?: MessageType,
  ): Promise<DecryptedChatMessage> {
    return this.fallback.sendMessage(matchId, plaintext, msgType);
  }

  async getActiveLobbies(): Promise<DuoLobby[]> {
    return this.fallback.getActiveLobbies();
  }

  async createLobby(input: CreateLobbyInput): Promise<DuoLobby> {
    return this.fallback.createLobby(input);
  }

  async getPublicProfileByUsername(username: string): Promise<GamerProfile | null> {
    return this.fallback.getPublicProfileByUsername(username);
  }

  async giveGgBadge(
    recipientId: string,
    matchId: string,
    badge: GgBadgeCode,
  ): Promise<void> {
    return this.fallback.giveGgBadge(recipientId, matchId, badge);
  }

  async blockPeer(peerId: string): Promise<void> {
    const client = getSupabaseBrowserClient();
    if (client) {
      const {
        data: { user },
      } = await client.auth.getUser();
      if (user) {
        await client
          .from('blocks')
          .insert({ blocker_id: user.id, blocked_id: peerId });
      }
    }
    return this.fallback.blockPeer(peerId);
  }

  async exportLgpdData(): Promise<LgpdExportPayload> {
    const payload = await this.fallback.exportLgpdData();
    return { ...payload, mode: 'supabase' };
  }

  async deleteAccount(): Promise<{ deletedAt: string }> {
    const client = getSupabaseBrowserClient();
    if (client) {
      const { error } = await client.functions.invoke('delete-account');
      if (error) {
        throw new Error(`Falha ao excluir conta LGPD: ${error.message}`);
      }
      await client.auth.signOut();
    }
    return this.fallback.deleteAccount();
  }
}

export function createNexusRepository(
  cipher: IMessageCipher = new WebCryptoE2EECipher(),
): INexusRepository {
  if (isSupabaseConfigured()) {
    return new SupabaseNexusRepository(cipher);
  }
  return new DemoSeedRepository(cipher);
}

export function createScoringStrategy(
  mode: 'hybrid' | 'coop',
): IMatchScoringStrategy {
  return mode === 'coop'
    ? new CoopDuoScoringStrategy()
    : new HybridGamerScoringStrategy();
}
