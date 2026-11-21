-- =============================================================================
-- Migration 0005: Security & Performance Advisor Hardening
-- Project: NEXUS DUO (Zero-Trust Gamer Dating & Duo Platform)
-- Fixes:
--   1. Revoke PUBLIC/anon/authenticated EXECUTE on internal trigger functions
--      (specifically `deactivate_match_on_block()` flagged by lint 0028/0029).
--   2. Add covering B-tree indexes on 5 foreign keys flagged by lint 0001
--      (accelerates joins & LGPD ON DELETE CASCADE).
-- =============================================================================

-- 1. Lock down trigger functions so they are NEVER callable as PostgREST RPCs
REVOKE ALL ON FUNCTION public.deactivate_match_on_block() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.set_updated_at() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.enforce_max_profile_photos() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.protect_match_immutable_columns() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.protect_message_immutable_columns() FROM PUBLIC, anon, authenticated;

-- 2. Covering indexes for foreign keys (LGPD cascade & query performance)
CREATE INDEX IF NOT EXISTS idx_duo_lobbies_game_id
  ON public.duo_lobbies (game_id);

CREATE INDEX IF NOT EXISTS idx_duo_lobbies_host_id
  ON public.duo_lobbies (host_id);

CREATE INDEX IF NOT EXISTS idx_messages_sender_id
  ON public.messages (sender_id);

CREATE INDEX IF NOT EXISTS idx_reports_reporter_id
  ON public.reports (reporter_id);

CREATE INDEX IF NOT EXISTS idx_user_badges_match_id
  ON public.user_badges (match_id);
