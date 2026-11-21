-- =============================================================================
-- Migration 0004: Zero-Trust RPCs, Matchmaking Engine, LGPD & Integrity Triggers
-- Project: NEXUS DUO (Zero-Trust Gamer Dating & Duo Platform)
-- Security Rule: EVERY SECURITY DEFINER function declares SET search_path = public, pg_temp
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. GENERIC updated_at TRIGGER
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_profiles_updated_at ON public.profiles;
CREATE TRIGGER trg_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_games_catalog_updated_at ON public.games_catalog;
CREATE TRIGGER trg_games_catalog_updated_at
  BEFORE UPDATE ON public.games_catalog
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_user_games_updated_at ON public.user_games;
CREATE TRIGGER trg_user_games_updated_at
  BEFORE UPDATE ON public.user_games
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_matches_updated_at ON public.matches;
CREATE TRIGGER trg_matches_updated_at
  BEFORE UPDATE ON public.matches
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_user_key_backups_updated_at ON public.user_key_backups;
CREATE TRIGGER trg_user_key_backups_updated_at
  BEFORE UPDATE ON public.user_key_backups
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

-- -----------------------------------------------------------------------------
-- 2. MAX 4 PHOTOS PER PROFILE TRIGGER (Concurrency-safe via advisory lock)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.enforce_max_profile_photos()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
  v_count integer;
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext('profile_photos:' || NEW.user_id::text));

  SELECT COUNT(*) INTO v_count
  FROM public.profile_photos
  WHERE user_id = NEW.user_id;

  IF v_count >= 4 THEN
    RAISE EXCEPTION 'MAX_PHOTOS_EXCEEDED: A profile may have at most 4 photos.'
      USING ERRCODE = 'check_violation';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_profile_photos_max_four ON public.profile_photos;
CREATE TRIGGER trg_profile_photos_max_four
  BEFORE INSERT ON public.profile_photos
  FOR EACH ROW
  EXECUTE FUNCTION public.enforce_max_profile_photos();

-- -----------------------------------------------------------------------------
-- 3. IMMUTABILITY TRIGGERS (Matches & E2EE Messages Integrity)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.protect_match_immutable_columns()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.user_a <> OLD.user_a
     OR NEW.user_b <> OLD.user_b
     OR NEW.compatibility_score <> OLD.compatibility_score
     OR NEW.created_at <> OLD.created_at THEN
    RAISE EXCEPTION 'IMMUTABLE_MATCH_FIELDS: Match participants and score cannot be altered.'
      USING ERRCODE = 'insufficient_privilege';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_matches_protect_immutable ON public.matches;
CREATE TRIGGER trg_matches_protect_immutable
  BEFORE UPDATE ON public.matches
  FOR EACH ROW
  EXECUTE FUNCTION public.protect_match_immutable_columns();

CREATE OR REPLACE FUNCTION public.protect_message_immutable_columns()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.match_id <> OLD.match_id
     OR NEW.sender_id <> OLD.sender_id
     OR NEW.ciphertext_b64 <> OLD.ciphertext_b64
     OR NEW.nonce_b64 <> OLD.nonce_b64
     OR NEW.msg_type <> OLD.msg_type
     OR NEW.created_at <> OLD.created_at THEN
    RAISE EXCEPTION 'IMMUTABLE_MESSAGE_FIELDS: Only read_at may be updated on E2EE messages.'
      USING ERRCODE = 'insufficient_privilege';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_messages_protect_immutable ON public.messages;
CREATE TRIGGER trg_messages_protect_immutable
  BEFORE UPDATE ON public.messages
  FOR EACH ROW
  EXECUTE FUNCTION public.protect_message_immutable_columns();

-- -----------------------------------------------------------------------------
-- 4. AUTOMATIC MATCH DEACTIVATION ON BLOCK (1-Tap Safety Shield)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.deactivate_match_on_block()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_a uuid;
  v_user_b uuid;
BEGIN
  v_user_a := LEAST(NEW.blocker_id, NEW.blocked_id);
  v_user_b := GREATEST(NEW.blocker_id, NEW.blocked_id);

  UPDATE public.matches
  SET is_active = false,
      updated_at = now()
  WHERE user_a = v_user_a
    AND user_b = v_user_b
    AND is_active = true;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_blocks_deactivate_match ON public.blocks;
