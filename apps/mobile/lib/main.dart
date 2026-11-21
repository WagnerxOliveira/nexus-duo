import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/app_config.dart';
import 'core/providers/app_providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/nexus_theme.dart';
import 'core/widgets/nexus_ui_kit.dart';
import 'core/widgets/nexus_update_widgets.dart';

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

class NexusDuoApp extends ConsumerStatefulWidget {
  const NexusDuoApp({super.key});

  @override
  ConsumerState<NexusDuoApp> createState() => _NexusDuoAppState();
}

class _NexusDuoAppState extends ConsumerState<NexusDuoApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(appUpdateControllerProvider.notifier).onAppResumed());
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'NEXUS DUO',
      debugShowCheckedModeBanner: false,
      theme: NexusTheme.dark(),
      routerConfig: router,
      builder: (context, child) => ResponsiveTextScaleGuard(
        child: NexusForceUpdateGate(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}
