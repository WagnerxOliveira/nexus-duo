-- =============================================================================
-- Migration 0002: Core Tables, Integrity Constraints & Strategic Indexes
-- Project: NEXUS DUO (Zero-Trust Gamer Dating & Duo Platform)
-- PostgreSQL 15+ / Supabase Free Tier Optimized
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. PROFILES
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.profiles (
  id                      uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username                text NOT NULL UNIQUE
                            CONSTRAINT profiles_username_format_chk CHECK (username ~ '^[a-z0-9_]{3,24}$'),
  display_name            text NOT NULL
                            CONSTRAINT profiles_display_name_len_chk CHECK (char_length(trim(display_name)) BETWEEN 2 AND 40),
  birth_date              date NOT NULL
                            CONSTRAINT profiles_min_age_18_chk CHECK (birth_date <= CURRENT_DATE - INTERVAL '18 years'),
  gender                  text NOT NULL
                            CONSTRAINT profiles_gender_chk CHECK (gender IN ('woman', 'man', 'non_binary', 'other')),
  interested_in           text[] NOT NULL DEFAULT ARRAY['woman', 'man', 'non_binary', 'other']::text[]
                            CONSTRAINT profiles_interested_in_chk CHECK (
                              cardinality(interested_in) >= 1
                              AND interested_in <@ ARRAY['woman', 'man', 'non_binary', 'other']::text[]
                            ),
  bio                     text NOT NULL DEFAULT ''
                            CONSTRAINT profiles_bio_len_chk CHECK (char_length(bio) <= 500),
  gamer_dna               jsonb NOT NULL DEFAULT '{"competitive":50,"social":50,"immersion":50,"chaos":50}'::jsonb
                            CONSTRAINT profiles_gamer_dna_obj_chk CHECK (jsonb_typeof(gamer_dna) = 'object'),
  schedule_mask           bigint[3] NOT NULL DEFAULT ARRAY[0::bigint, 0::bigint, 0::bigint]
                            CONSTRAINT profiles_schedule_mask_len_chk CHECK (array_length(schedule_mask, 1) = 3),
  dna_embedding           extensions.vector(128),
  approx_location         extensions.geography(Point, 4326),
  city_label              text NOT NULL DEFAULT ''
                            CONSTRAINT profiles_city_label_len_chk CHECK (char_length(city_label) <= 80),
  is_liveness_verified    boolean NOT NULL DEFAULT false,
  is_active               boolean NOT NULL DEFAULT true,
  only_verified_filter    boolean NOT NULL DEFAULT false,
  women_or_receiver_first boolean NOT NULL DEFAULT false,
  e2ee_public_key         text
                            CONSTRAINT profiles_e2ee_key_len_chk CHECK (
                              e2ee_public_key IS NULL OR char_length(e2ee_public_key) BETWEEN 40 AND 64
                            ),
  discord_handle          text
                            CONSTRAINT profiles_discord_len_chk CHECK (
                              discord_handle IS NULL OR char_length(discord_handle) <= 40
                            ),
  steam_id                text
                            CONSTRAINT profiles_steam_id_len_chk CHECK (
                              steam_id IS NULL OR char_length(steam_id) <= 40
                            ),
  last_active_at          timestamptz NOT NULL DEFAULT now(),
  created_at              timestamptz NOT NULL DEFAULT now(),
  updated_at              timestamptz NOT NULL DEFAULT now()
);

COMMENT ON COLUMN public.profiles.approx_location IS
  'Grid-snapped (>= 3km) + jittered geography point. NEVER exposed via direct SELECT or API responses.';
COMMENT ON COLUMN public.profiles.schedule_mask IS
  '3x64-bit bitmask encoding 168 weekly availability hours (Mon 00h..Sun 23h) for O(1) bitwise DP overlap.';

-- -----------------------------------------------------------------------------
-- 2. PROFILE_PHOTOS (Max 4 photos per profile enforced by constraint + trigger)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.profile_photos (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  storage_path text NOT NULL
                 CONSTRAINT profile_photos_path_chk CHECK (char_length(trim(storage_path)) BETWEEN 3 AND 255),
  position     smallint NOT NULL
                 CONSTRAINT profile_photos_position_chk CHECK (position BETWEEN 1 AND 4),
  is_primary   boolean NOT NULL DEFAULT false,
  created_at   timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT profile_photos_user_position_uk UNIQUE (user_id, position)
);

