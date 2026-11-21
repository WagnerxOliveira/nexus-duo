// =============================================================================
// Shared CORS & Security Headers for NEXUS DUO Supabase Edge Functions
// =============================================================================

const DEFAULT_ALLOWED_ORIGINS = [
  "http://localhost:3000",
  "http://127.0.0.1:3000",
  "https://nexusduo.app",
];

function getAllowedOrigins(): string[] {
  const raw = Deno.env.get("ALLOWED_ORIGINS");
  if (!raw || raw.trim().length === 0) {
    return DEFAULT_ALLOWED_ORIGINS;
  }
  return raw
    .split(",")
    .map((origin) => origin.trim())
    .filter((origin) => origin.length > 0);
}

export function buildCorsHeaders(req: Request): Record<string, string> {
  const requestOrigin = req.headers.get("Origin");
  const allowlist = getAllowedOrigins();
  const allowedOrigin =
    requestOrigin && allowlist.includes(requestOrigin)
      ? requestOrigin
      : allowlist[0];

  return {
    "Access-Control-Allow-Origin": allowedOrigin,
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
    "Vary": "Origin",
    "X-Content-Type-Options": "nosniff",
    "Referrer-Policy": "no-referrer",
  };
}

export function jsonResponse(
  req: Request,
  body: unknown,
  status = 200,
  extraHeaders: Record<string, string> = {},
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...buildCorsHeaders(req),
      "Content-Type": "application/json; charset=utf-8",
      ...extraHeaders,
    },
  });
}
