import type {
  DuoLobby,
  GamerProfile,
  UserGame,
} from '@/core/domain/types';
import { WeeklyScheduleMask } from '@/core/algo/scheduleDp';

export const DEMO_GAME_CATALOG: readonly UserGame[] = [
  {
    id: 'game-valorant',
    slug: 'valorant',
    title: 'Valorant',
    genres: ['FPS', 'Tactical', 'Competitive'],
    platforms: ['PC', 'PS5', 'Xbox'],
    preferredMode: 'casual',
    supportsCrossplay: false,
    rankLabel: 'Platina II',
    isRankOcrVerified: true,
    hoursPlayed: 640,
    priorityOrder: 1,
    accentColor: '#EC4899',
  },
  {
    id: 'game-bg3',
    slug: 'baldurs-gate-3',
    title: "Baldur's Gate 3",
    genres: ['RPG', 'Co-op', 'Story'],
    platforms: ['PC', 'PS5', 'Xbox'],
    preferredMode: 'coop',
    supportsCrossplay: true,
    rankLabel: 'Modo Honra',
    isRankOcrVerified: true,
    hoursPlayed: 310,
    priorityOrder: 2,
    accentColor: '#8B5CF6',
  },
  {
    id: 'game-stardew',
    slug: 'stardew-valley',
    title: 'Stardew Valley',
    genres: ['Cozy', 'Indie', 'Co-op'],
    platforms: ['PC', 'Switch', 'PS5', 'Mobile'],
    preferredMode: 'chill',
    supportsCrossplay: false,
    rankLabel: 'Ano 4 · Fazenda Coop',
    hoursPlayed: 420,
    priorityOrder: 3,
    accentColor: '#10B981',
  },
  {
    id: 'game-it-takes-two',
    slug: 'it-takes-two',
    title: 'It Takes Two',
    genres: ['Co-op', 'Adventure', 'Puzzle'],
    platforms: ['PC', 'PS5', 'Xbox', 'Switch'],
    preferredMode: 'coop',
    supportsCrossplay: false,
    rankLabel: 'Platinado',
    hoursPlayed: 38,
    priorityOrder: 4,
    accentColor: '#06B6D4',
  },
  {
    id: 'game-rocket-league',
    slug: 'rocket-league',
    title: 'Rocket League',
    genres: ['Sports', 'Competitive', 'Arcade'],
    platforms: ['PC', 'PS5', 'Xbox', 'Switch'],
    preferredMode: 'ranked',
    supportsCrossplay: true,
    rankLabel: 'Diamante I',
    isRankOcrVerified: true,
    hoursPlayed: 520,
    priorityOrder: 5,
    accentColor: '#F59E0B',
  },
  {
    id: 'game-elden-ring',
    slug: 'elden-ring',
    title: 'Elden Ring',
    genres: ['RPG', 'Soulslike', 'Co-op'],
    platforms: ['PC', 'PS5', 'Xbox'],
    preferredMode: 'coop',
    supportsCrossplay: false,
    rankLabel: 'NG+3 · Sem Summon',
    hoursPlayed: 290,
    priorityOrder: 3,
    accentColor: '#F59E0B',
  },
  {
    id: 'game-cs2',
    slug: 'counter-strike-2',
    title: 'Counter-Strike 2',
    genres: ['FPS', 'Tactical', 'Competitive'],
    platforms: ['PC'],
    preferredMode: 'ranked',
    supportsCrossplay: false,
    rankLabel: '16.800 Premier',
    isRankOcrVerified: true,
    hoursPlayed: 1120,
    priorityOrder: 2,
    accentColor: '#06B6D4',
  },
  {
    id: 'game-lol',
    slug: 'league-of-legends',
    title: 'League of Legends',
    genres: ['MOBA', 'Strategy', 'Competitive'],
    platforms: ['PC'],
    preferredMode: 'ranked',
    supportsCrossplay: false,
    rankLabel: 'Esmeralda III',
    isRankOcrVerified: true,
    hoursPlayed: 980,
    priorityOrder: 1,
    accentColor: '#8B5CF6',
  },
  {
    id: 'game-ow2',
    slug: 'overwatch-2',
    title: 'Overwatch 2',
    genres: ['FPS', 'Hero Shooter', 'Co-op'],
    platforms: ['PC', 'PS5', 'Xbox', 'Switch'],
    preferredMode: 'casual',
    supportsCrossplay: true,
    rankLabel: 'Main Tank · Diamante',
    hoursPlayed: 410,
    priorityOrder: 2,
    accentColor: '#06B6D4',
  },
  {
    id: 'game-genshin',
    slug: 'genshin-impact',
    title: 'Genshin Impact',
    genres: ['RPG', 'Cozy', 'Adventure'],
    platforms: ['PC', 'PS5', 'Mobile'],
    preferredMode: 'chill',
    supportsCrossplay: true,
    rankLabel: 'AR 59',
    isRankOcrVerified: true,
    hoursPlayed: 530,
    priorityOrder: 3,
    accentColor: '#EC4899',
  },
];

