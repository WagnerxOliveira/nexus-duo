import 'package:flutter/material.dart';
import 'package:nexus_design_tokens/nexus_tokens.dart';

import '../../../../core/widgets/nexus_ui_kit.dart';
import '../../../../core/widgets/nexus_update_widgets.dart';

/// Shared responsive Cyber-Velvet auth backdrop with zero-overflow scroll framing
/// and optional stylish top Update Pill button.
class AuthScaffoldShell extends StatelessWidget {
  const AuthScaffoldShell({
    required this.child,
    this.showBackButton = false,
    this.onBack,
    this.showUpdateButton = true,
    super.key,
  });

  final Widget child;
  final bool showBackButton;
  final VoidCallback? onBack;
  final bool showUpdateButton;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalPad = screenWidth < NexusBreakpoints.mobileCompactMax
        ? NexusSpacing.pageCompact
        : NexusSpacing.pageStandard;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
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
                  vertical: NexusSpacing.md,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: NexusSpacing.sm,
                        runSpacing: NexusSpacing.sm,
                        children: <Widget>[
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              if (showBackButton) ...<Widget>[
                                IconButton(
                                  onPressed: onBack,
                                  tooltip: 'Voltar',
                                  icon: const Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    size: 18,
                                  ),
                                  color: NexusColors.textPrimary,
                                ),
                              ],
                              const Flexible(
                                child: NexusBrandLogo(compact: true),
                              ),
                            ],
                          ),
                          if (showUpdateButton)
                            const NexusDiscreetUpdatePill(compact: true),
                        ],
                      ),
                      const SizedBox(height: NexusSpacing.lg),
                      child,
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
