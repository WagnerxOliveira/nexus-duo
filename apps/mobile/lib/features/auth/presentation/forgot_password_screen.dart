import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_design_tokens/nexus_tokens.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/widgets/nexus_ui_kit.dart';
import '../../shared/domain/nexus_repositories.dart';
import 'email_otp_verification_screen.dart';
import 'widgets/auth_scaffold_shell.dart';

/// Screen — Esqueci a minha senha (`/forgot-password`).
/// Dispara o código OTP de 6 dígitos via Resend se a conta existir; se não existir,
/// informa claramente e oferece atalho direto para o cadastro com o e-mail preenchido.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({this.initialEmail, super.key});

  final String? initialEmail;

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  bool _notFound = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final seed = widget.initialEmail?.trim() ?? '';
    if (seed.isNotEmpty) {
      _emailController.text = seed;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim().toLowerCase();
    setState(() {
      _errorMessage = null;
      _notFound = false;
    });

    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _errorMessage = 'Informe um e-mail válido.');
      return;
    }

    setState(() => _isLoading = true);
    final res = await ref
        .read(authRepositoryProvider)
        .requestPasswordResetOtp(email);
    if (!mounted) return;
    setState(() => _isLoading = false);

    res.fold(
      onSuccess: (dispatch) {
        context.push(
          '/verify-otp',
          extra: OtpFlowArgs(
            email: email,
            maskedEmail: dispatch.maskedEmail,
            purpose: OtpPurpose.passwordReset,
            initialCooldownSeconds: dispatch.cooldownSeconds,
            demoCodeHint: dispatch.demoCodeHint,
          ),
        );
      },
      onFailure: (failure) {
        setState(() {
          _notFound = failure.code == 'ACCOUNT_NOT_FOUND';
          _errorMessage = failure.message;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffoldShell(
      showBackButton: true,
      onBack: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/login');
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Esqueci a minha senha',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: NexusSpacing.xs),
          Text(
            'Digite seu e-mail cadastrado. Enviaremos um código de 6 dígitos para você redefinir sua senha com segurança.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: NexusColors.textSecondary),
          ),
          const SizedBox(height: NexusSpacing.lg),
          NexusGlassCard(
            glow: true,
            padding: const EdgeInsets.all(NexusSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextField(
                  key: const Key('forgot_email_field'),
                  controller: _emailController,
                  enabled: !_isLoading,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    labelText: 'E-mail cadastrado',
                    hintText: 'voce@dominio.com',
                    prefixIcon: Icon(Icons.mail_outline_rounded),
                  ),
                ),
                const SizedBox(height: NexusSpacing.lg),
                NexusGradientButton(
                  key: const Key('forgot_submit_button'),
                  label: 'Enviar Código de 6 Dígitos',
                  icon: Icons.send_rounded,
                  isLoading: _isLoading,
                  onPressed: _submit,
                ),
                if (_errorMessage != null) ...<Widget>[
                  const SizedBox(height: NexusSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(NexusSpacing.sm),
                    decoration: BoxDecoration(
                      color: NexusColors.semanticDanger.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(NexusRadii.md),
                      border: Border.all(
                        color: NexusColors.semanticDanger.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Text(
                          _errorMessage!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: NexusColors.semanticDanger,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (_notFound) ...<Widget>[
                          const SizedBox(height: NexusSpacing.sm),
                          TextButton(
                            onPressed: () => context.go(
                              '/register?email=${Uri.encodeQueryComponent(_emailController.text.trim().toLowerCase())}',
                            ),
                            child: const Text('Criar Conta com Este E-mail'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
