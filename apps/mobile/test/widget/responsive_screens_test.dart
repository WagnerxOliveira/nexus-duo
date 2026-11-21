import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_duo/core/providers/app_providers.dart';
import 'package:nexus_duo/core/router/app_shell.dart';
import 'package:nexus_duo/core/theme/nexus_theme.dart';
import 'package:nexus_duo/core/widgets/nexus_ui_kit.dart';
import 'package:nexus_duo/features/auth/presentation/welcome_screen.dart';
import 'package:nexus_duo/features/chat/presentation/chat_screen.dart';
import 'package:nexus_duo/features/discovery/presentation/match_celebration_screen.dart';
import 'package:nexus_duo/features/onboarding/presentation/onboarding_screen.dart';
import 'package:nexus_duo/features/shared/data/demo_seed_repositories.dart';

const List<({String name, Size size})> _viewports =
    <({String name, Size size})>[
      (name: 'Mobile Compact 360x800', size: Size(360, 800)),
      (name: 'Mobile Standard 412x915', size: Size(412, 915)),
      (name: 'Tablet 768x1024', size: Size(768, 1024)),
      (name: 'Desktop 1280x800', size: Size(1280, 800)),
    ];

Future<void> _pumpAndAssertZeroOverflow(
  WidgetTester tester, {
  required Widget screen,
  required Size viewport,
}) async {
  final capturedErrors = <FlutterErrorDetails>[];
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    capturedErrors.add(details);
  };

  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1.0;

  try {
    await tester.pumpWidget(
      ProviderScope(
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
          home: screen,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final overflowErrors = capturedErrors
        .where(
          (e) =>
              e.exceptionAsString().contains('RenderFlex overflowed') ||
              e.exceptionAsString().contains('OVERFLOWING'),
        )
        .toList();

    expect(
      overflowErrors,
      isEmpty,
      reason:
          'Overflow detected at ${viewport.width}x${viewport.height} (textScaleFactor 1.3): '
          '${overflowErrors.map((e) => e.exceptionAsString()).join('\n')}',
    );
    expect(
      capturedErrors,
      isEmpty,
      reason:
          'Unexpected Flutter errors at ${viewport.width}x${viewport.height}: '
          '${capturedErrors.map((e) => e.exceptionAsString()).join('\n')}',
    );
  } finally {
    FlutterError.onError = originalOnError;
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }
}

void main() {
  final seedStore = DemoSeedStore();
  final seededMatch = seedStore.matches.first;

  for (final vp in _viewports) {
    group('Responsive zero-overflow @ ${vp.name} (textScaleFactor: 1.3)', () {
      testWidgets('WelcomeScreen renders cleanly', (tester) async {
        await _pumpAndAssertZeroOverflow(
          tester,
          screen: const WelcomeScreen(),
          viewport: vp.size,
        );
        expect(find.text('NEXUS DUO'), findsOneWidget);
        expect(find.text('Entrar em Modo Demo Instantâneo'), findsOneWidget);
      });

      testWidgets('OnboardingScreen renders cleanly', (tester) async {
        await _pumpAndAssertZeroOverflow(
          tester,
          screen: const OnboardingScreen(),
          viewport: vp.size,
        );
        expect(find.textContaining('Passo 1 de 4'), findsOneWidget);
      });

      testWidgets('Discovery Daily Loot Drop renders cleanly', (tester) async {
        await _pumpAndAssertZeroOverflow(
          tester,
          screen: const NexusAppShell(initialTabIndex: 0),
          viewport: vp.size,
        );
        expect(find.text('Daily Loot Drop'), findsOneWidget);
      });

      testWidgets('Lobby Duo Agora renders cleanly', (tester) async {
        await _pumpAndAssertZeroOverflow(
          tester,
          screen: const NexusAppShell(initialTabIndex: 1),
          viewport: vp.size,
        );
        expect(find.text('Lobby "Duo Agora"'), findsOneWidget);
      });

      testWidgets('MatchCelebrationScreen renders cleanly', (tester) async {
        await _pumpAndAssertZeroOverflow(
          tester,
          screen: MatchCelebrationScreen(matchOverride: seededMatch),
          viewport: vp.size,
        );
        expect(find.text('IT\'S A DUO!'), findsOneWidget);
      });

      testWidgets('ChatScreen E2EE renders cleanly & reveals blurred media', (
        tester,
      ) async {
        await _pumpAndAssertZeroOverflow(
          tester,
          screen: ChatScreen(match: seededMatch),
          viewport: vp.size,
        );
        expect(
          find.textContaining('Criptografado ponta a ponta'),
          findsOneWidget,
        );
        final blurTile = find.text('Mídia protegida • Toque para revelar');
        expect(blurTile, findsOneWidget);
        await tester.tap(blurTile);
        await tester.pumpAndSettle();
        expect(find.text('Mídia protegida • Toque para revelar'), findsNothing);
      });

      testWidgets('ProfileScreen & 9:16 Gamer DNA Card render cleanly', (
        tester,
      ) async {
        await _pumpAndAssertZeroOverflow(
          tester,
          screen: const NexusAppShell(initialTabIndex: 3),
          viewport: vp.size,
        );
        expect(find.text('Meu Perfil & Gamer DNA'), findsOneWidget);
        expect(find.text('Exportar Gamer DNA Card (9:16)'), findsOneWidget);
      });
    });
  }

  testWidgets('ChatScreen encrypts and appends new message via DemoSeed E2EE', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final match = container.read(demoSeedStoreProvider).matches.first;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: NexusTheme.dark(),
          home: ChatScreen(match: match),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Bora Swiftplay às 21h!');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Bora Swiftplay às 21h!'), findsOneWidget);
  });
}