-- -----------------------------------------------------------------------------
-- 3. GAMES_CATALOG (Shared CDN-backed cache — 0 bytes Storage egress)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.games_catalog (
  id                 bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  external_source    public.external_game_source NOT NULL DEFAULT 'igdb',
  external_id        text NOT NULL
                       CONSTRAINT games_catalog_ext_id_chk CHECK (char_length(trim(external_id)) > 0),
  title              text NOT NULL
                       CONSTRAINT games_catalog_title_len_chk CHECK (char_length(trim(title)) BETWEEN 1 AND 160),
  slug               text NOT NULL UNIQUE
                       CONSTRAINT games_catalog_slug_format_chk CHECK (slug ~ '^[a-z0-9-]+$'),
  cover_url          text NOT NULL
                       CONSTRAINT games_catalog_cover_https_chk CHECK (cover_url ~ '^https://'),
  genres             text[] NOT NULL DEFAULT ARRAY[]::text[],
  platforms          text[] NOT NULL DEFAULT ARRAY[]::text[],
  supports_crossplay boolean NOT NULL DEFAULT false,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT games_catalog_source_ext_uk UNIQUE (external_source, external_id)
);

-- -----------------------------------------------------------------------------
-- 4. USER_GAMES
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.user_games (
  user_id              uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  game_id              bigint NOT NULL REFERENCES public.games_catalog(id) ON DELETE CASCADE,
  platform             text NOT NULL
                         CONSTRAINT user_games_platform_chk CHECK (
                           platform IN ('pc', 'ps5', 'ps4', 'xbox', 'switch', 'mobile', 'steam_deck')
                         ),
  rank_label           text
                         CONSTRAINT user_games_rank_len_chk CHECK (
                           rank_label IS NULL OR char_length(rank_label) <= 48
                         ),
  is_rank_ocr_verified boolean NOT NULL DEFAULT false,
  verified_gamertag    text
                         CONSTRAINT user_games_gamertag_len_chk CHECK (
                           verified_gamertag IS NULL OR char_length(verified_gamertag) <= 64
                         ),
  hours_played         integer NOT NULL DEFAULT 0
                         CONSTRAINT user_games_hours_chk CHECK (hours_played BETWEEN 0 AND 100000),
  priority_order       smallint NOT NULL DEFAULT 1
                         CONSTRAINT user_games_priority_chk CHECK (priority_order BETWEEN 1 AND 5),
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, game_id)
);

-- -----------------------------------------------------------------------------
-- 5. SWIPES
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.swipes (
  actor_id   uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  target_id  uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  action     public.swipe_action NOT NULL,
  intro_note text
               CONSTRAINT swipes_intro_note_len_chk CHECK (
                 intro_note IS NULL OR char_length(intro_note) <= 280
               ),
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (actor_id, target_id),
  CONSTRAINT swipes_no_self_chk CHECK (actor_id <> target_id)
);

-- -----------------------------------------------------------------------------
-- 6. MATCHES (Canonical ordering user_a < user_b prevents duplicate race matches)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.matches (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_a              uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  user_b              uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  compatibility_score smallint NOT NULL DEFAULT 0
                        CONSTRAINT matches_score_chk CHECK (compatibility_score BETWEEN 0 AND 100),
  icebreaker_prompts  jsonb NOT NULL DEFAULT '[]'::jsonb
                        CONSTRAINT matches_icebreakers_array_chk CHECK (jsonb_typeof(icebreaker_prompts) = 'array'),
  is_active           boolean NOT NULL DEFAULT true,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT matches_canonical_order_chk CHECK (user_a < user_b),
  CONSTRAINT matches_canonical_pair_uk UNIQUE (user_a, user_b)
);

-- -----------------------------------------------------------------------------
-- 7. USER_BADGES (Positive GG / Fair Play Reputation Badges)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.user_badges (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  giver_id     uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  match_id     uuid NOT NULL REFERENCES public.matches(id) ON DELETE CASCADE,
  badge_code   public.badge_code NOT NULL,
  created_at   timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT user_badges_no_self_chk CHECK (recipient_id <> giver_id),
  CONSTRAINT user_badges_unique_award_uk UNIQUE (giver_id, recipient_id, match_id, badge_code)
);

-- -----------------------------------------------------------------------------
-- 8. MESSAGES (E2EE AES-256-GCM Ciphertext + 96-bit Nonce)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.messages (
  id             bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  match_id       uuid NOT NULL REFERENCES public.matches(id) ON DELETE CASCADE,
  sender_id      uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  ciphertext_b64 text NOT NULL
                   CONSTRAINT messages_ciphertext_len_chk CHECK (char_length(ciphertext_b64) BETWEEN 1 AND 16384),
  nonce_b64      text NOT NULL
                   CONSTRAINT messages_nonce_len_chk CHECK (char_length(nonce_b64) BETWEEN 12 AND 32),
  msg_type       public.message_type NOT NULL DEFAULT 'text',
  created_at     timestamptz NOT NULL DEFAULT now(),
  read_at        timestamptz
);

