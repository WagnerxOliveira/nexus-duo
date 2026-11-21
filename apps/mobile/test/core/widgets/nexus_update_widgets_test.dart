import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexus_duo/core/providers/app_providers.dart';
import 'package:nexus_duo/core/theme/nexus_theme.dart';
import 'package:nexus_duo/core/updater/github_release_updater.dart';
import 'package:nexus_duo/core/widgets/nexus_ui_kit.dart';
import 'package:nexus_duo/core/widgets/nexus_update_widgets.dart';
import 'package:nexus_duo/features/auth/presentation/login_screen.dart';

Map<String, dynamic> _manifestPayload({
  required String versionName,
  required int versionCode,
  bool forceUpdate = false,
  String? sha256Hex,
  int sizeBytes = 48000000,
}) {
  return <String, dynamic>{
    'schema_version': 2,
    'app_id': 'com.nexusduo.app',
    'channel': 'stable',
    'version_name': versionName,
    'version_code': versionCode,
    'min_supported_version_code': 1,
    'force_update': forceUpdate,
    'rollout_enabled': true,
    'published_at': '2026-11-21T20:00:00Z',
    'signing_cert_sha256': 'a' * 64,
    'release_url':
        'https://github.com/WagnerxOliveira/nexus-duo/releases/tag/v$versionName',
    'release_notes_pt_br': <String>[
      'Atualização discreta com 1 toque sem sair do app.',
      'Instalação automática ao retornar dos Ajustes.',
    ],
    'apks': <String, dynamic>{
      'arm64-v8a': <String, dynamic>{
        'file_name': 'nexus-duo-v$versionName-arm64-v8a.apk',
        'url':
            'https://github.com/WagnerxOliveira/nexus-duo/releases/download/v$versionName/nexus-duo-v$versionName-arm64-v8a.apk',
        'sha256': sha256Hex ?? ('a' * 64),
        'size_bytes': sizeBytes,
      },
    },
  };
}

