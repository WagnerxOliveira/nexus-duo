import 'person_names_blocklist.g.dart';

/// Immutable result describing every rule evaluated against a candidate password.
class PasswordPolicyEvaluation {
  const PasswordPolicyEvaluation({
    required this.length,
    required this.hasValidLength,
    required this.hasLowercase,
    required this.hasUppercase,
    required this.hasDigit,
    required this.hasSpecialChar,
    required this.hasNoWhitespace,
    required this.hasNoPersonName,
    this.detectedBlockedTerm,
  });

  final int length;
  final bool hasValidLength;
  final bool hasLowercase;
  final bool hasUppercase;
  final bool hasDigit;
  final bool hasSpecialChar;
  final bool hasNoWhitespace;
  final bool hasNoPersonName;
  final String? detectedBlockedTerm;

  bool get isValid =>
      hasValidLength &&
      hasLowercase &&
      hasUppercase &&
      hasDigit &&
      hasSpecialChar &&
      hasNoWhitespace &&
      hasNoPersonName;

  /// Score in `[0, 4]` used by UI strength bars.
  int get strengthScore {
    var score = 0;
    if (hasValidLength) score++;
    if (hasLowercase && hasUppercase) score++;
    if (hasDigit && hasSpecialChar) score++;
    if (isValid && length >= 10) score++;
    return score;
  }

  /// Human-readable reason explaining the highest-priority unmet rule.
  String? get primaryErrorMessage {
    if (length == 0) {
      return 'Digite uma senha entre 8 e 12 caracteres.';
    }
    if (!hasNoWhitespace) {
      return 'A senha não pode conter espaços.';
    }
    if (length < NexusPasswordPolicy.minLength) {
      return 'A senha deve ter no mínimo ${NexusPasswordPolicy.minLength} caracteres.';
    }
    if (length > NexusPasswordPolicy.maxLength) {
      return 'A senha deve ter no máximo ${NexusPasswordPolicy.maxLength} caracteres.';
    }
    if (!hasLowercase) {
      return 'Inclua pelo menos 1 letra minúscula (a-z).';
    }
    if (!hasUppercase) {
      return 'Inclua pelo menos 1 letra maiúscula (A-Z).';
    }
    if (!hasDigit) {
      return 'Inclua pelo menos 1 número (0-9).';
    }
    if (!hasSpecialChar) {
      return 'Inclua pelo menos 1 caractere especial (ex.: !@#\$%^&*).';
    }
    if (!hasNoPersonName) {
      return 'Por segurança, a senha não pode conter nomes de pessoas ou partes do seu e-mail.';
    }
    return null;
  }
}

/// 4-layer password security validator enforced identically on Mobile (Dart)
/// and Supabase Edge Functions (Deno TypeScript).
abstract final class NexusPasswordPolicy {
  static const int minLength = 8;
  static const int maxLength = 12;

  static final RegExp _lowerRegex = RegExp(r'[a-z]');
  static final RegExp _upperRegex = RegExp(r'[A-Z]');
  static final RegExp _digitRegex = RegExp(r'[0-9]');
  static final RegExp _specialRegex = RegExp(r'[^A-Za-z0-9\s]');
  static final RegExp _whitespaceRegex = RegExp(r'\s');
  static final RegExp _alphaTokenRegex = RegExp(r'[a-z]+');

  static const Map<int, String> _accentFoldMap = <int, String>{
    0x00E0: 'a',
    0x00E1: 'a',
    0x00E2: 'a',
    0x00E3: 'a',
    0x00E4: 'a',
    0x00E5: 'a',
    0x00E7: 'c',
    0x00E8: 'e',
    0x00E9: 'e',
    0x00EA: 'e',
    0x00EB: 'e',
    0x00EC: 'i',
    0x00ED: 'i',
    0x00EE: 'i',
    0x00EF: 'i',
    0x00F1: 'n',
    0x00F2: 'o',
    0x00F3: 'o',
    0x00F4: 'o',
    0x00F5: 'o',
    0x00F6: 'o',
    0x00F8: 'o',
    0x00F9: 'u',
    0x00FA: 'u',
    0x00FB: 'u',
    0x00FC: 'u',
    0x00FD: 'y',
    0x00FF: 'y',
  };

