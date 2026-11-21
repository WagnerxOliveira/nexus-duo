import 'dart:convert';
import 'dart:typed_data';

import '../errors/app_failure.dart';

/// Image container format supported by the avatars bucket.
enum AvatarImageFormat {
  webp('image/webp', 'webp'),
  jpeg('image/jpeg', 'jpg'),
  png('image/png', 'png');

  const AvatarImageFormat(this.mimeType, this.extension);
  final String mimeType;
  final String extension;
}

/// Result of client-side EXIF/GPS metadata removal before avatar upload.
class SanitizedAvatarImage {
  const SanitizedAvatarImage({
    required this.bytes,
    required this.format,
    required this.removedMetadataSegments,
  });

  final Uint8List bytes;
  final AvatarImageFormat format;
  final int removedMetadataSegments;
}

/// Strips EXIF, GPS, XMP, and comment metadata on-device prior to uploading
/// profile photos to Supabase Storage (`avatars` bucket, 1 MiB limit).
class AvatarPhotoSanitizer {
  const AvatarPhotoSanitizer({this.maxUploadBytes = 1024 * 1024});

  final int maxUploadBytes;

  Result<SanitizedAvatarImage> sanitize(Uint8List rawBytes) {
    if (rawBytes.isEmpty) {
      return const FailureResult<SanitizedAvatarImage>(
        ValidationFailure('A foto selecionada está vazia.'),
      );
    }

    final Result<SanitizedAvatarImage> sanitized;
    if (_isWebP(rawBytes)) {
      sanitized = _stripWebpMetadata(rawBytes);
    } else if (_isJpeg(rawBytes)) {
      sanitized = _stripJpegMetadata(rawBytes);
    } else if (_isPng(rawBytes)) {
      sanitized = _stripPngMetadata(rawBytes);
    } else {
      return const FailureResult<SanitizedAvatarImage>(
        ValidationFailure(
          'Formato de imagem não suportado. Use WebP, JPEG ou PNG.',
        ),
      );
    }

    final value = sanitized.valueOrNull;
    if (value == null) return sanitized;

    if (value.bytes.length > maxUploadBytes) {
      return FailureResult<SanitizedAvatarImage>(
        ValidationFailure(
          'Foto excede o limite de ${(maxUploadBytes / (1024 * 1024)).toStringAsFixed(1)} MiB após otimização.',
        ),
      );
    }
    return sanitized;
  }

  /// Parses `record_swipe_and_match` RPC payloads consistently.
  static ({
    bool matched,
    String? matchId,
    int compatibilityScore,
    List<String> icebreakers,
  })
  parseSwipeAndMatchResponse(
    Map<String, dynamic> payload, {
    int fallbackScore = 85,
  }) {
    final matched = (payload['matched'] as bool?) ?? false;
    final matchId = payload['match_id']?.toString();
    final score =
        (payload['compatibility_score'] as num?)?.toInt() ?? fallbackScore;
    final icebreakers = extractIcebreakerPrompts(payload['icebreaker_prompts']);
    return (
      matched: matched,
      matchId: matchId,
      compatibilityScore: score,
      icebreakers: icebreakers,
    );
  }

  /// Extracts readable prompt strings from JSONB objects or string arrays.
  static List<String> extractIcebreakerPrompts(dynamic raw) {
    if (raw is! List<dynamic>) return const <String>[];
    final prompts = <String>[];
    for (final item in raw) {
      if (item is String && item.trim().isNotEmpty) {
        prompts.add(item.trim());
      } else if (item is Map<dynamic, dynamic>) {
        final prompt = item['prompt']?.toString().trim();
        if (prompt != null && prompt.isNotEmpty) {
          prompts.add(prompt);
        }
      }
    }
    return prompts;
  }

  bool _isWebP(Uint8List b) =>
      b.length >= 12 &&
      b[0] == 0x52 &&
      b[1] == 0x49 &&
      b[2] == 0x46 &&
      b[3] == 0x46 &&
      b[8] == 0x57 &&
      b[9] == 0x45 &&
      b[10] == 0x42 &&
      b[11] == 0x50;

  bool _isJpeg(Uint8List b) => b.length >= 4 && b[0] == 0xFF && b[1] == 0xD8;

  bool _isPng(Uint8List b) =>
      b.length >= 8 &&
      b[0] == 0x89 &&
      b[1] == 0x50 &&
      b[2] == 0x4E &&
      b[3] == 0x47 &&
      b[4] == 0x0D &&
      b[5] == 0x0A &&
      b[6] == 0x1A &&
      b[7] == 0x0A;

