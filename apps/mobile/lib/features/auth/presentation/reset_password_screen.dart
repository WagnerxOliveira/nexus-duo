import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_design_tokens/nexus_tokens.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/security/nexus_password_policy.dart';
import '../../../core/widgets/nexus_ui_kit.dart';
import 'widgets/auth_scaffold_shell.dart';
import 'widgets/nexus_password_policy_checklist.dart';

class ResetPasswordArgs {
  const ResetPasswordArgs({required this.email, required this.resetToken});

  final String email;
  final String resetToken;
}

/// Screen — Redefinição final de senha após validação do OTP de 6 dígitos (`/reset-password`).
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({required this.args, super.key});

  final ResetPasswordArgs args;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isSaving = false;
  bool _done = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_refresh);
    _confirmController.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final newPwd = _passwordController.text;
    final confirmPwd = _confirmController.text;
    setState(() => _errorMessage = null);

    final policy = NexusPasswordPolicy.evaluate(
      newPwd,
      email: widget.args.email,
    );
    if (!policy.isValid) {
      setState(
        () => _errorMessage =
            policy.primaryErrorMessage ??
            'A nova senha não atende aos requisitos de segurança.',
      );
      return;
    }
    if (newPwd != confirmPwd) {
      setState(() => _errorMessage = 'As duas senhas digitadas não conferem.');
      return;
    }

    setState(() => _isSaving = true);
    final res = await ref
        .read(authRepositoryProvider)
        .completePasswordReset(
          email: widget.args.email,
          resetToken: widget.args.resetToken,
          newPassword: newPwd,
          confirmPassword: confirmPwd,
        );
    if (!mounted) return;
    setState(() => _isSaving = false);

    res.fold(
      onSuccess: (_) => setState(() => _done = true),
      onFailure: (failure) => setState(() => _errorMessage = failure.message),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mismatch =
        _confirmController.text.isNotEmpty &&
        _passwordController.text != _confirmController.text;

    return AuthScaffoldShell(
      showBackButton: !_done,
      onBack: () => context.go('/login'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Definir Nova Senha',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: NexusSpacing.xs),
          Text(
            'Escolha uma nova senha forte entre 8 e 12 caracteres para ${widget.args.email}.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: NexusColors.textSecondary),
          ),
          const SizedBox(height: NexusSpacing.lg),
          NexusGlassCard(
            glow: true,
            padding: const EdgeInsets.all(NexusSpacing.lg),
            child: _done
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const Icon(
                        Icons.verified_rounded,
                        size: 48,
                        color: NexusColors.semanticSuccess,
                      ),
                      const SizedBox(height: NexusSpacing.md),
                      Text(
                        'Senha alterada com sucesso!',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: NexusSpacing.xs),
                      Text(
                        'Agora você já pode entrar no NEXUS DUO utilizando sua nova senha.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: NexusSpacing.lg),
                      NexusGradientButton(
                        label: 'Ir para o Login',
                        icon: Icons.login_rounded,
                        onPressed: () => context.go(
                          '/login?email=${Uri.encodeQueryComponent(widget.args.email)}',
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      TextField(
                        key: const Key('reset_new_password_field'),
                        controller: _passwordController,
                        enabled: !_isSaving,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Digite sua nova senha',
                          hintText: '8 a 12 caracteres sem nomes',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: NexusSpacing.sm),
                      NexusPasswordPolicyChecklist(
                        password: _passwordController.text,
                        email: widget.args.email,
                      ),
                      const SizedBox(height: NexusSpacing.md),
                      TextField(
                        key: const Key('reset_confirm_password_field'),
                        controller: _confirmController,
                        enabled: !_isSaving,
                        obscureText: _obscureConfirm,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: 'Digite sua nova senha novamente',
                          hintText: 'Repita exatamente a nova senha',
                          prefixIcon: const Icon(Icons.lock_reset_rounded),
                          errorText: mismatch
                              ? 'As duas senhas digitadas não conferem.'
                              : null,
                          suffixIcon: IconButton(
                            onPressed: () => setState(
                              () => _obscureConfirm = !_obscureConfirm,
                            ),
                            icon: Icon(
                              _obscureConfirm
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                      ),
                      if (_errorMessage != null) ...<Widget>[
                        const SizedBox(height: NexusSpacing.md),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: NexusColors.semanticDanger,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: NexusSpacing.lg),
                      NexusGradientButton(
                        key: const Key('reset_submit_button'),
                        label: 'Salvar Nova Senha',
                        icon: Icons.check_circle_outline_rounded,
                        isLoading: _isSaving,
                        onPressed: _submit,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