-- -----------------------------------------------------------------------------
-- 9. DUO_LOBBIES (Ephemeral "Duo Agora" 2-hour Lobbies)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.duo_lobbies (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  host_id    uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  game_id    bigint NOT NULL REFERENCES public.games_catalog(id) ON DELETE CASCADE,
  mode       public.lobby_mode NOT NULL DEFAULT 'casual',
  voice_pref public.voice_preference NOT NULL DEFAULT 'discord',
  notes      text NOT NULL DEFAULT ''
               CONSTRAINT duo_lobbies_notes_len_chk CHECK (char_length(notes) <= 200),
  is_open    boolean NOT NULL DEFAULT true,
  expires_at timestamptz NOT NULL DEFAULT (now() + INTERVAL '2 hours'),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT duo_lobbies_ttl_chk CHECK (
    expires_at > created_at AND expires_at <= created_at + INTERVAL '4 hours'
  )
);

-- -----------------------------------------------------------------------------
-- 10. BLOCKS
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.blocks (
  blocker_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  blocked_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (blocker_id, blocked_id),
  CONSTRAINT blocks_no_self_chk CHECK (blocker_id <> blocked_id)
);

-- -----------------------------------------------------------------------------
-- 11. REPORTS
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.reports (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  reported_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  reason      public.report_reason NOT NULL,
  details     text NOT NULL DEFAULT ''
                CONSTRAINT reports_details_len_chk CHECK (char_length(details) <= 1000),
  created_at  timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT reports_no_self_chk CHECK (reporter_id <> reported_id)
);

-- -----------------------------------------------------------------------------
-- 12. USER_KEY_BACKUPS (Encrypted E2EE Private Key Vault for 2nd Monitor Sync)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.user_key_backups (
  user_id                   uuid PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  encrypted_private_key_b64 text NOT NULL
                              CONSTRAINT key_backups_cipher_len_chk CHECK (char_length(encrypted_private_key_b64) BETWEEN 32 AND 4096),
  salt_b64                  text NOT NULL
                              CONSTRAINT key_backups_salt_len_chk CHECK (char_length(salt_b64) BETWEEN 16 AND 128),
  nonce_b64                 text NOT NULL
                              CONSTRAINT key_backups_nonce_len_chk CHECK (char_length(nonce_b64) BETWEEN 12 AND 64),
  kdf_params                jsonb NOT NULL DEFAULT '{"algorithm":"argon2id","memory_kib":65536,"iterations":3,"parallelism":1}'::jsonb
                              CONSTRAINT key_backups_kdf_obj_chk CHECK (jsonb_typeof(kdf_params) = 'object'),
  updated_at                timestamptz NOT NULL DEFAULT now()
);

-- =============================================================================
-- STRATEGIC PERFORMANCE INDEXES
-- =============================================================================

-- PostGIS GiST radial spatial lookup O(log N)
CREATE INDEX IF NOT EXISTS idx_profiles_location
  ON public.profiles USING GIST (approx_location);

-- pgvector HNSW cosine semantic similarity O(log N)
CREATE INDEX IF NOT EXISTS idx_profiles_dna_hnsw
  ON public.profiles USING hnsw (dna_embedding extensions.vector_cosine_ops);

-- Partial index for active discovery pool recency scan
CREATE INDEX IF NOT EXISTS idx_profiles_active_last_seen
  ON public.profiles (last_active_at DESC)
  WHERE is_active = true;

-- Trigram GIN fuzzy autocomplete on game titles (< 5ms)
CREATE INDEX IF NOT EXISTS idx_games_title_trgm
  ON public.games_catalog USING GIN (title extensions.gin_trgm_ops);

-- Cursor-based chat pagination O(log N)
CREATE INDEX IF NOT EXISTS idx_messages_match_created
  ON public.messages (match_id, created_at DESC);

-- Partial index for open ephemeral lobbies ordered by expiration
CREATE INDEX IF NOT EXISTS idx_duo_lobbies_open_expires
  ON public.duo_lobbies (expires_at DESC)
  WHERE is_open = true;

-- Supporting FK & lookup indexes
CREATE UNIQUE INDEX IF NOT EXISTS idx_profile_photos_one_primary
  ON public.profile_photos (user_id)
  WHERE is_primary = true;

CREATE INDEX IF NOT EXISTS idx_profile_photos_user_pos
  ON public.profile_photos (user_id, position);

CREATE INDEX IF NOT EXISTS idx_user_games_user_priority
  ON public.user_games (user_id, priority_order);

CREATE INDEX IF NOT EXISTS idx_user_games_game_id
  ON public.user_games (game_id);

CREATE INDEX IF NOT EXISTS idx_user_badges_recipient
  ON public.user_badges (recipient_id, badge_code);

CREATE INDEX IF NOT EXISTS idx_swipes_actor_created
  ON public.swipes (actor_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_swipes_target_positive
  ON public.swipes (target_id, actor_id)
  WHERE action IN ('like', 'super_duo');

CREATE INDEX IF NOT EXISTS idx_matches_user_a_active
  ON public.matches (user_a)
  WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_matches_user_b_active
  ON public.matches (user_b)
  WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_blocks_blocked_blocker
  ON public.blocks (blocked_id, blocker_id);

CREATE INDEX IF NOT EXISTS idx_reports_reported_created
  ON public.reports (reported_id, created_at DESC);
