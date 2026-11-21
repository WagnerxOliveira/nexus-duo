// =============================================================================
// Resend Transactional Mailer with Premium Cyber-Velvet & Obsidian Neon HTML
// Exclusive to NEXUS DUO (uses RESEND_API_KEY & RESEND_FROM_EMAIL in hfuntccxwoijjkmitewb)
// =============================================================================

export type OtpEmailPurpose = "signup_verify" | "password_reset";

export interface SendOtpEmailResult {
  ok: boolean;
  code?: string;
  message?: string;
  resendId?: string;
}

function escapeHtml(text: string): string {
  return text
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

export function buildOtpEmailHtml(params: {
  code: string;
  purpose: OtpEmailPurpose;
  recipientEmail: string;
}): { subject: string; html: string; text: string } {
  const isReset = params.purpose === "password_reset";
  const safeCode = escapeHtml(params.code);
  const safeRecipient = escapeHtml(params.recipientEmail);

  const subject = isReset
    ? `${safeCode} é seu código de redefinição de senha · NEXUS DUO`
    : `${safeCode} é seu código de verificação · NEXUS DUO`;

  const badgeLabel = isReset
    ? "RECUPERAÇÃO DE CONTA"
    : "CONFIRMAÇÃO DE CADASTRO";
  const title = isReset
    ? "Redefina sua senha no NEXUS DUO"
    : "Bem-vindo(a) ao NEXUS DUO";
  const subtitle = isReset
    ? `Recebemos uma solicitação para alterar a senha da conta associada a <strong>${safeRecipient}</strong>. Digite o código de 6 dígitos abaixo no aplicativo:`
    : `Falta apenas 1 passo para validar seu e-mail <strong>${safeRecipient}</strong> e desbloquear seu Perfil Gamer com chat E2EE. Digite o código abaixo no aplicativo:`;

  const html = `<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <meta name="color-scheme" content="dark" />
  <title>${escapeHtml(subject)}</title>
</head>
<body style="margin:0;padding:0;background-color:#09090B;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,'Plus Jakarta Sans',sans-serif;color:#FAFAFA;">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="background-color:#09090B;padding:32px 16px;">
    <tr>
      <td align="center">
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="max-width:540px;background-color:#13131A;border:1px solid #27273A;border-radius:20px;overflow:hidden;">
          <!-- Cyber-Velvet Top Accent Bar -->
          <tr>
            <td style="height:5px;background:linear-gradient(90deg,#8B5CF6 0%,#EC4899 50%,#06B6D4 100%);font-size:0;line-height:0;">&nbsp;</td>
          </tr>
          <!-- Brand Header -->
          <tr>
            <td style="padding:28px 28px 12px 28px;">
              <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0">
                <tr>
                  <td align="left" style="vertical-align:middle;">
                    <span style="display:inline-block;padding:6px 12px;border-radius:10px;background-color:#1E1B4B;border:1px solid #8B5CF6;color:#FAFAFA;font-size:15px;font-weight:800;letter-spacing:1.4px;">NEXUS DUO</span>
                  </td>
                  <td align="right" style="vertical-align:middle;">
                    <span style="display:inline-block;padding:4px 10px;border-radius:999px;background-color:#0F172A;border:1px solid #06B6D4;color:#22D3EE;font-size:10px;font-weight:700;letter-spacing:0.9px;">${badgeLabel}</span>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          <!-- Headline & Copy -->
          <tr>
            <td style="padding:8px 28px 16px 28px;">
              <h1 style="margin:0 0 12px 0;font-size:22px;line-height:1.3;font-weight:700;color:#FAFAFA;">${title}</h1>
              <p style="margin:0;font-size:14px;line-height:1.65;color:#A1A1AA;">${subtitle}</p>
            </td>
          </tr>
          <!-- 6-Digit Neon OTP Box -->
          <tr>
            <td style="padding:12px 28px 20px 28px;" align="center">
              <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="background-color:#09090B;border:1.5px solid #8B5CF6;border-radius:16px;">
                <tr>
                  <td align="center" style="padding:24px 16px;">
                    <div style="font-size:11px;font-weight:700;letter-spacing:1.6px;color:#06B6D4;margin-bottom:8px;text-transform:uppercase;">Seu Código de Verificação</div>
                    <div style="font-family:'JetBrains Mono',Consolas,'Courier New',monospace;font-size:38px;line-height:1.15;font-weight:800;letter-spacing:10px;color:#FAFAFA;padding-left:10px;">${safeCode}</div>
                    <div style="margin-top:10px;font-size:12px;color:#A1A1AA;">Expira automaticamente em <strong style="color:#FAFAFA;">10 minutos</strong> · Uso único</div>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          <!-- Anti-Phishing Security Box -->
          <tr>
            <td style="padding:0 28px 24px 28px;">
              <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="background-color:#1A1325;border:1px solid #3B2D54;border-radius:12px;">
                <tr>
                  <td style="padding:14px 16px;font-size:12px;line-height:1.55;color:#D4D4D8;">
                    <strong style="color:#F472B6;">Aviso de Segurança Zero-Trust:</strong> Nunca compartilhe este código com terceiros. A equipe NEXUS DUO jamais solicita sua senha ou código por Discord, chat ou WhatsApp. Se não foi você quem solicitou, ignore este e-mail com segurança.
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          <!-- Footer & LGPD -->
          <tr>
            <td style="padding:16px 28px 24px 28px;border-top:1px solid #232334;font-size:11px;line-height:1.6;color:#71717A;">
              Enviado com segurança pelo ecossistema <strong style="color:#A1A1AA;">NEXUS DUO</strong> (Criptografia E2EE X25519 + AES-256-GCM).<br/>
              Você pode exercer seus direitos de privacidade (LGPD Art. 18 — exportação ou exclusão de conta) a qualquer momento dentro do aplicativo.
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;

  const text = [
    `NEXUS DUO — ${badgeLabel}`,
    "",
    title,
    `Código de verificação (válido por 10 minutos): ${params.code}`,
    "",
    "Nunca compartilhe este código com terceiros. Se você não solicitou esta operação, ignore este e-mail.",
  ].join("\n");

  return { subject, html, text };
}

export async function sendOtpViaResend(params: {
  recipientEmail: string;
  code: string;
  purpose: OtpEmailPurpose;
}): Promise<SendOtpEmailResult> {
  const apiKey = Deno.env.get("RESEND_API_KEY")?.trim();
  const fromEmail = Deno.env.get("RESEND_FROM_EMAIL")?.trim();

  if (!apiKey || !fromEmail) {
    return {
      ok: false,
      code: "EMAIL_PROVIDER_NOT_CONFIGURED",
      message:
        "Serviço de e-mail transacional Resend ainda não configurado no projeto Supabase nexus-duo (RESEND_API_KEY / RESEND_FROM_EMAIL).",
    };
  }

  const content = buildOtpEmailHtml({
    code: params.code,
    purpose: params.purpose,
    recipientEmail: params.recipientEmail,
  });

  const resp = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: fromEmail,
      to: [params.recipientEmail],
      subject: content.subject,
      html: content.html,
      text: content.text,
    }),
  });

  if (!resp.ok) {
    const errText = await resp.text().catch(() => "");
    console.error("Resend API error:", resp.status, errText);
    return {
      ok: false,
      code: "RESEND_DELIVERY_FAILED",
      message:
        "Não foi possível entregar o código por e-mail neste momento. Verifique o domínio remetente no Resend.",
    };
  }

  const data = await resp.json().catch(() => ({})) as { id?: string };
  return { ok: true, resendId: data.id };
}
