import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/welcome_screen.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/discovery/domain/discovery_entities.dart';
import '../../features/discovery/presentation/match_celebration_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../providers/app_providers.dart';
import 'app_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/welcome',
    routes: <RouteBase>[
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(path: '/app', builder: (context, state) => const NexusAppShell()),
      GoRoute(
        path: '/match-celebration',
        builder: (context, state) => const MatchCelebrationScreen(),
      ),
      GoRoute(
        path: '/chat/:matchId',
        builder: (context, state) {
          final extraMatch = state.extra;
          if (extraMatch is DuoMatch) {
            return ChatScreen(match: extraMatch);
          }
          final matchId = state.pathParameters['matchId'];
          final store = ref.read(demoSeedStoreProvider);
          final found = store.matches.firstWhere(
            (m) => m.id == matchId,
            orElse: () => store.matches.first,
          );
          return ChatScreen(match: found);
        },
      ),
    ],
  );
});
