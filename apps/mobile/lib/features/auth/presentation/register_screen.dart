import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_design_tokens/nexus_tokens.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/security/nexus_password_policy.dart';
import '../../../core/widgets/nexus_ui_kit.dart';
import '../../legal/domain/legal_documents_br.dart';
import '../../shared/domain/nexus_repositories.dart';
import 'email_otp_verification_screen.dart';
import 'widgets/auth_scaffold_shell.dart';
import 'widgets/nexus_password_policy_checklist.dart';

/// Screen — Cadastro NEXUS DUO (`/register`).
///
/// Exige confirmação dupla de e-mail e senha, política rígida de senha (8..12
/// caracteres com 4 classes e bloqueio anti-nomes em 4 camadas), declaração de
/// maioridade 18+ e abertura direta dos Termos & LGPD antes do código OTP por e-mail.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({this.initialEmail, super.key});

  final String? initialEmail;

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _confirmEmailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptedTermsAndAge = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final seed = widget.initialEmail?.trim() ?? '';
    if (seed.isNotEmpty) {
      _emailController.text = seed;
    }
    _emailController.addListener(_refreshUi);
    _confirmEmailController.addListener(_refreshUi);
    _passwordController.addListener(_refreshUi);
    _confirmPasswordController.addListener(_refreshUi);
  }

  void _refreshUi() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _emailController.dispose();
    _confirmEmailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _openLegalTerms() async {
    final accepted = await context.push<bool>('/legal');
    if (accepted == true && mounted) {
      setState(() => _acceptedTermsAndAge = true);
    }
  }

  Future<void> _handleRegister() async {
    final email = _emailController.text.trim().toLowerCase();
    final confirmEmail = _confirmEmailController.text.trim().toLowerCase();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    setState(() => _errorMessage = null);

    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _errorMessage = 'Informe um e-mail válido.');
      return;
    }
    if (email != confirmEmail) {
      setState(
        () => _errorMessage =
            'Os dois campos de e-mail devem ser idênticos para receber o código.',
      );
      return;
    }

    final policy = NexusPasswordPolicy.evaluate(password, email: email);
    if (!policy.isValid) {
      setState(
        () => _errorMessage =
            policy.primaryErrorMessage ??
            'A senha não atende aos requisitos de segurança.',
      );
      return;
    }

    if (password != confirmPassword) {
      setState(() => _errorMessage = 'As duas senhas digitadas não conferem.');
      return;
    }
    if (!_acceptedTermsAndAge) {
      setState(
        () => _errorMessage =
            'Leia e aceite os Termos de Uso, LGPD e confirmação de maioridade (18+).',
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final res = await ref
        .read(authRepositoryProvider)
        .startEmailRegistration(
          email: email,
          confirmEmail: confirmEmail,
          password: password,
          confirmPassword: confirmPassword,
          acceptTerms: true,
          confirmAge18Plus: true,
          termsVersion: kNexusTermsVersion,
          privacyVersion: kNexusPrivacyVersion,
          appVersion: '1.1.0',
        );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    res.fold(
      onSuccess: (dispatch) {
        context.push(
          '/verify-otp',
          extra: OtpFlowArgs(
            email: email,
            maskedEmail: dispatch.maskedEmail,
            purpose: OtpPurpose.signupVerify,
            passwordForPostVerifySignIn: password,
            initialCooldownSeconds: dispatch.cooldownSeconds,
            demoCodeHint: dispatch.demoCodeHint,
          ),
        );
      },
      onFailure: (failure) {
        setState(() => _errorMessage = failure.message);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final emailText = _emailController.text.trim().toLowerCase();
    final confirmEmailText = _confirmEmailController.text.trim().toLowerCase();
    final emailsMismatch =
        confirmEmailText.isNotEmpty && emailText != confirmEmailText;
    final passwordsMismatch =
        _confirmPasswordController.text.isNotEmpty &&
        _passwordController.text != _confirmPasswordController.text;

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
            'Criar Conta NEXUS DUO',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: NexusSpacing.xs),
          Text(
            'Enviaremos um código de 6 dígitos para o seu e-mail confirmar sua conta 18+ com segurança.',
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
                  key: const Key('register_email_field'),
                  controller: _emailController,
                  enabled: !_isSubmitting,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const <String>[AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'Digite seu e-mail',
                    hintText: 'voce@dominio.com',
                    prefixIcon: Icon(Icons.mail_outline_rounded),
                  ),
                ),
                const SizedBox(height: NexusSpacing.md),
                TextField(
                  key: const Key('register_confirm_email_field'),
                  controller: _confirmEmailController,
                  enabled: !_isSubmitting,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Digite seu e-mail novamente',
                    hintText: 'Repita seu e-mail',
                    prefixIcon: const Icon(Icons.mark_email_read_outlined),
                    errorText: emailsMismatch
                        ? 'Os e-mails digitados não estão iguais.'
                        : null,
                  ),
                ),
                const SizedBox(height: NexusSpacing.md),
                TextField(
                  key: const Key('register_password_field'),
                  controller: _passwordController,
                  enabled: !_isSubmitting,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Digite sua senha',
                    hintText: '8 a 12 caracteres com símbolos e números',
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
                const SizedBox(height: NexusSpacing.sm),
                NexusPasswordPolicyChecklist(
                  password: _passwordController.text,
                  email: _emailController.text,
                ),
                const SizedBox(height: NexusSpacing.md),
                TextField(
                  key: const Key('register_confirm_password_field'),
                  controller: _confirmPasswordController,
                  enabled: !_isSubmitting,
                  obscureText: _obscureConfirmPassword,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: 'Digite sua senha novamente',
                    hintText: 'Repita exatamente sua senha',
                    prefixIcon: const Icon(Icons.lock_reset_rounded),
                    errorText: passwordsMismatch
                        ? 'As senhas digitadas não conferem.'
                        : null,
                    suffixIcon: IconButton(
                      onPressed: () => setState(
                        () =>
                            _obscureConfirmPassword = !_obscureConfirmPassword,
                      ),
                      tooltip: _obscureConfirmPassword
                          ? 'Mostrar senha'
                          : 'Ocultar senha',
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: NexusSpacing.md),
                Material(
                  color: NexusColors.bgVoid.withValues(alpha: 0.65),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(NexusRadii.md),
                    side: BorderSide(
                      color: _acceptedTermsAndAge
                          ? NexusColors.semanticSuccess.withValues(alpha: 0.6)
                          : NexusColors.borderSubtle,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(NexusSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        CheckboxListTile(
                          key: const Key('register_terms_checkbox'),
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: _acceptedTermsAndAge,
                          activeColor: NexusColors.brandPrimary,
                          onChanged: _isSubmitting
                              ? null
                              : (val) => setState(
                                  () => _acceptedTermsAndAge = val ?? false,
                                ),
                          title: const Text(
                            'Declaro ter 18 anos ou mais e aceito os Termos de Uso, Política de Privacidade (LGPD) e Diretrizes de Segurança.',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            key: const Key('register_terms_link'),
                            onPressed: _openLegalTerms,
                            icon: const Icon(Icons.gavel_rounded, size: 17),
                            style: TextButton.styleFrom(
                              foregroundColor: NexusColors.accentCyber,
                            ),
                            label: const Text(
                              'Ler Termos de Uso, LGPD e Compliance (18+)',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_errorMessage != null) ...<Widget>[
                  const SizedBox(height: NexusSpacing.md),
                  Container(
                    key: const Key('register_error_banner'),
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
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: NexusColors.semanticDanger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: NexusSpacing.lg),
                NexusGradientButton(
                  key: const Key('register_submit_button'),
                  label: 'Criar Conta e Enviar Código (6 dígitos)',
                  icon: Icons.mark_email_unread_rounded,
                  isLoading: _isSubmitting,
                  onPressed: _handleRegister,
                ),
                const SizedBox(height: NexusSpacing.sm),
                TextButton(
                  key: const Key('register_back_to_login_link'),
                  onPressed: _isSubmitting ? null : () => context.go('/login'),
                  child: const Text('Já tenho uma conta · Fazer Login'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
