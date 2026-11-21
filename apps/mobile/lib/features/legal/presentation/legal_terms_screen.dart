import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_design_tokens/nexus_tokens.dart';

import '../../../core/theme/nexus_theme.dart';
import '../../../core/widgets/nexus_ui_kit.dart';
import '../domain/legal_documents_br.dart';

/// Screen — Termos de Uso, Política de Privacidade (LGPD) e Diretrizes de Segurança.
///
/// Returns `true` when popped via the "Li e Concordo" button so `RegisterScreen`
/// can automatically mark the mandatory legal consent checkbox.
class LegalTermsScreen extends StatelessWidget {
  const LegalTermsScreen({this.initialTabIndex = 0, super.key});

  final int initialTabIndex;

  @override
  Widget build(BuildContext context) {
    final safeInitial = initialTabIndex.clamp(
      0,
      LegalDocumentsBr.tabs.length - 1,
    );

    return DefaultTabController(
      length: LegalDocumentsBr.tabs.length,
      initialIndex: safeInitial,
      child: Scaffold(
        backgroundColor: NexusColors.bgVoid,
        appBar: AppBar(
          backgroundColor: NexusColors.bgSurface,
          title: const Text('Termos, LGPD & Segurança'),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: NexusColors.accentCyber,
            labelColor: NexusColors.accentCyber,
            unselectedLabelColor: NexusColors.textSecondary,
            tabs: LegalDocumentsBr.tabs.map((t) => Tab(text: t.label)).toList(),
          ),
        ),
        body: Column(
          children: <Widget>[
            Expanded(
              child: TabBarView(
                children: LegalDocumentsBr.tabs
                    .map((tab) => _LegalTabContent(tab: tab))
                    .toList(),
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                color: NexusColors.bgSurface,
                border: Border(
                  top: BorderSide(color: NexusColors.borderSubtle),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(
                NexusSpacing.md,
                NexusSpacing.sm,
                NexusSpacing.md,
                NexusSpacing.md,
              ),
              child: SafeArea(
                top: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Text(
                          'Versão $kNexusTermsVersion • Conformidade LGPD, Marco Civil, ECA (18+), CP, CC, CDC & PI',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: NexusColors.textSecondary),
                        ),
                        const SizedBox(height: NexusSpacing.sm),
                        NexusGradientButton(
                          key: const Key('legal_accept_button'),
                          label: 'Li e Concordo com os Termos (18+)',
                          icon: Icons.verified_user_rounded,
                          onPressed: () {
                            if (context.canPop()) {
                              context.pop(true);
                            } else {
                              context.go('/register');
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegalTabContent extends StatelessWidget {
  const _LegalTabContent({required this.tab});

  final LegalDocumentTab tab;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final pad = screenWidth < NexusBreakpoints.mobileCompactMax
        ? NexusSpacing.pageCompact
        : NexusSpacing.pageStandard;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: EdgeInsets.all(pad),
          children: <Widget>[
            NexusGlassCard(
              glow: true,
              padding: const EdgeInsets.all(NexusSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(
                    Icons.gavel_rounded,
                    color: NexusColors.brandSecondary,
                    size: 22,
                  ),
                  const SizedBox(width: NexusSpacing.sm),
                  Expanded(
                    child: Text(
                      tab.subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: NexusColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: NexusSpacing.md),
            for (final section in tab.sections) ...<Widget>[
              NexusGlassCard(
                padding: const EdgeInsets.all(NexusSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      section.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: NexusColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: NexusColors.accentCyber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(NexusRadii.sm),
                        border: Border.all(
                          color: NexusColors.accentCyber.withValues(
                            alpha: 0.40,
                          ),
                        ),
                      ),
                      child: Text(
                        section.legalBasis,
                        style: NexusTheme.monoStat(
                          fontSize: 10.5,
                          color: NexusColors.accentCyber,
                        ),
                      ),
                    ),
                    const SizedBox(height: NexusSpacing.sm),
                    Text(
                      section.body,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: NexusColors.textSecondary,
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: NexusSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }
}
