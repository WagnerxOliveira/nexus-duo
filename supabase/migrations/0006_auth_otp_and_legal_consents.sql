-- =============================================================================
-- Migration 0006: Transactional Email OTPs, Rate Limits & Legal Consents (LGPD)
-- Project: NEXUS DUO (Isolated exclusively on project hfuntccxwoijjkmitewb)
-- Zero-Trust Principles:
--   - `auth_email_otps` & `auth_rate_events` are inaccessible to `anon` /
--     `authenticated` roles (RLS enabled + REVOKE ALL + zero client policies).
--   - Only HMAC/SHA-256 digests are persisted (zero plaintext OTP or raw IP).
--   - `legal_consents` is append-only audit evidence (`SELECT`/`INSERT` own row).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. TRANSACTIONAL EMAIL OTPs (Signup Verification & Password Reset)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.auth_email_otps (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email_hash       text NOT NULL,
  user_id          uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  purpose          text NOT NULL
                     CONSTRAINT auth_email_otps_purpose_chk
                     CHECK (purpose IN ('signup_verify', 'password_reset')),
  code_hash        text NOT NULL,
  reset_token_hash text,
  attempts         smallint NOT NULL DEFAULT 0
                     CONSTRAINT auth_email_otps_attempts_chk
                     CHECK (attempts >= 0),
  max_attempts     smallint NOT NULL DEFAULT 5
                     CONSTRAINT auth_email_otps_max_attempts_chk
                     CHECK (max_attempts BETWEEN 1 AND 10),
  expires_at       timestamptz NOT NULL,
  consumed_at      timestamptz,
  ip_hash          text,
  metadata         jsonb NOT NULL DEFAULT '{}'::jsonb
                     CONSTRAINT auth_email_otps_metadata_obj_chk
                     CHECK (jsonb_typeof(metadata) = 'object'),
  created_at       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_auth_email_otps_lookup
  ON public.auth_email_otps (email_hash, purpose, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_auth_email_otps_active
  ON public.auth_email_otps (email_hash, purpose)
  WHERE consumed_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_auth_email_otps_ip_rate
  ON public.auth_email_otps (ip_hash, created_at DESC)
  WHERE ip_hash IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_auth_email_otps_reset_token
  ON public.auth_email_otps (reset_token_hash)
  WHERE reset_token_hash IS NOT NULL;

ALTER TABLE public.auth_email_otps ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.auth_email_otps FROM PUBLIC, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 2. AUTHENTICATION RATE-LIMIT BUCKETS (Distributed Edge Protection)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.auth_rate_events (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bucket_key text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_auth_rate_events_bucket_time
  ON public.auth_rate_events (bucket_key, created_at DESC);

ALTER TABLE public.auth_rate_events ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.auth_rate_events FROM PUBLIC, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 3. APPEND-ONLY LEGAL CONSENTS (LGPD / Marco Civil / ECA 18+ Audit Trail)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.legal_consents (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id               uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  terms_version         text NOT NULL
                          CONSTRAINT legal_consents_terms_ver_chk
                          CHECK (char_length(trim(terms_version)) BETWEEN 2 AND 32),
  privacy_version       text NOT NULL
                          CONSTRAINT legal_consents_privacy_ver_chk
                          CHECK (char_length(trim(privacy_version)) BETWEEN 2 AND 32),
  age_confirmed_18_plus boolean NOT NULL
                          CONSTRAINT legal_consents_age_18_chk
                          CHECK (age_confirmed_18_plus = true),
  app_version           text NOT NULL DEFAULT '1.1.0'
                          CONSTRAINT legal_consents_app_ver_chk
                          CHECK (char_length(trim(app_version)) BETWEEN 1 AND 32),
  ip_hash               text,
  user_agent            text,
  accepted_at           timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_legal_consents_user_accepted
  ON public.legal_consents (user_id, accepted_at DESC);

ALTER TABLE public.legal_consents ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'legal_consents'
      AND policyname = 'legal_consents_select_own'
  ) THEN
    CREATE POLICY legal_consents_select_own
      ON public.legal_consents
      FOR SELECT
      TO authenticated
      USING ((SELECT auth.uid()) = user_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'legal_consents'
      AND policyname = 'legal_consents_insert_own'
  ) THEN
    CREATE POLICY legal_consents_insert_own
      ON public.legal_consents
      FOR INSERT
      TO authenticated
      WITH CHECK ((SELECT auth.uid()) = user_id);
  END IF;
END $$;

-- -----------------------------------------------------------------------------
-- 4. SERVICE-ROLE-ONLY AUTH LOOKUP HELPER
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.lookup_auth_user_by_email(p_email text)
RETURNS TABLE(id uuid, email text, email_confirmed_at timestamptz)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
  SELECT u.id, u.email::text, u.email_confirmed_at
  FROM auth.users AS u
  WHERE lower(u.email) = lower(trim(p_email))
    AND u.deleted_at IS NULL
  LIMIT 1;
$$;

REVOKE ALL ON FUNCTION public.lookup_auth_user_by_email(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.lookup_auth_user_by_email(text) TO service_role;
