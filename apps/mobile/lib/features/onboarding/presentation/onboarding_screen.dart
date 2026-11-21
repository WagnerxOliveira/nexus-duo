import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_design_tokens/nexus_tokens.dart';

import '../../../core/domain/value_objects/gamer_age.dart';
import '../../../core/domain/value_objects/weekly_schedule_mask.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/widgets/nexus_ui_kit.dart';
import '../../profile/domain/gamer_profile.dart';
import '../../verification/data/mlkit_verifiers.dart';

/// Screen 2 — Onboarding em 4 Passos Rápidos (< 90s):
/// (1) Identidade 18+
/// (2) Top 5 Jogos + Plataformas
/// (3) Sliders Gamer DNA + Grade Semanal Tátil (`WeeklyScheduleMask`)
/// (4) Fotos WebP (strip EXIF) + Liveness & OCR de Rank
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const List<String> _dayLabels = <String>[
    'Seg',
    'Ter',
    'Qua',
    'Qui',
    'Sex',
    'Sáb',
    'Dom',
  ];
  static const List<String> _periodLabels = <String>[
    'Manhã',
    'Tarde',
    'Noite',
    'Madrug.',
  ];

  int _step = 0;

  // Step 1
  late final TextEditingController _nameController;
  late final TextEditingController _cityController;
  DateTime _birthDate = DateTime(2000, 6, 15);
  String _gender = 'Feminino';
  String? _ageError;

  // Step 2
  final TextEditingController _gameSearchController = TextEditingController();
  final Set<String> _selectedGameSlugs = <String>{
    'valorant',
    'baldurs-gate-3',
    'stardew-valley',
  };
  final Set<GamerPlatform> _selectedPlatforms = <GamerPlatform>{
    GamerPlatform.pc,
    GamerPlatform.switchConsole,
  };

  // Step 3
  double _competitiveSlider = 62;
  double _voiceSlider = 84;
  double _coopSlider = 90;
  late WeeklyScheduleMask _scheduleMask;

  // Step 4
  bool _photoWebpPrepared = true;
  bool _livenessVerified = false;
  String? _livenessSummary;
  String? _ocrRankSummary;
  bool _isRunningVerification = false;

  @override
  void initState() {
    super.initState();
    final initial = ref.read(myProfileProvider);
    _nameController = TextEditingController(text: initial.displayName);
    _cityController = TextEditingController(text: initial.cityLabel);
    _scheduleMask = initial.scheduleMask;
    _livenessVerified = initial.isLivenessVerified;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _gameSearchController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate,
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    final ageCheck = GamerAge.fromBirthDate(picked);
    setState(() {
      _birthDate = picked;
      _ageError = ageCheck.failureOrNull?.message;
    });
  }

  Future<void> _runLivenessCheck() async {
    setState(() => _isRunningVerification = true);
    final verifier = MlKitLivenessVerifier();
    final result = await verifier.verify();
    if (!mounted) return;
    setState(() {
      _isRunningVerification = false;
      result.fold(
        onSuccess: (proof) {
          _livenessVerified = proof.isVerified;
          _livenessSummary = proof.summary;
        },
        onFailure: (failure) {
          _livenessSummary = failure.message;
        },
      );
    });
  }

  Future<void> _runRankOcrCheck() async {
    setState(() => _isRunningVerification = true);
    final verifier = MlKitRankOcrVerifier();
    final result = await verifier.verify();
    if (!mounted) return;
    setState(() {
      _isRunningVerification = false;
      result.fold(
        onSuccess: (proof) => _ocrRankSummary = proof.summary,
        onFailure: (failure) => _ocrRankSummary = failure.message,
      );
    });
  }

  Future<void> _nextOrFinish() async {
    if (_step == 0) {
      final ageRes = GamerAge.fromBirthDate(_birthDate);
      if (ageRes.isFailure) {
        setState(() => _ageError = ageRes.failureOrNull?.message);
        return;
      }
      setState(() {
        _ageError = null;
        _step = 1;
      });
      return;
    }

    if (_step < 3) {
      setState(() => _step += 1);
      return;
    }

    final age = GamerAge.fromBirthDate(_birthDate).valueOrNull;
    if (age == null) {
      setState(() {
        _step = 0;
        _ageError = 'Confirme ter 18 anos ou mais para concluir.';
      });
      return;
    }

    final store = ref.read(demoSeedStoreProvider);
    final chosenGames = store.gamesCatalog
        .where((g) => _selectedGameSlugs.contains(g.slug))
        .take(5)
        .toList();

    final current = ref.read(myProfileProvider);
    final archetype = GamerDna.inferArchetype(
      competitiveScore: _competitiveSlider.round(),
      voicePreferenceScore: _voiceSlider.round(),
      coopFocusScore: _coopSlider.round(),
    );

    final updated = current.copyWith(
      displayName: _nameController.text.trim().isEmpty
          ? current.displayName
          : _nameController.text.trim(),
      age: age,
      gender: _gender,
      cityLabel: _cityController.text.trim().isEmpty
          ? current.cityLabel
          : _cityController.text.trim(),
      games: chosenGames.isEmpty ? current.games : chosenGames,
      platforms: _selectedPlatforms.isEmpty
          ? current.platforms
          : _selectedPlatforms.toList(),
      gamerDna: current.gamerDna.copyWith(
        competitiveScore: _competitiveSlider.round(),
        voicePreferenceScore: _voiceSlider.round(),
        coopFocusScore: _coopSlider.round(),
        archetypeTitle: archetype,
      ),
      scheduleMask: _scheduleMask,
      isLivenessVerified: _livenessVerified,
    );

    final saveResult = await ref
        .read(profileRepositoryProvider)
        .saveMyProfile(updated);
    if (!mounted) return;
    saveResult.fold(
      onSuccess: (saved) {
        ref.read(myProfileProvider.notifier).state = saved;
        context.go('/app');
      },
      onFailure: (failure) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalPad = screenWidth < NexusBreakpoints.mobileCompactMax
        ? NexusSpacing.pageCompact
        : NexusSpacing.pageStandard;

    return Scaffold(
      appBar: AppBar(
        title: const NexusBrandLogo(compact: true),
        actions: <Widget>[
          TextButton(
            onPressed: () => context.go('/app'),
            child: const Text('Pular (Demo)'),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPad,
                    vertical: NexusSpacing.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              'Passo ${_step + 1} de 4 — ${_stepTitle(_step)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          Text(
                            '${((_step + 1) * 25)}%',
                            style: const TextStyle(
                              color: NexusColors.accentCyber,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: NexusSpacing.sm),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(NexusRadii.pill),
                        child: LinearProgressIndicator(
                          minHeight: 6,
                          value: (_step + 1) / 4.0,
                          backgroundColor: NexusColors.bgElevated,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            NexusColors.brandPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPad,
                      vertical: NexusSpacing.md,
                    ),
                    child: switch (_step) {
                      0 => _buildStepIdentity(context),
                      1 => _buildStepGames(context),
                      2 => _buildStepDnaAndSchedule(context),
                      _ => _buildStepVerification(context),
                    },
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(horizontalPad),
                  child: Row(
                    children: <Widget>[
                      if (_step > 0) ...<Widget>[
                        OutlinedButton(
                          onPressed: () => setState(() => _step -= 1),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(88, 50),
                            side: const BorderSide(
                              color: NexusColors.borderSubtle,
                            ),
                          ),
                          child: const Text('Voltar'),
                        ),
                        const SizedBox(width: NexusSpacing.sm),
                      ],
                      Expanded(
                        child: NexusGradientButton(
                          label: _step < 3
                              ? 'Continuar'
                              : 'Entrar no Daily Loot Drop',
                          icon: _step < 3
                              ? Icons.arrow_forward_rounded
                              : Icons.rocket_launch_rounded,
                          onPressed: _nextOrFinish,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _stepTitle(int step) => switch (step) {
    0 => 'Identidade 18+',
    1 => 'Top 5 Jogos & Plataformas',
    2 => 'Gamer DNA & Horários',
    _ => 'Fotos WebP, Liveness & OCR',
  };

  Widget _buildStepIdentity(BuildContext context) {
    final ageCheck = GamerAge.fromBirthDate(_birthDate);
    final ageYears = ageCheck.valueOrNull?.years;

    return NexusGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Seu perfil com privacidade segura',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: NexusSpacing.xs),
          Text(
            'Sua localização exata nunca é exibida — aplicamos fuzzing automático de 3 a 5 km.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: NexusSpacing.md),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nome ou Nickname',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: NexusSpacing.md),
          InkWell(
            onTap: _pickBirthDate,
            borderRadius: BorderRadius.circular(NexusRadii.md),
            child: Container(
              padding: const EdgeInsets.all(NexusSpacing.md),
              decoration: BoxDecoration(
                color: NexusColors.bgElevated,
                borderRadius: BorderRadius.circular(NexusRadii.md),
                border: Border.all(
                  color: _ageError != null
                      ? NexusColors.semanticDanger
                      : NexusColors.borderSubtle,
                ),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.cake_outlined,
                    color: NexusColors.brandPrimary,
                  ),
                  const SizedBox(width: NexusSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'Data de Nascimento (Obrigatório 18+)',
                          style: TextStyle(
                            color: NexusColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_birthDate.day.toString().padLeft(2, '0')}/${_birthDate.month.toString().padLeft(2, '0')}/${_birthDate.year}'
                          '${ageYears != null ? ' • $ageYears anos (OK)' : ''}',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.calendar_today_rounded, size: 18),
                ],
              ),
            ),
          ),
          if (_ageError != null) ...<Widget>[
            const SizedBox(height: NexusSpacing.xs),
            Text(
              _ageError!,
              style: const TextStyle(
                color: NexusColors.semanticDanger,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: NexusSpacing.md),
          Text('Gênero', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: NexusSpacing.sm),
          Wrap(
            spacing: NexusSpacing.sm,
            runSpacing: NexusSpacing.sm,
            children: <String>['Feminino', 'Masculino', 'Não-binário', 'Outro']
                .map(
                  (g) => ChoiceChip(
                    label: Text(g),
                    selected: _gender == g,
                    onSelected: (_) => setState(() => _gender = g),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: NexusSpacing.md),
          TextField(
            controller: _cityController,
            decoration: const InputDecoration(
              labelText: 'Cidade aproximada',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepGames(BuildContext context) {
    final catalog = ref.watch(demoSeedStoreProvider).gamesCatalog;
    final query = _gameSearchController.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? catalog
        : catalog
              .where((g) => g.title.toLowerCase().contains(query))
              .toList(growable: false);

    return NexusGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Escolha até 5 jogos favoritos (${_selectedGameSlugs.length}/5)',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: NexusSpacing.sm),
          TextField(
            controller: _gameSearchController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Buscar Valorant, Stardew Valley, BG3...',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: NexusSpacing.md),
          Wrap(
            spacing: NexusSpacing.sm,
            runSpacing: NexusSpacing.sm,
            children: filtered.map((game) {
              final selected = _selectedGameSlugs.contains(game.slug);
              return FilterChip(
                label: Text(game.title),
                selected: selected,
                onSelected: (isOn) {
                  setState(() {
                    if (isOn && _selectedGameSlugs.length < 5) {
                      _selectedGameSlugs.add(game.slug);
                    } else if (!isOn) {
                      _selectedGameSlugs.remove(game.slug);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: NexusSpacing.lg),
          Text(
            'Suas plataformas',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: NexusSpacing.sm),
          Wrap(
            spacing: NexusSpacing.sm,
            runSpacing: NexusSpacing.sm,
            children: GamerPlatform.values.map((p) {
              final selected = _selectedPlatforms.contains(p);
              return FilterChip(
                label: Text(p.label),
                selected: selected,
                onSelected: (isOn) {
                  setState(() {
                    if (isOn) {
                      _selectedPlatforms.add(p);
                    } else {
                      _selectedPlatforms.remove(p);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStepDnaAndSchedule(BuildContext context) {
    final archetype = GamerDna.inferArchetype(
      competitiveScore: _competitiveSlider.round(),
      voicePreferenceScore: _voiceSlider.round(),
      coopFocusScore: _coopSlider.round(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        NexusGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: NexusSpacing.sm,
                runSpacing: NexusSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Text(
                    'Seu Gamer DNA',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Chip(
                    label: Text(archetype),
                    backgroundColor: NexusColors.brandPrimary.withValues(
                      alpha: 0.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: NexusSpacing.md),
              _OnboardingSlider(
                leftLabel: 'Casual / Cozy',
                rightLabel: 'Competitivo',
                value: _competitiveSlider,
                onChanged: (v) => setState(() => _competitiveSlider = v),
              ),
              _OnboardingSlider(
                leftLabel: 'Só Chat',
                rightLabel: 'Call de Voz',
                value: _voiceSlider,
                onChanged: (v) => setState(() => _voiceSlider = v),
              ),
              _OnboardingSlider(
                leftLabel: 'Solo',
                rightLabel: 'Co-op / Duo',
                value: _coopSlider,
                onChanged: (v) => setState(() => _coopSlider = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: NexusSpacing.md),
        NexusGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Horários livres da semana (${_scheduleMask.activeHoursCount}h/sem)',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: NexusSpacing.xs),
              Text(
                'Toque nos blocos que você costuma jogar — nosso algoritmo DP calcula janelas contínuas reais.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: NexusSpacing.md),
              for (var day = 0; day < 7; day++) ...<Widget>[
                Padding(
                  padding: const EdgeInsets.only(bottom: NexusSpacing.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      SizedBox(
                        width: 40,
                        child: Text(
                          _dayLabels[day],
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: List<Widget>.generate(4, (period) {
                            final active = _scheduleMask.isPeriodActive(
                              day,
                              period,
                            );
                            return InkWell(
                              onTap: () => setState(() {
                                _scheduleMask = _scheduleMask.togglePeriod(
                                  day,
                                  period,
                                );
                              }),
                              borderRadius: BorderRadius.circular(
                                NexusRadii.sm,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: active
                                      ? NexusColors.brandPrimary.withValues(
                                          alpha: 0.35,
                                        )
                                      : NexusColors.bgElevated,
                                  borderRadius: BorderRadius.circular(
                                    NexusRadii.sm,
                                  ),
                                  border: Border.all(
                                    color: active
                                        ? NexusColors.brandPrimary
                                        : NexusColors.borderSubtle,
                                  ),
                                ),
                                child: Text(
                                  _periodLabels[period],
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: active
                                        ? NexusColors.textPrimary
                                        : NexusColors.textSecondary,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepVerification(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        NexusGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Fotos WebP com remoção de EXIF',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: NexusSpacing.xs),
              Text(
                'Suas fotos são convertidas para WebP no dispositivo removendo GPS, modelo de câmera e data original.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: NexusSpacing.md),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _photoWebpPrepared,
                onChanged: (v) => setState(() => _photoWebpPrepared = v),
                title: const Text('Avatar Cyber-Velvet otimizado (64 KB WebP)'),
                subtitle: const Text('Metadados EXIF removidos localmente'),
              ),
            ],
          ),
        ),
        const SizedBox(height: NexusSpacing.md),
        NexusGlassCard(
          glow: _livenessVerified,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.face_retouching_natural_rounded,
                    color: NexusColors.accentCyber,
                  ),
                  const SizedBox(width: NexusSpacing.sm),
                  Expanded(
                    child: Text(
                      'Selfie Liveness On-Device (ML Kit)',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (_livenessVerified)
                    const VerifiedPlayerBadge(compact: true),
                ],
              ),
              const SizedBox(height: NexusSpacing.xs),
              Text(
                '3 desafios gratuitos no aparelho: piscar, virar a cabeça e sorrir. Nenhum vídeo sai do celular.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: NexusSpacing.md),
              FilledButton.icon(
                onPressed: _isRunningVerification ? null : _runLivenessCheck,
                style: FilledButton.styleFrom(
                  backgroundColor: NexusColors.accentCyber,
                  foregroundColor: NexusColors.bgVoid,
                ),
                icon: const Icon(Icons.verified_rounded),
                label: Text(
                  _livenessVerified
                      ? 'Selo Verificado Ativo'
                      : 'Iniciar Verificação Liveness',
                ),
              ),
              if (_livenessSummary != null) ...<Widget>[
                const SizedBox(height: NexusSpacing.sm),
                Text(
                  _livenessSummary!,
                  style: const TextStyle(
                    color: NexusColors.semanticSuccess,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: NexusSpacing.md),
        NexusGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.document_scanner_rounded,
                    color: NexusColors.brandSecondary,
                  ),
                  const SizedBox(width: NexusSpacing.sm),
                  Expanded(
                    child: Text(
                      'OCR de Print de Rank (Custo Zero)',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: NexusSpacing.xs),
              Text(
                'Envie um print do Valorant, LoL ou CS2 para verificar seu elo sem compartilhar senhas.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: NexusSpacing.md),
              OutlinedButton.icon(
                onPressed: _isRunningVerification ? null : _runRankOcrCheck,
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('Testar OCR de Print de Rank'),
              ),
              if (_ocrRankSummary != null) ...<Widget>[
                const SizedBox(height: NexusSpacing.sm),
                Text(
                  _ocrRankSummary!,
                  style: const TextStyle(
                    color: NexusColors.semanticSuccess,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _OnboardingSlider extends StatelessWidget {
  const _OnboardingSlider({
    required this.leftLabel,
    required this.rightLabel,
    required this.value,
    required this.onChanged,
  });

  final String leftLabel;
  final String rightLabel;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                leftLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
            Expanded(
              child: Text(
                rightLabel,
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: 0,
          max: 100,
          divisions: 20,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
