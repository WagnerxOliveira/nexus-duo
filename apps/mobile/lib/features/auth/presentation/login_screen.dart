import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_design_tokens/nexus_tokens.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthChangeEvent;

import '../../../core/providers/app_providers.dart';
import '../../../core/widgets/nexus_ui_kit.dart';
import '../../../core/widgets/nexus_update_widgets.dart';
import '../../shared/domain/nexus_repositories.dart';
import 'email_otp_verification_screen.dart';
import 'widgets/auth_scaffold_shell.dart';

/// Screen 1 — Login principal do NEXUS DUO (`/login`).
///
/// Recursos de mercado incorporados logo na abertura do celular:
/// - Botão estiloso e sempre visível de Atualização (pílula neon + card spotlight);
/// - Login por E-mail & Senha com detecção automática de conta inexistente
///   (avisa o jogador e redireciona com o e-mail preenchido para `/register`);
/// - Links dedicados para Cadastro (`/register`) e Esqueci a minha senha (`/forgot-password`);
/// - Discord OAuth2 com listener deep-link PKCE e Modo Demo Instantâneo offline.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({this.prefilledEmail, super.key});

  final String? prefilledEmail;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  StreamSubscription<dynamic>? _authSub;
  Timer? _redirectTimer;

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _accountNotFoundBanner = false;
  bool _isInfoBanner = false;
  String? _feedbackMessage;

  @override
  void initState() {
    super.initState();
    if (widget.prefilledEmail != null && widget.prefilledEmail!.isNotEmpty) {
      _emailController.text = widget.prefilledEmail!;
    }
    Future<void>.microtask(_attachCloudSessionListeners);
  }

  Future<void> _attachCloudSessionListeners() async {
    final config = ref.read(appConfigProvider);
    if (!config.isSupabaseConfigured || ref.read(runtimeDemoOverrideProvider)) {
      return;
    }

    final repo = ref.read(authRepositoryProvider);
    final existing = await repo.currentSession();
    if (existing != null && mounted) {
      ref.read(authSessionProvider.notifier).state = existing;
      context.go(existing.hasCompletedOnboarding ? '/app' : '/onboarding');
      return;
    }

    try {
      final sbClient = ref.read(supabaseClientOrNullProvider);
      if (sbClient == null) return;
      _authSub = sbClient.auth.onAuthStateChange.listen((data) async {
        if (data.event == AuthChangeEvent.signedIn ||
            data.event == AuthChangeEvent.tokenRefreshed) {
          final session = await ref
              .read(authRepositoryProvider)
              .currentSession();
          if (session != null && mounted) {
            ref.read(authSessionProvider.notifier).state = session;
            context.go(session.hasCompletedOnboarding ? '/app' : '/onboarding');
          }
        }
      });
    } catch (_) {
      // Ignored cleanly outside configured cloud instances.
    }
  }

  @override
  void dispose() {
    _redirectTimer?.cancel();
    _authSub?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _encodedRegisterUri(String email) {
    final clean = email.trim().toLowerCase();
    if (clean.isEmpty) return '/register';
    return '/register?email=${Uri.encodeQueryComponent(clean)}';
  }

  String _encodedForgotUri(String email) {
    final clean = email.trim().toLowerCase();
    if (clean.isEmpty) return '/forgot-password';
    return '/forgot-password?email=${Uri.encodeQueryComponent(clean)}';
  }

  Future<void> _handleEmailLogin() async {
    final cleanEmail = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;

    _redirectTimer?.cancel();
    setState(() {
      _feedbackMessage = null;
      _accountNotFoundBanner = false;
      _isInfoBanner = false;
    });

    if (!cleanEmail.contains('@') || !cleanEmail.contains('.')) {
      setState(() {
        _feedbackMessage = 'Digite um e-mail válido para entrar.';
      });
      return;
    }
    if (password.isEmpty) {
      setState(() {
        _feedbackMessage = 'Digite sua senha para continuar.';
      });
      return;
    }

    setState(() => _isLoading = true);
    final repo = ref.read(authRepositoryProvider);

    final statusRes = await repo.checkAccountStatus(cleanEmail);
    if (!mounted) return;

    final status = statusRes.valueOrNull;
    if (status == AccountLookupStatus.notFound) {
      setState(() {
        _isLoading = false;
        _accountNotFoundBanner = true;
        _feedbackMessage =
            'Você ainda não tem conta no NEXUS DUO com este e-mail. Vamos criar sua conta agora!';
      });
      _redirectTimer = Timer(const Duration(milliseconds: 1400), () {
        if (mounted) {
          context.go(_encodedRegisterUri(cleanEmail));
        }
      });
      return;
    }

    if (status == AccountLookupStatus.unverified) {
      setState(() => _isLoading = false);
      unawaited(
        context.push(
          '/verify-otp',
          extra: OtpFlowArgs(
            email: cleanEmail,
            maskedEmail: cleanEmail,
            purpose: OtpPurpose.signupVerify,
          ),
        ),
      );
      return;
    }

    final signInRes = await repo.signInWithEmail(
      email: cleanEmail,
      password: password,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    signInRes.fold(
      onSuccess: (session) {
        ref.read(authSessionProvider.notifier).state = session;
        context.go(session.hasCompletedOnboarding ? '/app' : '/onboarding');
      },
      onFailure: (failure) {
        if (failure.code == 'ACCOUNT_NOT_FOUND') {
          setState(() {
            _accountNotFoundBanner = true;
            _feedbackMessage =
                'Você ainda não tem conta no NEXUS DUO com este e-mail. Vamos criar sua conta agora!';
          });
          return;
        }
        if (failure.code == 'EMAIL_NOT_CONFIRMED') {
          context.push(
            '/verify-otp',
            extra: OtpFlowArgs(
              email: cleanEmail,
              maskedEmail: cleanEmail,
              purpose: OtpPurpose.signupVerify,
            ),
          );
          return;
        }
        setState(() => _feedbackMessage = failure.message);
      },
    );
  }

  Future<void> _handleDiscordLogin() async {
    setState(() {
      _isLoading = true;
      _feedbackMessage = null;
      _accountNotFoundBanner = false;
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
          _feedbackMessage = failure.message;
        });
      },
    );
  }

  Future<void> _handleInstantDemo() async {
    setState(() {
      _isLoading = true;
      _feedbackMessage = null;
      _accountNotFoundBanner = false;
      _isInfoBanner = false;
    });
    ref.read(runtimeDemoOverrideProvider.notifier).state = true;
    final res = await ref.read(authRepositoryProvider).enterDemoMode();
    if (!mounted) return;
    setState(() => _isLoading = false);
    res.fold(
      onSuccess: (session) {
        ref.read(authSessionProvider.notifier).state = session;
        context.go('/app');
      },
      onFailure: (failure) {
        setState(() => _feedbackMessage = failure.message);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);

    return AuthScaffoldShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const NexusUpdateSpotlightCard(),
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
          const SizedBox(height: NexusSpacing.md),
          Text(
            'Entre para encontrar seu Duo.',
            style: Theme.of(context).textTheme.displayLarge,
          ),
          const SizedBox(height: NexusSpacing.sm),
          Text(
            'Compatibilidade real de jogos, horários contínuos em comum e chat criptografado ponta a ponta.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: NexusColors.textSecondary),
          ),
          const SizedBox(height: NexusSpacing.lg),
          NexusGlassCard(
            glow: true,
            padding: const EdgeInsets.all(NexusSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Acesse sua conta',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: NexusSpacing.md),
                TextField(
                  key: const Key('login_email_field'),
                  controller: _emailController,
                  enabled: !_isLoading,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const <String>[AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'Digite seu e-mail',
                    hintText: 'voce@nexusduo.app',
                    prefixIcon: Icon(Icons.mail_outline_rounded),
                  ),
                ),
                const SizedBox(height: NexusSpacing.md),
                TextField(
                  key: const Key('login_password_field'),
                  controller: _passwordController,
                  enabled: !_isLoading,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _handleEmailLogin(),
                  autofillHints: const <String>[AutofillHints.password],
                  decoration: InputDecoration(
                    labelText: 'Digite sua senha',
                    hintText: 'Sua senha cadastrada',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      tooltip: _obscurePassword
                          ? 'Mostrar senha'
                          : 'Ocultar senha',
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: NexusSpacing.xs),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    key: const Key('login_forgot_password_link'),
                    onPressed: _isLoading
                        ? null
                        : () => context.push(
                            _encodedForgotUri(_emailController.text),
                          ),
                    child: const Text('Esqueci a minha senha'),
                  ),
                ),
                const SizedBox(height: NexusSpacing.sm),
                NexusGradientButton(
                  key: const Key('login_submit_button'),
                  label: 'Entrar no NEXUS DUO',
                  icon: Icons.login_rounded,
                  isLoading: _isLoading,
                  onPressed: _handleEmailLogin,
                ),
                if (_feedbackMessage != null) ...<Widget>[
                  const SizedBox(height: NexusSpacing.md),
                  Container(
                    key: Key(
                      _accountNotFoundBanner
                          ? 'login_account_not_found_alert'
                          : 'login_feedback_banner',
                    ),
                    padding: const EdgeInsets.all(NexusSpacing.sm),
                    decoration: BoxDecoration(
                      color:
                          (_accountNotFoundBanner
                                  ? NexusColors.brandSecondary
                                  : _isInfoBanner
                                  ? NexusColors.accentCyber
                                  : NexusColors.semanticDanger)
                              .withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(NexusRadii.md),
                      border: Border.all(
                        color:
                            (_accountNotFoundBanner
                                    ? NexusColors.brandSecondary
                                    : _isInfoBanner
                                    ? NexusColors.accentCyber
                                    : NexusColors.semanticDanger)
                                .withValues(alpha: 0.5),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Text(
                          _feedbackMessage!,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _accountNotFoundBanner
                                ? NexusColors.textPrimary
                                : _isInfoBanner
                                ? NexusColors.accentCyber
                                : NexusColors.semanticDanger,
                          ),
                        ),
                        if (_accountNotFoundBanner) ...<Widget>[
                          const SizedBox(height: NexusSpacing.sm),
                          FilledButton.icon(
                            key: const Key('login_redirect_register_cta'),
                            onPressed: () {
                              _redirectTimer?.cancel();
                              context.go(
                                _encodedRegisterUri(_emailController.text),
                              );
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: NexusColors.brandSecondary,
                            ),
                            icon: const Icon(
                              Icons.person_add_alt_1_rounded,
                              size: 18,
                            ),
                            label: const Text('Criar Minha Conta Agora'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: NexusSpacing.md),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Text(
                      'Ainda não tem conta? ',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    TextButton(
                      key: const Key('login_register_link'),
                      onPressed: _isLoading
                          ? null
                          : () => context.push(
                              _encodedRegisterUri(_emailController.text),
                            ),
                      style: TextButton.styleFrom(
                        foregroundColor: NexusColors.accentCyber,
                      ),
                      child: const Text(
                        'Cadastre-se agora',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const Divider(height: NexusSpacing.lg),
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _handleDiscordLogin,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: NexusColors.textPrimary,
                    side: const BorderSide(color: NexusColors.borderSubtle),
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(NexusRadii.md),
                    ),
                  ),
                  icon: const Icon(Icons.headset_mic_rounded),
                  label: const Text('Entrar com Discord'),
                ),
                const SizedBox(height: NexusSpacing.sm),
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
              ],
            ),
          ),
          const SizedBox(height: NexusSpacing.md),
          Text(
            'Privacidade Zero-Trust: sua localização exata nunca é exibida e suas mensagens são cifradas localmente (AES-256-GCM).',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall,
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
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: NexusColors.textPrimary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
