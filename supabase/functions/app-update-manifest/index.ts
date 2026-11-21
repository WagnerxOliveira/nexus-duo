// =============================================================================
// Edge Function: app-update-manifest
// Purpose: Cached CDN proxy + remote rollout/force-update control for NEXUS DUO
// Security: Read-only, strict HTTPS host allowlist, zero secrets returned
// =============================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import { buildCorsHeaders, jsonResponse } from "../_shared/cors.ts";

const DEFAULT_REPO = "WagnerxOliveira/nexus-duo";
const DEFAULT_MANIFEST_URL =
  `https://github.com/${DEFAULT_REPO}/releases/latest/download/update-manifest.json`;
const ALLOWED_MANIFEST_HOSTS = new Set([
  "github.com",
  "objects.githubusercontent.com",
  "release-assets.githubusercontent.com",
]);

const CACHE_CONTROL_VALUE = "public, max-age=120, stale-while-revalidate=600";

interface ReleaseChannelRow {
  channel: string;
  latest_version_name: string;
  latest_version_code: number;
  min_supported_version_code: number;
  force_update: boolean;
  rollout_enabled: boolean;
  manifest_url: string;
  release_notes_pt_br: unknown;
  updated_at: string;
}

function isAllowedManifestUrl(rawUrl: string): boolean {
  try {
    const parsed = new URL(rawUrl);
    return (
      parsed.protocol === "https:" &&
      ALLOWED_MANIFEST_HOSTS.has(parsed.hostname.toLowerCase())
    );
  } catch {
    return false;
  }
}

async function fetchWithTimeout(
  url: string,
  init: RequestInit = {},
  timeoutMs = 8000,
): Promise<Response> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetch(url, { ...init, signal: controller.signal });
  } finally {
    clearTimeout(timer);
  }
}

function detectAbiKey(fileName: string): string | null {
  const lower = fileName.toLowerCase();
  if (!lower.endsWith(".apk")) return null;
  if (lower.includes("arm64-v8a") || lower.includes("arm64")) return "arm64-v8a";
  if (lower.includes("armeabi-v7a") || lower.includes("armeabi")) {
    return "armeabi-v7a";
  }
  if (lower.includes("x86_64")) return "x86_64";
  if (lower.includes("universal") || lower.includes("app-release")) {
    return "universal";
  }
  return "universal";
}

function parseSha256Sums(content: string): Map<string, string> {
  const map = new Map<string, string>();
  for (const line of content.split(/\r?\n/)) {
    const match = line.trim().match(/^([a-fA-F0-9]{64})\s+[*]?(.+)$/);
    if (match) {
      map.set(match[2].trim().toLowerCase(), match[1].toLowerCase());
    }
  }
  return map;
}

async function buildLegacyFallbackManifest(
  channelRow: ReleaseChannelRow | null,
  channel: string,
): Promise<Record<string, unknown>> {
  try {
    const apiRes = await fetchWithTimeout(
      `https://api.github.com/repos/${DEFAULT_REPO}/releases/latest`,
      {
        headers: {
          "Accept": "application/vnd.github+json",
          "User-Agent": "nexus-duo-edge-updater/1.0",
        },
      },
      6000,
    );
    if (apiRes.ok) {
      const rel = await apiRes.json() as Record<string, unknown>;
      const tagName = String(rel.tag_name ?? `v${channelRow?.latest_version_name ?? "1.1.0"}`);
      const versionName = tagName.replace(/^v/i, "");
      const assets = Array.isArray(rel.assets)
        ? (rel.assets as Record<string, unknown>[])
        : [];
      const sumsAsset = assets.find((a) =>
        String(a.name ?? "").toLowerCase().includes("sha256")
      );
      let shaMap = new Map<string, string>();
      if (sumsAsset && typeof sumsAsset.browser_download_url === "string") {
        const sumsRes = await fetchWithTimeout(
          sumsAsset.browser_download_url,
          {},
          5000,
        );
        if (sumsRes.ok) {
          shaMap = parseSha256Sums(await sumsRes.text());
        }
      }

      const apks: Record<string, Record<string, unknown>> = {};
      for (const asset of assets) {
        const fileName = String(asset.name ?? "");
        const abiKey = detectAbiKey(fileName);
        if (!abiKey) continue;
        const sha = shaMap.get(fileName.toLowerCase());
        const downloadUrl = String(asset.browser_download_url ?? "");
        const sizeBytes = Number(asset.size ?? 0);
        if (sha && isAllowedManifestUrl(downloadUrl) && sizeBytes > 0) {
          apks[abiKey] = {
            file_name: fileName,
            url: downloadUrl,
            sha256: sha,
            size_bytes: sizeBytes,
          };
        }
      }

      const rowVersionMatches = channelRow?.latest_version_name === versionName;
      return {
        schema_version: 2,
        app_id: "com.nexusduo.app",
        channel,
        version_name: versionName,
        version_code: rowVersionMatches
          ? channelRow!.latest_version_code
          : (channelRow?.latest_version_code ?? 3),
        min_supported_version_code: channelRow?.min_supported_version_code ?? 1,
        force_update: channelRow?.force_update ?? false,
        rollout_enabled: channelRow?.rollout_enabled ?? true,
        published_at: String(rel.published_at ?? channelRow?.updated_at ?? new Date().toISOString()),
        signing_cert_sha256: "",
        release_url: String(rel.html_url ?? `https://github.com/${DEFAULT_REPO}/releases/tag/${tagName}`),
        release_notes_pt_br: Array.isArray(channelRow?.release_notes_pt_br) &&
            (channelRow!.release_notes_pt_br as unknown[]).length > 0
          ? channelRow!.release_notes_pt_br
          : ["Melhorias de estabilidade, segurança Zero-Trust e desempenho no NEXUS DUO."],
        apks,
      };
    }
  } catch {
    // Fall through to DB-backed baseline response below.
  }

  const fallbackVersion = channelRow?.latest_version_name ?? "1.1.0";
  return {
    schema_version: 2,
    app_id: "com.nexusduo.app",
    channel,
    version_name: fallbackVersion,
    version_code: channelRow?.latest_version_code ?? 3,
    min_supported_version_code: channelRow?.min_supported_version_code ?? 1,
    force_update: channelRow?.force_update ?? false,
    rollout_enabled: channelRow?.rollout_enabled ?? true,
    published_at: channelRow?.updated_at ?? new Date().toISOString(),
    signing_cert_sha256: "",
    release_url: `https://github.com/${DEFAULT_REPO}/releases/tag/v${fallbackVersion}`,
    release_notes_pt_br: Array.isArray(channelRow?.release_notes_pt_br) &&
        (channelRow!.release_notes_pt_br as unknown[]).length > 0
      ? channelRow!.release_notes_pt_br
      : ["Versão mais recente monitorada via canal oficial NEXUS DUO."],
    apks: {},
  };
}

