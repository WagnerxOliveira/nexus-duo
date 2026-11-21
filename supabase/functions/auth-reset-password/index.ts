// =============================================================================
// Edge Function: auth-reset-password
// Validates opaque reset_token + confirms authoritative 4-layer password policy,
// updates user password via Supabase Admin API, and consumes token immediately.
// =============================================================================

import { buildCorsHeaders, jsonResponse } from "../_shared/cors.ts";
import {
  getAdminClient,
  getOtpPepper,
  hmacSha256Hex,
  isValidEmailSyntax,
  normalizeEmail,
  sha256Hex,
} from "../_shared/otp_crypto.ts";
import { evaluatePasswordPolicy } from "../_shared/password_policy.ts";

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: buildCorsHeaders(req) });
  }
  if (req.method !== "POST") {
    return jsonResponse(req, { code: "METHOD_NOT_ALLOWED", message: "Use POST." }, 405);
  }

  let body: {
    email?: unknown;
    reset_token?: unknown;
    new_password?: unknown;
    confirm_password?: unknown;
  };
  try {
    body = await req.json();
  } catch {
    return jsonResponse(req, { code: "INVALID_JSON", message: "JSON inválido." }, 400);
  }

  const email = normalizeEmail(String(body.email ?? ""));
  const resetToken = String(body.reset_token ?? "").trim();
  const newPassword = String(body.new_password ?? "");
  const confirmPassword = String(body.confirm_password ?? "");

  if (!isValidEmailSyntax(email)) {
    return jsonResponse(
      req,
      { code: "INVALID_EMAIL", message: "Informe um e-mail válido." },
      400,
    );
  }
  if (resetToken.length < 20) {
    return jsonResponse(
      req,
      { code: "RESET_TOKEN_INVALID", message: "Token de recuperação inválido." },
      400,
    );
  }
  if (newPassword !== confirmPassword) {
    return jsonResponse(
      req,
      { code: "PASSWORD_MISMATCH", message: "As duas senhas digitadas não conferem." },
      400,
    );
  }

  const policy = evaluatePasswordPolicy(newPassword, email);
  if (!policy.isValid) {
    return jsonResponse(
      req,
      {
        code: "PASSWORD_POLICY_VIOLATION",
        message: policy.primaryErrorMessage ?? "A nova senha não atende aos requisitos de segurança.",
      },
      400,
    );
  }

  const adminClient = getAdminClient();
  const pepper = getOtpPepper();
  const emailHash = await hmacSha256Hex(pepper, `email:${email}`);
  const resetTokenHash = await sha256Hex(resetToken);

  const { data: otpRow, error: fetchErr } = await adminClient
    .from("auth_email_otps")
    .select("*")
    .eq("email_hash", emailHash)
    .eq("purpose", "password_reset")
    .eq("reset_token_hash", resetTokenHash)
    .is("consumed_at", null)
    .gt("expires_at", new Date().toISOString())
    .limit(1)
    .maybeSingle();

  if (fetchErr || !otpRow || !otpRow.user_id) {
    return jsonResponse(
      req,
      {
        code: "RESET_TOKEN_INVALID",
        message: "Sessão de redefinição expirada ou já utilizada. Solicite um novo código.",
      },
      400,
    );
  }

  const { error: updateErr } = await adminClient.auth.admin.updateUserById(
    otpRow.user_id as string,
    { password: newPassword, email_confirm: true },
  );
  if (updateErr) {
    return jsonResponse(
      req,
      { code: "PASSWORD_UPDATE_FAILED", message: updateErr.message },
      400,
    );
  }

  await adminClient
    .from("auth_email_otps")
    .update({
      consumed_at: new Date().toISOString(),
      reset_token_hash: null,
    })
    .eq("id", otpRow.id as string);

  return jsonResponse(
    req,
    { ok: true, message: "Senha alterada com sucesso! Já pode entrar com a nova senha." },
    200,
  );
});
