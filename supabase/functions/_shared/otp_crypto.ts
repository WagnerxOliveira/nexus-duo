// =============================================================================
// Zero-Trust Cryptographic OTP, Hashing & Rate-Limit Helpers (Deno WebCrypto)
// =============================================================================

import { createClient, type SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const encoder = new TextEncoder();

export function getAdminClient(): SupabaseClient {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    throw new Error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
  }
  return createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

export function getOtpPepper(): string {
  const explicit = Deno.env.get("AUTH_OTP_PEPPER")?.trim();
  if (explicit && explicit.length >= 16) {
    return explicit;
  }
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "fallback-pepper";
  return `${serviceKey}:nexus-duo-otp-v1`;
}

export function normalizeEmail(raw: string): string {
  return raw.trim().toLowerCase();
}

export function isValidEmailSyntax(email: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(email) && email.length <= 254;
}

export function maskEmail(rawEmail: string): string {
  const email = normalizeEmail(rawEmail);
  const [local = "", domain = ""] = email.split("@");
  if (!domain) return "***";
  if (local.length <= 2) {
    return `${local[0] ?? "*"}***@${domain}`;
  }
  return `${local[0]}***${local[local.length - 1]}@${domain}`;
}

export async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", encoder.encode(value));
  return bytesToHex(new Uint8Array(digest));
}

export async function hmacSha256Hex(
  secret: string,
  message: string,
): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    encoder.encode(message),
  );
  return bytesToHex(new Uint8Array(signature));
}

export function timingSafeEqualHex(a: string, b: string): boolean {
  if (a.length !== b.length || a.length === 0) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) {
    diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return diff === 0;
}

/**
 * Generates an unbiased 6-digit OTP using CSPRNG with rejection sampling.
 */
export function generateSixDigitOtp(): string {
  const range = 1_000_000;
  const maxUnbiased = Math.floor(0x1_0000_0000 / range) * range;
  const buf = new Uint32Array(1);
  while (true) {
    crypto.getRandomValues(buf);
    const val = buf[0];
    if (val < maxUnbiased) {
      return String(val % range).padStart(6, "0");
    }
  }
}

/**
 * Generates a cryptographically strong opaque reset token (`43` URL-safe chars).
 */
export function generateOpaqueResetToken(): string {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

export async function extractClientIpHash(
  req: Request,
  pepper: string,
): Promise<string> {
  const rawIp =
    req.headers.get("cf-connecting-ip") ??
    req.headers.get("x-forwarded-for")?.split(",")[0] ??
    req.headers.get("x-real-ip") ??
    "unknown";
  return await hmacSha256Hex(pepper, `ip:${rawIp.trim()}`);
}

export async function enforceRateLimit(
  adminClient: SupabaseClient,
  bucketKey: string,
  maxEvents: number,
  windowSeconds: number,
): Promise<{ allowed: boolean; retryAfterSeconds: number }> {
  const sinceIso = new Date(Date.now() - windowSeconds * 1000).toISOString();
  const { count, data } = await adminClient
    .from("auth_rate_events")
    .select("created_at", { count: "exact" })
    .eq("bucket_key", bucketKey)
    .gte("created_at", sinceIso)
    .order("created_at", { ascending: true })
    .limit(1);

  const currentCount = count ?? 0;
  if (currentCount >= maxEvents) {
    const oldest = data?.[0]?.created_at
      ? new Date(data[0].created_at as string).getTime()
      : Date.now();
    const retryAfterSeconds = Math.max(
      1,
      Math.ceil((oldest + windowSeconds * 1000 - Date.now()) / 1000),
    );
    return { allowed: false, retryAfterSeconds };
  }

  await adminClient.from("auth_rate_events").insert({ bucket_key: bucketKey });
  return { allowed: true, retryAfterSeconds: 0 };
}

function bytesToHex(bytes: Uint8Array): string {
  return Array.from(bytes)
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}