void main() {
  testWidgets('Discreet pill stays completely hidden when up-to-date', (
    tester,
  ) async {
    final updater = GitHubReleaseUpdater(
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode(_manifestPayload(versionName: '1.1.0', versionCode: 3)),
          200,
        ),
      ),
      installedBuildInfoProvider: () async => const InstalledBuildInfo(
        versionName: '1.1.0',
        versionCode: 3,
        supportedAbis: <String>['arm64-v8a'],
      ),
      snoozeStore: UpdateSnoozeStore(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          releaseUpdaterProvider.overrideWithValue(updater),
          autoCheckUpdatesOnLaunchProvider.overrideWithValue(true),
        ],
        child: MaterialApp(theme: NexusTheme.dark(), home: const LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('nexus_update_pill_button')), findsNothing);
    expect(find.byKey(const Key('nexus_update_spotlight_cta')), findsNothing);
  });

  testWidgets(
    'Discreet pill appears on new release, snoozes for 24h on "Lembrar depois", and tracks minimized download',
    (tester) async {
      final tempDir = Directory.systemTemp.createTempSync('nexus_widget_dl_');
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });
      final streamGate = Completer<void>();
      final apkBytes = utf8.encode('FAKE-STREAM-APK-FOR-WIDGET-TEST');
      final apkSha = sha256.convert(apkBytes).toString();

      final client = MockClient.streaming((req, _) async {
        if (req.url.path.endsWith('/update-manifest.json')) {
          final body = utf8.encode(
            jsonEncode(
              _manifestPayload(
                versionName: '1.2.0',
                versionCode: 4,
                sha256Hex: apkSha,
                sizeBytes: apkBytes.length * 4,
              ),
            ),
          );
          return http.StreamedResponse(
            Stream<List<int>>.value(body),
            200,
            contentLength: body.length,
          );
        }
        final controller = StreamController<List<int>>();
        controller.add(apkBytes);
        unawaited(
          streamGate.future.then((_) {
            if (!controller.isClosed) controller.close();
          }),
        );
        return http.StreamedResponse(
          controller.stream,
          200,
          contentLength: apkBytes.length * 4,
        );
      });

      final updater = GitHubReleaseUpdater(
        httpClient: client,
        defaultDownloadDirectory: tempDir,
        installedBuildInfoProvider: () async => const InstalledBuildInfo(
          versionName: '1.1.0',
          versionCode: 3,
          supportedAbis: <String>['arm64-v8a'],
        ),
        availableStorageBytesProvider: () async => 500 * 1024 * 1024,
        snoozeStore: UpdateSnoozeStore(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            releaseUpdaterProvider.overrideWithValue(updater),
            autoCheckUpdatesOnLaunchProvider.overrideWithValue(true),
          ],
          child: MaterialApp(
            theme: NexusTheme.dark(),
            home: const LoginScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Pill appears discreetly
      expect(find.byKey(const Key('nexus_update_pill_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('nexus_update_pill_button')));
      await tester.pumpAndSettle();

      expect(find.text('Central de Atualizações'), findsOneWidget);
      expect(
        find.text('Atualização discreta com 1 toque sem sair do app.'),
        findsOneWidget,
      );

      // Start download -> Minimize -> verify % pill & Cancel
      await tester.tap(find.byKey(const Key('update_sheet_start_cta')));
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        find.byKey(const Key('update_sheet_minimize_cta')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('update_sheet_minimize_cta')));
      await tester.pumpAndSettle();

      // Pill displays percentage while minimized
      expect(find.byKey(const Key('nexus_update_pill_button')), findsOneWidget);
      expect(find.textContaining('%'), findsOneWidget);

      // Re-open sheet and cancel
      await tester.tap(find.byKey(const Key('nexus_update_pill_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('update_sheet_cancel_cta')));
      if (!streamGate.isCompleted) streamGate.complete();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();

      // Snooze ("Lembrar depois") hides discreet pill immediately
      await tester.tap(find.byKey(const Key('update_sheet_snooze_cta')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('nexus_update_pill_button')), findsNothing);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
    },
  );

  testWidgets(
    'NexusForceUpdateGate blocks navigation when force_update is active',
    (tester) async {
      final updater = GitHubReleaseUpdater(
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode(
              _manifestPayload(
                versionName: '1.2.0',
                versionCode: 4,
                forceUpdate: true,
              ),
            ),
            200,
          ),
        ),
        installedBuildInfoProvider: () async => const InstalledBuildInfo(
          versionName: '1.1.0',
          versionCode: 3,
          supportedAbis: <String>['arm64-v8a'],
        ),
        snoozeStore: UpdateSnoozeStore(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            releaseUpdaterProvider.overrideWithValue(updater),
            autoCheckUpdatesOnLaunchProvider.overrideWithValue(true),
          ],
          child: MaterialApp(
            theme: NexusTheme.dark(),
            builder: (context, child) =>
                NexusForceUpdateGate(child: child ?? const SizedBox.shrink()),
            home: const Scaffold(body: Text('Main Content Behind Gate')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('nexus_force_update_gate')), findsOneWidget);
      expect(find.text('Atualização Obrigatória'), findsOneWidget);
      expect(find.byKey(const Key('update_sheet_snooze_cta')), findsNothing);
    },
  );

  const viewports = <Size>[
    Size(320, 568),
    Size(360, 640),
    Size(412, 915),
    Size(768, 1024),
    Size(1440, 900),
  ];

  for (final vp in viewports) {
    testWidgets(
      'Discreet update pill + sheet renders zero-overflow at ${vp.width.toInt()}x${vp.height.toInt()} (1.3x scale)',
      (tester) async {
        final errors = <FlutterErrorDetails>[];
        final prevHandler = FlutterError.onError;
        FlutterError.onError = errors.add;
        tester.view.physicalSize = vp;
        tester.view.devicePixelRatio = 1.0;

        try {
          final updater = GitHubReleaseUpdater(
            httpClient: MockClient(
              (_) async => http.Response(
                jsonEncode(
                  _manifestPayload(versionName: '1.2.0', versionCode: 4),
                ),
                200,
              ),
            ),
            installedBuildInfoProvider: () async => const InstalledBuildInfo(
              versionName: '1.1.0',
              versionCode: 3,
              supportedAbis: <String>['arm64-v8a'],
            ),
            snoozeStore: UpdateSnoozeStore(),
          );

          await tester.pumpWidget(
            ProviderScope(
              overrides: <Override>[
                releaseUpdaterProvider.overrideWithValue(updater),
                autoCheckUpdatesOnLaunchProvider.overrideWithValue(true),
              ],
              child: MaterialApp(
                theme: NexusTheme.dark(),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(1.3)),
                  child: ResponsiveTextScaleGuard(
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
                home: const LoginScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.byKey(const Key('nexus_update_pill_button')),
            findsOneWidget,
          );
          await tester.tap(find.byKey(const Key('nexus_update_pill_button')));
          await tester.pumpAndSettle();
          expect(find.text('Central de Atualizações'), findsOneWidget);
          expect(errors, isEmpty);
        } finally {
          FlutterError.onError = prevHandler;
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        }
      },
    );
  }
}
