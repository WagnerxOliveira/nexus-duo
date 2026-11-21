import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../features/discovery/domain/discovery_entities.dart';
import '../../features/discovery/domain/match_scoring_strategy.dart';
import '../../features/lobby/domain/duo_lobby.dart';
import '../../features/profile/domain/gamer_profile.dart';
import '../../features/shared/data/demo_seed_repositories.dart';
import '../../features/shared/data/supabase_repositories.dart';
import '../../features/shared/domain/nexus_repositories.dart';
import '../config/app_config.dart';
import '../crypto/e2ee_cipher.dart';
import '../crypto/flutter_secure_key_vault.dart';
import '../updater/app_update_controller.dart';
import '../updater/github_release_updater.dart';

final appConfigProvider = Provider<AppConfig>((ref) {
  return AppConfig.fromEnvironment();
});

final supabaseClientOrNullProvider = Provider<sb.SupabaseClient?>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.isSupabaseConfigured) return null;
  try {
    return sb.Supabase.instance.client;
  } catch (_) {
    return null;
  }
});

/// Allows users on cloud-configured APKs to explore Demo Mode at runtime.
final runtimeDemoOverrideProvider = StateProvider<bool>((ref) => false);

final demoSeedStoreProvider = Provider<DemoSeedStore>((ref) {
  return DemoSeedStore();
});

final messageCipherProvider = Provider<IMessageCipher>((ref) {
  final config = ref.watch(appConfigProvider);
  final useDemo = config.isDemoMode || ref.watch(runtimeDemoOverrideProvider);
  if (useDemo) {
    return ref.watch(demoSeedStoreProvider).myCipher;
  }
  return AesGcmE2EECipher(keyVault: FlutterSecureKeyVault());
});

final authRepositoryProvider = Provider<IAuthRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  final useDemo = config.isDemoMode || ref.watch(runtimeDemoOverrideProvider);
  if (!useDemo) {
    return SupabaseAuthRepository(sb.Supabase.instance.client);
  }
  return DemoSeedAuthRepository(ref.watch(demoSeedStoreProvider));
});

final profileRepositoryProvider = Provider<IProfileRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  final useDemo = config.isDemoMode || ref.watch(runtimeDemoOverrideProvider);
  if (!useDemo) {
    return SupabaseProfileRepository(
      sb.Supabase.instance.client,
      ref.watch(messageCipherProvider),
    );
  }
  return DemoSeedProfileRepository(ref.watch(demoSeedStoreProvider));
});

final discoveryRepositoryProvider = Provider<IDiscoveryRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  final useDemo = config.isDemoMode || ref.watch(runtimeDemoOverrideProvider);
  if (!useDemo) {
    return SupabaseDiscoveryRepository(sb.Supabase.instance.client);
  }
  return DemoSeedDiscoveryRepository(ref.watch(demoSeedStoreProvider));
});

final lobbyRepositoryProvider = Provider<ILobbyRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  final useDemo = config.isDemoMode || ref.watch(runtimeDemoOverrideProvider);
  if (!useDemo) {
    return SupabaseLobbyRepository(sb.Supabase.instance.client);
  }
  return DemoSeedLobbyRepository(ref.watch(demoSeedStoreProvider));
});

final chatRepositoryProvider = Provider<IChatRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  final useDemo = config.isDemoMode || ref.watch(runtimeDemoOverrideProvider);
  if (!useDemo) {
    return SupabaseChatRepository(
      sb.Supabase.instance.client,
      ref.watch(messageCipherProvider),
    );
  }
  return DemoSeedChatRepository(ref.watch(demoSeedStoreProvider));
});

final scoringStrategyProvider = StateProvider<IMatchScoringStrategy>((ref) {
  return const HybridGamerScoringStrategy();
});

final releaseUpdaterProvider = Provider<GitHubReleaseUpdater>((ref) {
  final config = ref.watch(appConfigProvider);
  return GitHubReleaseUpdater(
    repository: config.githubReleasesRepo,
    supabaseUrl: config.supabaseUrl,
    supabaseAnonKey: config.supabaseAnonKey,
  );
});

final autoCheckUpdatesOnLaunchProvider = Provider<bool>((ref) => true);

final appUpdateControllerProvider =
    StateNotifierProvider<AppUpdateController, AppUpdateState>((ref) {
      final controller = AppUpdateController(ref.watch(releaseUpdaterProvider));
      controller.initializeAndAutoCheck(
        autoCheck: ref.watch(autoCheckUpdatesOnLaunchProvider),
      );
      return controller;
    });

final authSessionProvider = StateProvider<AuthSession?>((ref) => null);

final myProfileProvider = StateProvider<GamerProfile>((ref) {
  return ref.watch(demoSeedStoreProvider).myProfile;
});

final latestCelebrationMatchProvider = StateProvider<DuoMatch?>((ref) => null);

final discoveryDeckProvider =
    FutureProvider.autoDispose<List<DiscoveryCandidate>>((ref) async {
      final repo = ref.watch(discoveryRepositoryProvider);
      final me = ref.watch(myProfileProvider);
      final strategy = ref.watch(scoringStrategyProvider);
      final result = await repo.fetchDailyLootDrop(me: me, strategy: strategy);
      return result.valueOrNull ?? const <DiscoveryCandidate>[];
    });

final matchesProvider = FutureProvider.autoDispose<List<DuoMatch>>((ref) async {
  final repo = ref.watch(discoveryRepositoryProvider);
  final result = await repo.fetchMatches();
  return result.valueOrNull ?? const <DuoMatch>[];
});

final lobbyGameFilterProvider = StateProvider<String>((ref) => 'Todos');
final lobbyModeFilterProvider = StateProvider<LobbyMode?>((ref) => null);

final activeLobbiesProvider = FutureProvider.autoDispose<List<DuoLobby>>((
  ref,
) async {
  final repo = ref.watch(lobbyRepositoryProvider);
  final game = ref.watch(lobbyGameFilterProvider);
  final mode = ref.watch(lobbyModeFilterProvider);
  final result = await repo.fetchActiveLobbies(
    gameFilter: game,
    modeFilter: mode,
  );
  return result.valueOrNull ?? const <DuoLobby>[];
});