  /// Folds Portuguese/Latin-1 accents into plain ASCII lowercase letters and
  /// strips combining diacritical marks (`0x0300..0x036F`).
  static String normalizeAsciiLower(String raw) {
    final buffer = StringBuffer();
    for (final rune in raw.toLowerCase().runes) {
      if (rune >= 0x0300 && rune <= 0x036F) {
        continue;
      }
      final mapped = _accentFoldMap[rune];
      if (mapped != null) {
        buffer.write(mapped);
      } else {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString();
  }

  static String _deleet(String input, {required String oneAs}) {
    final buf = StringBuffer();
    for (var i = 0; i < input.length; i++) {
      final ch = input[i];
      switch (ch) {
        case '0':
          buf.write('o');
        case '1':
          buf.write(oneAs);
        case '3':
          buf.write('e');
        case '4':
          buf.write('a');
        case '5':
          buf.write('s');
        case '7':
          buf.write('t');
        case '8':
          buf.write('b');
        case '@':
          buf.write('a');
        case r'$':
          buf.write('s');
        case '!':
          buf.write('i');
        default:
          buf.write(ch);
      }
    }
    return buf.toString();
  }

  static List<String> _extractEmailSegments(String? email) {
    if (email == null || email.trim().isEmpty) {
      return const <String>[];
    }
    final localPart = normalizeAsciiLower(email.trim().split('@').first);
    final segments = <String>{};
    for (final match in _alphaTokenRegex.allMatches(localPart)) {
      final token = match.group(0)!;
      if (token.length >= 3) {
        segments.add(token);
      }
    }
    return segments.toList();
  }

  static String? _detectBlockedPersonOrEmailTerm(
    String password,
    String? email,
  ) {
    if (password.isEmpty) return null;
    final folded = normalizeAsciiLower(password);
    final variants = <String>{
      folded,
      _deleet(folded, oneAs: 'i'),
      _deleet(folded, oneAs: 'l'),
    };

    final emailSegments = _extractEmailSegments(email);

    for (final variant in variants) {
      // Layer 4: contextual check against non-trivial local email tokens
      final compactAlpha = variant.replaceAll(RegExp(r'[^a-z]'), '');
      for (final seg in emailSegments) {
        if (seg.length >= 4 && compactAlpha.contains(seg)) {
          return seg;
        }
        if (variant.contains(seg)) {
          return seg;
        }
      }

      // Layer 3: exact 3-char tokens + 4+ char contiguous dictionary windows
      for (final match in _alphaTokenRegex.allMatches(variant)) {
        final token = match.group(0)!;
        if (token.length == 3 && kShortPersonNames3.contains(token)) {
          return token;
        }
        if (emailSegments.contains(token)) {
          return token;
        }
        if (token.length >= 4) {
          if (kPersonNamesBlocklist.contains(token)) {
            return token;
          }
          final maxWindow = token.length < 14 ? token.length : 14;
          for (var win = 4; win <= maxWindow; win++) {
            for (var start = 0; start <= token.length - win; start++) {
              final sub = token.substring(start, start + win);
              if (kPersonNamesBlocklist.contains(sub)) {
                return sub;
              }
            }
          }
        }
      }
    }

    return null;
  }

  /// Evaluates [password] against length (8..12), 4 character classes, no
  /// whitespace, 4-layer person-name engine, and optional [email] local tokens.
  static PasswordPolicyEvaluation evaluate(String password, {String? email}) {
    final len = password.length;
    final hasValidLength = len >= minLength && len <= maxLength;
    final hasLowercase = _lowerRegex.hasMatch(password);
    final hasUppercase = _upperRegex.hasMatch(password);
    final hasDigit = _digitRegex.hasMatch(password);
    final hasSpecialChar = _specialRegex.hasMatch(password);
    final hasNoWhitespace = len > 0 && !_whitespaceRegex.hasMatch(password);
    final detected = _detectBlockedPersonOrEmailTerm(password, email);

    return PasswordPolicyEvaluation(
      length: len,
      hasValidLength: hasValidLength,
      hasLowercase: hasLowercase,
      hasUppercase: hasUppercase,
      hasDigit: hasDigit,
      hasSpecialChar: hasSpecialChar,
      hasNoWhitespace: hasNoWhitespace,
      hasNoPersonName: detected == null,
      detectedBlockedTerm: detected,
    );
  }
}
