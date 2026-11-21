import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_design_tokens/nexus_tokens.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/theme/nexus_theme.dart';
import '../../../core/widgets/nexus_ui_kit.dart';
import '../../legal/domain/legal_documents_br.dart';
import '../../shared/domain/nexus_repositories.dart';
import 'reset_password_screen.dart';
import 'widgets/auth_scaffold_shell.dart';

class OtpFlowArgs {
  const OtpFlowArgs({
    required this.email,
    required this.maskedEmail,
    required this.purpose,
    this.passwordForPostVerifySignIn,
    this.initialCooldownSeconds = 60,
    this.demoCodeHint,
  });

  final String email;
  final String maskedEmail;
  final OtpPurpose purpose;
  final String? passwordForPostVerifySignIn;
  final int initialCooldownSeconds;
  final String? demoCodeHint;
}

/// Screen — Verificação de Código de 6 Dígitos enviado por E-mail (Resend OTP).
class EmailOtpVerificationScreen extends ConsumerStatefulWidget {
  const EmailOtpVerificationScreen({required this.args, super.key});

  final OtpFlowArgs args;

  @override
  ConsumerState<EmailOtpVerificationScreen> createState() =>
      _EmailOtpVerificationScreenState();
}

class _EmailOtpVerificationScreenState
    extends ConsumerState<EmailOtpVerificationScreen> {
  final List<TextEditingController> _controllers =
      List<TextEditingController>.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List<FocusNode>.generate(
    6,
    (_) => FocusNode(),
  );

  Timer? _cooldownTimer;
  late int _cooldownRemaining;
  bool _isVerifying = false;
  bool _isResending = false;
  String? _errorMessage;
  String? _infoMessage;
  String? _demoHint;

  @override
  void initState() {
    super.initState();
    _cooldownRemaining = widget.args.initialCooldownSeconds.clamp(0, 120);
    _demoHint = widget.args.demoCodeHint;
    _startCooldownTimer();
  }

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    if (_cooldownRemaining <= 0) return;
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_cooldownRemaining > 0) {
          _cooldownRemaining--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _currentCode => _controllers.map((c) => c.text.trim()).join();

  void _onDigitChanged(int index, String raw) {
    final digitsOnly = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length > 1) {
      // Paste support across all 6 boxes
      for (var i = 0; i < 6; i++) {
        _controllers[i].text = i < digitsOnly.length ? digitsOnly[i] : '';
      }
      final nextIndex = digitsOnly.length >= 6 ? 5 : digitsOnly.length;
      _focusNodes[nextIndex].requestFocus();
      setState(() => _errorMessage = null);
      if (digitsOnly.length >= 6) {
        _submitOtp();
      }
      return;
    }

    if (digitsOnly != raw) {
      _controllers[index].text = digitsOnly;
      _controllers[index].selection = TextSelection.collapsed(
        offset: digitsOnly.length,
      );
    }

    if (digitsOnly.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else if (digitsOnly.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    setState(() => _errorMessage = null);
  }

  Future<void> _submitOtp() async {
    final code = _currentCode;
    if (code.length != 6) {
      setState(
        () => _errorMessage =
            'Digite todos os 6 dígitos enviados para o seu e-mail.',
      );
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    final repo = ref.read(authRepositoryProvider);
    final res = await repo.verifyEmailOtp(
      email: widget.args.email,
      code: code,
      purpose: widget.args.purpose,
    );
    if (!mounted) return;

    await res.fold(
      onSuccess: (verifyRes) async {
        if (widget.args.purpose == OtpPurpose.signupVerify) {
          final pwd = widget.args.passwordForPostVerifySignIn;
          if (pwd != null && pwd.isNotEmpty) {
            final loginRes = await repo.signInWithEmail(
              email: widget.args.email,
              password: pwd,
            );
            if (!mounted) return;
            loginRes.fold(
              onSuccess: (session) {
                ref.read(authSessionProvider.notifier).state = session;
                context.go('/onboarding');
              },
              onFailure: (_) {
                context.go(
                  '/login?email=${Uri.encodeQueryComponent(widget.args.email)}',
                );
              },
            );
            return;
          }
          context.go(
            '/login?email=${Uri.encodeQueryComponent(widget.args.email)}',
          );
          return;
        }

        final resetToken = verifyRes.resetToken;
        if (resetToken == null || resetToken.isEmpty) {
          setState(() {
            _isVerifying = false;
            _errorMessage = 'Não foi possível gerar o token de redefinição.';
          });
          return;
        }
        setState(() => _isVerifying = false);
        context.go(
          '/reset-password',
          extra: ResetPasswordArgs(
            email: widget.args.email,
            resetToken: resetToken,
          ),
        );
      },
      onFailure: (failure) async {
        setState(() {
          _isVerifying = false;
          _errorMessage = failure.message;
        });
      },
    );
  }

  Future<void> _handleResend() async {
    if (_cooldownRemaining > 0 || _isResending) return;
    setState(() {
      _isResending = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    final repo = ref.read(authRepositoryProvider);
    if (widget.args.purpose == OtpPurpose.passwordReset) {
      final res = await repo.requestPasswordResetOtp(widget.args.email);
      if (!mounted) return;
      setState(() => _isResending = false);
      res.fold(
        onSuccess: (dispatch) {
          setState(() {
            _cooldownRemaining = dispatch.cooldownSeconds;
            _demoHint = dispatch.demoCodeHint;
            _infoMessage =
                'Novo código de 6 dígitos enviado para ${dispatch.maskedEmail}.';
          });
          _startCooldownTimer();
        },
        onFailure: (failure) => setState(() => _errorMessage = failure.message),
      );
      return;
    }

    // Signup resend when password was carried from RegisterScreen
    final pwd = widget.args.passwordForPostVerifySignIn;
    if (pwd == null || pwd.isEmpty) {
      setState(() {
        _isResending = false;
        _errorMessage =
            'Volte ao cadastro para solicitar um novo código com segurança.';
      });
      return;
    }

    final res = await repo.startEmailRegistration(
      email: widget.args.email,
      confirmEmail: widget.args.email,
      password: pwd,
      confirmPassword: pwd,
      acceptTerms: true,
      confirmAge18Plus: true,
      termsVersion: kNexusTermsVersion,
      privacyVersion: kNexusPrivacyVersion,
      appVersion: '1.1.0',
    );
    if (!mounted) return;
    setState(() => _isResending = false);
    res.fold(
      onSuccess: (dispatch) {
        setState(() {
          _cooldownRemaining = dispatch.cooldownSeconds;
          _demoHint = dispatch.demoCodeHint;
          _infoMessage = 'Novo código enviado para ${dispatch.maskedEmail}!';
        });
        _startCooldownTimer();
      },
      onFailure: (failure) => setState(() => _errorMessage = failure.message),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isReset = widget.args.purpose == OtpPurpose.passwordReset;
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
            isReset
                ? 'Confirme o Código de Recuperação'
                : 'Verifique seu E-mail',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: NexusSpacing.xs),
          Text(
            'Enviamos um código de 6 dígitos para ${widget.args.maskedEmail}. Ele expira em 10 minutos.',
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
                if (_demoHint != null) ...<Widget>[
                  Container(
                    padding: const EdgeInsets.all(NexusSpacing.sm),
                    decoration: BoxDecoration(
                      color: NexusColors.accentCyber.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(NexusRadii.md),
                      border: Border.all(
                        color: NexusColors.accentCyber.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Text(
                      'Modo Demo ativo — utilize o código de verificação $_demoHint.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: NexusColors.accentCyber,
                      ),
                    ),
                  ),
                  const SizedBox(height: NexusSpacing.md),
                ],
                Row(
                  children: List<Widget>.generate(6, (index) {
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: index < 5 ? 6 : 0),
                        child: TextField(
                          key: Key('otp_box_$index'),
                          controller: _controllers[index],
                          focusNode: _focusNodes[index],
                          enabled: !_isVerifying,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          maxLength: index == 0 ? 6 : 1,
                          onChanged: (v) => _onDigitChanged(index, v),
                          style: NexusTheme.monoStat(
                            fontSize: 22,
                            color: NexusColors.textPrimary,
                          ),
                          decoration: InputDecoration(
                            counterText: '',
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 14,
                            ),
                            filled: true,
                            fillColor: NexusColors.bgVoid,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                NexusRadii.md,
                              ),
                              borderSide: const BorderSide(
                                color: NexusColors.borderSubtle,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                NexusRadii.md,
                              ),
                              borderSide: const BorderSide(
                                color: NexusColors.accentCyber,
                                width: 1.8,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: NexusSpacing.lg),
                NexusGradientButton(
                  key: const Key('otp_submit_button'),
                  label: isReset
                      ? 'Validar Código e Continuar'
                      : 'Confirmar Código e Entrar',
                  icon: Icons.verified_rounded,
                  isLoading: _isVerifying,
                  onPressed: _submitOtp,
                ),
                const SizedBox(height: NexusSpacing.sm),
                TextButton(
                  key: const Key('otp_resend_button'),
                  onPressed: (_cooldownRemaining > 0 || _isResending)
                      ? null
                      : _handleResend,
                  child: Text(
                    _cooldownRemaining > 0
                        ? 'Reenviar código em ${_cooldownRemaining}s'
                        : (_isResending
                              ? 'Reenviando código...'
                              : 'Não recebeu? Reenviar código de 6 dígitos'),
                  ),
                ),
                if (_infoMessage != null) ...<Widget>[
                  const SizedBox(height: NexusSpacing.sm),
                  Text(
                    _infoMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: NexusColors.semanticSuccess,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (_errorMessage != null) ...<Widget>[
                  const SizedBox(height: NexusSpacing.sm),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: NexusColors.semanticDanger,
                      fontWeight: FontWeight.w600,
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
