import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/app_config.dart';
import 'core/router/app_router.dart';
import 'core/theme/nexus_theme.dart';
import 'core/widgets/nexus_ui_kit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();
  if (config.isSupabaseConfigured) {
    await Supabase.initialize(
      url: config.supabaseUrl,
      publishableKey: config.supabaseAnonKey,
    );
  }
  runApp(const ProviderScope(child: NexusDuoApp()));
}

class NexusDuoApp extends ConsumerWidget {
  const NexusDuoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'NEXUS DUO',
      debugShowCheckedModeBanner: false,
      theme: NexusTheme.dark(),
      routerConfig: router,
      builder: (context, child) =>
          ResponsiveTextScaleGuard(child: child ?? const SizedBox.shrink()),
    );
  }
}
