// =============================================================================
// Edge Function: auth-forgot-password
// Validates existing account, applies anti-spam cooldown/rate limits, issues
// a 6-digit password reset OTP, and dispatches a dark-mode Resend email.
// =============================================================================

import { buildCorsHeaders, jsonResponse } from "../_shared/cors.ts";
import {
  enforceRateLimit,
  extractClientIpHash,
  generateSixDigitOtp,
  getAdminClient,
  getOtpPepper,
  hmacSha256Hex,
  isValidEmailSyntax,
  maskEmail,
  normalizeEmail,
} from "../_shared/otp_crypto.ts";
import { sendOtpViaResend } from "../_shared/resend_mailer.ts";

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

  const adminClient = getAdminClient();
  const pepper = getOtpPepper();
  const ipHash = await extractClientIpHash(req, pepper);
  const emailHash = await hmacSha256Hex(pepper, `email:${email}`);

  const ipRate = await enforceRateLimit(adminClient, `forgot_ip:${ipHash}`, 10, 3600);
  if (!ipRate.allowed) {
    return jsonResponse(
      req,
      {
        code: "OTP_RATE_LIMITED",
        message: "Muitas solicitações desta rede. Aguarde antes de tentar novamente.",
        retry_after_seconds: ipRate.retryAfterSeconds,
      },
      429,
    );
  }

  const { data: lookupData, error: lookupError } = await adminClient.rpc(
    "lookup_auth_user_by_email",
    { p_email: email },
  );
  if (lookupError) {
    return jsonResponse(
      req,
      { code: "LOOKUP_FAILED", message: "Erro ao localizar conta." },
      500,
    );
  }

  const existingUser = Array.isArray(lookupData) ? lookupData[0] : lookupData;
  if (!existingUser) {
    return jsonResponse(
      req,
      {
        code: "ACCOUNT_NOT_FOUND",
        message: "Nenhuma conta NEXUS DUO encontrada para este e-mail.",
      },
      404,
    );
  }

  const oneHourAgoIso = new Date(Date.now() - 3600 * 1000).toISOString();
  const { data: recentOtps } = await adminClient
    .from("auth_email_otps")
    .select("created_at")
    .eq("email_hash", emailHash)
    .eq("purpose", "password_reset")
    .gte("created_at", oneHourAgoIso)
    .order("created_at", { ascending: false });

  if (recentOtps && recentOtps.length > 0) {
    const lastCreatedMs = new Date(recentOtps[0].created_at as string).getTime();
    const diffSec = Math.floor((Date.now() - lastCreatedMs) / 1000);
    if (diffSec < 60) {
      return jsonResponse(
        req,
        {
          code: "OTP_COOLDOWN",
          message: `Aguarde ${60 - diffSec}s antes de reenviar o código.`,
          cooldown_seconds: 60 - diffSec,
        },
        429,
      );
    }
    if (recentOtps.length >= 5) {
      return jsonResponse(
        req,
        {
          code: "OTP_RATE_LIMITED",
          message: "Limite horário de redefinição atingido para este e-mail.",
        },
        429,
      );
    }
  }

  const otpCode = generateSixDigitOtp();
  const codeHash = await hmacSha256Hex(pepper, `${email}:password_reset:${otpCode}`);
  const expiresAtIso = new Date(Date.now() + 10 * 60 * 1000).toISOString();

  await adminClient
    .from("auth_email_otps")
    .update({ consumed_at: new Date().toISOString() })
    .eq("email_hash", emailHash)
    .eq("purpose", "password_reset")
    .is("consumed_at", null);

  const { data: insertedOtp, error: insertErr } = await adminClient
    .from("auth_email_otps")
    .insert({
      email_hash: emailHash,
      user_id: existingUser.id as string,
      purpose: "password_reset",
      code_hash: codeHash,
      expires_at: expiresAtIso,
      ip_hash: ipHash,
    })
    .select("id")
    .single();

  if (insertErr || !insertedOtp) {
    return jsonResponse(
      req,
      { code: "OTP_PERSIST_ERROR", message: "Erro ao criar código de recuperação." },
      500,
    );
  }

  const mailResult = await sendOtpViaResend({
    recipientEmail: email,
    code: otpCode,
    purpose: "password_reset",
  });

  if (!mailResult.ok) {
    await adminClient
      .from("auth_email_otps")
      .update({ consumed_at: new Date().toISOString() })
      .eq("id", insertedOtp.id as string);
    return jsonResponse(
      req,
      { code: mailResult.code ?? "EMAIL_ERROR", message: mailResult.message },
      503,
    );
  }

  return jsonResponse(
    req,
    {
      ok: true,
      masked_email: maskEmail(email),
      expires_in_seconds: 600,
      cooldown_seconds: 60,
    },
    200,
  );
});
