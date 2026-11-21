-- =============================================================================
-- Migration 0001: Extensions & Domain Enum Types
-- Project: NEXUS DUO (Zero-Trust Gamer Dating & Duo Platform)
-- PostgreSQL 15+ / Supabase
-- =============================================================================

-- 1. Required Extensions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "postgis";
CREATE EXTENSION IF NOT EXISTS "vector";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- 2. Domain Enums (idempotent definitions)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'swipe_action' AND typnamespace = 'public'::regnamespace) THEN
    CREATE TYPE public.swipe_action AS ENUM ('like', 'pass', 'super_duo');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'lobby_mode' AND typnamespace = 'public'::regnamespace) THEN
    CREATE TYPE public.lobby_mode AS ENUM ('casual', 'ranked', 'coop', 'chill');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'voice_preference' AND typnamespace = 'public'::regnamespace) THEN
    CREATE TYPE public.voice_preference AS ENUM ('discord', 'in_game', 'text_only');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'message_type' AND typnamespace = 'public'::regnamespace) THEN
    CREATE TYPE public.message_type AS ENUM ('text', 'icebreaker', 'lobby_invite', 'image_blur');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'badge_code' AND typnamespace = 'public'::regnamespace) THEN
    CREATE TYPE public.badge_code AS ENUM (
      'good_comms',     -- Boa Comunicacao
      'zero_tilt',      -- Zero Tilt / Calmo(a)
      'squad_partner',  -- Parceiro(a) de Squad
      'great_vibe',     -- Papo Incrivel
      'respectful'      -- Respeitoso(a)
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'external_game_source' AND typnamespace = 'public'::regnamespace) THEN
    CREATE TYPE public.external_game_source AS ENUM ('igdb', 'rawg', 'steam', 'manual');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'report_reason' AND typnamespace = 'public'::regnamespace) THEN
    CREATE TYPE public.report_reason AS ENUM (
      'harassment',
      'hate_speech',
      'catfish_fake',
      'underage',
      'spam_scam',
      'inappropriate_content',
      'other'
    );
  END IF;
END
$$;
