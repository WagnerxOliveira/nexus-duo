import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/email_otp_verification_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/reset_password_screen.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/discovery/domain/discovery_entities.dart';
import '../../features/discovery/presentation/match_celebration_screen.dart';
import '../../features/legal/presentation/legal_terms_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/shared/domain/nexus_repositories.dart';
import '../providers/app_providers.dart';
import 'app_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    routes: <RouteBase>[
      GoRoute(
        path: '/login',
        builder: (context, state) =>
            LoginScreen(prefilledEmail: state.uri.queryParameters['email']),
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) =>
            LoginScreen(prefilledEmail: state.uri.queryParameters['email']),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) =>
            RegisterScreen(initialEmail: state.uri.queryParameters['email']),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => ForgotPasswordScreen(
          initialEmail: state.uri.queryParameters['email'],
        ),
      ),
      GoRoute(
        path: '/verify-otp',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is OtpFlowArgs) {
            return EmailOtpVerificationScreen(args: extra);
          }
          final email =
              state.uri.queryParameters['email'] ?? 'voce@nexusduo.app';
          return EmailOtpVerificationScreen(
            args: OtpFlowArgs(
              email: email,
              maskedEmail: email,
              purpose: OtpPurpose.signupVerify,
            ),
          );
        },
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is ResetPasswordArgs) {
            return ResetPasswordScreen(args: extra);
          }
          return const ResetPasswordScreen(
            args: ResetPasswordArgs(email: 'voce@nexusduo.app', resetToken: ''),
          );
        },
      ),
      GoRoute(
        path: '/legal',
        builder: (context, state) {
          final tab =
              int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0;
          return LegalTermsScreen(initialTabIndex: tab);
        },
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
