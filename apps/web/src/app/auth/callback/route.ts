import { NextResponse } from 'next/server';
import { getSupabaseServerClient } from '@/core/supabase/server';

const SAFE_HOST_PATTERN = /^[a-zA-Z0-9.-]+(:\d+)?$/;

function sanitizeRedirectPath(rawNext: string | null): string {
  if (!rawNext) {
    return '/app';
  }
  if (rawNext.startsWith('/') && !rawNext.startsWith('//') && !rawNext.startsWith('/\\')) {
    return rawNext;
  }
  return '/app';
}

function resolveRedirectOrigin(request: Request, fallbackOrigin: string): string {
  if (process.env.NODE_ENV === 'development') {
    return fallbackOrigin;
  }
  const forwardedHost = request.headers.get('x-forwarded-host')?.split(',')[0]?.trim();
  if (!forwardedHost || !SAFE_HOST_PATTERN.test(forwardedHost)) {
    return fallbackOrigin;
  }
  const forwardedProto = request.headers.get('x-forwarded-proto')?.split(',')[0]?.trim();
  const proto = forwardedProto === 'http' ? 'http' : 'https';
  return `${proto}://${forwardedHost}`;
}

/**
 * Callback OAuth2 PKCE & confirmação de e-mail para o Supabase Auth SSR.
 *
 * Troca o parâmetro `?code=` por cookies HTTP-only seguros no domínio Web
 * antes de redirecionar o jogador para o painel de 2º Monitor (`/app`).
 */
export async function GET(request: Request) {
  const { searchParams, origin } = new URL(request.url);
  const redirectOrigin = resolveRedirectOrigin(request, origin);
  const safeNext = sanitizeRedirectPath(searchParams.get('next'));
  const oauthError = searchParams.get('error');

  if (oauthError) {
    return NextResponse.redirect(
      `${redirectOrigin}/app?auth_error=${encodeURIComponent(oauthError)}`,
    );
  }

  const supabase = await getSupabaseServerClient();
  if (!supabase) {
    // Em modo Demo/Offline sem variáveis Supabase, segue diretamente para o destino seguro.
    return NextResponse.redirect(`${redirectOrigin}${safeNext}`);
  }

  const code = searchParams.get('code');
  if (!code) {
    return NextResponse.redirect(`${redirectOrigin}/app?auth_error=missing_code`);
  }

  const { error } = await supabase.auth.exchangeCodeForSession(code);
  if (error) {
    return NextResponse.redirect(`${redirectOrigin}/app?auth_error=callback_failed`);
  }

  return NextResponse.redirect(`${redirectOrigin}${safeNext}`);
}
