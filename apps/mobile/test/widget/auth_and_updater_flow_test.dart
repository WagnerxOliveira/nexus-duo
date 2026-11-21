import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexus_duo/core/providers/app_providers.dart';
import 'package:nexus_duo/core/router/app_router.dart';
import 'package:nexus_duo/core/theme/nexus_theme.dart';
import 'package:nexus_duo/core/updater/github_release_updater.dart';

class _TestApp extends ConsumerWidget {
  const _TestApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(theme: NexusTheme.dark(), routerConfig: router);
  }
}

void main() {
  testWidgets(
    'LoginScreen displays discreet Update Pill when newer CDN manifest exists',
    (tester) async {
      final mockClient = MockClient((req) async {
        if (req.url.path.endsWith('/update-manifest.json')) {
          return http.Response(
            jsonEncode(<String, dynamic>{
              'schema_version': 2,
              'app_id': 'com.nexusduo.app',
              'channel': 'stable',
              'version_name': '9.9.9',
              'version_code': 99,
              'min_supported_version_code': 1,
              'force_update': false,
              'rollout_enabled': true,
              'published_at': '2026-11-21T20:00:00Z',
              'signing_cert_sha256': 'a' * 64,
              'release_url':
                  'https://github.com/WagnerxOliveira/nexus-duo/releases/tag/v9.9.9',
              'release_notes_pt_br': <String>['Melhorias de E2EE e Auth'],
              'apks': <String, dynamic>{
                'universal': <String, dynamic>{
                  'file_name': 'nexus-duo-v9.9.9-universal.apk',
                  'url':
                      'https://github.com/WagnerxOliveira/nexus-duo/releases/download/v9.9.9/nexus-duo-v9.9.9-universal.apk',
                  'sha256': 'a' * 64,
                  'size_bytes': 52428800,
                },
              },
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      final updater = GitHubReleaseUpdater(
        httpClient: mockClient,
        installedBuildInfoProvider: () async =>
            const InstalledBuildInfo(versionName: '1.1.0', versionCode: 3),
        snoozeStore: UpdateSnoozeStore(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            releaseUpdaterProvider.overrideWithValue(updater),
            autoCheckUpdatesOnLaunchProvider.overrideWithValue(true),
          ],
          child: const _TestApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('nexus_update_pill_button')), findsOneWidget);
      expect(find.byKey(const Key('nexus_update_spotlight_cta')), findsNothing);

      await tester.tap(find.byKey(const Key('nexus_update_pill_button')));
      await tester.pumpAndSettle();
      expect(find.text('Central de Atualizações'), findsOneWidget);
      expect(find.text('Melhorias de E2EE e Auth'), findsOneWidget);
      expect(find.byKey(const Key('update_sheet_start_cta')), findsOneWidget);
      expect(find.byKey(const Key('update_sheet_snooze_cta')), findsOneWidget);
    },
  );

  testWidgets(
    'Unregistered email on Login warns user and redirects to Register -> Legal -> OTP 6 digits -> Onboarding',
    (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            autoCheckUpdatesOnLaunchProvider.overrideWithValue(false),
          ],
          child: const _TestApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Discreet pill stays hidden when auto-check is off / no update pending
      expect(find.byKey(const Key('nexus_update_pill_button')), findsNothing);

      const newEmail = 'jogador.novo@nexusduo.app';
      await tester.enterText(
        find.byKey(const Key('login_email_field')),
        newEmail,
      );
      await tester.enterText(
        find.byKey(const Key('login_password_field')),
        'K9#vQ2!pX4',
      );
      await tester.ensureVisible(find.byKey(const Key('login_submit_button')));
      await tester.tap(find.byKey(const Key('login_submit_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        find.byKey(const Key('login_account_not_found_alert')),
        findsOneWidget,
      );

      // Redirect automatically after ~1.4s with prefilled email
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pumpAndSettle();

      expect(find.text('Criar Conta NEXUS DUO'), findsOneWidget);
      expect(find.text(newEmail), findsWidgets);

      // Fill confirm email + valid 8..12 password
      await tester.enterText(
        find.byKey(const Key('register_confirm_email_field')),
        newEmail,
      );
      await tester.enterText(
        find.byKey(const Key('register_password_field')),
        'K9#vQ2!pX4',
      );
      await tester.enterText(
        find.byKey(const Key('register_confirm_password_field')),
        'K9#vQ2!pX4',
      );

      // Open Legal Terms screen and accept
      await tester.ensureVisible(find.byKey(const Key('register_terms_link')));
      await tester.tap(find.byKey(const Key('register_terms_link')));
      await tester.pumpAndSettle();
      expect(find.text('Termos, LGPD & Segurança'), findsOneWidget);
      await tester.tap(find.byKey(const Key('legal_accept_button')));
      await tester.pumpAndSettle();

      // Submit signup -> Email OTP verification
      await tester.ensureVisible(
        find.byKey(const Key('register_submit_button')),
      );
      await tester.tap(find.byKey(const Key('register_submit_button')));
      await tester.pumpAndSettle();

      expect(find.text('Verifique seu E-mail'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('otp_box_0')), '123456');
      await tester.pumpAndSettle();

      expect(find.textContaining('Passo 1 de 4'), findsOneWidget);
    },
  );

  testWidgets(
    'Forgot Password -> OTP 6 digits -> Reset Password updates password end-to-end',
    (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            autoCheckUpdatesOnLaunchProvider.overrideWithValue(false),
          ],
          child: const _TestApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('login_forgot_password_link')),
      );
      await tester.tap(find.byKey(const Key('login_forgot_password_link')));
      await tester.pumpAndSettle();
      expect(find.text('Esqueci a minha senha'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('forgot_email_field')),
        'clara@nexusduo.app',
      );
      await tester.ensureVisible(find.byKey(const Key('forgot_submit_button')));
      await tester.tap(find.byKey(const Key('forgot_submit_button')));
      await tester.pumpAndSettle();

      expect(find.text('Confirme o Código de Recuperação'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('otp_box_0')), '123456');
      await tester.pumpAndSettle();

      expect(find.text('Definir Nova Senha'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('reset_new_password_field')),
        'Z8#mT4!qW2',
      );
      await tester.enterText(
        find.byKey(const Key('reset_confirm_password_field')),
        'Z8#mT4!qW2',
      );
      await tester.ensureVisible(find.byKey(const Key('reset_submit_button')));
      await tester.tap(find.byKey(const Key('reset_submit_button')));
      await tester.pumpAndSettle();

      expect(find.text('Senha alterada com sucesso!'), findsOneWidget);
    },
  );
}
