// =============================================================================
// Edge Function: delete-account
// Purpose: LGPD Art. 18 — Right to be Forgotten (Zero-Trust Account Deletion)
// Security:
//   - Validates caller JWT via userClient.auth.getUser()
//   - Purges user's Storage objects in private bucket `avatars`
//   - Calls auth.admin.deleteUser(uid) to revoke sessions/tokens and cascade
//     deletion to `public.profiles` and all 10 dependent tables.
// =============================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import { buildCorsHeaders, jsonResponse } from "../_shared/cors.ts";

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: buildCorsHeaders(req) });
  }

  if (req.method !== "POST" && req.method !== "DELETE") {
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
  const adminClient = createClient(supabaseUrl, supabaseServiceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  // 1. Purge avatar objects from Storage before deleting profile/auth user
  const { data: photos } = await adminClient
    .from("profile_photos")
    .select("storage_path")
    .eq("user_id", userId);

  const paths = (photos ?? [])
    .map((p) => String(p.storage_path ?? "").trim())
    .filter((p) => p.length > 0 && p.startsWith(`${userId}/`));

  let purgedCount = 0;
  if (paths.length > 0) {
    const { error: storageError } = await adminClient.storage
      .from("avatars")
      .remove(paths);
    if (!storageError) {
      purgedCount = paths.length;
    }
  }

  // 2. Delete auth user via Supabase Admin API (revokes tokens + cascades DB)
  const { error: deleteError } = await adminClient.auth.admin.deleteUser(userId);
  if (deleteError) {
    return jsonResponse(
      req,
      { error: "Failed to delete user identity" },
      500,
    );
  }

  return jsonResponse(
    req,
    {
      deleted: true,
      user_id: userId,
      purged_storage_objects: purgedCount,
      deleted_at: new Date().toISOString(),
    },
    200,
    { "Cache-Control": "no-store" },
  );
});
