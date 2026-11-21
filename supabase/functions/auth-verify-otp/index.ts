// =============================================================================
// Edge Function: auth-verify-otp
// Verifies a 6-digit OTP via constant-time HMAC comparison with max 5 attempts.
//   - signup_verify  -> confirms user email + writes immutable legal_consents row
//   - password_reset -> emits single-use opaque reset_token (10 min TTL)
// =============================================================================

import { buildCorsHeaders, jsonResponse } from "../_shared/cors.ts";
import {
  enforceRateLimit,
  extractClientIpHash,
  generateOpaqueResetToken,
  getAdminClient,
  getOtpPepper,
  hmacSha256Hex,
  isValidEmailSyntax,
  normalizeEmail,
  sha256Hex,
  timingSafeEqualHex,
} from "../_shared/otp_crypto.ts";

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: buildCorsHeaders(req) });
  }
  if (req.method !== "POST") {
    return jsonResponse(req, { code: "METHOD_NOT_ALLOWED", message: "Use POST." }, 405);
  }

  let body: { email?: unknown; code?: unknown; purpose?: unknown };
  try {
    body = await req.json();
  } catch {
    return jsonResponse(req, { code: "INVALID_JSON", message: "JSON inválido." }, 400);
  }

  const email = normalizeEmail(String(body.email ?? ""));
  const code = String(body.code ?? "").trim();
  const purpose = String(body.purpose ?? "").trim();

  if (!isValidEmailSyntax(email)) {
    return jsonResponse(
      req,
      { code: "INVALID_EMAIL", message: "Informe um e-mail válido." },
      400,
    );
  }
  if (!/^\d{6}$/.test(code)) {
    return jsonResponse(
      req,
      { code: "OTP_INVALID_FORMAT", message: "O código deve conter exatamente 6 dígitos numéricos." },
      400,
    );
  }
  if (purpose !== "signup_verify" && purpose !== "password_reset") {
    return jsonResponse(
      req,
      { code: "INVALID_PURPOSE", message: "Finalidade de verificação inválida." },
      400,
    );
  }

  const adminClient = getAdminClient();
  const pepper = getOtpPepper();
  const ipHash = await extractClientIpHash(req, pepper);
  const emailHash = await hmacSha256Hex(pepper, `email:${email}`);

  const ipRate = await enforceRateLimit(adminClient, `verify_ip:${ipHash}`, 30, 900);
  if (!ipRate.allowed) {
    return jsonResponse(
      req,
      {
        code: "RATE_LIMITED",
        message: "Muitas tentativas de verificação. Aguarde alguns minutos.",
        retry_after_seconds: ipRate.retryAfterSeconds,
      },
      429,
    );
  }

  const { data: otpRow, error: fetchErr } = await adminClient
    .from("auth_email_otps")
    .select("*")
    .eq("email_hash", emailHash)
    .eq("purpose", purpose)
    .is("consumed_at", null)
    .is("reset_token_hash", null)
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (fetchErr || !otpRow) {
    return jsonResponse(
      req,
      {
        code: "OTP_EXPIRED_OR_NOT_FOUND",
        message: "Nenhum código ativo encontrado. Solicite um novo código.",
      },
      400,
    );
  }

  const expiresAtMs = new Date(otpRow.expires_at as string).getTime();
  if (Number.isNaN(expiresAtMs) || expiresAtMs <= Date.now()) {
    await adminClient
      .from("auth_email_otps")
      .update({ consumed_at: new Date().toISOString() })
      .eq("id", otpRow.id as string);
    return jsonResponse(
      req,
      {
        code: "OTP_EXPIRED",
        message: "Este código expirou após 10 minutos. Solicite um novo código.",
      },
      400,
    );
  }

  const currentAttempts = Number(otpRow.attempts ?? 0);
  const maxAttempts = Number(otpRow.max_attempts ?? 5);
  if (currentAttempts >= maxAttempts) {
    await adminClient
      .from("auth_email_otps")
      .update({ consumed_at: new Date().toISOString() })
      .eq("id", otpRow.id as string);
    return jsonResponse(
      req,
      {
        code: "OTP_MAX_ATTEMPTS",
        message: "Número máximo de tentativas excedido. Solicite um novo código.",
      },
      429,
    );
  }

  const expectedHash = await hmacSha256Hex(pepper, `${email}:${purpose}:${code}`);
  const isMatch = timingSafeEqualHex(expectedHash, String(otpRow.code_hash ?? ""));

  if (!isMatch) {
    const nextAttempts = currentAttempts + 1;
    const remaining = Math.max(0, maxAttempts - nextAttempts);
    await adminClient
      .from("auth_email_otps")
      .update({
        attempts: nextAttempts,
        consumed_at: remaining === 0 ? new Date().toISOString() : null,
      })
      .eq("id", otpRow.id as string);

    return jsonResponse(
      req,
      {
        code: remaining === 0 ? "OTP_MAX_ATTEMPTS" : "OTP_INVALID",
        remaining_attempts: remaining,
        message:
          remaining === 0
            ? "Código incorreto e limite atingido. Solicite um novo código."
            : `Código incorreto. Você ainda tem ${remaining} tentativa(s).`,
      },
      remaining === 0 ? 429 : 400,
    );
  }

  const userId = otpRow.user_id as string | null;
  if (!userId) {
    return jsonResponse(
      req,
      { code: "USER_LINK_MISSING", message: "Registro de conta não encontrado." },
      400,
    );
  }

  if (purpose === "signup_verify") {
    await adminClient
      .from("auth_email_otps")
      .update({ consumed_at: new Date().toISOString() })
      .eq("id", otpRow.id as string);

    const { error: confirmErr } = await adminClient.auth.admin.updateUserById(userId, {
      email_confirm: true,
    });
    if (confirmErr) {
      return jsonResponse(
        req,
        { code: "CONFIRM_FAILED", message: confirmErr.message },
        500,
      );
    }

    const meta = (otpRow.metadata ?? {}) as Record<string, unknown>;
    await adminClient.from("legal_consents").insert({
      user_id: userId,
      terms_version: String(meta.terms_version ?? "1.0.0-br").slice(0, 32),
      privacy_version: String(meta.privacy_version ?? "1.0.0-br").slice(0, 32),
      age_confirmed_18_plus: true,
      app_version: String(meta.app_version ?? "1.1.0").slice(0, 32),
      ip_hash: otpRow.ip_hash as string | null,
      user_agent: meta.user_agent ? String(meta.user_agent).slice(0, 240) : null,
    });

    return jsonResponse(req, { ok: true, verified: true }, 200);
  }

  // password_reset -> issue single-use opaque reset_token valid for 10 min
  const resetToken = generateOpaqueResetToken();
  const resetTokenHash = await sha256Hex(resetToken);
  const resetExpiresAtIso = new Date(Date.now() + 10 * 60 * 1000).toISOString();

  const { error: tokenUpdateErr } = await adminClient
    .from("auth_email_otps")
    .update({
      reset_token_hash: resetTokenHash,
      expires_at: resetExpiresAtIso,
    })
    .eq("id", otpRow.id as string);

  if (tokenUpdateErr) {
    return jsonResponse(
      req,
      { code: "TOKEN_ISSUE_FAILED", message: "Não foi possível emitir token de redefinição." },
      500,
    );
  }

  return jsonResponse(
    req,
    { ok: true, verified: true, reset_token: resetToken },
    200,
  );
});
