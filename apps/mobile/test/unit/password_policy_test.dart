import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_duo/core/security/nexus_password_policy.dart';

void main() {
  group('NexusPasswordPolicy (8..12 chars, 4 classes & 4-layer anti-names)', () {
    test('rejects passwords shorter than 8 or longer than 12 characters', () {
      expect(
        NexusPasswordPolicy.evaluate('K9#vQ2!').hasValidLength,
        isFalse,
      ); // 7 chars
      expect(
        NexusPasswordPolicy.evaluate('K9#vQ2!pX4Zz1').hasValidLength,
        isFalse,
      ); // 13 chars
      expect(
        NexusPasswordPolicy.evaluate('K9#vQ2!p').isValid,
        isTrue,
      ); // 8 chars
      expect(
        NexusPasswordPolicy.evaluate('K9#vQ2!pX4zQ').isValid,
        isTrue,
      ); // 12 chars
    });

    test(
      'enforces lowercase, uppercase, digit, special char, and no spaces',
      () {
        expect(
          NexusPasswordPolicy.evaluate('k9#vq2!px4').hasUppercase,
          isFalse,
        );
        expect(
          NexusPasswordPolicy.evaluate('K9#VQ2!PX4').hasLowercase,
          isFalse,
        );
        expect(NexusPasswordPolicy.evaluate('Kz#vQz!pXz').hasDigit, isFalse);
        expect(
          NexusPasswordPolicy.evaluate('K9mvQ2mpX4').hasSpecialChar,
          isFalse,
        );
        expect(
          NexusPasswordPolicy.evaluate('K9#v Q2!pX').hasNoWhitespace,
          isFalse,
        );
        expect(NexusPasswordPolicy.evaluate('K9#vQ2!pX4').isValid, isTrue);
      },
    );

    test(
      'blocks Brazilian first names, surnames, international names, accents & leetspeak',
      () {
        // Exact BR first name
        expect(
          NexusPasswordPolicy.evaluate('Wagner#91').hasNoPersonName,
          isFalse,
        );
        // 3-char token name
        expect(
          NexusPasswordPolicy.evaluate('Ana#98765').hasNoPersonName,
          isFalse,
        );
        // Accented name (Unicode folding)
        expect(
          NexusPasswordPolicy.evaluate('Júlia!123').hasNoPersonName,
          isFalse,
        );
        // Leetspeak obfuscation
        expect(
          NexusPasswordPolicy.evaluate('M4r1a#202').hasNoPersonName,
          isFalse,
        );
        expect(
          NexusPasswordPolicy.evaluate('W@gn3r!1a').hasNoPersonName,
          isFalse,
        );
        expect(
          NexusPasswordPolicy.evaluate('J0ao\$2026').hasNoPersonName,
          isFalse,
        );
        // Brazilian surname
        expect(
          NexusPasswordPolicy.evaluate('Oliveira!9').hasNoPersonName,
          isFalse,
        );
        expect(
          NexusPasswordPolicy.evaluate('S1lva#998').hasNoPersonName,
          isFalse,
        );
        // International name
        expect(
          NexusPasswordPolicy.evaluate('Sarah!987').hasNoPersonName,
          isFalse,
        );
      },
    );

    test('blocks arbitrary tokens from user email local-part', () {
      const customEmail = 'zorbax99.gamer@nexusduo.app';
      expect(
        NexusPasswordPolicy.evaluate(
          'Zorbax!92',
          email: customEmail,
        ).hasNoPersonName,
        isFalse,
      );
      expect(
        NexusPasswordPolicy.evaluate(
          'Z0rb@x#12',
          email: customEmail,
        ).hasNoPersonName,
        isFalse,
      );
      // Strong non-name password passes even with customEmail
      expect(
        NexusPasswordPolicy.evaluate('K9#vQ2!pX4', email: customEmail).isValid,
        isTrue,
      );
    });
  });
}
