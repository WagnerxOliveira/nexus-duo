import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_design_tokens/nexus_tokens.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/theme/nexus_theme.dart';
import '../../../core/widgets/nexus_ui_kit.dart';
import '../../discovery/domain/discovery_entities.dart';
import '../../profile/domain/gamer_profile.dart';
import '../domain/chat_message.dart';

/// Matches Inbox tab listing all active Duos ready for E2EE chat.
class MatchesListScreen extends ConsumerWidget {
  const MatchesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchesAsync = ref.watch(matchesProvider);
    final width = MediaQuery.sizeOf(context).width;
    final pad = width < NexusBreakpoints.mobileCompactMax
        ? NexusSpacing.pageCompact
        : NexusSpacing.pageStandard;

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: EdgeInsets.fromLTRB(
                  pad,
                  NexusSpacing.md,
                  pad,
                  NexusSpacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Seus Duos (E2EE)',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    Text(
                      'Conversas protegidas por X25519 + AES-256-GCM',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: matchesAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                      color: NexusColors.brandPrimary,
                    ),
                  ),
                  error: (err, _) => Center(child: Text('Erro: $err')),
                  data: (matches) {
                    if (matches.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: EdgeInsets.all(pad),
                          child: const Text(
                            'Nenhum match ativo ainda. Curta perfis no Daily Loot Drop!',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: EdgeInsets.all(pad),
                      itemCount: matches.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: NexusSpacing.sm),
                      itemBuilder: (context, index) {
                        final match = matches[index];
                        return InkWell(
                          onTap: () =>
                              context.push('/chat/${match.id}', extra: match),
                          borderRadius: BorderRadius.circular(NexusRadii.xl),
                          child: NexusGlassCard(
                            padding: const EdgeInsets.all(NexusSpacing.md),
                            child: Row(
                              children: <Widget>[
                                MatchScoreRing(
                                  percent: match.compatibilityScore,
                                  size: 52,
                                ),
                                const SizedBox(width: NexusSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Row(
                                        children: <Widget>[
                                          Expanded(
                                            child: Text(
                                              match.peer.displayName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(
                                                context,
                                              ).textTheme.titleLarge,
                                            ),
                                          ),
                                          if (match.peer.isLivenessVerified)
                                            const VerifiedPlayerBadge(
                                              compact: true,
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        match.lastMessagePreview ??
                                            'Toque para enviar um Co-op Icebreaker',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: NexusSpacing.sm),
                                const Icon(
                                  Icons.lock_outline_rounded,
                                  size: 18,
                                  color: NexusColors.accentCyber,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Screen 6 — Chat E2EE em Tempo Real com cadeado verificado, Co-op Icebreakers,
/// blur protetor em imagens recebidas, atalho Discord/Gamertag e GG Badges.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({required this.match, super.key});

  final DuoMatch match;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _inputController = TextEditingController();
  final Set<String> _revealedImageIds = <String>{};
  List<ChatMessage> _messages = <ChatMessage>[];
  bool _isLoading = true;
  bool _isSending = false;
  StreamSubscription<List<ChatMessage>>? _subscription;

  @override
  void initState() {
    super.initState();
    unawaited(_loadAndSubscribe());
  }

  Future<void> _loadAndSubscribe() async {
    final repo = ref.read(chatRepositoryProvider);
    final res = await repo.fetchMessages(widget.match);
    if (!mounted) return;
    setState(() {
      _messages = res.valueOrNull ?? <ChatMessage>[];
      _isLoading = false;
    });
    _subscription = repo.watchMessages(widget.match).listen((updated) {
      if (!mounted) return;
      setState(() => _messages = updated);
    });
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _send(
    String text, {
    ChatMessageType type = ChatMessageType.text,
  }) async {
    final clean = text.trim();
    if (clean.isEmpty || _isSending) return;
    setState(() => _isSending = true);
    final me = ref.read(myProfileProvider);
    final res = await ref
        .read(chatRepositoryProvider)
        .sendMessage(
          match: widget.match,
          senderId: me.id,
          plaintext: clean,
          type: type,
        );
    if (!mounted) return;
    setState(() => _isSending = false);
    res.fold(
      onSuccess: (_) {
        _inputController.clear();
        ref.invalidate(matchesProvider);
      },
      onFailure: (failure) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      },
    );
  }

  Future<void> _openGgBadgeSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: NexusColors.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(NexusRadii.xl),
        ),
      ),
      builder: (sheetCtx) {
        return Padding(
          padding: const EdgeInsets.all(NexusSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Enviar GG Fair Play Badge para ${widget.match.peer.displayName}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: NexusSpacing.xs),
              Text(
                'Apenas reforço positivo voluntário após jogar ou conversar.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: NexusSpacing.md),
              Wrap(
                spacing: NexusSpacing.sm,
                runSpacing: NexusSpacing.sm,
                children: GgBadgeCode.values.map((badge) {
                  return ActionChip(
                    label: Text('${badge.emoji} ${badge.label}'),
                    onPressed: () async {
                      await ref
                          .read(profileRepositoryProvider)
                          .awardGgBadge(
                            recipientId: widget.match.peer.id,
                            matchId: widget.match.id,
                            badge: badge,
                          );
                      if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Selo ${badge.emoji} ${badge.label} enviado!',
                            ),
                          ),
                        );
                      }
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  void _copyGamertag() {
    final discord =
        widget.match.peer.discordHandle ?? '@${widget.match.peer.username}';
    final riot = widget.match.peer.games.isNotEmpty
        ? widget.match.peer.games.first.verifiedGamertag
        : null;
    final copyText = riot != null ? 'Discord: $discord | ID: $riot' : discord;
    Clipboard.setData(ClipboardData(text: copyText));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Copiado: $copyText')));
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(myProfileProvider);
    final peer = widget.match.peer;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          peer.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (peer.isLivenessVerified) ...<Widget>[
                        const SizedBox(width: 6),
                        const VerifiedPlayerBadge(compact: true),
                      ],
                    ],
                  ),
                  Text(
                    '${widget.match.compatibilityScore}% Match • ${peer.discordHandle ?? '@${peer.username}'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Copiar Discord / Gamertag',
            onPressed: _copyGamertag,
            icon: const Icon(
              Icons.headset_mic_outlined,
              color: NexusColors.accentCyber,
            ),
          ),
          IconButton(
            tooltip: 'Enviar GG Badge',
            onPressed: _openGgBadgeSheet,
            icon: const Icon(
              Icons.workspace_premium_outlined,
              color: NexusColors.semanticSuccess,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              children: <Widget>[
                // E2EE Verified Lock Banner
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(
                    horizontal: NexusSpacing.md,
                    vertical: NexusSpacing.xs,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: NexusSpacing.md,
                    vertical: NexusSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: NexusColors.accentCyber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(NexusRadii.md),
                    border: Border.all(
                      color: NexusColors.accentCyber.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.verified_user_rounded,
                        size: 16,
                        color: NexusColors.accentCyber,
                      ),
                      const SizedBox(width: NexusSpacing.sm),
                      Expanded(
                        child: Text(
                          'Criptografado ponta a ponta (X25519 + AES-256-GCM)',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: NexusColors.accentCyber),
                        ),
                      ),
                    ],
                  ),
                ),
                // Initial Co-op Icebreakers strip
                if (widget.match.icebreakerPrompts.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: NexusSpacing.md,
                      vertical: NexusSpacing.xs,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: NexusSpacing.sm,
                        runSpacing: NexusSpacing.xs,
                        children: widget.match.icebreakerPrompts.take(2).map((
                          prompt,
                        ) {
                          return ActionChip(
                            avatar: const Icon(
                              Icons.bolt_rounded,
                              size: 14,
                              color: NexusColors.brandSecondary,
                            ),
                            label: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 260),
                              child: Text(
                                prompt,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            onPressed: () =>
                                _send(prompt, type: ChatMessageType.icebreaker),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: NexusColors.brandPrimary,
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(NexusSpacing.md),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[index];
                            final isMine = msg.senderId == me.id;
                            final isRevealed =
                                isMine || _revealedImageIds.contains(msg.id);
                            return Align(
                              alignment: isMine
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 420,
                                ),
                                child: Container(
                                  margin: const EdgeInsets.only(
                                    bottom: NexusSpacing.sm,
                                  ),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    gradient: isMine
                                        ? NexusGradients.brand
                                        : null,
                                    color: isMine
                                        ? null
                                        : NexusColors.bgElevated,
                                    borderRadius: BorderRadius.circular(
                                      NexusRadii.lg,
                                    ),
                                    border: isMine
                                        ? null
                                        : Border.all(
                                            color: NexusColors.borderSubtle,
                                          ),
                                  ),
                                  child: msg.type == ChatMessageType.imageBlur
                                      ? _ProtectedBlurImageTile(
                                          caption: msg.plaintext,
                                          revealed: isRevealed,
                                          onReveal: () => setState(
                                            () => _revealedImageIds.add(msg.id),
                                          ),
                                        )
                                      : Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Text(
                                              msg.plaintext,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyLarge
                                                  ?.copyWith(
                                                    color: Colors.white,
                                                  ),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: <Widget>[
                                                Icon(
                                                  Icons.lock_rounded,
                                                  size: 11,
                                                  color: Colors.white
                                                      .withValues(alpha: 0.7),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${msg.createdAt.hour.toString().padLeft(2, '0')}:${msg.createdAt.minute.toString().padLeft(2, '0')}',
                                                  style: NexusTheme.monoStat(
                                                    fontSize: 10,
                                                    color: Colors.white
                                                        .withValues(
                                                          alpha: 0.75,
                                                        ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                // Message composer
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    NexusSpacing.md,
                    NexusSpacing.xs,
                    NexusSpacing.md,
                    NexusSpacing.md,
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: _inputController,
                          textInputAction: TextInputAction.send,
                          onSubmitted: _send,
                          decoration: const InputDecoration(
                            hintText: 'Mensagem cifrada E2EE...',
                          ),
                        ),
                      ),
                      const SizedBox(width: NexusSpacing.sm),
                      IconButton.filled(
                        onPressed: _isSending
                            ? null
                            : () => _send(_inputController.text),
                        style: IconButton.styleFrom(
                          backgroundColor: NexusColors.brandPrimary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(48, 48),
                        ),
                        icon: const Icon(Icons.send_rounded),
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
}

class _ProtectedBlurImageTile extends StatelessWidget {
  const _ProtectedBlurImageTile({
    required this.caption,
    required this.revealed,
    required this.onReveal,
  });

  final String caption;
  final bool revealed;
  final VoidCallback onReveal;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: revealed ? null : onReveal,
      borderRadius: BorderRadius.circular(NexusRadii.md),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(NexusRadii.md),
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(NexusSpacing.md),
              decoration: const BoxDecoration(
                gradient: NexusGradients.cyberAura,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(
                    Icons.image_rounded,
                    size: 32,
                    color: NexusColors.accentCyber,
                  ),
                  const SizedBox(height: NexusSpacing.sm),
                  Text(caption, style: const TextStyle(color: Colors.white)),
                ],
              ),
            ),
            if (!revealed)
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    color: NexusColors.bgVoid.withValues(alpha: 0.65),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(NexusSpacing.sm),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.visibility_outlined,
                          size: 16,
                          color: NexusColors.accentCyber,
                        ),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Mídia protegida • Toque para revelar',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
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
