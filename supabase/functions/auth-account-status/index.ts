// =============================================================================
// Edge Function: auth-account-status
// Checks whether an email already belongs to a NEXUS DUO account (`not_found`,
// `unverified`, or `active`) with persistent IP rate-limiting & timing jitter.
// =============================================================================

import { buildCorsHeaders, jsonResponse } from "../_shared/cors.ts";
import {
  enforceRateLimit,
  extractClientIpHash,
  getAdminClient,
  getOtpPepper,
  isValidEmailSyntax,
  normalizeEmail,
} from "../_shared/otp_crypto.ts";

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: buildCorsHeaders(req) });
  }
  if (req.method !== "POST") {
    return jsonResponse(req, { code: "METHOD_NOT_ALLOWED", message: "Use POST." }, 405);
  }

  let body: { email?: unknown };
  try {
    body = await req.json();
  } catch {
    return jsonResponse(req, { code: "INVALID_JSON", message: "JSON inválido." }, 400);
  }

  const email = normalizeEmail(String(body.email ?? ""));
  if (!isValidEmailSyntax(email)) {
    return jsonResponse(
      req,
      { code: "INVALID_EMAIL", message: "Informe um e-mail válido." },
      400,
    );
  }

  const startedAt = Date.now();
  const adminClient = getAdminClient();
  const pepper = getOtpPepper();
  const ipHash = await extractClientIpHash(req, pepper);

  const rate = await enforceRateLimit(
    adminClient,
    `acct_status:${ipHash}`,
    25,
    900,
  );
  if (!rate.allowed) {
    return jsonResponse(
      req,
      {
        code: "RATE_LIMITED",
        message: "Muitas tentativas. Aguarde alguns instantes antes de tentar novamente.",
        retry_after_seconds: rate.retryAfterSeconds,
      },
      429,
    );
  }

  const { data, error } = await adminClient.rpc("lookup_auth_user_by_email", {
    p_email: email,
  });

  if (error) {
    console.error("lookup_auth_user_by_email error:", error.message);
    return jsonResponse(
      req,
      { code: "LOOKUP_FAILED", message: "Falha ao consultar status da conta." },
      500,
    );
  }

  const row = Array.isArray(data) ? data[0] : data;
  const elapsed = Date.now() - startedAt;
  if (elapsed < 120) {
    await new Promise((resolve) => setTimeout(resolve, 120 - elapsed));
  }

  if (!row) {
    return jsonResponse(req, { status: "not_found" }, 200);
  }

  const confirmedAt = row.email_confirmed_at as string | null | undefined;
  return jsonResponse(
    req,
    { status: confirmedAt ? "active" : "unverified" },
    200,
  );
});
