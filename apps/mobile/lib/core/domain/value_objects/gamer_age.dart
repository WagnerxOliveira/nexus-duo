import '../../errors/app_failure.dart';

/// Immutable Value Object enforcing the strict 18+ age invariant.
class GamerAge {
  const GamerAge._({required this.birthDate, required this.years});

  static const int minimumAge = 18;
  static const int maximumAge = 110;

  final DateTime birthDate;
  final int years;

  /// Validates [birthDate] against [now] (UTC/local calendar date).
  /// Returns [ValidationFailure] if the user is under 18 or birthDate is invalid.
  static Result<GamerAge> fromBirthDate(DateTime birthDate, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    if (birthDate.isAfter(reference)) {
      return const FailureResult<GamerAge>(
        ValidationFailure(
          'Data de nascimento não pode estar no futuro.',
          code: 'BIRTH_DATE_IN_FUTURE',
        ),
      );
    }

    var age = reference.year - birthDate.year;
    final hasHadBirthdayThisYear =
        reference.month > birthDate.month ||
        (reference.month == birthDate.month && reference.day >= birthDate.day);
    if (!hasHadBirthdayThisYear) {
      age -= 1;
    }

    if (age < minimumAge) {
      return const FailureResult<GamerAge>(
        ValidationFailure(
          'O NEXUS DUO é exclusivo para maiores de 18 anos.',
          code: 'UNDERAGE_NOT_ALLOWED',
        ),
      );
    }

    if (age > maximumAge) {
      return const FailureResult<GamerAge>(
        ValidationFailure(
          'Informe uma data de nascimento válida.',
          code: 'AGE_OUT_OF_RANGE',
        ),
      );
    }

    return Success<GamerAge>(
      GamerAge._(
        birthDate: DateTime(birthDate.year, birthDate.month, birthDate.day),
        years: age,
      ),
    );
  }

  /// Validates an integer age directly when only age years are available.
  static Result<GamerAge> fromYears(int years, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    if (years < minimumAge) {
      return const FailureResult<GamerAge>(
        ValidationFailure(
          'O NEXUS DUO é exclusivo para maiores de 18 anos.',
          code: 'UNDERAGE_NOT_ALLOWED',
        ),
      );
    }
    if (years > maximumAge) {
      return const FailureResult<GamerAge>(
        ValidationFailure(
          'Idade fora do intervalo permitido.',
          code: 'AGE_OUT_OF_RANGE',
        ),
      );
    }
    return Success<GamerAge>(
      GamerAge._(
        birthDate: DateTime(
          reference.year - years,
          reference.month,
          reference.day,
        ),
        years: years,
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GamerAge && birthDate == other.birthDate && years == other.years;

  @override
  int get hashCode => Object.hash(birthDate, years);
}
