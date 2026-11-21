-- =============================================================================
-- Migration 0007: App Release Channels & Remote Update Control
-- Project: NEXUS DUO (Isolated exclusively on project hfuntccxwoijjkmitewb)
-- Zero-Trust Principles:
--   - Public read-only SELECT policy for `anon` and `authenticated` roles.
--   - Zero client write privileges (`INSERT`/`UPDATE`/`DELETE` strictly service-only).
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.app_release_channels (
  channel                    text PRIMARY KEY DEFAULT 'stable'
                               CONSTRAINT app_release_channels_channel_chk
                               CHECK (channel IN ('stable', 'beta')),
  latest_version_name        text NOT NULL
                               CONSTRAINT app_release_channels_ver_name_chk
                               CHECK (char_length(trim(latest_version_name)) BETWEEN 3 AND 32),
  latest_version_code        integer NOT NULL
                               CONSTRAINT app_release_channels_ver_code_chk
                               CHECK (latest_version_code >= 1),
  min_supported_version_code integer NOT NULL DEFAULT 1
                               CONSTRAINT app_release_channels_min_code_chk
                               CHECK (min_supported_version_code >= 1),
  force_update               boolean NOT NULL DEFAULT false,
  rollout_enabled            boolean NOT NULL DEFAULT true,
  manifest_url               text NOT NULL
                               CONSTRAINT app_release_channels_manifest_url_chk
                               CHECK (manifest_url ~ '^https://'),
  release_notes_pt_br        jsonb NOT NULL DEFAULT '[]'::jsonb
                               CONSTRAINT app_release_channels_notes_array_chk
                               CHECK (jsonb_typeof(release_notes_pt_br) = 'array'),
  updated_at                 timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.app_release_channels ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.app_release_channels FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.app_release_channels TO anon, authenticated;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'app_release_channels'
      AND policyname = 'app_release_channels_public_read'
  ) THEN
    CREATE POLICY app_release_channels_public_read
      ON public.app_release_channels
      FOR SELECT
      TO anon, authenticated
      USING (true);
  END IF;
END $$;

INSERT INTO public.app_release_channels (
  channel,
  latest_version_name,
  latest_version_code,
  min_supported_version_code,
  force_update,
  rollout_enabled,
  manifest_url,
  release_notes_pt_br
)
VALUES (
  'stable',
  '1.1.0',
  3,
  1,
  false,
  true,
  'https://github.com/WagnerxOliveira/nexus-duo/releases/latest/download/update-manifest.json',
  '["Melhorias de estabilidade, autenticação OTP via Resend e privacidade Zero-Trust."]'::jsonb
)
ON CONFLICT (channel) DO NOTHING;
