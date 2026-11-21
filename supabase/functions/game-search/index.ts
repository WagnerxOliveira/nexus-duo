// =============================================================================
// Edge Function: game-search
// Purpose: Zero-cost cached game autocomplete (Postgres -> IGDB -> RAWG fallback)
// Security:
//   - Requires valid Supabase Auth JWT (Zero-Trust, protects external quotas)
//   - Controlled CORS via ALLOWED_ORIGINS allowlist
//   - All API keys & service_role read strictly via Deno.env.get()
// =============================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import { buildCorsHeaders, jsonResponse } from "../_shared/cors.ts";

interface CatalogGame {
  id?: number;
  external_source: "igdb" | "rawg" | "steam" | "manual";
  external_id: string;
  title: string;
  slug: string;
  cover_url: string;
  genres: string[];
  platforms: string[];
  supports_crossplay: boolean;
}

interface IgdbGameRaw {
  id: number;
  name?: string;
  slug?: string;
  cover?: { image_id?: string };
  genres?: Array<{ name?: string }>;
  platforms?: Array<{ abbreviation?: string; name?: string }>;
}

interface RawgGameRaw {
  id: number;
  name?: string;
  slug?: string;
  background_image?: string;
  genres?: Array<{ slug?: string; name?: string }>;
  platforms?: Array<{ platform?: { slug?: string } }>;
}

const CACHE_SUFFICIENT_THRESHOLD = 5;
let cachedTwitchToken: { token: string; expiresAt: number } | null = null;

function sanitizeSlug(raw: string): string {
  return raw
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 120) || "game";
}

