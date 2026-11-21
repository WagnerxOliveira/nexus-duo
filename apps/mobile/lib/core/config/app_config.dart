/// Runtime configuration injected via `--dart-define`.
///
/// When [supabaseUrl] or [supabaseAnonKey] is empty, the app transparently
/// switches to [DemoSeed*] repositories so evaluators can explore every screen
/// immediately without external credentials.
class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.githubReleasesRepo,
    required this.appEnv,
  });

  factory AppConfig.fromEnvironment() {
    return const AppConfig(
      supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
      supabaseAnonKey: String.fromEnvironment('SUPABASE_ANON_KEY'),
      githubReleasesRepo: String.fromEnvironment(
        'GITHUB_RELEASES_REPO',
        defaultValue: 'WagnerxOliveira/nexus-duo',
      ),
      appEnv: String.fromEnvironment('APP_ENV', defaultValue: 'development'),
    );
  }

  final String supabaseUrl;
  final String supabaseAnonKey;
  final String githubReleasesRepo;
  final String appEnv;

  bool get isSupabaseConfigured =>
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;

  bool get isDemoMode => !isSupabaseConfigured;
}
