import 'dart:math' as math;

import '../../errors/app_failure.dart';

/// Breakdown of continuous co-op time windows computed via O(168) DP.
class ScheduleOverlapAnalysis {
  const ScheduleOverlapAnalysis({
    required this.totalCommonHours,
    required this.usableCoopHours,
    required this.longestContinuousBlock,
    required this.continuousBlocks,
    required this.score,
  });

  /// Total overlapping 1-hour slots across the 168-hour week.
  final int totalCommonHours;

  /// Sum of hours belonging to continuous blocks of >= 2 hours.
  final int usableCoopHours;

  /// Length (in hours) of the longest contiguous play window (with wrap-around).
  final int longestContinuousBlock;

  /// Lengths of every maximal contiguous overlapping block across the week.
  final List<int> continuousBlocks;

  /// Normalized schedule compatibility score in `[0.0, 1.0]`.
  final double score;
}

/// Encapsulates a 7x24 weekly gamer availability grid (168 hours)
/// into 3 x 64-bit chunks (`bigint[3]` in PostgreSQL).
///
/// Indexing convention:
/// - `day`: 0 = Monday .. 6 = Sunday
/// - `hourOfDay`: 0 .. 23
/// - `hourIndex = day * 24 + hourOfDay` in `[0, 167]`
/// - Chunk 0: hours `0..63`
/// - Chunk 1: hours `64..127`
/// - Chunk 2: hours `128..167` (40 valid bits, high 24 bits always 0)
class WeeklyScheduleMask {
  WeeklyScheduleMask._(List<BigInt> rawChunks)
    : _rawChunks = List<BigInt>.unmodifiable(rawChunks);

  static const int totalHours = 168;
  static const int chunkCount = 3;
  static final BigInt _mask64 = (BigInt.one << 64) - BigInt.one;
  static final BigInt _mask40 = (BigInt.one << 40) - BigInt.one;

  final List<BigInt> _rawChunks;

  /// Empty schedule (0 available hours).
  factory WeeklyScheduleMask.empty() {
    return WeeklyScheduleMask._(<BigInt>[
      BigInt.zero,
      BigInt.zero,
      BigInt.zero,
    ]);
  }

  /// Fully available schedule (all 168 hours active).
  factory WeeklyScheduleMask.full() {
    return WeeklyScheduleMask._(<BigInt>[_mask64, _mask64, _mask40]);
  }

  /// Builds a schedule from a validated `List<int>` of 3 64-bit chunks.
  static Result<WeeklyScheduleMask> fromChunks(List<int> chunks) {
    if (chunks.length != chunkCount) {
      return const FailureResult<WeeklyScheduleMask>(
        ValidationFailure(
          'schedule_mask deve conter exatamente 3 blocos de 64 bits.',
          code: 'INVALID_SCHEDULE_CHUNKS',
        ),
      );
    }
    return Success<WeeklyScheduleMask>(
      WeeklyScheduleMask._(<BigInt>[
        BigInt.from(chunks[0]).toUnsigned(64),
        BigInt.from(chunks[1]).toUnsigned(64),
        BigInt.from(chunks[2]).toUnsigned(64) & _mask40,
      ]),
    );
  }

  /// Builds a schedule directly from active hour indices `0..167`.
  factory WeeklyScheduleMask.fromHours(Iterable<int> activeHours) {
    final chunks = <BigInt>[BigInt.zero, BigInt.zero, BigInt.zero];
    for (final hour in activeHours) {
      if (hour < 0 || hour >= totalHours) {
        continue;
      }
      final chunkIndex = hour ~/ 64;
      final bitOffset = hour % 64;
      chunks[chunkIndex] = chunks[chunkIndex] | (BigInt.one << bitOffset);
    }
    chunks[2] = chunks[2] & _mask40;
    return WeeklyScheduleMask._(chunks);
  }

  /// Convenience builder for 4 daily periods per day:
  /// period 0: Manhã (08..11), 1: Tarde (14..17), 2: Noite (19..22), 3: Madrugada (23, 00..02).
  factory WeeklyScheduleMask.fromDayPeriods(Map<int, Set<int>> dayPeriods) {
    final hours = <int>{};
    for (final entry in dayPeriods.entries) {
      final day = entry.key;
      if (day < 0 || day > 6) continue;
      for (final period in entry.value) {
        for (final hour in hoursForPeriod(day, period)) {
          hours.add(hour);
        }
      }
    }
    return WeeklyScheduleMask.fromHours(hours);
  }

  /// Maps `(day, periodIndex)` into concrete weekly hour indices `0..167`.
  static List<int> hoursForPeriod(int day, int periodIndex) {
    final base = day * 24;
    return switch (periodIndex) {
      0 => <int>[base + 8, base + 9, base + 10, base + 11], // Manhã
      1 => <int>[base + 14, base + 15, base + 16, base + 17], // Tarde
      2 => <int>[base + 19, base + 20, base + 21, base + 22], // Noite
      3 => <int>[
        base + 23,
        ((day + 1) % 7) * 24,
        ((day + 1) % 7) * 24 + 1,
      ], // Madrugada (wrap-around Sunday 23h -> Monday 01h)
      _ => const <int>[],
    };
  }

  /// Signed 64-bit integer representation compatible with PostgreSQL `bigint[3]`.
  List<int> get chunks => List<int>.unmodifiable(<int>[
    _rawChunks[0].toSigned(64).toInt(),
    _rawChunks[1].toSigned(64).toInt(),
    _rawChunks[2].toSigned(64).toInt(),
  ]);

