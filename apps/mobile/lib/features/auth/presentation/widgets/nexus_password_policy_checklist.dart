import 'package:flutter/material.dart';
import 'package:nexus_design_tokens/nexus_tokens.dart';

import '../../../../core/security/nexus_password_policy.dart';
import '../../../../core/theme/nexus_theme.dart';

/// Live password strength meter + 6-rule compliance checklist (`8-12` chars,
/// lowercase, uppercase, digit, special char, and 4-layer anti-person-name check).
class NexusPasswordPolicyChecklist extends StatelessWidget {
  const NexusPasswordPolicyChecklist({
    required this.password,
    this.email,
    super.key,
  });

  final String password;
  final String? email;

  @override
  Widget build(BuildContext context) {
    final eval = NexusPasswordPolicy.evaluate(password, email: email);
    final score = eval.strengthScore;
    final barColor = switch (score) {
      <= 1 => NexusColors.semanticDanger,
      2 => NexusColors.semanticWarning,
      3 => NexusColors.accentCyber,
      _ => NexusColors.semanticSuccess,
    };

    return Container(
      padding: const EdgeInsets.all(NexusSpacing.sm),
      decoration: BoxDecoration(
        color: NexusColors.bgVoid.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(NexusRadii.md),
        border: Border.all(
          color: eval.isValid
              ? NexusColors.semanticSuccess.withValues(alpha: 0.6)
              : NexusColors.borderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Segurança da Senha',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: NexusColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: NexusSpacing.sm),
              Text(
                '${eval.length}/${NexusPasswordPolicy.maxLength} chars',
                style: NexusTheme.monoStat(
                  fontSize: 11,
                  color: eval.hasValidLength
                      ? NexusColors.accentCyber
                      : NexusColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(NexusRadii.pill),
            child: LinearProgressIndicator(
              value: password.isEmpty ? 0.0 : (score / 4).clamp(0.15, 1.0),
              minHeight: 6,
              backgroundColor: NexusColors.bgElevated,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          const SizedBox(height: NexusSpacing.sm),
          _PolicyRuleRow(
            passed: eval.hasValidLength,
            label: 'Entre 8 e 12 caracteres (obrigatório)',
          ),
          _PolicyRuleRow(
            passed: eval.hasLowercase,
            label: 'Pelo menos 1 letra minúscula (a-z)',
          ),
          _PolicyRuleRow(
            passed: eval.hasUppercase,
            label: 'Pelo menos 1 letra maiúscula (A-Z)',
          ),
          _PolicyRuleRow(
            passed: eval.hasDigit,
            label: 'Pelo menos 1 número (0-9)',
          ),
          _PolicyRuleRow(
            passed: eval.hasSpecialChar && eval.hasNoWhitespace,
            label: 'Pelo menos 1 caractere especial (ex.: !@#\$%*) sem espaços',
          ),
          _PolicyRuleRow(
            passed: password.isNotEmpty && eval.hasNoPersonName,
            isWarningWhenEmpty: password.isEmpty,
            label: eval.hasNoPersonName || eval.detectedBlockedTerm == null
                ? 'Sem nomes de pessoas (ou variações) nem partes do e-mail'
                : 'Bloqueado: contém nome/e-mail ("${eval.detectedBlockedTerm}")',
          ),
        ],
      ),
    );
  }
}

class _PolicyRuleRow extends StatelessWidget {
  const _PolicyRuleRow({
    required this.passed,
    required this.label,
    this.isWarningWhenEmpty = false,
  });

  final bool passed;
  final bool isWarningWhenEmpty;
  final String label;

  @override
  Widget build(BuildContext context) {
    final Color iconColor;
    final IconData icon;
    if (passed && !isWarningWhenEmpty) {
      iconColor = NexusColors.semanticSuccess;
      icon = Icons.check_circle_rounded;
    } else if (!passed && !isWarningWhenEmpty) {
      iconColor = NexusColors.textSecondary;
      icon = Icons.radio_button_unchecked_rounded;
    } else {
      iconColor = NexusColors.textSecondary;
      icon = Icons.radio_button_unchecked_rounded;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 1.5),
            child: Icon(icon, size: 15, color: iconColor),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 12,
                color: passed && !isWarningWhenEmpty
                    ? NexusColors.textPrimary
                    : NexusColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
