-- =============================================================================
-- pgTAP Zero-Trust Security & RLS Verification Suite — NEXUS DUO
-- Run with: supabase test db
-- Tests: user_a, user_b, user_c (outsider), blocked_user, and anon
-- =============================================================================

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgtap;

SELECT plan(36);

-- -----------------------------------------------------------------------------
-- Helper: Switch active Supabase session identity inside test transaction
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION pg_temp.set_test_user(p_uid uuid, p_role text DEFAULT 'authenticated')
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  IF p_role = 'anon' THEN
    PERFORM set_config('request.jwt.claim.sub', '', true);
    PERFORM set_config('request.jwt.claim.role', 'anon', true);
    PERFORM set_config('request.jwt.claims', '{"role":"anon"}', true);
    EXECUTE 'SET LOCAL ROLE anon';
  ELSE
    PERFORM set_config('request.jwt.claim.sub', p_uid::text, true);
    PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
    PERFORM set_config(
      'request.jwt.claims',
      json_build_object('sub', p_uid::text, 'role', 'authenticated')::text,
      true
    );
    EXECUTE 'SET LOCAL ROLE authenticated';
  END IF;
END;
$$;

-- -----------------------------------------------------------------------------
-- Seed Test Identities (as superuser/postgres before switching roles)
-- -----------------------------------------------------------------------------
DO $$
DECLARE
  v_user_a       CONSTANT uuid := '11111111-1111-4111-8111-111111111111';
  v_user_b       CONSTANT uuid := '22222222-2222-4222-8222-222222222222';
  v_user_c       CONSTANT uuid := '33333333-3333-4333-8333-333333333333';
  v_blocked_user CONSTANT uuid := '44444444-4444-4444-8444-444444444444';
  v_game_id      bigint;
