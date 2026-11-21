// =============================================================================
// Edge Function: auth-register-start
// Validates email + confirmation, 4-layer password policy (8-12 chars, 4 classes,
// zero person names/email tokens), legal 18+ consent, creates unconfirmed user,
// stores HMAC-SHA256 6-digit OTP, and dispatches Resend HTML verification email.
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
import { evaluatePasswordPolicy } from "../_shared/password_policy.ts";
import { sendOtpViaResend } from "../_shared/resend_mailer.ts";

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: buildCorsHeaders(req) });
  }
  if (req.method !== "POST") {
    return jsonResponse(req, { code: "METHOD_NOT_ALLOWED", message: "Use POST." }, 405);
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return jsonResponse(req, { code: "INVALID_JSON", message: "JSON inválido." }, 400);
  }

  const email = normalizeEmail(String(body.email ?? ""));
  const confirmEmail = normalizeEmail(String(body.confirm_email ?? ""));
  const password = String(body.password ?? "");
  const confirmPassword = String(body.confirm_password ?? "");
  const acceptTerms = body.accept_terms === true;
  const confirmAge18Plus = body.confirm_age_18_plus === true;
  const termsVersion = String(body.terms_version ?? "1.0.0-br").trim().slice(0, 32);
  const privacyVersion = String(body.privacy_version ?? "1.0.0-br").trim().slice(0, 32);
  const appVersion = String(body.app_version ?? "1.1.0").trim().slice(0, 32);

  if (!isValidEmailSyntax(email)) {
    return jsonResponse(
      req,
      { code: "INVALID_EMAIL", message: "Informe um e-mail válido." },
      400,
    );
  }
  if (email !== confirmEmail) {
    return jsonResponse(
      req,
      { code: "EMAIL_MISMATCH", message: "Os dois campos de e-mail devem ser idênticos." },
      400,
    );
  }
  if (!acceptTerms || !confirmAge18Plus) {
    return jsonResponse(
      req,
      {
        code: "LEGAL_CONSENT_REQUIRED",
        message: "Você precisa confirmar ter 18+ anos e aceitar os Termos de Uso e LGPD.",
      },
      400,
    );
  }
  if (password !== confirmPassword) {
    return jsonResponse(
      req,
      { code: "PASSWORD_MISMATCH", message: "As duas senhas digitadas não conferem." },
      400,
    );
  }

  const policy = evaluatePasswordPolicy(password, email);
  if (!policy.isValid) {
    return jsonResponse(
      req,
      {
        code: "PASSWORD_POLICY_VIOLATION",
        message: policy.primaryErrorMessage ?? "A senha não atende aos requisitos de segurança.",
      },
      400,
    );
  }

  const adminClient = getAdminClient();
  const pepper = getOtpPepper();
  const ipHash = await extractClientIpHash(req, pepper);
  const emailHash = await hmacSha256Hex(pepper, `email:${email}`);

  const ipRate = await enforceRateLimit(adminClient, `otp_ip:${ipHash}`, 10, 3600);
  if (!ipRate.allowed) {
    return jsonResponse(
      req,
      {
        code: "OTP_RATE_LIMITED",
        message: "Muitos códigos solicitados desta rede. Aguarde antes de tentar novamente.",
        retry_after_seconds: ipRate.retryAfterSeconds,
      },
      429,
    );
  }

  // Cooldown 60s and max 5 sends/hour per email
  const oneHourAgoIso = new Date(Date.now() - 3600 * 1000).toISOString();
  const { data: recentOtps } = await adminClient
    .from("auth_email_otps")
    .select("created_at")
    .eq("email_hash", emailHash)
    .eq("purpose", "signup_verify")
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
          message: `Aguarde ${60 - diffSec}s antes de solicitar um novo código.`,
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
          message: "Limite horário de códigos atingido para este e-mail. Tente novamente mais tarde.",
        },
        429,
      );
    }
  }

  const { data: lookupData, error: lookupError } = await adminClient.rpc(
    "lookup_auth_user_by_email",
    { p_email: email },
  );
  if (lookupError) {
    console.error("lookup_auth_user_by_email error:", lookupError.message);
    return jsonResponse(
      req,
      { code: "REGISTER_ERROR", message: "Erro interno ao verificar cadastro." },
      500,
    );
  }

  const existingUser = Array.isArray(lookupData) ? lookupData[0] : lookupData;
  let userId: string;

  if (existingUser) {
    if (existingUser.email_confirmed_at) {
      return jsonResponse(
        req,
        {
          code: "ACCOUNT_ALREADY_EXISTS",
          message: "Este e-mail já possui uma conta ativa no NEXUS DUO. Faça login ou recupere sua senha.",
        },
        409,
      );
    }
    userId = existingUser.id as string;
    const { error: updateErr } = await adminClient.auth.admin.updateUserById(userId, {
      password,
      email_confirm: false,
    });
    if (updateErr) {
      return jsonResponse(
        req,
        { code: "REGISTER_ERROR", message: updateErr.message },
        400,
      );
    }
  } else {
    const { data: created, error: createErr } = await adminClient.auth.admin.createUser({
      email,
      password,
      email_confirm: false,
    });
    if (createErr || !created.user) {
      return jsonResponse(
        req,
        { code: "REGISTER_ERROR", message: createErr?.message ?? "Não foi possível iniciar o cadastro." },
        400,
      );
    }
    userId = created.user.id;
  }

  const otpCode = generateSixDigitOtp();
  const codeHash = await hmacSha256Hex(pepper, `${email}:signup_verify:${otpCode}`);
  const expiresAtIso = new Date(Date.now() + 10 * 60 * 1000).toISOString();

  // Invalidate previous unconsumed signup OTPs for this email
  await adminClient
    .from("auth_email_otps")
    .update({ consumed_at: new Date().toISOString() })
    .eq("email_hash", emailHash)
    .eq("purpose", "signup_verify")
    .is("consumed_at", null);

  const userAgent = (req.headers.get("user-agent") ?? "").slice(0, 240);
  const { data: insertedOtp, error: insertErr } = await adminClient
    .from("auth_email_otps")
    .insert({
      email_hash: emailHash,
      user_id: userId,
      purpose: "signup_verify",
      code_hash: codeHash,
      expires_at: expiresAtIso,
      ip_hash: ipHash,
      metadata: {
        terms_version: termsVersion,
        privacy_version: privacyVersion,
        app_version: appVersion,
        user_agent: userAgent,
      },
    })
    .select("id")
    .single();

  if (insertErr || !insertedOtp) {
    console.error("Failed inserting signup OTP:", insertErr?.message);
    return jsonResponse(
      req,
      { code: "OTP_PERSIST_ERROR", message: "Falha ao registrar código de verificação." },
      500,
    );
  }

  const mailResult = await sendOtpViaResend({
    recipientEmail: email,
    code: otpCode,
    purpose: "signup_verify",
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