CREATE TRIGGER trg_blocks_deactivate_match
  AFTER INSERT ON public.blocks
  FOR EACH ROW
  EXECUTE FUNCTION public.deactivate_match_on_block();

-- -----------------------------------------------------------------------------
-- 5. SCHEDULE OVERLAP DP HELPER (Continuous Co-op Window DP — O(168) = O(1))
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.compute_schedule_overlap_score(
  p_mask_a bigint[],
  p_mask_b bigint[]
)
RETURNS double precision
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public, pg_temp
AS $$
DECLARE
  v_m0 bigint;
  v_m1 bigint;
  v_m2 bigint;
  v_chunk bigint;
  v_bit integer;
  v_h integer;
  v_is_set boolean;
  v_cur_run integer := 0;
  v_first_run integer := 0;
  v_seen_zero boolean := false;
  v_weighted_sum double precision := 0.0;
BEGIN
  IF p_mask_a IS NULL OR p_mask_b IS NULL
     OR array_length(p_mask_a, 1) <> 3
     OR array_length(p_mask_b, 1) <> 3 THEN
    RETURN 0.0;
  END IF;

  v_m0 := p_mask_a[1] & p_mask_b[1];
  v_m1 := p_mask_a[2] & p_mask_b[2];
  v_m2 := p_mask_a[3] & p_mask_b[3];

  IF v_m0 = 0 AND v_m1 = 0 AND v_m2 = 0 THEN
    RETURN 0.0;
  END IF;

  FOR v_h IN 0..167 LOOP
    IF v_h < 64 THEN
      v_chunk := v_m0;
      v_bit := v_h;
    ELSIF v_h < 128 THEN
      v_chunk := v_m1;
      v_bit := v_h - 64;
    ELSE
      v_chunk := v_m2;
      v_bit := v_h - 128;
    END IF;

    v_is_set := ((v_chunk & (1::bigint << v_bit)) <> 0);

    IF v_is_set THEN
      v_cur_run := v_cur_run + 1;
    ELSE
      IF NOT v_seen_zero THEN
        v_first_run := v_cur_run;
        v_seen_zero := true;
      ELSIF v_cur_run >= 2 THEN
        v_weighted_sum := v_weighted_sum + ((v_cur_run - 1)::double precision * 1.5);
      END IF;
      v_cur_run := 0;
    END IF;
  END LOOP;

  -- Wrap-around Sunday night -> Monday early morning
  IF NOT v_seen_zero THEN
    -- All 168 hours overlap
    RETURN 1.0;
  END IF;

  IF (v_first_run + v_cur_run) >= 2 THEN
    v_weighted_sum := v_weighted_sum + (((v_first_run + v_cur_run) - 1)::double precision * 1.5);
  END IF;

  RETURN LEAST(1.0, v_weighted_sum / 10.0);
END;
$$;

GRANT EXECUTE ON FUNCTION public.compute_schedule_overlap_score(bigint[], bigint[]) TO authenticated;