BEGIN
  INSERT INTO auth.users (id, aud, role, email, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
  VALUES
    (v_user_a,       'authenticated', 'authenticated', 'user_a@nexusduo.test',  '{}'::jsonb, '{}'::jsonb, now(), now()),
    (v_user_b,       'authenticated', 'authenticated', 'user_b@nexusduo.test',  '{}'::jsonb, '{}'::jsonb, now(), now()),
    (v_user_c,       'authenticated', 'authenticated', 'user_c@nexusduo.test',  '{}'::jsonb, '{}'::jsonb, now(), now()),
    (v_blocked_user, 'authenticated', 'authenticated', 'blocked@nexusduo.test', '{}'::jsonb, '{}'::jsonb, now(), now())
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.profiles (
    id, username, display_name, birth_date, gender, interested_in,
    bio, schedule_mask, city_label, is_liveness_verified, e2ee_public_key
  )
  VALUES
    (
      v_user_a, 'clara_val', 'Clara', DATE '1999-05-10', 'woman', ARRAY['man', 'woman', 'non_binary'],
      'Main Sage e Stardew Valley.', ARRAY[16711680::bigint, 16711680::bigint, 255::bigint],
      'Sao Paulo, SP', true, 'Lf5/8h/sZzBwu7f1D7KRq9Edf0y1NSFzFbjhiwrqs2E='
    ),
    (
      v_user_b, 'lucas_duo', 'Lucas', DATE '1997-08-22', 'man', ARRAY['woman', 'non_binary'],
      'Valorant e Baldur''s Gate 3 co-op.', ARRAY[16711680::bigint, 16711680::bigint, 255::bigint],
      'Sao Paulo, SP', true, '6G4CBAE6tQC6mdGj6cOLjJPkS+WZ2pn8K+/hneZ78Q0='
    ),
    (
      v_user_c, 'bia_cozy', 'Bia', DATE '2000-01-15', 'woman', ARRAY['woman', 'man'],
      'Cozy games e RPG.', ARRAY[255::bigint, 0::bigint, 0::bigint],
      'Campinas, SP', false, 'lNvQ74Jl1TvHOHYNNRoJlf1cMAwwfAEBT7nK5iPNTyk='
    ),
    (
      v_blocked_user, 'toxic_bot', 'BlockedUser', DATE '1996-03-03', 'man', ARRAY['woman', 'man'],
      'Conta bloqueada nos testes.', ARRAY[255::bigint, 255::bigint, 255::bigint],
      'Sao Paulo, SP', false, 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA='
    );

  -- Ensure at least one catalog game exists even if seed.sql has not run
  INSERT INTO public.games_catalog (external_source, external_id, title, slug, cover_url, genres, platforms, supports_crossplay)
  VALUES (
    'igdb', '126459', 'Valorant', 'valorant',
    'https://images.igdb.com/igdb/image/upload/t_cover_big/co2mvt.jpg',
    ARRAY['fps', 'tactical'], ARRAY['pc'], false
  )
  ON CONFLICT (slug) DO NOTHING;

  SELECT id INTO v_game_id FROM public.games_catalog WHERE slug = 'valorant' LIMIT 1;

  INSERT INTO public.user_games (user_id, game_id, platform, rank_label, is_rank_ocr_verified, priority_order)
  VALUES
    (v_user_a, v_game_id, 'pc', 'Platina II', true, 1),
    (v_user_b, v_game_id, 'pc', 'Diamante I', true, 1);

  INSERT INTO public.duo_lobbies (host_id, game_id, mode, voice_pref, notes)
  VALUES (v_user_a, v_game_id, 'casual', 'discord', 'Swiftplay chill agora');
END
$$;

-- =============================================================================
-- SECTION A: SCHEMA SECURITY INVARIANTS (Tests 1..5)
-- =============================================================================

-- Test 1: 100% of public domain tables have RLS enabled
SELECT is(
  (
    SELECT COUNT(*)::integer
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relkind = 'r'
      AND c.relname IN (
        'profiles', 'profile_photos', 'games_catalog', 'user_games',
        'user_badges', 'swipes', 'matches', 'messages',
        'duo_lobbies', 'blocks', 'reports', 'user_key_backups'
      )
      AND c.relrowsecurity = true
  ),
  12,
  'T01: All 12 core tables have ENABLE ROW LEVEL SECURITY'
);

-- Test 2: Zero SECURITY DEFINER functions in public without pinned search_path = public, pg_temp
SELECT is(
  (
    SELECT COUNT(*)::integer
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.prosecdef = true
      AND (
        p.proconfig IS NULL
        OR NOT ('search_path=public, pg_temp' = ANY(p.proconfig))
      )
  ),
  0,
  'T02: Every SECURITY DEFINER function pins SET search_path = public, pg_temp'
);

-- Test 3: CHECK >= 18 rejects underage profiles
SELECT throws_ok(
  $$
    INSERT INTO auth.users (id, aud, role, email, created_at, updated_at)
    VALUES ('55555555-5555-4555-8555-555555555555', 'authenticated', 'authenticated', 'minor@nexusduo.test', now(), now());
    INSERT INTO public.profiles (id, username, display_name, birth_date, gender)
    VALUES ('55555555-5555-4555-8555-555555555555', 'minor_acc', 'Minor', (CURRENT_DATE - INTERVAL '17 years')::date, 'other');
  $$,
  '23514',
  NULL,
  'T03: CHECK constraint rejects profiles younger than 18 years old'
);

-- Test 4: get_discovery_deck return columns NEVER include approx_location, lat, or lng
SELECT is(
  (
    SELECT COUNT(*)::integer
    FROM information_schema.parameters prm
    JOIN information_schema.routines r ON r.specific_name = prm.specific_name
    WHERE r.routine_schema = 'public'
      AND r.routine_name = 'get_discovery_deck'
      AND prm.parameter_mode = 'OUT'
      AND prm.parameter_name IN ('approx_location', 'lat', 'lng', 'latitude', 'longitude')
  ),
  0,
  'T04: get_discovery_deck output signature exposes ZERO coordinate columns'
);

-- Test 5: get_discovery_deck includes distance_km_bucket output column
SELECT is(
  (
    SELECT COUNT(*)::integer
    FROM information_schema.parameters prm
    JOIN information_schema.routines r ON r.specific_name = prm.specific_name
    WHERE r.routine_schema = 'public'
      AND r.routine_name = 'get_discovery_deck'
      AND prm.parameter_mode = 'OUT'
      AND prm.parameter_name = 'distance_km_bucket'
  ),
  1,
  'T05: get_discovery_deck exposes privacy-safe distance_km_bucket'
);

-- =============================================================================
-- SECTION B: ANON ZERO-TRUST ISOLATION (Tests 6..12)
-- =============================================================================
SELECT pg_temp.set_test_user(NULL, 'anon');

-- Test 6: anon can read games_catalog for autocomplete
SELECT ok(
  (SELECT COUNT(*) FROM public.games_catalog) >= 1,
  'T06: anon can read games_catalog for public autocomplete'
);

-- Test 7: anon CANNOT read profiles
SELECT throws_ok(
  'SELECT id FROM public.profiles',
  '42501',
  NULL,
  'T07: anon is denied SELECT on profiles'
);

-- Test 8: anon CANNOT read messages
SELECT throws_ok(
  'SELECT id FROM public.messages',
  '42501',
  NULL,
  'T08: anon is denied SELECT on messages'
);

-- Test 9: anon CANNOT read swipes
SELECT throws_ok(
  'SELECT actor_id FROM public.swipes',
  '42501',
  NULL,
  'T09: anon is denied SELECT on swipes'
);

-- Test 10: anon CANNOT read user_key_backups
SELECT throws_ok(
  'SELECT user_id FROM public.user_key_backups',
  '42501',
  NULL,
  'T10: anon is denied SELECT on user_key_backups'
);

-- Test 11: anon CANNOT read duo_lobbies
SELECT throws_ok(
  'SELECT id FROM public.duo_lobbies',
  '42501',
  NULL,
  'T11: anon is denied SELECT on duo_lobbies'
);

-- Test 12: anon CANNOT execute get_discovery_deck
SELECT throws_ok(
  'SELECT * FROM public.get_discovery_deck(10, 50, false)',
  '42501',
  NULL,
  'T12: anon is denied EXECUTE on get_discovery_deck'
);

-- =============================================================================
-- SECTION C: LOCATION PRIVACY & COLUMN-LEVEL PROTECTION (Tests 13..16)
-- =============================================================================
RESET ROLE;
SELECT pg_temp.set_test_user('11111111-1111-4111-8111-111111111111', 'authenticated');

-- Test 13: authenticated CANNOT SELECT approx_location from profiles
SELECT throws_ok(
  'SELECT approx_location FROM public.profiles',
  '42501',
  NULL,
  'T13: authenticated is denied direct SELECT on profiles.approx_location'
);

-- Test 14: update_fuzzed_location succeeds and never returns lat/lng
SELECT is(
  (public.update_fuzzed_location(-23.550520, -46.633308, 'Sao Paulo, SP') ?| ARRAY['lat', 'lng', 'approx_location']),
  false,
  'T14: update_fuzzed_location never returns coordinates in JSON response'
);

RESET ROLE;
SELECT pg_temp.set_test_user('22222222-2222-4222-8222-222222222222', 'authenticated');
SELECT public.update_fuzzed_location(-23.561414, -46.655881, 'Sao Paulo, SP');

-- Test 15: get_discovery_deck returns user_a to user_b with coarse distance_km_bucket
SELECT ok(
  EXISTS (
    SELECT 1
    FROM public.get_discovery_deck(20, 50, true) d
    WHERE d.profile_id = '11111111-1111-4111-8111-111111111111'
      AND (d.distance_km_bucket = '< 5 km' OR d.distance_km_bucket LIKE '~% km')
      AND d.compatibility_score BETWEEN 0 AND 100
  ),
  'T15: get_discovery_deck returns eligible match with coarse distance_km_bucket'
);

-- Test 16: authenticated CANNOT update another user's profile
SELECT is(
  (
    WITH updated AS (
      UPDATE public.profiles
      SET bio = 'hacked'
      WHERE id = '11111111-1111-4111-8111-111111111111'
      RETURNING id
    )
    SELECT COUNT(*)::integer FROM updated
  ),
  0,
  'T16: user_b cannot modify user_a profile'
);

-- =============================================================================
-- SECTION D: SWIPES, SELF-SWIPE BLOCK & ATOMIC CANONICAL MATCH (Tests 17..22)
-- =============================================================================
RESET ROLE;
SELECT pg_temp.set_test_user('11111111-1111-4111-8111-111111111111', 'authenticated');

-- Test 17: Direct self-swipe is rejected
SELECT throws_ok(
  $$
    INSERT INTO public.swipes (actor_id, target_id, action)
    VALUES ('11111111-1111-4111-8111-111111111111', '11111111-1111-4111-8111-111111111111', 'like')
  $$,
  NULL,
  NULL,
  'T17: Direct self-swipe is blocked by RLS and CHECK constraint'
);

-- Test 18: RPC self-swipe is rejected
SELECT throws_ok(
  $$ SELECT public.record_swipe_and_match('11111111-1111-4111-8111-111111111111', 'like', NULL) $$,
  '23514',
  NULL,
  'T18: record_swipe_and_match rejects self-swipe'
);

-- user_a likes user_b via RPC (no reciprocal yet)
SELECT is(
  (public.record_swipe_and_match('22222222-2222-4222-8222-222222222222', 'like', 'Bora Valorant?') ->> 'matched')::boolean,
  false,
  'T19: First unilateral like returns matched = false'
);

-- Switch to user_b
RESET ROLE;
SELECT pg_temp.set_test_user('22222222-2222-4222-8222-222222222222', 'authenticated');

-- Test 20: user_b CANNOT spy on user_a's swipes
SELECT is(
  (SELECT COUNT(*)::integer FROM public.swipes WHERE actor_id = '11111111-1111-4111-8111-111111111111'),
  0,
  'T20: user_b cannot read user_a swipes'
);

-- Test 21: user_b CANNOT forge a swipe with actor_id = user_a
SELECT throws_ok(
  $$
    INSERT INTO public.swipes (actor_id, target_id, action)
    VALUES ('11111111-1111-4111-8111-111111111111', '33333333-3333-4333-8333-333333333333', 'like')
  $$,
  '42501',
  NULL,
  'T21: user_b cannot forge swipe as user_a'
);

-- Test 22: Reciprocal like atomically creates canonical match with 3 icebreakers
SELECT ok(
  (
    SELECT
      (res ->> 'matched')::boolean = true
      AND (res ->> 'match_id') IS NOT NULL
      AND jsonb_array_length(res -> 'icebreaker_prompts') = 3
    FROM (
      SELECT public.record_swipe_and_match('11111111-1111-4111-8111-111111111111', 'like', 'Partiu!') AS res
    ) q
  ),
  'T22: Reciprocal swipe atomically creates canonical match with 3 icebreaker prompts'
);

-- =============================================================================
-- SECTION E: E2EE MESSAGES ISOLATION & ANTI-FORGERY (Tests 23..28)
-- =============================================================================
RESET ROLE;
SELECT pg_temp.set_test_user('11111111-1111-4111-8111-111111111111', 'authenticated');

-- Test 23: user_a can insert E2EE message in active match
SELECT lives_ok(
  $$
    INSERT INTO public.messages (match_id, sender_id, ciphertext_b64, nonce_b64, msg_type)
    SELECT id, '11111111-1111-4111-8111-111111111111',
           'JNKMcjSTmyuvvaBwuRYL8UIYnnSE+jAnaKpiMX9dDqzgYp473BIrkh3VxAGLhcYotapjFCBLFZMfBhDsf0chVhX6vjHXt9aYJOeORDoKVkHiyqRcGpY0TlKzh9lSdnYv9Zb7djQ=',
           'xuM7nejNfM11pp2z',
           'text'
    FROM public.matches
    WHERE user_a = '11111111-1111-4111-8111-111111111111'
      AND user_b = '22222222-2222-4222-8222-222222222222'
  $$,
  'T23: user_a can send E2EE message in active match'
);

-- Test 24: user_a CANNOT forge sender_id = user_b on INSERT
SELECT throws_ok(
  $$
    INSERT INTO public.messages (match_id, sender_id, ciphertext_b64, nonce_b64, msg_type)
    SELECT id, '22222222-2222-4222-8222-222222222222',
           'FORGED_CIPHERTEXT_PAYLOAD==',
           'xuM7nejNfM11pp2z',
           'text'
    FROM public.matches
    WHERE user_a = '11111111-1111-4111-8111-111111111111'
      AND user_b = '22222222-2222-4222-8222-222222222222'
  $$,
  '42501',
  NULL,
  'T24: Spoofing sender_id in messages is blocked by RLS'
);

-- Switch to user_b (valid match participant)
RESET ROLE;
SELECT pg_temp.set_test_user('22222222-2222-4222-8222-222222222222', 'authenticated');

-- Test 25: user_b can read user_a message in their match
SELECT is(
  (SELECT COUNT(*)::integer FROM public.messages),
  1,
  'T25: user_b can read messages from their active match'
);

-- Test 26: user_b CANNOT tamper with ciphertext_b64 on UPDATE
SELECT throws_ok(
  $$
    UPDATE public.messages
    SET ciphertext_b64 = 'TAMPERED=='
  $$,
  '42501',
  NULL,
  'T26: Immutability trigger blocks ciphertext tampering on UPDATE'
);

-- Switch to user_c (outsider not in match)
RESET ROLE;
SELECT pg_temp.set_test_user('33333333-3333-4333-8333-333333333333', 'authenticated');

-- Test 27: user_c sees 0 matches and 0 messages from user_a <-> user_b
SELECT is(
  (SELECT COUNT(*)::integer FROM public.matches) + (SELECT COUNT(*)::integer FROM public.messages),
  0,
  'T27: Outsider user_c cannot read third-party matches or messages'
);

-- Test 28: user_c CANNOT inject message into user_a <-> user_b match (using known match_id)
SELECT throws_ok(
  $$
    INSERT INTO public.messages (match_id, sender_id, ciphertext_b64, nonce_b64, msg_type)
    VALUES (
      '00000000-0000-4000-8000-000000000001',
      '33333333-3333-4333-8333-333333333333',
      'INJECTED==',
      'xuM7nejNfM11pp2z',
      'text'
    )
  $$,
  '42501',
  NULL,
  'T28: Outsider user_c cannot inject message into foreign match'
);

-- =============================================================================
-- SECTION F: USER_KEY_BACKUPS STRICT OWNER ISOLATION (Tests 29..30)
-- =============================================================================
RESET ROLE;
SELECT pg_temp.set_test_user('11111111-1111-4111-8111-111111111111', 'authenticated');

SELECT lives_ok(
  $$
    INSERT INTO public.user_key_backups (user_id, encrypted_private_key_b64, salt_b64, nonce_b64)
    VALUES (
      '11111111-1111-4111-8111-111111111111',
      'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
      'BBBBBBBBBBBBBBBBBBBBBBBB',
      'CCCCCCCCCCCCCCCC'
    )
  $$,
  'T29: user_a can store own encrypted E2EE key backup'
);

RESET ROLE;
SELECT pg_temp.set_test_user('22222222-2222-4222-8222-222222222222', 'authenticated');

SELECT is(
  (SELECT COUNT(*)::integer FROM public.user_key_backups WHERE user_id = '11111111-1111-4111-8111-111111111111'),
  0,
  'T30: user_b cannot read user_a encrypted E2EE key backup'
);

-- =============================================================================
-- SECTION G: BLOCKING SHIELD, PHOTO LIMIT & LGPD EXPORT (Tests 31..36)
-- =============================================================================
RESET ROLE;
SELECT pg_temp.set_test_user('11111111-1111-4111-8111-111111111111', 'authenticated');

-- user_a blocks blocked_user
INSERT INTO public.blocks (blocker_id, blocked_id)
VALUES ('11111111-1111-4111-8111-111111111111', '44444444-4444-4444-8444-444444444444');

-- Switch to blocked_user
RESET ROLE;
SELECT pg_temp.set_test_user('44444444-4444-4444-8444-444444444444', 'authenticated');

-- Test 31: blocked_user CANNOT see user_a in profiles or profiles_public_view
SELECT is(
  (SELECT COUNT(*)::integer FROM public.profiles WHERE id = '11111111-1111-4111-8111-111111111111')
  + (SELECT COUNT(*)::integer FROM public.profiles_public_view WHERE id = '11111111-1111-4111-8111-111111111111'),
  0,
  'T31: blocked_user cannot view blocker profile or public view'
);

-- Test 32: blocked_user CANNOT see user_a active duo_lobbies or user_games
SELECT is(
  (SELECT COUNT(*)::integer FROM public.duo_lobbies WHERE host_id = '11111111-1111-4111-8111-111111111111')
  + (SELECT COUNT(*)::integer FROM public.user_games WHERE user_id = '11111111-1111-4111-8111-111111111111'),
  0,
  'T32: blocked_user cannot see blocker duo_lobbies or user_games'
);

-- Test 33: blocked_user CANNOT enumerate who blocked them
SELECT is(
  (SELECT COUNT(*)::integer FROM public.blocks WHERE blocker_id = '11111111-1111-4111-8111-111111111111'),
  0,
  'T33: blocked_user cannot read blocker rows in blocks table'
);

-- Test 34: blocked_user CANNOT swipe on blocker via RPC
SELECT throws_ok(
  $$ SELECT public.record_swipe_and_match('11111111-1111-4111-8111-111111111111', 'like', NULL) $$,
  '42501',
  NULL,
  'T34: record_swipe_and_match rejects swipe against user who blocked caller'
);

-- Switch back to user_a for photo limit & LGPD export checks
RESET ROLE;
SELECT pg_temp.set_test_user('11111111-1111-4111-8111-111111111111', 'authenticated');

INSERT INTO public.profile_photos (user_id, storage_path, position, is_primary) VALUES
  ('11111111-1111-4111-8111-111111111111', '11111111-1111-4111-8111-111111111111/p1.webp', 1, true),
  ('11111111-1111-4111-8111-111111111111', '11111111-1111-4111-8111-111111111111/p2.webp', 2, false),
  ('11111111-1111-4111-8111-111111111111', '11111111-1111-4111-8111-111111111111/p3.webp', 3, false),
  ('11111111-1111-4111-8111-111111111111', '11111111-1111-4111-8111-111111111111/p4.webp', 4, false);

-- Test 35: 5th photo is rejected by max-4 photos trigger / constraint
SELECT throws_ok(
  $$
    INSERT INTO public.profile_photos (user_id, storage_path, position, is_primary)
    VALUES ('11111111-1111-4111-8111-111111111111', '11111111-1111-4111-8111-111111111111/p5.webp', 4, false)
  $$,
  '23514',
  NULL,
  'T35: Trigger enforces maximum of 4 photos per profile'
);

-- Test 36: LGPD export_my_data returns owner data without raw approx_location
SELECT ok(
  (
    SELECT
      (exp ->> 'user_id') = '11111111-1111-4111-8111-111111111111'
      AND (exp -> 'profile' ->> 'username') = 'clara_val'
      AND NOT ((exp -> 'profile') ? 'approx_location')
      AND (exp ->> 'has_encrypted_key_backup')::boolean = true
    FROM (SELECT public.export_my_data() AS exp) q
  ),
  'T36: LGPD export_my_data exports full owner bundle without raw approx_location'
);

SELECT * FROM finish();

ROLLBACK;
