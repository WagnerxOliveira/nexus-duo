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
    'LoginScreen displays stylish Update Pill & Spotlight Card when newer release exists',
    (tester) async {
      final mockClient = MockClient((req) async {
        if (req.url.path.endsWith('/releases/latest')) {
          return http.Response(
            jsonEncode(<String, dynamic>{
              'tag_name': 'v9.9.9',
              'body': 'Melhorias de E2EE e Auth',
              'html_url':
                  'https://github.com/WagnerxOliveira/nexus-duo/releases/tag/v9.9.9',
              'assets': <Map<String, dynamic>>[
                <String, dynamic>{
                  'name': 'nexus-duo-v9.9.9-universal.apk',
                  'size': 52428800,
                  'browser_download_url': 'https://example.com/app.apk',
                },
                <String, dynamic>{
                  'name': 'SHA256SUMS.txt',
                  'browser_download_url': 'https://example.com/SHA256SUMS.txt',
                },
              ],
            }),
            200,
          );
        }
        return http.Response(
          '${'a' * 64}  nexus-duo-v9.9.9-universal.apk\n',
          200,
        );
      });

      final updater = GitHubReleaseUpdater(
        httpClient: mockClient,
        currentVersionProvider: () async => '1.1.0',
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
      expect(
        find.byKey(const Key('nexus_update_spotlight_cta')),
        findsOneWidget,
      );
      expect(
        find.textContaining('Atualizar Agora para v9.9.9'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('nexus_update_pill_button')));
      await tester.pumpAndSettle();
      expect(find.text('Central de Atualizações'), findsOneWidget);
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

      // Always-visible stylish update button is present even with no pending update
      expect(find.byKey(const Key('nexus_update_pill_button')), findsOneWidget);

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