function sanitizeSearchQuery(raw: string): string {
  return raw
    .trim()
    .replace(/["\\\r\n\t;]/g, " ")
    .replace(/\s+/g, " ")
    .slice(0, 80);
}

function normalizePlatform(label: string): string | null {
  const lower = label.toLowerCase();
  if (lower.includes("pc") || lower.includes("windows") || lower.includes("linux") || lower.includes("mac")) {
    return "pc";
  }
  if (lower.includes("ps5") || lower.includes("playstation 5")) return "ps5";
  if (lower.includes("ps4") || lower.includes("playstation 4")) return "ps4";
  if (lower.includes("xbox")) return "xbox";
  if (lower.includes("switch") || lower.includes("nintendo")) return "switch";
  if (lower.includes("ios") || lower.includes("android") || lower.includes("mobile")) return "mobile";
  return null;
}

async function getTwitchAccessToken(
  clientId: string,
  clientSecret: string,
): Promise<string | null> {
  const now = Date.now();
  if (cachedTwitchToken && cachedTwitchToken.expiresAt > now + 60_000) {
    return cachedTwitchToken.token;
  }

  const tokenUrl = new URL("https://id.twitch.tv/oauth2/token");
  tokenUrl.searchParams.set("client_id", clientId);
  tokenUrl.searchParams.set("client_secret", clientSecret);
  tokenUrl.searchParams.set("grant_type", "client_credentials");

  const res = await fetch(tokenUrl.toString(), { method: "POST" });
  if (!res.ok) return null;

  const data = await res.json();
  if (!data?.access_token) return null;

  cachedTwitchToken = {
    token: String(data.access_token),
    expiresAt: now + Number(data.expires_in ?? 3600) * 1000,
  };
  return cachedTwitchToken.token;
}

async function fetchFromIgdb(query: string, limit: number): Promise<CatalogGame[]> {
  const clientId = Deno.env.get("TWITCH_CLIENT_ID");
  const clientSecret = Deno.env.get("TWITCH_CLIENT_SECRET");
  if (!clientId || !clientSecret) return [];

  const accessToken = await getTwitchAccessToken(clientId, clientSecret);
  if (!accessToken) return [];

  const body =
    `search "${query}"; ` +
    `fields id,name,slug,cover.image_id,genres.name,platforms.abbreviation,platforms.name; ` +
    `where cover != null; ` +
    `limit ${limit};`;

  const res = await fetch("https://api.igdb.com/v4/games", {
    method: "POST",
    headers: {
      "Client-ID": clientId,
      "Authorization": `Bearer ${accessToken}`,
      "Content-Type": "text/plain",
    },
    body,
  });

  if (!res.ok) return [];
  const items = (await res.json()) as IgdbGameRaw[];
  if (!Array.isArray(items)) return [];

  const games: CatalogGame[] = [];
  for (const item of items) {
    const title = item.name?.trim();
    const imageId = item.cover?.image_id?.trim();
    if (!title || !imageId) continue;

    const platforms = Array.from(
      new Set(
        (item.platforms ?? [])
          .map((p) => normalizePlatform(p.abbreviation ?? p.name ?? ""))
          .filter((p): p is string => p !== null),
      ),
    );

    const genres = Array.from(
      new Set(
        (item.genres ?? [])
          .map((g) => sanitizeSlug(g.name ?? ""))
          .filter((g) => g.length > 0),
      ),
    );

    games.push({
      external_source: "igdb",
      external_id: String(item.id),
      title: title.slice(0, 160),
      slug: sanitizeSlug(item.slug ?? title),
      cover_url: `https://images.igdb.com/igdb/image/upload/t_cover_big/${imageId}.jpg`,
      genres,
      platforms: platforms.length > 0 ? platforms : ["pc"],
      supports_crossplay: false,
    });
  }
  return games;
}

async function fetchFromRawg(query: string, limit: number): Promise<CatalogGame[]> {
  const apiKey = Deno.env.get("RAWG_API_KEY");
  if (!apiKey) return [];

  const url = new URL("https://api.rawg.io/api/games");
  url.searchParams.set("key", apiKey);
  url.searchParams.set("search", query);
  url.searchParams.set("page_size", String(limit));

  const res = await fetch(url.toString(), { method: "GET" });
  if (!res.ok) return [];

  const payload = await res.json();
  const items = (payload?.results ?? []) as RawgGameRaw[];
  if (!Array.isArray(items)) return [];

  const games: CatalogGame[] = [];
  for (const item of items) {
    const title = item.name?.trim();
    const cover = item.background_image?.trim();
    if (!title || !cover || !cover.startsWith("https://")) continue;

    const platforms = Array.from(
      new Set(
        (item.platforms ?? [])
          .map((p) => normalizePlatform(p.platform?.slug ?? ""))
          .filter((p): p is string => p !== null),
      ),
    );

    const genres = Array.from(
      new Set(
        (item.genres ?? [])
          .map((g) => sanitizeSlug(g.slug ?? g.name ?? ""))
          .filter((g) => g.length > 0),
      ),
    );

    games.push({
      external_source: "rawg",
      external_id: String(item.id),
      title: title.slice(0, 160),
      slug: sanitizeSlug(item.slug ?? title),
      cover_url: cover,
      genres,
      platforms: platforms.length > 0 ? platforms : ["pc"],
      supports_crossplay: false,
    });
  }
  return games;
}

interface SteamStoreSearchItem {
  id: number;
  name?: string;
}

async function fetchFromSteamStore(query: string, limit: number): Promise<CatalogGame[]> {
  const url = new URL("https://store.steampowered.com/api/storesearch/");
  url.searchParams.set("term", query);
  url.searchParams.set("l", "brazilian");
  url.searchParams.set("cc", "BR");

  const res = await fetch(url.toString(), { method: "GET" });
  if (!res.ok) return [];

  const payload = await res.json();
  const items = (payload?.items ?? []) as SteamStoreSearchItem[];
  if (!Array.isArray(items)) return [];

  const games: CatalogGame[] = [];
  for (const item of items.slice(0, limit)) {
    const title = item.name?.trim();
    if (!title || !Number.isFinite(item.id)) continue;

    games.push({
      external_source: "steam",
      external_id: String(item.id),
      title: title.slice(0, 160),
      slug: sanitizeSlug(title),
      cover_url: `https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/${item.id}/library_600x900.jpg`,
      genres: ["pc", "steam"],
      platforms: ["pc", "steam_deck"],
      supports_crossplay: false,
    });
  }
  return games;
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: buildCorsHeaders(req) });
  }

  if (req.method !== "GET" && req.method !== "POST") {
    return jsonResponse(req, { error: "Method not allowed" }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!supabaseUrl || !supabaseAnonKey) {
    return jsonResponse(req, { error: "Server configuration incomplete" }, 500);
  }

  // Zero-Trust JWT validation
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

  // Parse query & limit from GET querystring or POST JSON body
  let rawQuery = "";
  let rawLimit = 10;

  if (req.method === "GET") {
    const url = new URL(req.url);
    rawQuery = url.searchParams.get("q") ?? "";
    rawLimit = Number(url.searchParams.get("limit") ?? "10");
  } else {
    try {
      const body = await req.json();
      rawQuery = String(body?.q ?? "");
      rawLimit = Number(body?.limit ?? 10);
    } catch {
      return jsonResponse(req, { error: "Invalid JSON payload" }, 400);
    }
  }

  const query = sanitizeSearchQuery(rawQuery);
  const limit = Math.min(20, Math.max(1, Number.isFinite(rawLimit) ? Math.floor(rawLimit) : 10));

  if (query.length < 2) {
    return jsonResponse(req, { error: "Query must be at least 2 characters" }, 400);
  }

  // Stage 1: PostgreSQL games_catalog trigram/ILIKE cache lookup
  const { data: cachedRows, error: cacheError } = await userClient
    .from("games_catalog")
    .select("id, external_source, external_id, title, slug, cover_url, genres, platforms, supports_crossplay")
    .ilike("title", `%${query}%`)
    .order("title", { ascending: true })
    .limit(limit);

  if (cacheError) {
    return jsonResponse(req, { error: "Failed to query game catalog" }, 500);
  }

  const cachedGames = (cachedRows ?? []) as CatalogGame[];
  if (cachedGames.length >= CACHE_SUFFICIENT_THRESHOLD) {
    return jsonResponse(
      req,
      { query, source: "cache", results: cachedGames },
      200,
      { "Cache-Control": "private, max-age=300" },
    );
  }

  // Stage 2: External fallback (IGDB primary -> RAWG secondary -> Steam Store zero-key)
  let source: "cache" | "igdb" | "rawg" | "steam_public" = "cache";
  let externalGames: CatalogGame[] = [];

  try {
    externalGames = await fetchFromIgdb(query, limit);
    if (externalGames.length > 0) {
      source = "igdb";
    } else {
      externalGames = await fetchFromRawg(query, limit);
      if (externalGames.length > 0) {
        source = "rawg";
      } else {
        externalGames = await fetchFromSteamStore(query, limit);
        if (externalGames.length > 0) {
          source = "steam_public";
        }
      }
    }
  } catch {
    // Graceful degradation: serve whatever was found in local Postgres cache
    externalGames = [];
  }

  // Persist newly fetched games into Postgres cache using server-side service_role key
  if (externalGames.length > 0 && supabaseServiceRoleKey) {
    const adminClient = createClient(supabaseUrl, supabaseServiceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    await adminClient
      .from("games_catalog")
      .upsert(externalGames, { onConflict: "slug", ignoreDuplicates: false });

    const { data: refreshedRows } = await userClient
      .from("games_catalog")
      .select("id, external_source, external_id, title, slug, cover_url, genres, platforms, supports_crossplay")
      .ilike("title", `%${query}%`)
      .order("title", { ascending: true })
      .limit(limit);

    if (refreshedRows && refreshedRows.length > 0) {
      return jsonResponse(
        req,
        { query, source, results: refreshedRows },
        200,
        { "Cache-Control": "private, max-age=300" },
      );
    }
  }

  // Merge deduplicated fallback results if cache write was unavailable
  const mergedBySlug = new Map<string, CatalogGame>();
  for (const g of [...cachedGames, ...externalGames]) {
    if (!mergedBySlug.has(g.slug)) {
      mergedBySlug.set(g.slug, g);
    }
  }

  return jsonResponse(
    req,
    {
      query,
      source,
      results: Array.from(mergedBySlug.values()).slice(0, limit),
    },
    200,
    { "Cache-Control": "private, max-age=120" },
  );
});
