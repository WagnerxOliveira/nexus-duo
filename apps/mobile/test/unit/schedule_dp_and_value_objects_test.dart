import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_duo/core/domain/value_objects/gamer_age.dart';
import 'package:nexus_duo/core/domain/value_objects/weekly_schedule_mask.dart';
import 'package:nexus_duo/core/errors/app_failure.dart';

void main() {
  group('GamerAge Value Object', () {
    final referenceNow = DateTime(2026, 11, 21);

    test('rejects underage birthDate (< 18) with ValidationFailure', () {
      final result = GamerAge.fromBirthDate(
        DateTime(2008, 11, 22), // turns 18 tomorrow
        now: referenceNow,
      );
      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<ValidationFailure>());
      expect(result.failureOrNull?.code, equals('UNDERAGE_NOT_ALLOWED'));
    });

    test('accepts exact 18th birthday and adult ages', () {
      final exact18 = GamerAge.fromBirthDate(
        DateTime(2008, 11, 21),
        now: referenceNow,
      );
      expect(exact18.isSuccess, isTrue);
      expect(exact18.valueOrNull?.years, equals(18));
    });

    test('rejects future birthDate', () {
      final future = GamerAge.fromBirthDate(
        DateTime(2027, 1, 1),
        now: referenceNow,
      );
      expect(future.isFailure, isTrue);
      expect(future.failureOrNull, isA<ValidationFailure>());
    });
  });

  group('WeeklyScheduleMask & O(168) Continuous Co-op Window DP', () {
    test(
      'handles circular wrap-around Sunday 23h -> Monday 01h as 1 block of 3h',
      () {
        final sundayNightToMonday = WeeklyScheduleMask.fromHours(const <int>[
          167, // Sunday 23:00
          0, // Monday 00:00
          1, // Monday 01:00
        ]);

        final analysis = sundayNightToMonday.analyzeContinuousWindows(
          sundayNightToMonday,
        );

        expect(analysis.totalCommonHours, equals(3));
        expect(analysis.usableCoopHours, equals(3));
        expect(analysis.longestContinuousBlock, equals(3));
        expect(analysis.continuousBlocks, equals(const <int>[3]));
        expect(analysis.score, greaterThan(0.3));
      },
    );

    test(
      'rewards continuous >=2h blocks far more than isolated 1h fragments',
      () {
        // 4 isolated 1-hour slots scattered across the week
        final fragmented = WeeklyScheduleMask.fromHours(const <int>[
          10,
          34,
          58,
          82,
        ]);
        // 1 single 4-hour continuous block (same total common hours = 4)
        final continuous = WeeklyScheduleMask.fromHours(const <int>[
          20,
          21,
          22,
          23,
        ]);

        final fragAnalysis = fragmented.analyzeContinuousWindows(fragmented);
        final contAnalysis = continuous.analyzeContinuousWindows(continuous);

        expect(fragAnalysis.totalCommonHours, equals(4));
        expect(contAnalysis.totalCommonHours, equals(4));
        expect(fragAnalysis.usableCoopHours, equals(0));
        expect(contAnalysis.usableCoopHours, equals(4));
        expect(contAnalysis.longestContinuousBlock, equals(4));
        expect(contAnalysis.score, greaterThan(fragAnalysis.score * 5));
      },
    );

    test('handles empty and full 168-hour schedules cleanly', () {
      final empty = WeeklyScheduleMask.empty();
      final full = WeeklyScheduleMask.full();

      final emptyAnalysis = empty.analyzeContinuousWindows(full);
      expect(emptyAnalysis.totalCommonHours, equals(0));
      expect(emptyAnalysis.longestContinuousBlock, equals(0));
      expect(emptyAnalysis.continuousBlocks, isEmpty);
      expect(emptyAnalysis.score, equals(0.0));

      final fullAnalysis = full.analyzeContinuousWindows(full);
      expect(fullAnalysis.totalCommonHours, equals(168));
      expect(fullAnalysis.usableCoopHours, equals(168));
      expect(fullAnalysis.longestContinuousBlock, equals(168));
      expect(fullAnalysis.continuousBlocks, equals(const <int>[168]));
      expect(fullAnalysis.score, equals(1.0));
    });

    test(
      'validates 3x64-bit chunks round-trip and rejects invalid chunk counts',
      () {
        final invalid = WeeklyScheduleMask.fromChunks(const <int>[1, 2]);
        expect(invalid.isFailure, isTrue);
        expect(invalid.failureOrNull, isA<ValidationFailure>());

        final original = WeeklyScheduleMask.fromHours(const <int>[
          0,
          63,
          64,
          127,
          128,
          167,
        ]);
        final restored = WeeklyScheduleMask.fromChunks(original.chunks);
        expect(restored.isSuccess, isTrue);
        expect(restored.valueOrNull, equals(original));
        expect(original.commonHoursCount(restored.valueOrNull!), equals(6));
      },
    );
  });
}