  Result<SanitizedAvatarImage> _stripWebpMetadata(Uint8List bytes) {
    final chunks = BytesBuilder(copy: false);
    var offset = 12;
    var removed = 0;

    while (offset + 8 <= bytes.length) {
      final fourCc = ascii.decode(
        bytes.sublist(offset, offset + 4),
        allowInvalid: true,
      );
      final chunkSize = ByteData.sublistView(
        bytes,
        offset + 4,
        offset + 8,
      ).getUint32(0, Endian.little);
      final paddedSize = chunkSize + (chunkSize.isOdd ? 1 : 0);
      final nextOffset = offset + 8 + paddedSize;
      if (nextOffset > bytes.length) {
        return const FailureResult<SanitizedAvatarImage>(
          ValidationFailure('Arquivo WebP corrompido ao remover metadados.'),
        );
      }

      if (fourCc == 'EXIF' || fourCc == 'XMP ') {
        removed++;
      } else if (fourCc == 'VP8X' && chunkSize >= 4) {
        final chunk = Uint8List.fromList(bytes.sublist(offset, nextOffset));
        // Clear VP8X EXIF (bit 3) and XMP (bit 2) flags so header stays valid.
        chunk[8] = chunk[8] & ~0x0C;
        chunks.add(chunk);
      } else {
        chunks.add(bytes.sublist(offset, nextOffset));
      }
      offset = nextOffset;
    }

    final body = chunks.takeBytes();
    final riffSize = 4 + body.length;
    final out = BytesBuilder(copy: false)
      ..add(ascii.encode('RIFF'))
      ..add(_uint32Le(riffSize))
      ..add(ascii.encode('WEBP'))
      ..add(body);

    return Success<SanitizedAvatarImage>(
      SanitizedAvatarImage(
        bytes: out.takeBytes(),
        format: AvatarImageFormat.webp,
        removedMetadataSegments: removed,
      ),
    );
  }

  Result<SanitizedAvatarImage> _stripJpegMetadata(Uint8List bytes) {
    final out = BytesBuilder(copy: false)..add(<int>[0xFF, 0xD8]);
    var offset = 2;
    var removed = 0;

    while (offset < bytes.length) {
      if (bytes[offset] != 0xFF) {
        return const FailureResult<SanitizedAvatarImage>(
          ValidationFailure('Estrutura JPEG inválida ao remover EXIF.'),
        );
      }
      while (offset < bytes.length && bytes[offset] == 0xFF) {
        offset++;
      }
      if (offset >= bytes.length) break;

      final marker = bytes[offset];
      offset++;

      // End of image (EOI) or restart markers (RST0..RST7) without length.
      if (marker == 0xD9) {
        out.add(<int>[0xFF, 0xD9]);
        break;
      }
      if (marker == 0x00 || (marker >= 0xD0 && marker <= 0xD7)) {
        out.add(<int>[0xFF, marker]);
        continue;
      }

      // Start of Scan (SOS): copy header + entropy stream verbatim to EOI.
      if (marker == 0xDA) {
        out.add(<int>[0xFF, 0xDA]);
        out.add(bytes.sublist(offset));
        break;
      }

      if (offset + 2 > bytes.length) {
        return const FailureResult<SanitizedAvatarImage>(
          ValidationFailure('Segmento JPEG truncado.'),
        );
      }
      final segLen = (bytes[offset] << 8) | bytes[offset + 1];
      final segEnd = offset + segLen;
      if (segLen < 2 || segEnd > bytes.length) {
        return const FailureResult<SanitizedAvatarImage>(
          ValidationFailure('Tamanho de segmento JPEG inválido.'),
        );
      }

      // Strip APP1..APP15 (EXIF/GPS/XMP/ICC) and COM (0xFE) segments.
      final isMetadataMarker =
          (marker >= 0xE1 && marker <= 0xEF) || marker == 0xFE;
      if (isMetadataMarker) {
        removed++;
      } else {
        out.add(<int>[0xFF, marker]);
        out.add(bytes.sublist(offset, segEnd));
      }
      offset = segEnd;
    }

    return Success<SanitizedAvatarImage>(
      SanitizedAvatarImage(
        bytes: out.takeBytes(),
        format: AvatarImageFormat.jpeg,
        removedMetadataSegments: removed,
      ),
    );
  }

  Result<SanitizedAvatarImage> _stripPngMetadata(Uint8List bytes) {
    final out = BytesBuilder(copy: false)..add(bytes.sublist(0, 8));
    var offset = 8;
    var removed = 0;

    const metadataChunks = <String>{'eXIf', 'tEXt', 'iTXt', 'zTXt'};

    while (offset + 12 <= bytes.length) {
      final chunkLen = ByteData.sublistView(
        bytes,
        offset,
        offset + 4,
      ).getUint32(0, Endian.big);
      final chunkType = ascii.decode(
        bytes.sublist(offset + 4, offset + 8),
        allowInvalid: true,
      );
      final totalLen = 12 + chunkLen;
      if (offset + totalLen > bytes.length) {
        return const FailureResult<SanitizedAvatarImage>(
          ValidationFailure('Chunk PNG inválido ao remover metadados.'),
        );
      }

      if (metadataChunks.contains(chunkType)) {
        removed++;
      } else {
        out.add(bytes.sublist(offset, offset + totalLen));
      }
      offset += totalLen;
      if (chunkType == 'IEND') break;
    }

    return Success<SanitizedAvatarImage>(
      SanitizedAvatarImage(
        bytes: out.takeBytes(),
        format: AvatarImageFormat.png,
        removedMetadataSegments: removed,
      ),
    );
  }

  Uint8List _uint32Le(int value) {
    final bd = ByteData(4)..setUint32(0, value, Endian.little);
    return bd.buffer.asUint8List();
  }
}