async function computeWeakEtag(payloadText: string): Promise<string> {
  const bytes = new TextEncoder().encode(payloadText);
  const hashBuffer = await crypto.subtle.digest("SHA-256", bytes);
  const hex = Array.from(new Uint8Array(hashBuffer))
    .slice(0, 8)
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
  return `W/"${hex}"`;
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: buildCorsHeaders(req),
    });
  }

  if (req.method !== "GET" && req.method !== "HEAD") {
    return jsonResponse(req, { error: "Method not allowed" }, 405);
  }

  const reqUrl = new URL(req.url);
  const rawChannel = reqUrl.searchParams.get("channel")?.trim().toLowerCase();
  const channel = rawChannel === "beta" ? "beta" : "stable";

  let channelRow: ReleaseChannelRow | null = null;
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");

  if (supabaseUrl && supabaseAnonKey) {
    try {
      const supabase = createClient(supabaseUrl, supabaseAnonKey, {
        auth: { persistSession: false, autoRefreshToken: false },
      });
      const { data } = await supabase
        .from("app_release_channels")
        .select(
          "channel, latest_version_name, latest_version_code, min_supported_version_code, force_update, rollout_enabled, manifest_url, release_notes_pt_br, updated_at",
        )
        .eq("channel", channel)
        .maybeSingle();
      if (data) {
        channelRow = data as ReleaseChannelRow;
      }
    } catch {
      channelRow = null;
    }
  }

  const targetManifestUrl =
    channelRow?.manifest_url && isAllowedManifestUrl(channelRow.manifest_url)
      ? channelRow.manifest_url
      : DEFAULT_MANIFEST_URL;

  let baseManifest: Record<string, unknown> | null = null;
  try {
    const upstream = await fetchWithTimeout(
      targetManifestUrl,
      {
        headers: {
          "Accept": "application/json",
          "User-Agent": "nexus-duo-edge-updater/1.0",
        },
      },
      8000,
    );
    if (upstream.ok) {
      const parsed = await upstream.json();
      if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) {
        baseManifest = parsed as Record<string, unknown>;
      }
    }
  } catch {
    baseManifest = null;
  }

  if (!baseManifest) {
    baseManifest = await buildLegacyFallbackManifest(channelRow, channel);
  }

  const manifestMinCode = Number(baseManifest.min_supported_version_code ?? 1);
  const channelMinCode = Number(channelRow?.min_supported_version_code ?? 1);
  const mergedNotes = Array.isArray(baseManifest.release_notes_pt_br) &&
      (baseManifest.release_notes_pt_br as unknown[]).length > 0
    ? baseManifest.release_notes_pt_br
    : Array.isArray(channelRow?.release_notes_pt_br) &&
        (channelRow!.release_notes_pt_br as unknown[]).length > 0
    ? channelRow!.release_notes_pt_br
    : ["Melhorias de estabilidade, segurança Zero-Trust e desempenho no NEXUS DUO."];

  const mergedPayload: Record<string, unknown> = {
    ...baseManifest,
    schema_version: 2,
    app_id: "com.nexusduo.app",
    channel,
    min_supported_version_code: Math.max(
      Number.isFinite(manifestMinCode) ? manifestMinCode : 1,
      Number.isFinite(channelMinCode) ? channelMinCode : 1,
    ),
    force_update: Boolean(baseManifest.force_update) ||
      Boolean(channelRow?.force_update),
    rollout_enabled: channelRow !== null
      ? channelRow.rollout_enabled
      : (baseManifest.rollout_enabled ?? true),
    release_notes_pt_br: mergedNotes,
  };

  const serialized = JSON.stringify(mergedPayload);
  const etag = await computeWeakEtag(serialized);
  const extraHeaders = {
    "Cache-Control": CACHE_CONTROL_VALUE,
    "ETag": etag,
  };

  const ifNoneMatch = req.headers.get("if-none-match");
  if (ifNoneMatch && ifNoneMatch.trim() === etag) {
    return new Response(null, {
      status: 304,
      headers: {
        ...buildCorsHeaders(req),
        ...extraHeaders,
      },
    });
  }

  if (req.method === "HEAD") {
    return new Response(null, {
      status: 200,
      headers: {
        ...buildCorsHeaders(req),
        "Content-Type": "application/json; charset=utf-8",
        ...extraHeaders,
      },
    });
  }

  return jsonResponse(req, mergedPayload, 200, extraHeaders);
});