-- -----------------------------------------------------------------------------
-- 6. RPC: update_fuzzed_location (Anti-Stalking Grid Snapping >= 3km + Jitter)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.update_fuzzed_location(
  p_lat double precision,
  p_lng double precision,
  p_city_label text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid;
  v_lat_step double precision := 0.036; -- ~4.0 km latitude grid (>= 3 km everywhere)
  v_cos_lat double precision;
  v_lng_step double precision;
  v_snapped_lat double precision;
  v_snapped_lng double precision;
  v_jitter_lat double precision;
  v_jitter_lng double precision;
  v_fuzzed_lat double precision;
  v_fuzzed_lng double precision;
  v_clean_city text;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'UNAUTHORIZED: Authentication required.'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  IF p_lat IS NULL OR p_lng IS NULL OR p_lat < -90.0 OR p_lat > 90.0 OR p_lng < -180.0 OR p_lng > 180.0 THEN
    RAISE EXCEPTION 'INVALID_COORDINATES: Latitude/longitude out of bounds.'
      USING ERRCODE = 'invalid_parameter_value';
  END IF;

  v_clean_city := left(trim(COALESCE(p_city_label, '')), 80);

  -- Snap coordinates to ~4 km cell center, then apply bounded random jitter (~1 km)
  v_cos_lat := GREATEST(cos(radians(p_lat)), 0.15);
  v_lng_step := v_lat_step / v_cos_lat;

  v_snapped_lat := round(p_lat / v_lat_step) * v_lat_step;
  v_snapped_lng := round(p_lng / v_lng_step) * v_lng_step;

  v_jitter_lat := (random() - 0.5) * 0.018;
  v_jitter_lng := (random() - 0.5) * (0.018 / v_cos_lat);

  v_fuzzed_lat := GREATEST(-89.9, LEAST(89.9, v_snapped_lat + v_jitter_lat));
  v_fuzzed_lng := GREATEST(-179.9, LEAST(179.9, v_snapped_lng + v_jitter_lng));

  UPDATE public.profiles
  SET approx_location = ST_SetSRID(ST_MakePoint(v_fuzzed_lng, v_fuzzed_lat), 4326)::geography,
      city_label = v_clean_city,
      last_active_at = now(),
      updated_at = now()
  WHERE id = v_uid;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PROFILE_NOT_FOUND: Create profile before updating location.'
      USING ERRCODE = 'no_data_found';
  END IF;

  -- Never return coordinates (exact or fuzzed) in RPC response
  RETURN jsonb_build_object(
    'status', 'ok',
    'city_label', v_clean_city,
    'location_fuzzed', true
  );
END;
$$;

REVOKE ALL ON FUNCTION public.update_fuzzed_location(double precision, double precision, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_fuzzed_location(double precision, double precision, text) TO authenticated;

-- -----------------------------------------------------------------------------
-- 7. RPC: get_discovery_deck (3-Stage Sublinear Funnel, ZERO lat/lng exposure)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_discovery_deck(
  p_limit integer DEFAULT 20,
  p_max_distance_km integer DEFAULT 50,
  p_only_verified boolean DEFAULT false
)
RETURNS TABLE (
  profile_id              uuid,
  username                text,
  display_name            text,
  age_years               integer,
  gender                  text,
  bio                     text,
  gamer_dna               jsonb,
  city_label              text,
  is_liveness_verified    boolean,
  women_or_receiver_first boolean,
  e2ee_public_key         text,
  distance_km_bucket      text,
  compatibility_score     smallint,
  shared_games            jsonb,
  photos                  jsonb,
  badges                  jsonb
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid;
  v_me public.profiles%ROWTYPE;
  v_limit integer;
  v_max_dist_km double precision;
  v_max_dist_m double precision;
  v_require_verified boolean;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'UNAUTHORIZED: Authentication required.'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  SELECT * INTO v_me
  FROM public.profiles
  WHERE id = v_uid;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PROFILE_NOT_FOUND: Complete onboarding profile first.'
      USING ERRCODE = 'no_data_found';
  END IF;

  v_limit := GREATEST(1, LEAST(COALESCE(p_limit, 20), 50));
  v_max_dist_km := GREATEST(5, LEAST(COALESCE(p_max_distance_km, 50), 500))::double precision;
  v_max_dist_m := v_max_dist_km * 1000.0;
  v_require_verified := COALESCE(p_only_verified, false) OR v_me.only_verified_filter;

  RETURN QUERY
  WITH
  -- Stage 1: PostGIS GiST radial + mutual preferences + exclusions (K <= 300)
  stage1_candidates AS (
    SELECT
      p.id,
      p.username,
      p.display_name,
      EXTRACT(YEAR FROM age(CURRENT_DATE, p.birth_date))::integer AS age_years,
      p.gender,
      p.bio,
      p.gamer_dna,
      p.schedule_mask,
      p.dna_embedding,
      p.city_label,
      p.is_liveness_verified,
      p.women_or_receiver_first,
      p.e2ee_public_key,
      p.created_at,
      CASE
        WHEN v_me.approx_location IS NOT NULL AND p.approx_location IS NOT NULL
          THEN ST_Distance(v_me.approx_location, p.approx_location) / 1000.0
        ELSE NULL
      END AS dist_km
    FROM public.profiles p
    WHERE p.id <> v_uid
      AND p.is_active = true
      AND p.birth_date <= CURRENT_DATE - INTERVAL '18 years'
      AND p.gender = ANY(v_me.interested_in)
      AND v_me.gender = ANY(p.interested_in)
      AND (NOT v_require_verified OR p.is_liveness_verified = true)
      AND (
        v_me.approx_location IS NULL
        OR p.approx_location IS NULL
        OR ST_DWithin(p.approx_location, v_me.approx_location, v_max_dist_m)
      )
      AND NOT EXISTS (
        SELECT 1 FROM public.swipes s
        WHERE s.actor_id = v_uid AND s.target_id = p.id
      )
      AND NOT EXISTS (
        SELECT 1 FROM public.matches m
        WHERE m.user_a = LEAST(v_uid, p.id)
          AND m.user_b = GREATEST(v_uid, p.id)
      )
      AND NOT EXISTS (
        SELECT 1 FROM public.blocks b
        WHERE (b.blocker_id = v_uid AND b.blocked_id = p.id)
           OR (b.blocker_id = p.id AND b.blocked_id = v_uid)
      )
    ORDER BY p.last_active_at DESC
    LIMIT 300
  ),
  -- Stage 2: pgvector HNSW / Cosine semantic similarity (M <= 60)
  stage2_semantic AS (
    SELECT
      c.*,
      CASE
        WHEN v_me.dna_embedding IS NOT NULL AND c.dna_embedding IS NOT NULL
          THEN GREATEST(0.0, LEAST(1.0, 1.0 - ((c.dna_embedding <=> v_me.dna_embedding) / 2.0)))
        ELSE 0.5
      END AS dna_score
    FROM stage1_candidates c
    ORDER BY
      CASE
        WHEN v_me.dna_embedding IS NOT NULL AND c.dna_embedding IS NOT NULL
          THEN (c.dna_embedding <=> v_me.dna_embedding)
        ELSE 1.0
      END ASC
    LIMIT 60
  ),
  -- Stage 3: DP Schedule + Weighted Games Priority + Proximity + Fairness
  stage3_scored AS (
    SELECT
      s2.id,
      s2.username,
      s2.display_name,
      s2.age_years,
      s2.gender,
      s2.bio,
      s2.gamer_dna,
      s2.city_label,
      s2.is_liveness_verified,
      s2.women_or_receiver_first,
      s2.e2ee_public_key,
      s2.dist_km,
      s2.dna_score,
      public.compute_schedule_overlap_score(v_me.schedule_mask, s2.schedule_mask) AS schedule_score,
      COALESCE((
        SELECT LEAST(1.0, SUM(
          (1.0 / log(2.0, (LEAST(ug_me.priority_order, ug_other.priority_order) + 2)::numeric))::double precision
          * CASE
              WHEN ug_me.platform = ug_other.platform OR gc.supports_crossplay THEN 1.25
              ELSE 1.0
            END
        ) / 2.2)
        FROM public.user_games ug_me
        INNER JOIN public.user_games ug_other
          ON ug_other.user_id = s2.id
         AND ug_other.game_id = ug_me.game_id
        INNER JOIN public.games_catalog gc
          ON gc.id = ug_me.game_id
        WHERE ug_me.user_id = v_uid
      ), 0.0) AS games_score,
      CASE
        WHEN s2.dist_km IS NULL THEN 0.5
        ELSE GREATEST(0.0, LEAST(1.0, 1.0 - (s2.dist_km / v_max_dist_km)))
      END AS proximity_score,
      -- Ethical boost for verified profiles & newcomers (anti-Pareto fairness)
      (CASE WHEN s2.is_liveness_verified THEN 1.08 ELSE 1.0 END)
      * (CASE WHEN s2.created_at >= now() - INTERVAL '7 days' THEN 1.06 ELSE 1.0 END) AS fairness_boost
    FROM stage2_semantic s2
  )
  SELECT
    s3.id AS profile_id,
    s3.username,
    s3.display_name,
    s3.age_years,
    s3.gender,
    s3.bio,
    s3.gamer_dna,
    s3.city_label,
    s3.is_liveness_verified,
    s3.women_or_receiver_first,
    s3.e2ee_public_key,
    -- Privacy-safe coarse distance bucket (NEVER exact coordinates or raw float km)
    CASE
      WHEN s3.dist_km IS NULL THEN 'Distancia oculta'
      WHEN s3.dist_km < 5.0   THEN '< 5 km'
      ELSE '~' || GREATEST(5, round(s3.dist_km)::integer)::text || ' km'
    END AS distance_km_bucket,
    LEAST(100, GREATEST(0, round(
      (0.35 * s3.games_score
       + 0.25 * s3.schedule_score
       + 0.25 * s3.dna_score
       + 0.15 * s3.proximity_score) * 100.0
    )))::smallint AS compatibility_score,
    COALESCE((
      SELECT jsonb_agg(
        jsonb_build_object(
          'game_id', gc.id,
          'title', gc.title,
          'slug', gc.slug,
          'cover_url', gc.cover_url,
          'rank_label', ug_other.rank_label,
          'is_rank_ocr_verified', ug_other.is_rank_ocr_verified,
          'platform', ug_other.platform
        ) ORDER BY ug_other.priority_order ASC
      )
      FROM public.user_games ug_me
      INNER JOIN public.user_games ug_other
        ON ug_other.user_id = s3.id AND ug_other.game_id = ug_me.game_id
      INNER JOIN public.games_catalog gc
        ON gc.id = ug_other.game_id
      WHERE ug_me.user_id = v_uid
    ), '[]'::jsonb) AS shared_games,
    COALESCE((
      SELECT jsonb_agg(
        jsonb_build_object(
          'id', pp.id,
          'storage_path', pp.storage_path,
          'position', pp.position,
          'is_primary', pp.is_primary
        ) ORDER BY pp.position ASC
      )
      FROM public.profile_photos pp
      WHERE pp.user_id = s3.id
    ), '[]'::jsonb) AS photos,
    COALESCE((
      SELECT jsonb_agg(
        jsonb_build_object(
          'badge_code', b_agg.badge_code,
          'count', b_agg.badge_count
        ) ORDER BY b_agg.badge_count DESC
      )
      FROM (
        SELECT ub.badge_code, COUNT(*)::integer AS badge_count
        FROM public.user_badges ub
        WHERE ub.recipient_id = s3.id
        GROUP BY ub.badge_code
      ) b_agg
    ), '[]'::jsonb) AS badges
  FROM stage3_scored s3
  ORDER BY
    ((0.35 * s3.games_score
      + 0.25 * s3.schedule_score
      + 0.25 * s3.dna_score
      + 0.15 * s3.proximity_score) * s3.fairness_boost) DESC,
    s3.id ASC
  LIMIT v_limit;
END;
$$;

REVOKE ALL ON FUNCTION public.get_discovery_deck(integer, integer, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_discovery_deck(integer, integer, boolean) TO authenticated;

-- -----------------------------------------------------------------------------
-- 8. RPC: record_swipe_and_match (Atomic Canonical Match + Co-op Icebreakers + Anti-Bot)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.record_swipe_and_match(
  p_target_id uuid,
  p_action text,
  p_intro_note text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor_id uuid;
  v_action public.swipe_action;
  v_actor public.profiles%ROWTYPE;
  v_target public.profiles%ROWTYPE;
  v_recent_min integer;
  v_recent_day integer;
  v_super_day integer;
  v_has_reciprocal boolean := false;
  v_user_a uuid;
  v_user_b uuid;
  v_top_shared_game text;
  v_schedule_score double precision;
  v_dna_score double precision;
  v_games_score double precision;
  v_compat smallint;
  v_icebreakers jsonb;
  v_match_id uuid;
  v_clean_note text;
BEGIN
  v_actor_id := auth.uid();
  IF v_actor_id IS NULL THEN
    RAISE EXCEPTION 'UNAUTHORIZED: Authentication required.'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  IF p_target_id IS NULL OR p_target_id = v_actor_id THEN
    RAISE EXCEPTION 'INVALID_SWIPE_TARGET: Cannot swipe on yourself or null target.'
      USING ERRCODE = 'check_violation';
  END IF;

  IF p_action NOT IN ('like', 'pass', 'super_duo') THEN
    RAISE EXCEPTION 'INVALID_SWIPE_ACTION: Action must be like, pass, or super_duo.'
      USING ERRCODE = 'invalid_parameter_value';
  END IF;
  v_action := p_action::public.swipe_action;

  v_clean_note := NULLIF(left(trim(COALESCE(p_intro_note, '')), 280), '');

  -- Validate both profiles exist, are active, and are strictly 18+
  SELECT * INTO v_actor FROM public.profiles WHERE id = v_actor_id;
  IF NOT FOUND OR NOT v_actor.is_active OR v_actor.birth_date > CURRENT_DATE - INTERVAL '18 years' THEN
    RAISE EXCEPTION 'ACTOR_INELIGIBLE: Active 18+ profile required.'
      USING ERRCODE = 'check_violation';
  END IF;

  SELECT * INTO v_target FROM public.profiles WHERE id = p_target_id;
  IF NOT FOUND OR NOT v_target.is_active OR v_target.birth_date > CURRENT_DATE - INTERVAL '18 years' THEN
    RAISE EXCEPTION 'TARGET_INELIGIBLE: Target profile unavailable.'
      USING ERRCODE = 'no_data_found';
  END IF;

  -- Block check (bidirectional)
  IF EXISTS (
    SELECT 1 FROM public.blocks b
    WHERE (b.blocker_id = v_actor_id AND b.blocked_id = p_target_id)
       OR (b.blocker_id = p_target_id AND b.blocked_id = v_actor_id)
  ) THEN
    RAISE EXCEPTION 'INTERACTION_BLOCKED: Action not permitted between blocked users.'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  -- Anti-bot rate limiting
  SELECT COUNT(*) INTO v_recent_min
  FROM public.swipes
  WHERE actor_id = v_actor_id
    AND created_at >= now() - INTERVAL '1 minute';

  IF v_recent_min >= 20 THEN
    RAISE EXCEPTION 'RATE_LIMIT_EXCEEDED: Slow down! Maximum 20 swipes per minute.'
      USING ERRCODE = 'raise_exception';
  END IF;

  SELECT COUNT(*) INTO v_recent_day
  FROM public.swipes
  WHERE actor_id = v_actor_id
    AND created_at >= now() - INTERVAL '24 hours';

  IF v_recent_day >= 100 THEN
    RAISE EXCEPTION 'RATE_LIMIT_EXCEEDED: Daily swipe limit reached. Come back at the next Daily Loot Drop!'
      USING ERRCODE = 'raise_exception';
  END IF;

  IF v_action = 'super_duo' THEN
    SELECT COUNT(*) INTO v_super_day
    FROM public.swipes
    WHERE actor_id = v_actor_id
      AND action = 'super_duo'
      AND created_at >= now() - INTERVAL '24 hours';

    IF v_super_day >= 5 THEN
      RAISE EXCEPTION 'RATE_LIMIT_EXCEEDED: Daily Super Duo limit (5) reached.'
        USING ERRCODE = 'raise_exception';
    END IF;
  END IF;

  -- Record swipe idempotently
  INSERT INTO public.swipes (actor_id, target_id, action, intro_note)
  VALUES (v_actor_id, p_target_id, v_action, v_clean_note)
  ON CONFLICT (actor_id, target_id) DO NOTHING;

  -- Check for reciprocal positive swipe
  IF v_action IN ('like', 'super_duo') THEN
    v_user_a := LEAST(v_actor_id, p_target_id);
    v_user_b := GREATEST(v_actor_id, p_target_id);

    -- Serialize concurrent reciprocal swipes for the same canonical pair
    PERFORM pg_advisory_xact_lock(hashtext('match_pair:' || v_user_a::text || ':' || v_user_b::text));

    SELECT EXISTS (
      SELECT 1
      FROM public.swipes s
      WHERE s.actor_id = p_target_id
        AND s.target_id = v_actor_id
        AND s.action IN ('like', 'super_duo')
    ) INTO v_has_reciprocal;

    IF v_has_reciprocal THEN
      -- Find top shared game for contextual Co-op Icebreakers
      SELECT gc.title INTO v_top_shared_game
      FROM public.user_games ug1
      INNER JOIN public.user_games ug2
        ON ug2.user_id = p_target_id AND ug2.game_id = ug1.game_id
      INNER JOIN public.games_catalog gc
        ON gc.id = ug1.game_id
      WHERE ug1.user_id = v_actor_id
      ORDER BY (ug1.priority_order + ug2.priority_order) ASC
      LIMIT 1;

      v_schedule_score := public.compute_schedule_overlap_score(v_actor.schedule_mask, v_target.schedule_mask);

      v_dna_score := CASE
        WHEN v_actor.dna_embedding IS NOT NULL AND v_target.dna_embedding IS NOT NULL
          THEN GREATEST(0.0, LEAST(1.0, 1.0 - ((v_actor.dna_embedding <=> v_target.dna_embedding) / 2.0)))
        ELSE 0.65
      END;

      SELECT COALESCE(LEAST(1.0, COUNT(*)::double precision / 3.0), 0.0)
      INTO v_games_score
      FROM public.user_games ug1
      INNER JOIN public.user_games ug2
        ON ug2.user_id = p_target_id AND ug2.game_id = ug1.game_id
      WHERE ug1.user_id = v_actor_id;

      v_compat := LEAST(100, GREATEST(50, round(
        (0.40 * v_games_score + 0.30 * v_schedule_score + 0.30 * v_dna_score) * 100.0
      )))::smallint;

      IF v_top_shared_game IS NOT NULL THEN
        v_icebreakers := jsonb_build_array(
          jsonb_build_object(
            'type', 'direct_invite',
            'game', v_top_shared_game,
            'prompt', format('Voces dois jogam %s! Topam uma partida casual hoje no horario livre de voces?', v_top_shared_game)
          ),
          jsonb_build_object(
            'type', 'fun_choice',
            'game', v_top_shared_game,
            'prompt', format('No %s: estrategia 100%% coordenada na call ou caos criativo dando risada?', v_top_shared_game)
          ),
          jsonb_build_object(
            'type', 'mini_quiz',
            'game', v_top_shared_game,
            'prompt', format('Se voces pudessem banir um mapa, chefe ou personagem de %s para sempre, qual seria?', v_top_shared_game)
          )
        );
      ELSE
        v_icebreakers := jsonb_build_array(
          jsonb_build_object(
            'type', 'direct_invite',
            'game', NULL,
            'prompt', 'Qual jogo co-op voces apresentariam primeiro num "Co-op First Date" de 30 minutos?'
          ),
          jsonb_build_object(
            'type', 'fun_choice',
            'game', NULL,
            'prompt', 'Duo perfeito: tryhard focado em subir elo ou madrugada chill explorando um indie novo?'
          ),
          jsonb_build_object(
            'type', 'mini_quiz',
            'game', NULL,
            'prompt', 'Qual trilha sonora de jogo voce colocaria para tocar de fundo numa viagem de carro?'
          )
        );
      END IF;

      INSERT INTO public.matches (user_a, user_b, compatibility_score, icebreaker_prompts, is_active)
      VALUES (v_user_a, v_user_b, v_compat, v_icebreakers, true)
      ON CONFLICT (user_a, user_b) DO UPDATE
        SET is_active = true,
            compatibility_score = EXCLUDED.compatibility_score,
            icebreaker_prompts = CASE
              WHEN jsonb_array_length(public.matches.icebreaker_prompts) = 0
                THEN EXCLUDED.icebreaker_prompts
              ELSE public.matches.icebreaker_prompts
            END,
            updated_at = now()
      RETURNING id, compatibility_score, icebreaker_prompts
      INTO v_match_id, v_compat, v_icebreakers;

      RETURN jsonb_build_object(
        'matched', true,
        'match_id', v_match_id,
        'compatibility_score', v_compat,
        'icebreaker_prompts', v_icebreakers
      );
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'matched', false,
    'match_id', NULL,
    'compatibility_score', NULL,
    'icebreaker_prompts', '[]'::jsonb
  );
END;
$$;

REVOKE ALL ON FUNCTION public.record_swipe_and_match(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.record_swipe_and_match(uuid, text, text) TO authenticated;

-- -----------------------------------------------------------------------------
-- 9. LGPD RPC: export_my_data (Art. 18 — Data Portability)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.export_my_data()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid;
  v_result jsonb;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'UNAUTHORIZED: Authentication required.'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  SELECT jsonb_build_object(
    'exported_at', now(),
    'user_id', v_uid,
    'profile', (
      SELECT jsonb_build_object(
        'id', p.id,
        'username', p.username,
        'display_name', p.display_name,
        'birth_date', p.birth_date,
        'gender', p.gender,
        'interested_in', p.interested_in,
        'bio', p.bio,
        'gamer_dna', p.gamer_dna,
        'schedule_mask', p.schedule_mask,
        'city_label', p.city_label,
        'has_approx_location', (p.approx_location IS NOT NULL),
        'is_liveness_verified', p.is_liveness_verified,
        'is_active', p.is_active,
        'only_verified_filter', p.only_verified_filter,
        'women_or_receiver_first', p.women_or_receiver_first,
        'e2ee_public_key', p.e2ee_public_key,
        'discord_handle', p.discord_handle,
        'steam_id', p.steam_id,
        'last_active_at', p.last_active_at,
        'created_at', p.created_at,
        'updated_at', p.updated_at
      )
      FROM public.profiles p
      WHERE p.id = v_uid
    ),
    'profile_photos', COALESCE((
      SELECT jsonb_agg(to_jsonb(pp) ORDER BY pp.position ASC)
      FROM public.profile_photos pp
      WHERE pp.user_id = v_uid
    ), '[]'::jsonb),
    'user_games', COALESCE((
      SELECT jsonb_agg(
        jsonb_build_object(
          'game_id', ug.game_id,
          'title', gc.title,
          'platform', ug.platform,
          'rank_label', ug.rank_label,
          'is_rank_ocr_verified', ug.is_rank_ocr_verified,
          'verified_gamertag', ug.verified_gamertag,
          'hours_played', ug.hours_played,
          'priority_order', ug.priority_order
        ) ORDER BY ug.priority_order ASC
      )
      FROM public.user_games ug
      INNER JOIN public.games_catalog gc ON gc.id = ug.game_id
      WHERE ug.user_id = v_uid
    ), '[]'::jsonb),
    'badges_received', COALESCE((
      SELECT jsonb_agg(jsonb_build_object('badge_code', ub.badge_code, 'created_at', ub.created_at))
      FROM public.user_badges ub
      WHERE ub.recipient_id = v_uid
    ), '[]'::jsonb),
    'swipes_sent', COALESCE((
      SELECT jsonb_agg(to_jsonb(s) ORDER BY s.created_at DESC)
      FROM public.swipes s
      WHERE s.actor_id = v_uid
    ), '[]'::jsonb),
    'matches', COALESCE((
      SELECT jsonb_agg(to_jsonb(m) ORDER BY m.created_at DESC)
      FROM public.matches m
      WHERE v_uid IN (m.user_a, m.user_b)
    ), '[]'::jsonb),
    'messages_sent_e2ee', COALESCE((
      SELECT jsonb_agg(to_jsonb(msg) ORDER BY msg.created_at DESC)
      FROM public.messages msg
      WHERE msg.sender_id = v_uid
    ), '[]'::jsonb),
    'duo_lobbies', COALESCE((
      SELECT jsonb_agg(to_jsonb(dl) ORDER BY dl.created_at DESC)
      FROM public.duo_lobbies dl
      WHERE dl.host_id = v_uid
    ), '[]'::jsonb),
    'blocks_created', COALESCE((
      SELECT jsonb_agg(to_jsonb(bl) ORDER BY bl.created_at DESC)
      FROM public.blocks bl
      WHERE bl.blocker_id = v_uid
    ), '[]'::jsonb),
    'reports_filed', COALESCE((
      SELECT jsonb_agg(to_jsonb(rp) ORDER BY rp.created_at DESC)
      FROM public.reports rp
      WHERE rp.reporter_id = v_uid
    ), '[]'::jsonb),
    'has_encrypted_key_backup', EXISTS (
      SELECT 1 FROM public.user_key_backups kb WHERE kb.user_id = v_uid
    )
  ) INTO v_result;

  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.export_my_data() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.export_my_data() TO authenticated;

-- -----------------------------------------------------------------------------
-- 10. LGPD RPC: delete_my_account (Art. 18 — Right to be Forgotten)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.delete_my_account()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid;
  v_photo_paths jsonb;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'UNAUTHORIZED: Authentication required.'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  -- Capture avatar paths so client/edge worker can purge objects from Storage API
  SELECT COALESCE(jsonb_agg(pp.storage_path), '[]'::jsonb)
  INTO v_photo_paths
  FROM public.profile_photos pp
  WHERE pp.user_id = v_uid;

  -- Cascade-delete public profile & all linked rows (photos, games, badges, swipes,
  -- matches, messages, lobbies, blocks, reports, key backups)
  DELETE FROM public.profiles WHERE id = v_uid;

  -- Delete identity in auth.users to immediately revoke JWTs & refresh tokens
  DELETE FROM auth.users WHERE id = v_uid;

  RETURN jsonb_build_object(
    'deleted', true,
    'user_id', v_uid,
    'storage_paths_to_purge', v_photo_paths,
    'deleted_at', now()
  );
END;
$$;

REVOKE ALL ON FUNCTION public.delete_my_account() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.delete_my_account() TO authenticated;
