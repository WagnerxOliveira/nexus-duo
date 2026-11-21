export type SwipeAction = 'like' | 'pass' | 'super_duo';
export type LobbyMode = 'casual' | 'ranked' | 'coop' | 'chill';
export type VoicePreference = 'discord' | 'in_game' | 'text_only';
export type MessageType = 'text' | 'icebreaker' | 'lobby_invite' | 'image_blur';

export type GgBadgeCode =
  | 'zero_tilt'
  | 'boa_call'
  | 'carregou_time'
  | 'cozy_vibes'
  | 'pontual_lobby';

export interface GgBadgeMeta {
  code: GgBadgeCode;
  label: string;
  description: string;
  accent: 'cyber' | 'success' | 'primary' | 'secondary' | 'warning';
}

export const GG_BADGE_CATALOG: Record<GgBadgeCode, GgBadgeMeta> = {
  zero_tilt: {
    code: 'zero_tilt',
    label: 'Zero Tilt',
    description: 'Mantém a calma mesmo em partidas viradas',
    accent: 'success',
  },
  boa_call: {
    code: 'boa_call',
    label: 'Boa Call',
    description: 'Comunicação clara, respeitosa e divertida',
    accent: 'cyber',
  },
  carregou_time: {
    code: 'carregou_time',
    label: 'MVP do Duo',
    description: 'Decisivo na hora H e joga em equipe',
    accent: 'primary',
  },
  cozy_vibes: {
    code: 'cozy_vibes',
    label: 'Cozy Vibes',
    description: 'Companhia leve para jogar sem pressão',
    accent: 'secondary',
  },
  pontual_lobby: {
    code: 'pontual_lobby',
    label: 'Pontual na Lobby',
    description: 'Sempre aparece no horário combinado',
    accent: 'warning',
  },
};

export interface UserGame {
  id: string;
  slug: string;
  title: string;
  genres: readonly string[];
  platforms: readonly string[];
  preferredMode: LobbyMode;
  supportsCrossplay: boolean;
  rankLabel?: string;
  isRankOcrVerified?: boolean;
  verifiedGamertag?: string;
  hoursPlayed: number;
  priorityOrder: number; // 1..5
  accentColor: string;
}

export interface GamerDna {
  /** 0 = 100% Casual, 100 = 100% Competitivo */
  competitive: number;
  /** 0 = Só Chat, 100 = Call de Voz sempre */
  voiceCall: number;
  /** 0 = Solo/Side-by-side, 100 = Co-op Total */
  coopFocus: number;
  /** 0 = Diurno, 100 = Coruja / Madrugada */
  nightOwl: number;
  /** 0 = Chill / História, 100 = Adrenalina / Tryhard */
  intensity: number;
  archetype: string;
  relationshipGoal: string;
}

export interface GamerProfile {
  id: string;
  username: string;
  displayName: string;
  age: number;
  cityLabel: string;
  distanceKm: number;
  distanceBucket: string;
  bio: string;
  promptQuestion: string;
  promptAnswer: string;
  avatarGradient: readonly [string, string, string];
  avatarGlyph: string;
  isLivenessVerified: boolean;
  isOnlineNow: boolean;
  discordHandle: string;
  riotOrSteamTag: string;
  e2eePublicKeyB64: string;
  /** Only populated locally for demo peers so real E2EE decryption works end-to-end in demo mode */
  demoPrivateKeyB64?: string;
  gamerDna: GamerDna;
  /** 3x64-bit stringified bigints or bigint tuple representing 168h weekly schedule */
  scheduleHours: readonly number[];
  games: readonly UserGame[];
  ggBadges: readonly { code: GgBadgeCode; count: number }[];
  primeScheduleLabel: string;
  dailyImpressions?: number;
  isNewbie?: boolean;
}

export interface MatchScoreBreakdown {
  strategyName: string;
  totalPercent: number; // 0..100
  rankScore: number; // Fairness-adjusted score
  gamesScore: number; // 0..1
  scheduleScore: number; // 0..1
  dnaScore: number; // 0..1
  proximityScore: number; // 0..1
  sharedGames: readonly UserGame[];
  overlapHoursTotal: number;
  longestContinuousBlockHours: number;
  continuousBlocksCount: number;
  primeOverlapLabel: string;
}

export interface DiscoveryCandidate {
  profile: GamerProfile;
  score: MatchScoreBreakdown;
  icebreakers: readonly string[];
}

export interface MatchRecord {
  id: string;
  peer: GamerProfile;
  compatibilityScore: number;
  overlapHoursTotal: number;
  sharedGameTitles: readonly string[];
  icebreakerPrompts: readonly string[];
  createdAt: string;
  unreadCount: number;
  lastMessagePreview?: string;
}

export interface EncryptedWireMessage {
  id: string;
  matchId: string;
  senderId: string;
  ciphertextB64: string;
  nonceB64: string;
  msgType: MessageType;
  createdAt: string;
  readAt?: string;
}

export interface DecryptedChatMessage {
  id: string;
  matchId: string;
  senderId: string;
  plaintext: string;
  ciphertextB64: string;
  nonceB64: string;
  msgType: MessageType;
  createdAt: string;
  verifiedE2EE: boolean;
  mediaBlurred?: boolean;
  mediaCaption?: string;
}

export interface DuoLobby {
  id: string;
  hostId: string;
  hostUsername: string;
  hostDisplayName: string;
  hostVerified: boolean;
  hostGradient: readonly [string, string, string];
  gameTitle: string;
  gameSlug: string;
  mode: LobbyMode;
  voicePref: VoicePreference;
  notes: string;
  createdAt: string;
  expiresAt: string;
  compatibilityPercent: number;
}

export interface CreateLobbyInput {
  gameTitle: string;
  mode: LobbyMode;
  voicePref: VoicePreference;
  notes: string;
}

export interface LgpdExportPayload {
  exportedAt: string;
  app: 'NEXUS DUO Web';
  mode: 'supabase' | 'demo';
  profile: Omit<GamerProfile, 'demoPrivateKeyB64'>;
  matchesCount: number;
  activeLobbiesCount: number;
  e2eeNote: string;
}