  /// Checks whether hour `hourIndex` (`0..167`) is available.
  bool isAvailableAt(int hourIndex) {
    if (hourIndex < 0 || hourIndex >= totalHours) {
      return false;
    }
    final chunkIndex = hourIndex ~/ 64;
    final bitOffset = hourIndex % 64;
    return ((_rawChunks[chunkIndex] >> bitOffset) & BigInt.one) == BigInt.one;
  }

  /// Checks whether at least half of the hours in `(day, period)` are enabled.
  bool isPeriodActive(int day, int periodIndex) {
    final slotHours = hoursForPeriod(day, periodIndex);
    if (slotHours.isEmpty) return false;
    var active = 0;
    for (final h in slotHours) {
      if (isAvailableAt(h)) active++;
    }
    return active >= (slotHours.length / 2).ceil();
  }

  /// Returns a new mask with `(day, periodIndex)` toggled on/off.
  WeeklyScheduleMask togglePeriod(int day, int periodIndex) {
    final slotHours = hoursForPeriod(day, periodIndex);
    final enable = !isPeriodActive(day, periodIndex);
    final next = List<BigInt>.from(_rawChunks);
    for (final hour in slotHours) {
      final chunkIndex = hour ~/ 64;
      final bitOffset = hour % 64;
      final bit = BigInt.one << bitOffset;
      if (enable) {
        next[chunkIndex] = next[chunkIndex] | bit;
      } else {
        next[chunkIndex] = next[chunkIndex] & (_mask64 ^ bit);
      }
    }
    next[2] = next[2] & _mask40;
    return WeeklyScheduleMask._(next);
  }

  /// Bitwise AND across all 3 x 64-bit chunks (`O(1)`).
  WeeklyScheduleMask overlapWith(WeeklyScheduleMask other) {
    return WeeklyScheduleMask._(<BigInt>[
      _rawChunks[0] & other._rawChunks[0],
      _rawChunks[1] & other._rawChunks[1],
      (_rawChunks[2] & other._rawChunks[2]) & _mask40,
    ]);
  }

  /// Total number of active hours in this mask (`O(168) = O(1)`).
  int get activeHoursCount {
    var count = 0;
    for (var i = 0; i < totalHours; i++) {
      if (isAvailableAt(i)) count++;
    }
    return count;
  }

  /// Total overlapping hours between `this` and [other].
  int commonHoursCount(WeeklyScheduleMask other) {
    return overlapWith(other).activeHoursCount;
  }

  /// Dynamic Programming for Continuous Co-op Windows with circular wrap-around
  /// (Sunday 23:00 -> Monday 00:00..01:00) in `O(168)` time and `O(1)` DP state.
  ///
  /// Recurrence:
  /// `dp[t] = overlap[t] == 1 ? dp[t - 1] + 1 : 0`
  ///
  /// Non-linear reward:
  /// - Blocks of length `b >= 2` receive weight `w(b) = b + 0.5 * (b - 2)`
  /// - Isolated 1-hour blocks receive weight `0.15` (far smaller than >= 2h co-op sessions)
  /// - `score = min(1.0, totalWeight / 10.0)`
  ScheduleOverlapAnalysis analyzeContinuousWindows(WeeklyScheduleMask other) {
    final overlap = overlapWith(other);

    // Locate the first 0-bit to break circularity cleanly without double-counting.
    var firstZero = -1;
    for (var t = 0; t < totalHours; t++) {
      if (!overlap.isAvailableAt(t)) {
        firstZero = t;
        break;
      }
    }

    // All 168 hours overlap: one single continuous block covering the entire week.
    if (firstZero == -1) {
      return const ScheduleOverlapAnalysis(
        totalCommonHours: totalHours,
        usableCoopHours: totalHours,
        longestContinuousBlock: totalHours,
        continuousBlocks: <int>[totalHours],
        score: 1.0,
      );
    }

    final blocks = <int>[];
    var dpCurrent = 0;
    var totalCommon = 0;
    var longest = 0;

    for (var step = 1; step <= totalHours; step++) {
      final t = (firstZero + step) % totalHours;
      if (overlap.isAvailableAt(t)) {
        dpCurrent += 1;
        totalCommon += 1;
        if (dpCurrent > longest) {
          longest = dpCurrent;
        }
      } else {
        if (dpCurrent > 0) {
          blocks.add(dpCurrent);
          dpCurrent = 0;
        }
      }
    }

    if (dpCurrent > 0) {
      blocks.add(dpCurrent);
    }

    var usableHours = 0;
    var weightedSum = 0.0;
    for (final blockLen in blocks) {
      if (blockLen >= 2) {
        usableHours += blockLen;
        weightedSum += blockLen + 0.5 * (blockLen - 2);
      } else {
        weightedSum += 0.15;
      }
    }

    final normalizedScore = math.min(1.0, weightedSum / 10.0);

    return ScheduleOverlapAnalysis(
      totalCommonHours: totalCommon,
      usableCoopHours: usableHours,
      longestContinuousBlock: longest,
      continuousBlocks: List<int>.unmodifiable(blocks),
      score: normalizedScore,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! WeeklyScheduleMask) return false;
    return _rawChunks[0] == other._rawChunks[0] &&
        _rawChunks[1] == other._rawChunks[1] &&
        _rawChunks[2] == other._rawChunks[2];
  }

  @override
  int get hashCode => Object.hash(_rawChunks[0], _rawChunks[1], _rawChunks[2]);
}
