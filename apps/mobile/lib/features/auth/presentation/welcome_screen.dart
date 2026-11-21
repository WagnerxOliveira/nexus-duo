import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_design_tokens/nexus_tokens.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/providers/app_providers.dart';
import '../../../core/widgets/nexus_ui_kit.dart';

/// Screen 1 — Splash & Welcome Cinemático (Aura Cyber-Velvet).
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  StreamSubscription<sb.AuthState>? _authSub;
  bool _showEmailForm = false;
  bool _isSignUpMode = false;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isInfoBanner = false;

  @override
  void initState() {
    super.initState();
    _attachSupabaseAuthListener();
  }

  void _attachSupabaseAuthListener() {
    final config = ref.read(appConfigProvider);
    if (!config.isSupabaseConfigured) return;
    try {
      final client = sb.Supabase.instance.client;
      _authSub = client.auth.onAuthStateChange.listen((data) {
        if (!mounted) return;
        if (data.event == sb.AuthChangeEvent.signedIn &&
            data.session != null &&
            !ref.read(runtimeDemoOverrideProvider)) {
          _syncSessionAndNavigate();
        }
      });
      if (client.auth.currentSession != null) {
        Future<void>.microtask(_syncSessionAndNavigate);
      }
    } catch (_) {
      // Safe no-op when Supabase singleton is not initialized (e.g. widget tests).
    }
  }

  Future<void> _syncSessionAndNavigate() async {
    final session = await ref.read(authRepositoryProvider).currentSession();
    if (!mounted || session == null) return;
    ref.read(authSessionProvider.notifier).state = session;
    context.go(session.hasCompletedOnboarding ? '/app' : '/onboarding');
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleDiscordLogin() async {
    ref.read(runtimeDemoOverrideProvider.notifier).state = false;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isInfoBanner = false;
    });
    final res = await ref.read(authRepositoryProvider).signInWithDiscord();
    if (!mounted) return;
    setState(() => _isLoading = false);
    res.fold(
      onSuccess: (session) {
        ref.read(authSessionProvider.notifier).state = session;
        context.go(session.hasCompletedOnboarding ? '/app' : '/onboarding');
      },
      onFailure: (failure) {
        setState(() {
          _isInfoBanner = failure.code == 'OAUTH_PENDING';
          _errorMessage = failure.code == 'OAUTH_PENDING'
              ? 'Conclua o login com Discord no navegador e retorne ao app.'
              : failure.message;
        });
      },
    );
  }

  Future<void> _handleEmailSubmit() async {
    ref.read(runtimeDemoOverrideProvider.notifier).state = false;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isInfoBanner = false;
    });
    final authRepo = ref.read(authRepositoryProvider);
    final res = _isSignUpMode
        ? await authRepo.signUpWithEmail(
            email: _emailController.text,
            password: _passwordController.text,
          )
        : await authRepo.signInWithEmail(
            email: _emailController.text,
            password: _passwordController.text,
          );
    if (!mounted) return;
    setState(() => _isLoading = false);
    res.fold(
      onSuccess: (session) {
        ref.read(authSessionProvider.notifier).state = session;
        context.go(session.hasCompletedOnboarding ? '/app' : '/onboarding');
      },
      onFailure: (failure) {
        setState(() {
          _isInfoBanner = failure.code == 'AUTH_CONFIRM_EMAIL';
          _errorMessage = failure.message;
        });
      },
    );
  }

  Future<void> _handleInstantDemo() async {
    ref.read(runtimeDemoOverrideProvider.notifier).state = true;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isInfoBanner = false;
    });
    final res = await ref.read(authRepositoryProvider).enterDemoMode();
    if (!mounted) return;
    setState(() => _isLoading = false);
    res.fold(
      onSuccess: (session) {
        ref.read(authSessionProvider.notifier).state = session;
        context.go('/app');
      },
      onFailure: (failure) {
        setState(() => _errorMessage = failure.message);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalPad = screenWidth < NexusBreakpoints.mobileCompactMax
        ? NexusSpacing.pageCompact
        : NexusSpacing.pageStandard;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // Ambient Cyber-Velvet radial aura
          const DecoratedBox(
            decoration: BoxDecoration(
              color: NexusColors.bgVoid,
              gradient: RadialGradient(
                center: Alignment(-0.4, -0.7),
                radius: 1.35,
                colors: <Color>[
                  Color(0x3D8B5CF6),
                  Color(0x1F06B6D4),
                  NexusColors.bgVoid,
                ],
                stops: <double>[0.0, 0.45, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPad,
                  vertical: NexusSpacing.lg,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: NexusBrandLogo(),
                      ),
                      const SizedBox(height: NexusSpacing.xl),
                      Wrap(
                        spacing: NexusSpacing.sm,
                        runSpacing: NexusSpacing.sm,
                        children: <Widget>[
                          const _TrustPill(
                            icon: Icons.lock_outline_rounded,
                            label: 'Chat E2EE X25519',
                            color: NexusColors.accentCyber,
                          ),
                          const _TrustPill(
                            icon: Icons.verified_user_outlined,
                            label: 'Liveness 18+',
                            color: NexusColors.semanticSuccess,
                          ),
                          if (config.isDemoMode)
                            const _TrustPill(
                              icon: Icons.bolt_rounded,
                              label: 'Modo Demo Pronto',
                              color: NexusColors.brandSecondary,
                            ),
                        ],
                      ),
                      const SizedBox(height: NexusSpacing.lg),
                      Text(
                        'Encontre seu Duo na vida e no jogo.',
                        style: Theme.of(context).textTheme.displayLarge,
                      ),
                      const SizedBox(height: NexusSpacing.md),
                      Text(
                        'Compatibilidade real de jogos, horários contínuos em comum, chat criptografado ponta a ponta e zero swipe tóxico.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: NexusColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: NexusSpacing.xl),
                      NexusGlassCard(
                        glow: true,
                        padding: const EdgeInsets.all(NexusSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            NexusGradientButton(
                              label: 'Entrar com Discord',
                              icon: Icons.headset_mic_rounded,
                              isLoading: _isLoading,
                              onPressed: _handleDiscordLogin,
                            ),
                            const SizedBox(height: NexusSpacing.md),
                            OutlinedButton.icon(
                              onPressed: _isLoading
                                  ? null
                                  : () => setState(
                                      () => _showEmailForm = !_showEmailForm,
                                    ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: NexusColors.textPrimary,
                                side: const BorderSide(
                                  color: NexusColors.borderSubtle,
                                ),
                                minimumSize: const Size.fromHeight(48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    NexusRadii.md,
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.mail_outline_rounded),
                              label: const Text('Continuar com Email'),
                            ),
                            if (_showEmailForm) ...<Widget>[
                              const SizedBox(height: NexusSpacing.md),
                              Wrap(
                                spacing: NexusSpacing.sm,
                                children: <Widget>[
                                  ChoiceChip(
                                    label: const Text('Entrar'),
                                    selected: !_isSignUpMode,
                                    onSelected: _isLoading
                                        ? null
                                        : (_) => setState(
                                            () => _isSignUpMode = false,
                                          ),
                                  ),
                                  ChoiceChip(
                                    label: const Text('Criar Conta'),
                                    selected: _isSignUpMode,
                                    onSelected: _isLoading
                                        ? null
                                        : (_) => setState(
                                            () => _isSignUpMode = true,
                                          ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: NexusSpacing.sm),
                              TextField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                  hintText: 'voce@nexusduo.app',
                                ),
                              ),
                              const SizedBox(height: NexusSpacing.sm),
                              TextField(
                                controller: _passwordController,
                                obscureText: true,
                                decoration: InputDecoration(
                                  labelText: 'Senha',
                                  hintText: _isSignUpMode
                                      ? 'Mínimo 8 caracteres (letras e números)'
                                      : 'Sua senha',
                                ),
                              ),
                              const SizedBox(height: NexusSpacing.md),
                              FilledButton(
                                onPressed: _isLoading
                                    ? null
                                    : _handleEmailSubmit,
                                style: FilledButton.styleFrom(
                                  backgroundColor: NexusColors.brandPrimary,
                                  minimumSize: const Size.fromHeight(46),
                                ),
                                child: Text(
                                  _isSignUpMode
                                      ? 'Criar Conta com Email'
                                      : 'Entrar com Email',
                                ),
                              ),
                            ],
                            const SizedBox(height: NexusSpacing.md),
                            TextButton.icon(
                              onPressed: _isLoading ? null : _handleInstantDemo,
                              style: TextButton.styleFrom(
                                foregroundColor: NexusColors.accentCyber,
                                minimumSize: const Size.fromHeight(46),
                              ),
                              icon: const Icon(Icons.auto_awesome_rounded),
                              label: const Text(
                                'Entrar em Modo Demo Instantâneo',
                                textAlign: TextAlign.center,
                              ),
                            ),
                            if (_errorMessage != null) ...<Widget>[
                              const SizedBox(height: NexusSpacing.sm),
                              Text(
                                _errorMessage!,
                                style: TextStyle(
                                  color: _isInfoBanner
                                      ? NexusColors.accentCyber
                                      : NexusColors.semanticDanger,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: NexusSpacing.lg),
                      Text(
                        'Privacidade Zero-Trust: sua localização exata nunca é exibida e suas mensagens são cifradas localmente (AES-256-GCM).',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustPill extends StatelessWidget {
  const _TrustPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(NexusRadii.pill),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
