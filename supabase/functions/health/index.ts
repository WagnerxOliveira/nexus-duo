// =============================================================================
// Edge Function: health
// Purpose: Lightweight readiness & Supabase DB keepalive check (Free Tier safe)
// Security: Read-only, controlled CORS, zero secrets returned
// =============================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import { buildCorsHeaders, jsonResponse } from "../_shared/cors.ts";

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

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");

  let dbStatus: "connected" | "degraded" | "unconfigured" = "unconfigured";

  if (supabaseUrl && supabaseAnonKey) {
    try {
      const supabase = createClient(supabaseUrl, supabaseAnonKey, {
        auth: { persistSession: false, autoRefreshToken: false },
      });

      const { error } = await supabase
        .from("games_catalog")
        .select("id", { count: "exact", head: true })
        .limit(1);

      dbStatus = error ? "degraded" : "connected";
    } catch {
      dbStatus = "degraded";
    }
  }

  const healthy = dbStatus === "connected";
  return jsonResponse(
    req,
    {
      status: healthy ? "ok" : "degraded",
      service: "nexus-duo-edge",
      database: dbStatus,
      timestamp: new Date().toISOString(),
    },
    healthy ? 200 : 503,
    { "Cache-Control": "no-store" },
  );
});
