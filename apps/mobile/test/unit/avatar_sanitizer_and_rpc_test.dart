import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_duo/core/media/avatar_photo_sanitizer.dart';

Uint8List _uint32Le(int value) {
  final bd = ByteData(4)..setUint32(0, value, Endian.little);
  return bd.buffer.asUint8List();
}

Uint8List _uint32Be(int value) {
  final bd = ByteData(4)..setUint32(0, value, Endian.big);
  return bd.buffer.asUint8List();
}

void main() {
  group('AvatarPhotoSanitizer EXIF/Metadata Stripping', () {
    const sanitizer = AvatarPhotoSanitizer();

    test('strips APP1 EXIF/GPS and COM segments from JPEG', () {
      // Minimal synthetic JPEG: SOI + APP1(Exif GPS) + COM + SOF0 + SOS + EOI
      final exifPayload = utf8.encode('Exif\u0000\u0000GPS_LAT_23.55');
      final app1Len = 2 + exifPayload.length;
      final comPayload = utf8.encode('Camera=SecretPhone');
      final comLen = 2 + comPayload.length;

      final rawJpeg = Uint8List.fromList(<int>[
        0xFF, 0xD8, // SOI
        0xFF, 0xE1, (app1Len >> 8) & 0xFF, app1Len & 0xFF, ...exifPayload,
        0xFF, 0xFE, (comLen >> 8) & 0xFF, comLen & 0xFF, ...comPayload,
        0xFF, 0xC0, 0x00, 0x05, 0x08, 0x00, 0x01, // SOF0
        0xFF, 0xDA, 0x00, 0x03, 0x01, 0x11, 0x22, // SOS + data
        0xFF, 0xD9, // EOI
      ]);

      final result = sanitizer.sanitize(rawJpeg);
      expect(result.isSuccess, isTrue);
      final sanitized = result.valueOrNull!;
      expect(sanitized.format, AvatarImageFormat.jpeg);
      expect(sanitized.removedMetadataSegments, 2);

      final text = latin1.decode(sanitized.bytes, allowInvalid: true);
      expect(text.contains('GPS_LAT'), isFalse);
      expect(text.contains('SecretPhone'), isFalse);
      expect(sanitized.bytes.take(2), orderedEquals(<int>[0xFF, 0xD8]));
      expect(
        sanitized.bytes.sublist(sanitized.bytes.length - 2),
        orderedEquals(<int>[0xFF, 0xD9]),
      );
    });

    test('strips EXIF and XMP chunks from WebP and clears VP8X flags', () {
      final vp8xChunk = <int>[
        ...ascii.encode('VP8X'),
        ..._uint32Le(10),
        0x0C, 0x00, 0x00, 0x00, // EXIF (bit 3) + XMP (bit 2) flags set
        0x01, 0x00, 0x00,
        0x01, 0x00, 0x00,
      ];
      final vp8Chunk = <int>[
        ...ascii.encode('VP8 '),
        ..._uint32Le(4),
        0xAA,
        0xBB,
        0xCC,
        0xDD,
      ];
      final exifPayload = utf8.encode('GPS_EXIF_DATA!');
      final exifChunk = <int>[
        ...ascii.encode('EXIF'),
        ..._uint32Le(exifPayload.length),
        ...exifPayload,
      ];
      final xmpPayload = utf8.encode('<x:xmpmeta>SECRET</x:xmpmeta>');
      final xmpChunk = <int>[
        ...ascii.encode('XMP '),
        ..._uint32Le(xmpPayload.length),
        ...xmpPayload,
        if (xmpPayload.length.isOdd) 0x00,
      ];

      final body = <int>[...vp8xChunk, ...vp8Chunk, ...exifChunk, ...xmpChunk];
      final rawWebp = Uint8List.fromList(<int>[
        ...ascii.encode('RIFF'),
        ..._uint32Le(4 + body.length),
        ...ascii.encode('WEBP'),
        ...body,
      ]);

      final result = sanitizer.sanitize(rawWebp);
      expect(result.isSuccess, isTrue);
      final sanitized = result.valueOrNull!;
      expect(sanitized.format, AvatarImageFormat.webp);
      expect(sanitized.removedMetadataSegments, 2);

      final text = latin1.decode(sanitized.bytes, allowInvalid: true);
      expect(text.contains('GPS_EXIF_DATA'), isFalse);
      expect(text.contains('xmpmeta'), isFalse);
      // Verify VP8X header flag bits 2 and 3 were cleared.
      expect(sanitized.bytes[20] & 0x0C, 0);
      // Verify RIFF size updated to match payload.
      final newRiffSize = ByteData.sublistView(
        sanitized.bytes,
        4,
        8,
      ).getUint32(0, Endian.little);
      expect(newRiffSize, sanitized.bytes.length - 8);
    });

    test('strips eXIf and tEXt chunks from PNG', () {
      List<int> pngChunk(String type, List<int> data) => <int>[
        ..._uint32Be(data.length),
        ...ascii.encode(type),
        ...data,
        0x00, 0x00, 0x00, 0x00, // dummy CRC for synthetic container test
      ];

      final rawPng = Uint8List.fromList(<int>[
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
        ...pngChunk('IHDR', List<int>.filled(13, 0)),
        ...pngChunk('eXIf', utf8.encode('GPS=secret')),
        ...pngChunk('tEXt', utf8.encode('Author=Hidden')),
        ...pngChunk('IDAT', <int>[0x01, 0x02]),
        ...pngChunk('IEND', const <int>[]),
      ]);

      final result = sanitizer.sanitize(rawPng);
      expect(result.isSuccess, isTrue);
      final sanitized = result.valueOrNull!;
      expect(sanitized.format, AvatarImageFormat.png);
      expect(sanitized.removedMetadataSegments, 2);
      final text = latin1.decode(sanitized.bytes, allowInvalid: true);
      expect(text.contains('GPS=secret'), isFalse);
      expect(text.contains('Author=Hidden'), isFalse);
    });

    test('rejects empty, oversized (>1MiB), and unsupported formats', () {
      expect(sanitizer.sanitize(Uint8List(0)).isFailure, isTrue);
      expect(
        sanitizer.sanitize(Uint8List.fromList(<int>[1, 2, 3, 4])).isFailure,
        isTrue,
      );

      final oversized = Uint8List.fromList(<int>[
        0xFF,
        0xD8,
        0xFF,
        0xDA,
        0x00,
        0x03,
        ...List<int>.filled(1024 * 1024 + 50, 0x42),
        0xFF,
        0xD9,
      ]);
      expect(sanitizer.sanitize(oversized).isFailure, isTrue);
    });
  });

  group('record_swipe_and_match RPC Parser', () {
    test('parses atomic match payload and object icebreakers', () {
      final parsed = AvatarPhotoSanitizer.parseSwipeAndMatchResponse(
        <String, dynamic>{
          'matched': true,
          'match_id': '550e8400-e29b-41d4-a716-446655440001',
          'compatibility_score': 94,
          'icebreaker_prompts': <Map<String, dynamic>>[
            <String, dynamic>{
              'type': 'direct_invite',
              'game': 'Valorant',
              'prompt': 'Bora um Swiftplay hoje?',
            },
            <String, dynamic>{
              'type': 'fun_choice',
              'game': 'Valorant',
              'prompt': 'Call coordenada ou caos?',
            },
          ],
        },
      );

      expect(parsed.matched, isTrue);
      expect(parsed.matchId, '550e8400-e29b-41d4-a716-446655440001');
      expect(parsed.compatibilityScore, 94);
      expect(parsed.icebreakers, <String>[
        'Bora um Swiftplay hoje?',
        'Call coordenada ou caos?',
      ]);
    });

    test('handles non-match payload gracefully', () {
      final parsed =
          AvatarPhotoSanitizer.parseSwipeAndMatchResponse(<String, dynamic>{
            'matched': false,
            'match_id': null,
            'compatibility_score': null,
            'icebreaker_prompts': const <dynamic>[],
          });

      expect(parsed.matched, isFalse);
      expect(parsed.matchId, isNull);
      expect(parsed.icebreakers, isEmpty);
    });
  });
}