function gameBySlug(slug: string, overrides?: Partial<UserGame>): UserGame {
  const found = DEMO_GAME_CATALOG.find((g) => g.slug === slug) ?? DEMO_GAME_CATALOG[0]!;
  return { ...found, ...overrides };
}

// Valid deterministic X25519 keypairs (matching packages/contracts/crypto_golden_vectors.json for Clara, Lucas, Bia)
const CLARA_PRIV = 'YGkk4j92xxx0nYxvZXaTDjvg5nfX6c7kGaJyy7WcYEw=';
const CLARA_PUB = 'Lf5/8h/sZzBwu7f1D7KRq9Edf0y1NSFzFbjhiwrqs2E=';

const LUCAS_PRIV = 'GBoXatNGHkeTsUwxJVuRz3jmYmLvGSGZ3rKuAzm7EGQ=';
const LUCAS_PUB = '6G4CBAE6tQC6mdGj6cOLjJPkS+WZ2pn8K+/hneZ78Q0=';

const BIA_PRIV = 'mDxrdIEKT0kPMg2oLQGg/ddn5zKVEGzMhsmFpvk4KF0=';
const BIA_PUB = 'lNvQ74Jl1TvHOHYNNRoJlf1cMAwwfAEBT7nK5iPNTyk=';

// Additional valid clamped X25519 keypairs for Demo current user (Alex) and Rafael
const ALEX_PRIV = 'aE4n7q9s2v5y8B/E(H+MbQeThWmZq4t7w!z%C*F-J@N='.replace(/[^A-Za-z0-9+/=]/g, 'A').slice(0, 43) + '=';
const RAFA_PRIV = 'cF5o8r0t3w6z9C1F4I7L0O3R6U9X2a5d8g1j4m7p0sQ=';

export const DEMO_CURRENT_USER: GamerProfile = {
  id: '22222222-2222-4222-8222-222222222222',
  username: 'alex_duo',
  displayName: 'Alex',
  age: 26,
  cityLabel: 'São Paulo · SP',
  distanceKm: 0,
  distanceBucket: 'Você',
  bio: 'Design engineer de dia, duo tranquilo à noite. Zero tilt, muita risada no Discord e café gelado na mesa.',
  promptQuestion: 'Nosso primeiro co-op ideal seria...',
  promptAnswer: 'Um Swiftplay sem pressão no Valorant seguido de explorar a Costa da Espada em Baldur’s Gate 3.',
  avatarGradient: ['#8B5CF6', '#06B6D4', '#191F31'],
  avatarGlyph: 'AX',
  isLivenessVerified: true,
  isOnlineNow: true,
  discordHandle: 'alex.duo#2049',
  riotOrSteamTag: 'AlexDuo#BR1',
  e2eePublicKeyB64: LUCAS_PUB,
  demoPrivateKeyB64: LUCAS_PRIV,
  gamerDna: {
    competitive: 62,
    voiceCall: 80,
    coopFocus: 88,
    nightOwl: 74,
    intensity: 58,
    archetype: 'Estrategista Co-op',
    relationshipGoal: 'Relacionamento sério + Duo fixo',
  },
  // Mon-Thu 20:00-23:59, Fri-Sat 20:00-01:59, Sun 19:00-23:59
  scheduleHours: WeeklyScheduleMask.fromDayWindow([0, 1, 2, 3], 20, 24)
    .union(WeeklyScheduleMask.fromDayWindow([4, 5], 20, 2))
    .union(WeeklyScheduleMask.fromDayWindow([6], 19, 24))
    .toHours(),
  games: [
    gameBySlug('valorant', { priorityOrder: 1, rankLabel: 'Ouro III', isRankOcrVerified: true, verifiedGamertag: 'AlexDuo#BR1' }),
    gameBySlug('baldurs-gate-3', { priorityOrder: 2 }),
    gameBySlug('stardew-valley', { priorityOrder: 3 }),
    gameBySlug('it-takes-two', { priorityOrder: 4 }),
    gameBySlug('rocket-league', { priorityOrder: 5, rankLabel: 'Platina III' }),
  ],
  ggBadges: [
    { code: 'zero_tilt', count: 14 },
    { code: 'boa_call', count: 11 },
    { code: 'pontual_lobby', count: 8 },
  ],
  primeScheduleLabel: 'Seg–Dom · 20h às 00h',
};

