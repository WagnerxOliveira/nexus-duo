// =============================================================================
// Authoritative 4-layer Password Security Policy for NEXUS DUO Edge Functions.
// Mirrors apps/mobile/lib/core/security/nexus_password_policy.dart exactly.
// =============================================================================

import {
  PERSON_NAMES_BLOCKLIST,
  SHORT_PERSON_NAMES_3,
} from "./person_names_blocklist.ts";

export interface PasswordPolicyEvaluation {
  length: number;
  hasValidLength: boolean;
  hasLowercase: boolean;
  hasUppercase: boolean;
  hasDigit: boolean;
  hasSpecialChar: boolean;
  hasNoWhitespace: boolean;
  hasNoPersonName: boolean;
  detectedBlockedTerm: string | null;
  isValid: boolean;
  primaryErrorMessage: string | null;
}

export const PASSWORD_MIN_LENGTH = 8;
export const PASSWORD_MAX_LENGTH = 12;

export function normalizeAsciiLower(raw: string): string {
  return raw
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase();
}

function deleet(input: string, oneAs: "i" | "l"): string {
  return input.replace(/[0134578@$!]/g, (ch) => {
    switch (ch) {
      case "0":
        return "o";
      case "1":
        return oneAs;
      case "3":
        return "e";
      case "4":
        return "a";
      case "5":
        return "s";
      case "7":
        return "t";
      case "8":
        return "b";
      case "@":
        return "a";
      case "$":
        return "s";
      case "!":
        return "i";
      default:
        return ch;
    }
  });
}

function extractEmailSegments(email?: string): string[] {
  if (!email || email.trim().length === 0) return [];
  const localPart = normalizeAsciiLower(email.trim().split("@")[0] ?? "");
  const segments = new Set<string>();
  for (const match of localPart.matchAll(/[a-z]+/g)) {
    const token = match[0];
    if (token.length >= 3) {
      segments.add(token);
    }
  }
  return [...segments];
}

function detectBlockedPersonOrEmailTerm(
  password: string,
  email?: string,
): string | null {
  if (!password) return null;
  const folded = normalizeAsciiLower(password);
  const variants = new Set<string>([
    folded,
    deleet(folded, "i"),
    deleet(folded, "l"),
  ]);
  const emailSegments = extractEmailSegments(email);

  for (const variant of variants) {
    const compactAlpha = variant.replace(/[^a-z]/g, "");
    for (const seg of emailSegments) {
      if (seg.length >= 4 && compactAlpha.includes(seg)) {
        return seg;
      }
      if (variant.includes(seg)) {
        return seg;
      }
    }

    for (const match of variant.matchAll(/[a-z]+/g)) {
      const token = match[0];
      if (token.length === 3 && SHORT_PERSON_NAMES_3.has(token)) {
        return token;
      }
      if (emailSegments.includes(token)) {
        return token;
      }
      if (token.length >= 4) {
        if (PERSON_NAMES_BLOCKLIST.has(token)) {
          return token;
        }
        const maxWindow = Math.min(token.length, 14);
        for (let win = 4; win <= maxWindow; win++) {
          for (let start = 0; start <= token.length - win; start++) {
            const sub = token.slice(start, start + win);
            if (PERSON_NAMES_BLOCKLIST.has(sub)) {
              return sub;
            }
          }
        }
      }
    }
  }

  return null;
}

export function evaluatePasswordPolicy(
  password: string,
  email?: string,
): PasswordPolicyEvaluation {
  const length = password.length;
  const hasValidLength =
    length >= PASSWORD_MIN_LENGTH && length <= PASSWORD_MAX_LENGTH;
  const hasLowercase = /[a-z]/.test(password);
  const hasUppercase = /[A-Z]/.test(password);
  const hasDigit = /[0-9]/.test(password);
  const hasSpecialChar = /[^A-Za-z0-9\s]/.test(password);
  const hasNoWhitespace = length > 0 && !/\s/.test(password);
  const detectedBlockedTerm = detectBlockedPersonOrEmailTerm(password, email);
  const hasNoPersonName = detectedBlockedTerm === null;

  const isValid =
    hasValidLength &&
    hasLowercase &&
    hasUppercase &&
    hasDigit &&
    hasSpecialChar &&
    hasNoWhitespace &&
    hasNoPersonName;

  let primaryErrorMessage: string | null = null;
  if (length === 0) {
    primaryErrorMessage = "Digite uma senha entre 8 e 12 caracteres.";
  } else if (!hasNoWhitespace) {
    primaryErrorMessage = "A senha não pode conter espaços.";
  } else if (length < PASSWORD_MIN_LENGTH) {
    primaryErrorMessage =
      `A senha deve ter no mínimo ${PASSWORD_MIN_LENGTH} caracteres.`;
  } else if (length > PASSWORD_MAX_LENGTH) {
    primaryErrorMessage =
      `A senha deve ter no máximo ${PASSWORD_MAX_LENGTH} caracteres.`;
  } else if (!hasLowercase) {
    primaryErrorMessage = "Inclua pelo menos 1 letra minúscula (a-z).";
  } else if (!hasUppercase) {
    primaryErrorMessage = "Inclua pelo menos 1 letra maiúscula (A-Z).";
  } else if (!hasDigit) {
    primaryErrorMessage = "Inclua pelo menos 1 número (0-9).";
  } else if (!hasSpecialChar) {
    primaryErrorMessage =
      "Inclua pelo menos 1 caractere especial (ex.: !@#$%^&*).";
  } else if (!hasNoPersonName) {
    primaryErrorMessage =
      "Por segurança, a senha não pode conter nomes de pessoas ou partes do seu e-mail.";
  }

  return {
    length,
    hasValidLength,
    hasLowercase,
    hasUppercase,
    hasDigit,
    hasSpecialChar,
    hasNoWhitespace,
    hasNoPersonName,
    detectedBlockedTerm,
    isValid,
    primaryErrorMessage,
  };
}
