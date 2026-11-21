/// Normalizes UI profile fields into PostgreSQL `CHECK`-compliant values
/// (`profiles_gender_chk`, `profiles_interested_in_chk`, `profiles_username_format_chk`).
abstract final class ProfileDbNormalizer {
  static const List<String> allValidGenders = <String>[
    'woman',
    'man',
    'non_binary',
    'other',
  ];

  static String normalizeGender(String raw) {
    final normalized = raw
        .trim()
        .toLowerCase()
        .replaceAll('ã', 'a')
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('-', '_')
        .replaceAll(' ', '_');
    return switch (normalized) {
      'woman' || 'feminino' || 'mulher' || 'female' => 'woman',
      'man' || 'masculino' || 'homem' || 'male' => 'man',
      'non_binary' || 'nao_binario' || 'naobinario' => 'non_binary',
      _ => 'other',
    };
  }

  static List<String> normalizeInterestedIn(List<String> rawList) {
    final result = <String>{};
    for (final item in rawList) {
      final lower = item.trim().toLowerCase();
      if (lower == 'todos' || lower == 'all' || lower == 'qualquer') {
        result.addAll(allValidGenders);
      } else if (lower.isNotEmpty) {
        result.add(normalizeGender(item));
      }
    }
    if (result.isEmpty) {
      return List<String>.from(allValidGenders);
    }
    return result.toList(growable: false);
  }

  static String normalizeUsername(String raw, {required String userId}) {
    final cleaned = raw
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final uidSuffix = userId
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '')
        .padRight(6, '0')
        .substring(0, 6);
    if (cleaned.length >= 3) {
      return cleaned.length <= 24 ? cleaned : cleaned.substring(0, 24);
    }
    final fallback = '${cleaned.isEmpty ? 'duo' : cleaned}_$uidSuffix';
    return fallback.length <= 24 ? fallback : fallback.substring(0, 24);
  }
}