export const DEMO_PROFILES: readonly GamerProfile[] = [
  {
    id: '11111111-1111-4111-8111-111111111111',
    username: 'valkyrie',
    displayName: 'Clara',
    age: 25,
    cityLabel: 'Pinheiros, São Paulo · SP',
    distanceKm: 7,
    distanceBucket: '~8 km',
    bio: 'Main Sentinel no Valorant e viciada em RPG narrativo. Se você dá call limpa e não dá rage quando perde pistol, já ganhou +50 pontos.',
    promptQuestion: 'O jeito mais rápido de conquistar meu Duo é...',
    promptAnswer: 'Combinar horário de verdade, respeitar o café da tarde e nunca dar surrender antes do 10-2.',
    avatarGradient: ['#8B5CF6', '#EC4899', '#191F31'],
    avatarGlyph: 'CV',
    isLivenessVerified: true,
    isOnlineNow: true,
    discordHandle: 'clara.valkyrie',
    riotOrSteamTag: 'Valkyrie#BR1',
    e2eePublicKeyB64: CLARA_PUB,
    demoPrivateKeyB64: CLARA_PRIV,
    gamerDna: {
      competitive: 72,
      voiceCall: 85,
      coopFocus: 84,
      nightOwl: 78,
      intensity: 64,
      archetype: 'Estrategista Serena',
      relationshipGoal: 'Conexão real + Duo de longo prazo',
    },
    // Mon-Fri 20:00-23:59, Sat-Sun 21:00-01:59 (wraps Sunday->Monday!)
    scheduleHours: WeeklyScheduleMask.fromDayWindow([0, 1, 2, 3, 4], 20, 24)
      .union(WeeklyScheduleMask.fromDayWindow([5, 6], 21, 2))
      .toHours(),
    games: [
      gameBySlug('valorant', { priorityOrder: 1, rankLabel: 'Platina II', isRankOcrVerified: true, verifiedGamertag: 'Valkyrie#BR1' }),
      gameBySlug('baldurs-gate-3', { priorityOrder: 2, rankLabel: 'Ato 3 · Modo Honra', isRankOcrVerified: true }),
      gameBySlug('elden-ring', { priorityOrder: 3 }),
      gameBySlug('it-takes-two', { priorityOrder: 4 }),
    ],
    ggBadges: [
      { code: 'zero_tilt', count: 29 },
      { code: 'boa_call', count: 24 },
      { code: 'carregou_time', count: 16 },
    ],
    primeScheduleLabel: 'Noites 20h–00h · FDS até 02h',
    dailyImpressions: 3,
    isNewbie: false,
  },
  {
    id: '33333333-3333-4333-8333-333333333333',
    username: 'biacozy',
    displayName: 'Bia',
    age: 24,
    cityLabel: 'Savassi, Belo Horizonte · MG',
    distanceKm: 18,
    distanceBucket: '~18 km',
    bio: 'Ilustradora, fã de trilhas sonoras de RPG e rainha das fazendas super organizadas no Stardew. Topa um co-op ouvindo lo-fi?',
    promptQuestion: 'Stardew Valley co-op: fazenda organizada ou caos criativo?',
    promptAnswer: 'Eu organizo os baús por cor enquanto você esquece de regar os morangos e a gente ri por 3 horas.',
    avatarGradient: ['#10B981', '#06B6D4', '#191F31'],
    avatarGlyph: 'BC',
    isLivenessVerified: true,
    isOnlineNow: true,
    discordHandle: 'bia.cozy',
    riotOrSteamTag: 'BiaCozy#MG',
    e2eePublicKeyB64: BIA_PUB,
    demoPrivateKeyB64: BIA_PRIV,
    gamerDna: {
      competitive: 26,
      voiceCall: 68,
      coopFocus: 96,
      nightOwl: 55,
      intensity: 32,
      archetype: 'Cozy Exploradora',
      relationshipGoal: 'Companhia leve + namoro gamer',
    },
    scheduleHours: WeeklyScheduleMask.fromDayWindow([1, 3, 4], 19, 23)
      .union(WeeklyScheduleMask.fromDayWindow([5, 6], 15, 22))
      .toHours(),
    games: [
      gameBySlug('stardew-valley', { priorityOrder: 1, rankLabel: 'Perfeição 100%', isRankOcrVerified: true }),
      gameBySlug('it-takes-two', { priorityOrder: 2 }),
      gameBySlug('genshin-impact', { priorityOrder: 3, rankLabel: 'AR 59', isRankOcrVerified: true }),
      gameBySlug('baldurs-gate-3', { priorityOrder: 4 }),
    ],
    ggBadges: [
      { code: 'cozy_vibes', count: 34 },
      { code: 'zero_tilt', count: 22 },
      { code: 'pontual_lobby', count: 19 },
    ],
    primeScheduleLabel: 'Ter/Qui/Sex 19h–23h · FDS Tarde',
    dailyImpressions: 2,
    isNewbie: true,
  },
  {
    id: '44444444-4444-4444-8444-444444444444',
    username: 'kael_br',
    displayName: 'Lucas',
    age: 27,
    cityLabel: 'Botafogo, Rio de Janeiro · RJ',
    distanceKm: 11,
    distanceBucket: '~12 km',
    bio: 'IGL calmo no Valorant e CS2, dev backend no tempo livre. Prometo nunca culpar o lag (só quando o ping bater 180ms).',
    promptQuestion: 'Meu superpoder em equipe é...',
    promptAnswer: 'Manter a moral alta no 4-11 e fazer a melhor playlist para a fila ranqueada.',
    avatarGradient: ['#06B6D4', '#8B5CF6', '#191F31'],
    avatarGlyph: 'KL',
    isLivenessVerified: true,
    isOnlineNow: false,
    discordHandle: 'kael.br',
    riotOrSteamTag: 'KaelBR#RIO',
    e2eePublicKeyB64: CLARA_PUB,
    demoPrivateKeyB64: CLARA_PRIV,
    gamerDna: {
      competitive: 84,
      voiceCall: 92,
      coopFocus: 78,
      nightOwl: 82,
      intensity: 76,
      archetype: 'IGL Tranquilo',
      relationshipGoal: 'Duo competitivo + afinidade fora da tela',
    },
    scheduleHours: WeeklyScheduleMask.fromDayWindow([0, 2, 4, 5], 21, 1)
      .union(WeeklyScheduleMask.fromDayWindow([6], 20, 24))
      .toHours(),
    games: [
      gameBySlug('valorant', { priorityOrder: 1, rankLabel: 'Diamante I', isRankOcrVerified: true, verifiedGamertag: 'KaelBR#RIO' }),
      gameBySlug('counter-strike-2', { priorityOrder: 2, rankLabel: '16.800 Premier', isRankOcrVerified: true }),
      gameBySlug('rocket-league', { priorityOrder: 3, rankLabel: 'Campeão I' }),
    ],
    ggBadges: [
      { code: 'boa_call', count: 31 },
      { code: 'carregou_time', count: 18 },
      { code: 'zero_tilt', count: 15 },
    ],
    primeScheduleLabel: 'Noites 21h–01h',
    dailyImpressions: 5,
    isNewbie: false,
  },
  {
    id: '55555555-5555-4555-8555-555555555555',
    username: 'rafatank',
    displayName: 'Rafael',
    age: 28,
    cityLabel: 'Batel, Curitiba · PR',
    distanceKm: 14,
    distanceBucket: '~15 km',
    bio: 'Main Tank que realmente protege a backline. Cozinho bem na vida real e topo tanto ARAM de sexta quanto campanha co-op de domingo.',
    promptQuestion: 'O que não pode faltar na nossa sessão de sexta?',
    promptAnswer: 'Pizza artesanal, Discord sem eco e zero toxicidade no chat all.',
    avatarGradient: ['#F59E0B', '#EC4899', '#191F31'],
    avatarGlyph: 'RT',
    isLivenessVerified: true,
    isOnlineNow: true,
    discordHandle: 'rafatank.gg',
    riotOrSteamTag: 'RafaTank#CWB',
    e2eePublicKeyB64: BIA_PUB,
    demoPrivateKeyB64: BIA_PRIV,
    gamerDna: {
      competitive: 66,
      voiceCall: 76,
      coopFocus: 90,
      nightOwl: 60,
      intensity: 62,
      archetype: 'Vanguarda Protetora',
      relationshipGoal: 'Parceria leve + games no fim de semana',
    },
    scheduleHours: WeeklyScheduleMask.fromDayWindow([0, 1, 3, 4], 20, 23)
      .union(WeeklyScheduleMask.fromDayWindow([5, 6], 18, 24))
      .toHours(),
    games: [
      gameBySlug('league-of-legends', { priorityOrder: 1, rankLabel: 'Esmeralda III', isRankOcrVerified: true, verifiedGamertag: 'RafaTank#CWB' }),
      gameBySlug('overwatch-2', { priorityOrder: 2, rankLabel: 'Diamante II · Tank' }),
      gameBySlug('rocket-league', { priorityOrder: 3 }),
      gameBySlug('baldurs-gate-3', { priorityOrder: 4 }),
    ],
    ggBadges: [
      { code: 'pontual_lobby', count: 27 },
      { code: 'zero_tilt', count: 20 },
      { code: 'cozy_vibes', count: 14 },
    ],
    primeScheduleLabel: 'Semana 20h–23h · FDS 18h–00h',
    dailyImpressions: 1,
    isNewbie: true,
  },
];

