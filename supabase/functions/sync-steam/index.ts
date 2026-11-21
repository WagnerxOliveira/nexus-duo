// =============================================================================
// Edge Function: sync-steam
// Purpose: Zero-Trust Steam / OpenDota Library & Hours Sync
// Security:
//   - Requires valid Supabase Auth JWT (userClient.auth.getUser())
//   - Reads optional STEAM_API_KEY strictly via Deno.env.get()
//   - Zero-key fallback to OpenDota Public API when STEAM_API_KEY is unset
// =============================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import { buildCorsHeaders, jsonResponse } from "../_shared/cors.ts";

interface SteamOwnedGame {
  appid: number;
  name?: string;
  playtime_forever?: number;
}

function sanitizeSlug(raw: string): string {
  return (
    raw
      .toLowerCase()
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g, "")
      .replace(/[^a-z0-9]+/g, "-")
      .replace(/^-+|-+$/g, "")
      .slice(0, 120) || "steam-game"
  );
}

function toOpenDotaAccountId(steamId: string): string {
  if (/^\d{17}$/.test(steamId)) {
    const id64 = BigInt(steamId);
    const offset = BigInt("76561197960265728");
    if (id64 > offset) {
      return (id64 - offset).toString();
    }
  }
  return steamId;
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: buildCorsHeaders(req) });
  }

  if (req.method !== "POST") {
    return jsonResponse(req, { error: "Method not allowed" }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!supabaseUrl || !supabaseAnonKey || !supabaseServiceRoleKey) {
    return jsonResponse(req, { error: "Server configuration incomplete" }, 500);
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return jsonResponse(req, { error: "Missing bearer token" }, 401);
  }

  const userClient = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: authData, error: authError } = await userClient.auth.getUser();
  if (authError || !authData?.user) {
    return jsonResponse(req, { error: "Invalid or expired token" }, 401);
  }
  const userId = authData.user.id;

  let steamId = "";
  try {
    const body = await req.json();
    steamId = String(body?.steam_id ?? "").trim();
  } catch {
    return jsonResponse(req, { error: "Invalid JSON payload" }, 400);
  }

  if (!/^\d{5,20}$/.test(steamId)) {
    return jsonResponse(
      req,
      { error: "Provide a numeric SteamID64 or OpenDota account ID" },
      400,
    );
  }

  const steamApiKey = Deno.env.get("STEAM_API_KEY");
  const adminClient = createClient(supabaseUrl, supabaseServiceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  // 1. Primary: Steam Web API when STEAM_API_KEY is configured
  if (steamApiKey) {
    const steamUrl = new URL(
      "https://api.steampowered.com/IPlayerService/GetOwnedGames/v1/",
    );
    steamUrl.searchParams.set("key", steamApiKey);
    steamUrl.searchParams.set("steamid", steamId);
    steamUrl.searchParams.set("include_appinfo", "true");
    steamUrl.searchParams.set("include_played_free_games", "true");

    const steamRes = await fetch(steamUrl.toString());
    if (steamRes.ok) {
      const payload = await steamRes.json();
      const rawGames = (payload?.response?.games ?? []) as SteamOwnedGame[];
      const topGames = rawGames
        .filter((g) => Boolean(g.name) && (g.playtime_forever ?? 0) > 0)
        .sort((a, b) => (b.playtime_forever ?? 0) - (a.playtime_forever ?? 0))
        .slice(0, 5);

      if (topGames.length > 0) {
        const catalogBatch = topGames.map((g) => ({
          external_source: "steam",
          external_id: String(g.appid),
          title: String(g.name).slice(0, 160),
          slug: sanitizeSlug(String(g.name)),
          cover_url: `https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/${g.appid}/library_600x900.jpg`,
          genres: ["pc", "steam"],
          platforms: ["pc"],
          supports_crossplay: false,
        }));

        await adminClient
          .from("games_catalog")
          .upsert(catalogBatch, { onConflict: "slug", ignoreDuplicates: false });

        const { data: catalogRows } = await adminClient
          .from("games_catalog")
          .select("id, slug, title")
          .in("slug", catalogBatch.map((c) => c.slug));

        const idBySlug = new Map(
          (catalogRows ?? []).map((r) => [String(r.slug), Number(r.id)]),
        );

        const userGamesRows = topGames
          .map((g, index) => {
            const gameId = idBySlug.get(sanitizeSlug(String(g.name)));
            if (!gameId) return null;
            return {
              user_id: userId,
              game_id: gameId,
              platform: "pc",
              hours_played: Math.min(100000, Math.round((g.playtime_forever ?? 0) / 60)),
              priority_order: index + 1,
            };
          })
          .filter((row): row is NonNullable<typeof row> => row !== null);

        if (userGamesRows.length > 0) {
          await adminClient
            .from("user_games")
            .upsert(userGamesRows, { onConflict: "user_id,game_id" });
        }

        await adminClient
          .from("profiles")
          .update({ steam_id: steamId })
          .eq("id", userId);

        return jsonResponse(req, {
          source: "steam",
          synced_count: userGamesRows.length,
          games: topGames.map((g) => ({
            appid: g.appid,
            title: g.name,
            hours_played: Math.round((g.playtime_forever ?? 0) / 60),
          })),
        });
      }
    }
  }

  // 2. Zero-Key Fallback: OpenDota Public API for Dota 2 rank & profile
  try {
    const accountId = toOpenDotaAccountId(steamId);
    const dotaRes = await fetch(
      `https://api.opendota.com/api/players/${accountId}`,
    );
    if (dotaRes.ok) {
      const dotaData = await dotaRes.json();
      const persona = dotaData?.profile?.personaname;
      if (persona) {
        const rankTier = Number(dotaData?.rank_tier ?? 0);
        const rankLabel = rankTier > 0 ? `Rank Tier ${rankTier}` : "Unranked";
        const { data: dotaCatalog } = await adminClient
          .from("games_catalog")
          .select("id")
          .eq("slug", "dota-2")
          .maybeSingle();

        if (dotaCatalog?.id) {
          await adminClient.from("user_games").upsert(
            {
              user_id: userId,
              game_id: dotaCatalog.id,
              platform: "pc",
              rank_label: rankLabel,
              verified_gamertag: String(persona).slice(0, 64),
              priority_order: 1,
            },
            { onConflict: "user_id,game_id" },
          );
        }

        await adminClient
          .from("profiles")
          .update({ steam_id: steamId })
          .eq("id", userId);

        return jsonResponse(req, {
          source: "opendota",
          synced_count: dotaCatalog?.id ? 1 : 0,
          persona,
          rank_label: rankLabel,
        });
      }
    }
  } catch {
    // Graceful fallback response below
  }

  return jsonResponse(req, {
    source: steamApiKey ? "steam_private_or_empty" : "unconfigured",
    synced_count: 0,
    message: steamApiKey
      ? "Perfil Steam privado ou sem jogos públicos."
      : "STEAM_API_KEY opcional não cadastrada e OpenDota sem perfil público para este ID.",
  });
});
