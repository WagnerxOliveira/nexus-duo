-- =============================================================================
-- Migration 0003: Zero-Trust Row Level Security (RLS) & Column-Level Hardening
-- Project: NEXUS DUO (Zero-Trust Gamer Dating & Duo Platform)
-- Security Principle: Default-Deny, Strict auth.uid() Ownership, Zero Location Leak
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. ENABLE ROW LEVEL SECURITY ON 100% OF PUBLIC TABLES
-- -----------------------------------------------------------------------------
ALTER TABLE public.profiles         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profile_photos   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.games_catalog    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_games       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_badges      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.swipes           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.matches          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.duo_lobbies      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.blocks           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reports          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_key_backups ENABLE ROW LEVEL SECURITY;

-- -----------------------------------------------------------------------------
-- 2. HELPER: BIDIRECTIONAL BLOCK CHECK (Avoids RLS chicken-and-egg on blocks)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_blocked_between(p_user_1 uuid, p_user_2 uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid;
BEGIN
  v_uid := auth.uid();

  -- Fail-closed if unauthenticated or probing unrelated third-party pairs
  IF v_uid IS NULL OR p_user_1 IS NULL OR p_user_2 IS NULL THEN
    RETURN true;
  END IF;

  IF v_uid <> p_user_1 AND v_uid <> p_user_2 THEN
    RETURN true;
  END IF;

  RETURN EXISTS (
    SELECT 1
    FROM public.blocks b
    WHERE (b.blocker_id = p_user_1 AND b.blocked_id = p_user_2)
       OR (b.blocker_id = p_user_2 AND b.blocked_id = p_user_1)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.is_blocked_between(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_blocked_between(uuid, uuid) TO authenticated;

-- -----------------------------------------------------------------------------
-- 3. LEAST-PRIVILEGE TABLE & COLUMN GRANTS (HARD REVOKE ON approx_location)
-- -----------------------------------------------------------------------------
-- Revoke all default privileges from PUBLIC and anon on every table
REVOKE ALL ON TABLE
  public.profiles,
  public.profile_photos,
  public.games_catalog,
  public.user_games,
  public.user_badges,
  public.swipes,
  public.matches,
  public.messages,
  public.duo_lobbies,
  public.blocks,
  public.reports,
  public.user_key_backups
FROM PUBLIC, anon, authenticated;

-- games_catalog: read-only autocomplete for anon & authenticated (writes via service_role only)
GRANT SELECT ON TABLE public.games_catalog TO anon, authenticated;

-- profiles: EXPLICIT COLUMN-LEVEL GRANTS EXCLUDING approx_location
-- (In PostgreSQL, column-level GRANT without table-level GRANT guarantees approx_location
--  can NEVER be read or written directly via PostgREST/SQL by authenticated or anon.)
REVOKE SELECT (approx_location) ON TABLE public.profiles FROM PUBLIC, anon, authenticated;
REVOKE INSERT (approx_location) ON TABLE public.profiles FROM PUBLIC, anon, authenticated;
REVOKE UPDATE (approx_location) ON TABLE public.profiles FROM PUBLIC, anon, authenticated;

GRANT SELECT (
  id,
  username,
  display_name,
  birth_date,
  gender,
  interested_in,
  bio,
  gamer_dna,
  schedule_mask,
  dna_embedding,
  city_label,
  is_liveness_verified,
  is_active,
  only_verified_filter,
  women_or_receiver_first,
  e2ee_public_key,
  discord_handle,
  steam_id,
  last_active_at,
  created_at,
  updated_at
) ON TABLE public.profiles TO authenticated;

GRANT INSERT (
  id,
  username,
  display_name,
  birth_date,
  gender,
  interested_in,
  bio,
  gamer_dna,
  schedule_mask,
  dna_embedding,
  city_label,
  is_liveness_verified,
  is_active,
  only_verified_filter,
  women_or_receiver_first,
  e2ee_public_key,
  discord_handle,
  steam_id,
  last_active_at
) ON TABLE public.profiles TO authenticated;

GRANT UPDATE (
  username,
  display_name,
  birth_date,
  gender,
  interested_in,
  bio,
  gamer_dna,
  schedule_mask,
  dna_embedding,
  city_label,
  is_liveness_verified,
  is_active,
  only_verified_filter,
  women_or_receiver_first,
  e2ee_public_key,
  discord_handle,
  steam_id,
  last_active_at
) ON TABLE public.profiles TO authenticated;

GRANT DELETE ON TABLE public.profiles TO authenticated;

-- Remaining private tables: authenticated only (subject to strict RLS below)
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.profile_photos   TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.user_games       TO authenticated;
GRANT SELECT, INSERT, DELETE         ON TABLE public.user_badges      TO authenticated;
GRANT SELECT, INSERT                 ON TABLE public.swipes           TO authenticated;
GRANT SELECT, UPDATE                 ON TABLE public.matches          TO authenticated;
GRANT SELECT, INSERT, UPDATE         ON TABLE public.messages         TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.duo_lobbies      TO authenticated;
GRANT SELECT, INSERT, DELETE         ON TABLE public.blocks           TO authenticated;
GRANT SELECT, INSERT                 ON TABLE public.reports          TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.user_key_backups TO authenticated;

-- Sequence permission for identity column on messages
GRANT USAGE, SELECT ON SEQUENCE public.messages_id_seq TO authenticated;

-- -----------------------------------------------------------------------------
-- 4. SAFE PUBLIC DISCOVERY VIEW (security_invoker = true, ZERO approx_location / birth_date)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW public.profiles_public_view
WITH (security_invoker = true) AS
SELECT
  p.id,
  p.username,
  p.display_name,
  EXTRACT(YEAR FROM age(CURRENT_DATE, p.birth_date))::integer AS age_years,
  p.gender,
  p.bio,
  p.gamer_dna,
  p.schedule_mask,
  p.city_label,
  p.is_liveness_verified,
  p.women_or_receiver_first,
  p.e2ee_public_key,
  p.discord_handle,
  p.last_active_at
FROM public.profiles p
WHERE p.is_active = true;

REVOKE ALL ON TABLE public.profiles_public_view FROM PUBLIC, anon;
GRANT SELECT ON TABLE public.profiles_public_view TO authenticated;

-- =============================================================================
-- 5. EXPLICIT RLS POLICIES (SELECT, INSERT, UPDATE, DELETE) FOR ALL 12 TABLES
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 5.1 PROFILES
-- -----------------------------------------------------------------------------
CREATE POLICY "profiles_select_visible"
  ON public.profiles
  FOR SELECT
  TO authenticated
  USING (
    id = (select auth.uid())
    OR (
      is_active = true
      AND NOT public.is_blocked_between((select auth.uid()), id)
    )
  );

CREATE POLICY "profiles_insert_own"
  ON public.profiles
  FOR INSERT
  TO authenticated
  WITH CHECK (id = (select auth.uid()));

CREATE POLICY "profiles_update_own"
  ON public.profiles
  FOR UPDATE
  TO authenticated
  USING (id = (select auth.uid()))
  WITH CHECK (id = (select auth.uid()));

CREATE POLICY "profiles_delete_own"
  ON public.profiles
  FOR DELETE
  TO authenticated
  USING (id = (select auth.uid()));

-- -----------------------------------------------------------------------------
-- 5.2 PROFILE_PHOTOS
-- -----------------------------------------------------------------------------
CREATE POLICY "profile_photos_select_visible"
  ON public.profile_photos
  FOR SELECT
  TO authenticated
  USING (
    user_id = (select auth.uid())
    OR (
      NOT public.is_blocked_between((select auth.uid()), user_id)
      AND EXISTS (
        SELECT 1
        FROM public.profiles p
        WHERE p.id = profile_photos.user_id
          AND p.is_active = true
      )
    )
  );

CREATE POLICY "profile_photos_insert_own"
  ON public.profile_photos
  FOR INSERT
  TO authenticated
  WITH CHECK (user_id = (select auth.uid()));

CREATE POLICY "profile_photos_update_own"
  ON public.profile_photos
  FOR UPDATE
  TO authenticated
  USING (user_id = (select auth.uid()))
  WITH CHECK (user_id = (select auth.uid()));

CREATE POLICY "profile_photos_delete_own"
  ON public.profile_photos
  FOR DELETE
  TO authenticated
  USING (user_id = (select auth.uid()));

-- -----------------------------------------------------------------------------
-- 5.3 GAMES_CATALOG (Public autocomplete read; server-only writes)
-- -----------------------------------------------------------------------------
CREATE POLICY "games_catalog_select_public"
  ON public.games_catalog
  FOR SELECT
  TO anon, authenticated
  USING (true);

CREATE POLICY "games_catalog_deny_insert"
  ON public.games_catalog
  FOR INSERT
  TO authenticated
  WITH CHECK (false);

CREATE POLICY "games_catalog_deny_update"
  ON public.games_catalog
  FOR UPDATE
  TO authenticated
  USING (false)
  WITH CHECK (false);

CREATE POLICY "games_catalog_deny_delete"
  ON public.games_catalog
  FOR DELETE
  TO authenticated
  USING (false);

-- -----------------------------------------------------------------------------
-- 5.4 USER_GAMES
-- -----------------------------------------------------------------------------
CREATE POLICY "user_games_select_visible"
  ON public.user_games
  FOR SELECT
  TO authenticated
  USING (
    user_id = (select auth.uid())
    OR (
      NOT public.is_blocked_between((select auth.uid()), user_id)
      AND EXISTS (
        SELECT 1
        FROM public.profiles p
        WHERE p.id = user_games.user_id
          AND p.is_active = true
      )
    )
  );

CREATE POLICY "user_games_insert_own"
  ON public.user_games
  FOR INSERT
  TO authenticated
  WITH CHECK (user_id = (select auth.uid()));

CREATE POLICY "user_games_update_own"
  ON public.user_games
  FOR UPDATE
  TO authenticated
  USING (user_id = (select auth.uid()))
  WITH CHECK (user_id = (select auth.uid()));

CREATE POLICY "user_games_delete_own"
  ON public.user_games
  FOR DELETE
  TO authenticated
  USING (user_id = (select auth.uid()));

-- -----------------------------------------------------------------------------
-- 5.5 USER_BADGES (Positive GG Reputation Badges)
-- -----------------------------------------------------------------------------
CREATE POLICY "user_badges_select_visible"
  ON public.user_badges
  FOR SELECT
  TO authenticated
  USING (
    recipient_id = (select auth.uid())
    OR giver_id = (select auth.uid())
    OR NOT public.is_blocked_between((select auth.uid()), recipient_id)
  );

CREATE POLICY "user_badges_insert_from_match"
  ON public.user_badges
  FOR INSERT
  TO authenticated
  WITH CHECK (
    giver_id = (select auth.uid())
    AND recipient_id <> (select auth.uid())
    AND NOT public.is_blocked_between((select auth.uid()), recipient_id)
    AND EXISTS (
      SELECT 1
      FROM public.matches m
      WHERE m.id = user_badges.match_id
        AND m.is_active = true
        AND (
          (m.user_a = giver_id AND m.user_b = recipient_id)
          OR (m.user_a = recipient_id AND m.user_b = giver_id)
        )
    )
  );

CREATE POLICY "user_badges_deny_update"
  ON public.user_badges
  FOR UPDATE
  TO authenticated
  USING (false)
  WITH CHECK (false);

CREATE POLICY "user_badges_delete_own_given"
  ON public.user_badges
  FOR DELETE
  TO authenticated
  USING (giver_id = (select auth.uid()));

-- -----------------------------------------------------------------------------
-- 5.6 SWIPES (Strictly private to actor; no spying, no self-swipe, immutable)
-- -----------------------------------------------------------------------------
CREATE POLICY "swipes_select_own"
  ON public.swipes
  FOR SELECT
  TO authenticated
  USING (actor_id = (select auth.uid()));

CREATE POLICY "swipes_insert_own"
  ON public.swipes
  FOR INSERT
  TO authenticated
  WITH CHECK (
    actor_id = (select auth.uid())
    AND target_id <> (select auth.uid())
    AND NOT public.is_blocked_between((select auth.uid()), target_id)
  );

CREATE POLICY "swipes_deny_update"
  ON public.swipes
  FOR UPDATE
  TO authenticated
  USING (false)
  WITH CHECK (false);

CREATE POLICY "swipes_deny_delete"
  ON public.swipes
  FOR DELETE
  TO authenticated
  USING (false);

-- -----------------------------------------------------------------------------
-- 5.7 MATCHES (Participants only; created strictly via SECURITY DEFINER RPC)
-- -----------------------------------------------------------------------------
CREATE POLICY "matches_select_participants"
  ON public.matches
  FOR SELECT
  TO authenticated
  USING (
    (select auth.uid()) IN (user_a, user_b)
    AND NOT public.is_blocked_between(user_a, user_b)
  );

CREATE POLICY "matches_deny_direct_insert"
  ON public.matches
  FOR INSERT
  TO authenticated
  WITH CHECK (false);

CREATE POLICY "matches_update_participants"
  ON public.matches
  FOR UPDATE
  TO authenticated
  USING (
    (select auth.uid()) IN (user_a, user_b)
    AND NOT public.is_blocked_between(user_a, user_b)
  )
  WITH CHECK (
    (select auth.uid()) IN (user_a, user_b)
  );

CREATE POLICY "matches_deny_delete"
  ON public.matches
  FOR DELETE
  TO authenticated
  USING (false);

-- -----------------------------------------------------------------------------
-- 5.8 MESSAGES (E2EE Chat — Active match participants only, anti-spoofing)
-- -----------------------------------------------------------------------------
CREATE POLICY "messages_select_participants"
  ON public.messages
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.matches m
      WHERE m.id = messages.match_id
        AND m.is_active = true
        AND (select auth.uid()) IN (m.user_a, m.user_b)
        AND NOT public.is_blocked_between(m.user_a, m.user_b)
    )
  );

CREATE POLICY "messages_insert_sender"
  ON public.messages
  FOR INSERT
  TO authenticated
  WITH CHECK (
    sender_id = (select auth.uid())
    AND EXISTS (
      SELECT 1
      FROM public.matches m
      WHERE m.id = messages.match_id
        AND m.is_active = true
        AND (select auth.uid()) IN (m.user_a, m.user_b)
        AND NOT public.is_blocked_between(m.user_a, m.user_b)
    )
  );

-- Only recipient may update read_at (immutability trigger protects ciphertext/nonce/sender)
CREATE POLICY "messages_update_read_receipt"
  ON public.messages
  FOR UPDATE
  TO authenticated
  USING (
    sender_id <> (select auth.uid())
    AND EXISTS (
      SELECT 1
      FROM public.matches m
      WHERE m.id = messages.match_id
        AND m.is_active = true
        AND (select auth.uid()) IN (m.user_a, m.user_b)
        AND NOT public.is_blocked_between(m.user_a, m.user_b)
    )
  )
  WITH CHECK (
    sender_id <> (select auth.uid())
  );

CREATE POLICY "messages_deny_delete"
  ON public.messages
  FOR DELETE
  TO authenticated
  USING (false);

-- -----------------------------------------------------------------------------
-- 5.9 DUO_LOBBIES (Ephemeral 2h lobbies — hidden from blocked users)
-- -----------------------------------------------------------------------------
CREATE POLICY "duo_lobbies_select_active"
  ON public.duo_lobbies
  FOR SELECT
  TO authenticated
  USING (
    host_id = (select auth.uid())
    OR (
      is_open = true
      AND expires_at > now()
      AND NOT public.is_blocked_between((select auth.uid()), host_id)
    )
  );

CREATE POLICY "duo_lobbies_insert_own"
  ON public.duo_lobbies
  FOR INSERT
  TO authenticated
  WITH CHECK (host_id = (select auth.uid()));

CREATE POLICY "duo_lobbies_update_own"
  ON public.duo_lobbies
  FOR UPDATE
  TO authenticated
  USING (host_id = (select auth.uid()))
  WITH CHECK (host_id = (select auth.uid()));

CREATE POLICY "duo_lobbies_delete_own"
  ON public.duo_lobbies
  FOR DELETE
  TO authenticated
  USING (host_id = (select auth.uid()));

-- -----------------------------------------------------------------------------
-- 5.10 BLOCKS (Private to blocker; blocked user cannot enumerate)
-- -----------------------------------------------------------------------------
CREATE POLICY "blocks_select_own"
  ON public.blocks
  FOR SELECT
  TO authenticated
  USING (blocker_id = (select auth.uid()));

CREATE POLICY "blocks_insert_own"
  ON public.blocks
  FOR INSERT
  TO authenticated
  WITH CHECK (
    blocker_id = (select auth.uid())
    AND blocked_id <> (select auth.uid())
  );

CREATE POLICY "blocks_deny_update"
  ON public.blocks
  FOR UPDATE
  TO authenticated
  USING (false)
  WITH CHECK (false);

CREATE POLICY "blocks_delete_own"
  ON public.blocks
  FOR DELETE
  TO authenticated
  USING (blocker_id = (select auth.uid()));

-- -----------------------------------------------------------------------------
-- 5.11 REPORTS (Private to reporter; immutable audit trail)
-- -----------------------------------------------------------------------------
CREATE POLICY "reports_select_own"
  ON public.reports
  FOR SELECT
  TO authenticated
  USING (reporter_id = (select auth.uid()));

CREATE POLICY "reports_insert_own"
  ON public.reports
  FOR INSERT
  TO authenticated
  WITH CHECK (
    reporter_id = (select auth.uid())
    AND reported_id <> (select auth.uid())
  );

CREATE POLICY "reports_deny_update"
  ON public.reports
  FOR UPDATE
  TO authenticated
  USING (false)
  WITH CHECK (false);

CREATE POLICY "reports_deny_delete"
  ON public.reports
  FOR DELETE
  TO authenticated
  USING (false);

-- -----------------------------------------------------------------------------
-- 5.12 USER_KEY_BACKUPS (Strict owner-only E2EE private key backup vault)
-- -----------------------------------------------------------------------------
CREATE POLICY "user_key_backups_select_own"
  ON public.user_key_backups
  FOR SELECT
  TO authenticated
  USING (user_id = (select auth.uid()));

CREATE POLICY "user_key_backups_insert_own"
  ON public.user_key_backups
  FOR INSERT
  TO authenticated
  WITH CHECK (user_id = (select auth.uid()));

CREATE POLICY "user_key_backups_update_own"
  ON public.user_key_backups
  FOR UPDATE
  TO authenticated
  USING (user_id = (select auth.uid()))
  WITH CHECK (user_id = (select auth.uid()));

CREATE POLICY "user_key_backups_delete_own"
  ON public.user_key_backups
  FOR DELETE
  TO authenticated
  USING (user_id = (select auth.uid()));

-- -----------------------------------------------------------------------------
-- 6. STORAGE BUCKET RLS (avatars: folder-scoped by auth.uid(), guarded if schema exists)
-- -----------------------------------------------------------------------------
DO $$
BEGIN
  IF to_regclass('storage.objects') IS NOT NULL THEN
    -- Ensure avatars bucket exists with strict 1 MiB limit and image MIME types
    IF to_regclass('storage.buckets') IS NOT NULL THEN
      INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
      VALUES (
        'avatars',
        'avatars',
        false,
        1048576,
        ARRAY['image/webp', 'image/jpeg', 'image/png']::text[]
      )
      ON CONFLICT (id) DO UPDATE
        SET file_size_limit = EXCLUDED.file_size_limit,
            allowed_mime_types = EXCLUDED.allowed_mime_types;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'avatars_select_authenticated') THEN
      CREATE POLICY "avatars_select_authenticated"
        ON storage.objects
        FOR SELECT
        TO authenticated
        USING (
          bucket_id = 'avatars'
          AND (
            (storage.foldername(name))[1] = (select auth.uid())::text
            OR (
              (storage.foldername(name))[1] ~ '^[0-9a-fA-F-]{36}$'
              AND NOT public.is_blocked_between((select auth.uid()), ((storage.foldername(name))[1])::uuid)
            )
          )
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'avatars_insert_own_folder') THEN
      CREATE POLICY "avatars_insert_own_folder"
        ON storage.objects
        FOR INSERT
        TO authenticated
        WITH CHECK (
          bucket_id = 'avatars'
          AND (storage.foldername(name))[1] = (select auth.uid())::text
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'avatars_update_own_folder') THEN
      CREATE POLICY "avatars_update_own_folder"
        ON storage.objects
        FOR UPDATE
        TO authenticated
        USING (
          bucket_id = 'avatars'
          AND (storage.foldername(name))[1] = (select auth.uid())::text
        )
        WITH CHECK (
          bucket_id = 'avatars'
          AND (storage.foldername(name))[1] = (select auth.uid())::text
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'avatars_delete_own_folder') THEN
      CREATE POLICY "avatars_delete_own_folder"
        ON storage.objects
        FOR DELETE
        TO authenticated
        USING (
          bucket_id = 'avatars'
          AND (storage.foldername(name))[1] = (select auth.uid())::text
        );
    END IF;
  END IF;
END
$$;