// Keep references used for linting clarity
export const DEMO_FALLBACK_KEYS = { ALEX_PRIV, RAFA_PRIV } as const;

export function createInitialDemoLobbies(nowMs = Date.now()): DuoLobby[] {
  const twoHours = 2 * 60 * 60 * 1000;
  return [
    {
      id: 'lobby-clara-val',
      hostId: '11111111-1111-4111-8111-111111111111',
      hostUsername: 'valkyrie',
      hostDisplayName: 'Clara',
      hostVerified: true,
      hostGradient: ['#8B5CF6', '#EC4899', '#191F31'],
      gameTitle: 'Valorant',
      gameSlug: 'valorant',
      mode: 'casual',
      voicePref: 'discord',
      notes: '2 partidas de Swiftplay sem tilt, aquecendo pra noite!',
      createdAt: new Date(nowMs - 18 * 60 * 1000).toISOString(),
      expiresAt: new Date(nowMs + twoHours - 18 * 60 * 1000).toISOString(),
      compatibilityPercent: 94,
    },
    {
      id: 'lobby-bia-stardew',
      hostId: '33333333-3333-4333-8333-333333333333',
      hostUsername: 'biacozy',
      hostDisplayName: 'Bia',
      hostVerified: true,
      hostGradient: ['#10B981', '#06B6D4', '#191F31'],
      gameTitle: 'Stardew Valley',
      gameSlug: 'stardew-valley',
      mode: 'chill',
      voicePref: 'discord',
      notes: 'Começando fazenda nova co-op na praia, vibe café & lo-fi.',
      createdAt: new Date(nowMs - 34 * 60 * 1000).toISOString(),
      expiresAt: new Date(nowMs + twoHours - 34 * 60 * 1000).toISOString(),
      compatibilityPercent: 89,
    },
    {
      id: 'lobby-rafa-ow2',
      hostId: '55555555-5555-4555-8555-555555555555',
      hostUsername: 'rafatank',
      hostDisplayName: 'Rafael',
      hostVerified: true,
      hostGradient: ['#F59E0B', '#EC4899', '#191F31'],
      gameTitle: 'Overwatch 2',
      gameSlug: 'overwatch-2',
      mode: 'coop',
      voicePref: 'in_game',
      notes: 'Jogo de Tank, procurando suporte ou DPS tranquilo pra Quick Play.',
      createdAt: new Date(nowMs - 45 * 60 * 1000).toISOString(),
      expiresAt: new Date(nowMs + twoHours - 45 * 60 * 1000).toISOString(),
      compatibilityPercent: 84,
    },
  ];
}

export function findDemoProfileByUsername(rawUsername: string): GamerProfile | null {
  const normalized = decodeURIComponent(rawUsername)
    .trim()
    .replace(/^@/, '')
    .toLowerCase();
  if (normalized === DEMO_CURRENT_USER.username.toLowerCase()) {
    return DEMO_CURRENT_USER;
  }
  return (
    DEMO_PROFILES.find((p) => p.username.toLowerCase() === normalized) ?? null
  );
}
