import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/crypto/e2ee_cipher.dart';
import '../../../core/domain/value_objects/gamer_age.dart';
import '../../../core/domain/value_objects/profile_db_normalizer.dart';
import '../../../core/domain/value_objects/weekly_schedule_mask.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/media/avatar_photo_sanitizer.dart';
import '../../chat/domain/chat_message.dart';
import '../../discovery/domain/discovery_entities.dart';
import '../../discovery/domain/match_scoring_strategy.dart';
import '../../lobby/domain/duo_lobby.dart';
import '../../profile/domain/gamer_profile.dart';
import '../domain/nexus_repositories.dart';

/// Production Supabase Auth implementation (Discord OAuth2 + Email/Password).
class SupabaseAuthRepository implements IAuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;
  static const String _redirectUrl = 'com.nexusduo.app://login-callback';

  @override
  Future<AuthSession?> currentSession() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    final profileRow = await _client
        .from('profiles')
        .select('id')
        .eq('id', user.id)
        .maybeSingle();
    return AuthSession(
      userId: user.id,
      email: user.email ?? '',
      provider: (user.appMetadata['provider'] as String?) ?? 'email',
      isDemo: false,
      hasCompletedOnboarding: profileRow != null,
    );
  }

  @override
  Future<Result<AuthSession>> signInWithDiscord() async {
    try {
      await _client.auth.signInWithOAuth(
        OAuthProvider.discord,
        redirectTo: _redirectUrl,
      );
      final session = await currentSession();
      if (session == null) {
        return const FailureResult<AuthSession>(
          AuthFailure(
            'Aguardando retorno do Discord OAuth2.',
            code: 'OAUTH_PENDING',
          ),
        );
      }
      return Success<AuthSession>(session);
    } on AuthException catch (e) {
      return FailureResult<AuthSession>(AuthFailure(e.message));
    } catch (e) {
      return FailureResult<AuthSession>(
        NetworkFailure('Erro Discord OAuth: $e'),
      );
    }
  }

  @override
  Future<Result<AuthSession>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      final user = res.user;
      if (user == null) {
        return const FailureResult<AuthSession>(
          AuthFailure('Credenciais inválidas.'),
        );
      }
      final session = await currentSession();
      return Success<AuthSession>(
        session ??
            AuthSession(
              userId: user.id,
              email: user.email ?? email.trim(),
              provider: 'email',
              isDemo: false,
              hasCompletedOnboarding: false,
            ),
      );
    } on AuthException catch (e) {
      return FailureResult<AuthSession>(AuthFailure(e.message));
    } catch (e) {
      return FailureResult<AuthSession>(
        NetworkFailure('Erro ao autenticar: $e'),
      );
    }
  }

  @override
  Future<Result<AuthSession>> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final cleanEmail = email.trim();
      if (!cleanEmail.contains('@') || password.length < 8) {
        return const FailureResult<AuthSession>(
          ValidationFailure(
            'Informe um email válido e senha com 8+ caracteres (letras e números).',
          ),
        );
      }
      final res = await _client.auth.signUp(
        email: cleanEmail,
        password: password,
        emailRedirectTo: _redirectUrl,
      );
      final user = res.user;
      if (user == null) {
        return const FailureResult<AuthSession>(
          AuthFailure('Não foi possível criar a conta no momento.'),
        );
      }
      if (res.session == null) {
        return const FailureResult<AuthSession>(
          AuthFailure(
            'Conta criada! Confirme o link enviado ao seu email para entrar.',
            code: 'AUTH_CONFIRM_EMAIL',
          ),
        );
      }
      final session = await currentSession();
      return Success<AuthSession>(
        session ??
            AuthSession(
              userId: user.id,
              email: user.email ?? cleanEmail,
              provider: 'email',
              isDemo: false,
              hasCompletedOnboarding: false,
            ),
      );
    } on AuthException catch (e) {
      return FailureResult<AuthSession>(AuthFailure(e.message));
    } catch (e) {
      return FailureResult<AuthSession>(
        NetworkFailure('Erro ao criar conta: $e'),
      );
    }
  }

  @override
  Future<Result<AuthSession>> enterDemoMode() async {
    return const FailureResult<AuthSession>(
      AuthFailure(
        'Ative runtimeDemoOverrideProvider para entrar no Modo Demo em build cloud.',
      ),
    );
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}

/// Production Supabase Profile & LGPD repository.
class SupabaseProfileRepository implements IProfileRepository {
  SupabaseProfileRepository(
    this._client,
    this._cipher, {
    AvatarPhotoSanitizer sanitizer = const AvatarPhotoSanitizer(),
  }) : _sanitizer = sanitizer;

  final SupabaseClient _client;
  final IMessageCipher _cipher;
  final AvatarPhotoSanitizer _sanitizer;

  @override
  Future<Result<GamerProfile>> getMyProfile() async {
    try {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) {
        return const FailureResult<GamerProfile>(
          AuthFailure('Sessão expirada.'),
        );
      }
      final row = await _client
          .from('profiles')
          .select(
            'id, username, display_name, birth_date, gender, interested_in, bio, gamer_dna, schedule_mask, city_label, is_liveness_verified, e2ee_public_key, discord_handle, steam_id, only_verified_filter, women_or_receiver_first',
          )
          .eq('id', uid)
          .single();
      return Success<GamerProfile>(_mapProfileRow(row));
    } on PostgrestException catch (e) {
      return FailureResult<GamerProfile>(
        RlsPermissionFailure(e.message, code: e.code),
      );
    } catch (e) {
      return FailureResult<GamerProfile>(
        NetworkFailure('Erro ao carregar perfil: $e'),
      );
    }
  }

  @override
  Future<Result<GamerProfile>> saveMyProfile(GamerProfile profile) async {
    try {
      final uid = _client.auth.currentUser?.id ?? profile.id;
      final pubKey = await _cipher.getOrCreatePublicKeyB64();
      final embedding = profile.gamerDna.toEmbedding128(
        genres: profile.allGenres,
        platforms: profile.platforms,
      );

      final normalizedUsername = ProfileDbNormalizer.normalizeUsername(
        profile.username,
        userId: uid,
      );
      final normalizedGender = ProfileDbNormalizer.normalizeGender(
        profile.gender,
      );
      final normalizedInterestedIn = ProfileDbNormalizer.normalizeInterestedIn(
        profile.interestedIn,
      );

      await _client.from('profiles').upsert(<String, dynamic>{
        'id': uid,
        'username': normalizedUsername,
        'display_name': profile.displayName.trim(),
        'birth_date': profile.age.birthDate.toIso8601String().split('T').first,
        'gender': normalizedGender,
        'interested_in': normalizedInterestedIn,
        'bio': profile.bio,
        'city_label': profile.cityLabel,
        'gamer_dna': <String, dynamic>{
          'competitive': profile.gamerDna.competitiveScore,
          'voice': profile.gamerDna.voicePreferenceScore,
          'coop': profile.gamerDna.coopFocusScore,
          'night_owl': profile.gamerDna.nightOwlScore,
          'archetype': profile.gamerDna.archetypeTitle,
        },
        'schedule_mask': profile.scheduleMask.chunks,
        'dna_embedding': embedding,
        'is_liveness_verified': profile.isLivenessVerified,
        'e2ee_public_key': pubKey,
        'discord_handle': profile.discordHandle,
        'steam_id': profile.steamId,
        'only_verified_filter': profile.onlyVerifiedFilter,
        'women_or_receiver_first': profile.receiverFirstMode,
      });

      return Success<GamerProfile>(profile.copyWith(e2eePublicKeyB64: pubKey));
    } on PostgrestException catch (e) {
      return FailureResult<GamerProfile>(
        RlsPermissionFailure(e.message, code: e.code),
      );
    } catch (e) {
      return FailureResult<GamerProfile>(
        NetworkFailure('Erro ao salvar perfil no Supabase: $e'),
      );
    }
  }

  @override
  Future<Result<List<UserGameEntry>>> searchGamesCatalog(String query) async {
    try {
      final rows = await _client
          .from('games_catalog')
          .select('id, title, slug, genres, platforms, supports_crossplay')
          .ilike('title', '%${query.trim()}%')
          .limit(20);
      final games = (rows as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(
            (r) => UserGameEntry(
              gameId: (r['id'] as num).toInt(),
              title: r['title'] as String,
              slug: r['slug'] as String,
              genres: (r['genres'] as List<dynamic>? ?? const <dynamic>[])
                  .map((e) => e.toString())
                  .toList(),
              platforms: const <GamerPlatform>[GamerPlatform.pc],
              supportsCrossplay: (r['supports_crossplay'] as bool?) ?? false,
              priorityOrder: 1,
            ),
          )
          .toList(growable: false);
      return Success<List<UserGameEntry>>(games);
    } catch (e) {
      return FailureResult<List<UserGameEntry>>(
        NetworkFailure('Erro ao buscar catálogo de jogos: $e'),
      );
    }
  }

  @override
  Future<Result<void>> awardGgBadge({
    required String recipientId,
    required String matchId,
    required GgBadgeCode badge,
  }) async {
    try {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) {
        return const FailureResult<void>(
          AuthFailure('Usuário não autenticado.'),
        );
      }
      await _client.from('user_badges').insert(<String, dynamic>{
        'recipient_id': recipientId,
        'giver_id': uid,
        'match_id': matchId,
        'badge_code': badge.name,
      });
      return const Success<void>(null);
    } on PostgrestException catch (e) {
      return FailureResult<void>(RlsPermissionFailure(e.message));
    } catch (e) {
      return FailureResult<void>(NetworkFailure('Erro ao enviar GG Badge: $e'));
    }
  }

  @override
  Future<Result<Map<String, dynamic>>> exportLgpdJson() async {
    try {
      final result = await _client.rpc<Map<String, dynamic>>('export_my_data');
      return Success<Map<String, dynamic>>(result);
    } catch (e) {
      return FailureResult<Map<String, dynamic>>(
        NetworkFailure('Falha ao exportar dados LGPD: $e'),
      );
    }
  }

  @override
  Future<Result<void>> deleteMyAccount() async {
    try {
      final res = await _client.functions.invoke('delete-account');
      if (res.status >= 400) {
        return FailureResult<void>(
          NetworkFailure('Falha ao excluir conta LGPD (HTTP ${res.status}).'),
        );
      }
      await _client.auth.signOut();
      return const Success<void>(null);
    } catch (e) {
      return FailureResult<void>(
        NetworkFailure('Falha ao excluir conta LGPD: $e'),
      );
    }
  }

  @override
  Future<Result<String>> uploadSanitizedAvatar({
    required Uint8List rawBytes,
    required String fileName,
    int position = 0,
    bool isPrimary = true,
  }) async {
    try {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) {
        return const FailureResult<String>(
          AuthFailure('Usuário não autenticado para upload de foto.'),
        );
      }

      final sanitizedRes = _sanitizer.sanitize(rawBytes);
      final sanitized = sanitizedRes.valueOrNull;
      if (sanitized == null) {
        return FailureResult<String>(
          sanitizedRes.failureOrNull ??
              const ValidationFailure('Falha ao sanitizar foto de perfil.'),
        );
      }

      final safeStem = fileName
          .replaceAll(RegExp(r'\.[^.]+$'), '')
          .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final storagePath =
          '$uid/${DateTime.now().millisecondsSinceEpoch}_$safeStem.${sanitized.format.extension}';

      await _client.storage
          .from('avatars')
          .uploadBinary(
            storagePath,
            sanitized.bytes,
            fileOptions: FileOptions(
              contentType: sanitized.format.mimeType,
              upsert: true,
            ),
          );

      await _client.from('profile_photos').insert(<String, dynamic>{
        'user_id': uid,
        'storage_path': storagePath,
        'position': position,
        'is_primary': isPrimary,
      });

      return Success<String>(storagePath);
    } on StorageException catch (e) {
      return FailureResult<String>(NetworkFailure(e.message));
    } on PostgrestException catch (e) {
      return FailureResult<String>(
        RlsPermissionFailure(e.message, code: e.code),
      );
    } catch (e) {
      return FailureResult<String>(
        NetworkFailure('Erro ao enviar avatar sanitizado: $e'),
      );
    }
  }
}

/// Production Supabase Discovery repository using `get_discovery_deck` RPC
/// (never reading raw `approx_location` coordinates).
class SupabaseDiscoveryRepository implements IDiscoveryRepository {
  SupabaseDiscoveryRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Result<List<DiscoveryCandidate>>> fetchDailyLootDrop({
    required GamerProfile me,
    required IMatchScoringStrategy strategy,
  }) async {
    try {
      final rows = await _client.rpc<List<dynamic>>(
        'get_discovery_deck',
        params: <String, dynamic>{'p_limit': 20},
      );
      final candidates = rows
          .whereType<Map<String, dynamic>>()
          .map((row) {
            final profile = _mapProfileRow(row);
            final breakdown = strategy.calculate(me: me, target: profile);
            return DiscoveryCandidate(profile: profile, breakdown: breakdown);
          })
          .toList(growable: false);
      return Success<List<DiscoveryCandidate>>(candidates);
    } on PostgrestException catch (e) {
      return FailureResult<List<DiscoveryCandidate>>(
        RlsPermissionFailure(e.message, code: e.code),
      );
    } catch (e) {
      return FailureResult<List<DiscoveryCandidate>>(
        NetworkFailure('Erro ao carregar Daily Loot Drop: $e'),
      );
    }
  }

  @override
  Future<Result<DuoMatch?>> submitSwipe({
    required GamerProfile me,
    required DiscoveryCandidate candidate,
    required SwipeAction action,
    String? introNote,
  }) async {
    try {
      final actionName = switch (action) {
        SwipeAction.like => 'like',
        SwipeAction.pass => 'pass',
        SwipeAction.superDuo => 'super_duo',
      };
      final rawPayload = await _client.rpc<Map<String, dynamic>>(
        'record_swipe_and_match',
        params: <String, dynamic>{
          'p_target_id': candidate.profile.id,
          'p_action': actionName,
          'p_intro_note': introNote,
        },
      );

      final parsed = AvatarPhotoSanitizer.parseSwipeAndMatchResponse(
        rawPayload,
        fallbackScore: candidate.breakdown.totalScorePercent,
      );
      if (!parsed.matched || parsed.matchId == null) {
        return const Success<DuoMatch?>(null);
      }

      return Success<DuoMatch?>(
        DuoMatch(
          id: parsed.matchId!,
          peer: candidate.profile,
          compatibilityScore: parsed.compatibilityScore,
          commonHoursPerWeek: candidate.breakdown.commonHoursPerWeek,
          icebreakerPrompts: parsed.icebreakers,
          createdAt: DateTime.now(),
        ),
      );
    } on PostgrestException catch (e) {
      return FailureResult<DuoMatch?>(
        RlsPermissionFailure(e.message, code: e.code),
      );
    } catch (e) {
      return FailureResult<DuoMatch?>(
        NetworkFailure('Erro ao registrar swipe: $e'),
      );
    }
  }

  @override
  Future<Result<List<DuoMatch>>> fetchMatches() async {
    try {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) {
        return const FailureResult<List<DuoMatch>>(
          AuthFailure('Não autenticado.'),
        );
      }
      final rows = await _client
          .from('matches')
          .select(
            'id, user_a, user_b, compatibility_score, icebreaker_prompts, is_active, created_at',
          )
          .eq('is_active', true)
          .order('created_at', ascending: false);

      final matches = <DuoMatch>[];
      for (final raw
          in (rows as List<dynamic>).whereType<Map<String, dynamic>>()) {
        final peerId = raw['user_a'] == uid
            ? raw['user_b'] as String
            : raw['user_a'] as String;
        final peerRow = await _client
            .from('profiles')
            .select(
              'id, username, display_name, birth_date, gender, interested_in, bio, gamer_dna, schedule_mask, city_label, is_liveness_verified, e2ee_public_key, discord_handle, steam_id',
            )
            .eq('id', peerId)
            .maybeSingle();
        if (peerRow == null) continue;
        matches.add(
          DuoMatch(
            id: raw['id'] as String,
            peer: _mapProfileRow(peerRow),
            compatibilityScore:
                (raw['compatibility_score'] as num?)?.toInt() ?? 85,
            commonHoursPerWeek: 6,
            icebreakerPrompts: AvatarPhotoSanitizer.extractIcebreakerPrompts(
              raw['icebreaker_prompts'],
            ),
            createdAt:
                DateTime.tryParse(raw['created_at'] as String? ?? '') ??
                DateTime.now(),
          ),
        );
      }
      return Success<List<DuoMatch>>(matches);
    } catch (e) {
      return FailureResult<List<DuoMatch>>(
        NetworkFailure('Erro ao listar matches: $e'),
      );
    }
  }

  @override
  Future<Result<void>> blockAndReport({
    required String targetUserId,
    required String reason,
  }) async {
    try {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) {
        return const FailureResult<void>(AuthFailure('Não autenticado.'));
      }
      await _client.from('blocks').insert(<String, dynamic>{
        'blocker_id': uid,
        'blocked_id': targetUserId,
      });
      await _client.from('reports').insert(<String, dynamic>{
        'reporter_id': uid,
        'reported_id': targetUserId,
        'reason': reason,
      });
      return const Success<void>(null);
    } catch (e) {
      return FailureResult<void>(
        NetworkFailure('Erro ao bloquear usuário: $e'),
      );
    }
  }
}

/// Production Supabase Ephemeral 2-hour "Duo Agora" Lobby repository.
class SupabaseLobbyRepository implements ILobbyRepository {
  SupabaseLobbyRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Result<List<DuoLobby>>> fetchActiveLobbies({
    String? gameFilter,
    LobbyMode? modeFilter,
  }) async {
    try {
      final rows = await _client
          .from('duo_lobbies')
          .select('id, host_id, mode, voice_pref, notes, expires_at')
          .gt('expires_at', DateTime.now().toUtc().toIso8601String())
          .order('expires_at', ascending: true)
          .limit(30);
      final list = (rows as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(
            (r) => DuoLobby(
              id: r['id'] as String,
              hostId: r['host_id'] as String,
              hostDisplayName: 'Player Online',
              hostUsername: 'duo_host',
              hostVerified: true,
              gameTitle: gameFilter ?? 'Valorant',
              mode: LobbyMode.values.firstWhere(
                (m) => m.name == r['mode'],
                orElse: () => LobbyMode.casual,
              ),
              voicePreference: VoicePreference.discord,
              notes: (r['notes'] as String?) ?? '',
              expiresAt:
                  DateTime.tryParse(r['expires_at'] as String? ?? '') ??
                  DateTime.now().add(const Duration(hours: 2)),
              compatibilityScore: 90,
            ),
          )
          .toList(growable: false);
      return Success<List<DuoLobby>>(list);
    } catch (e) {
      return FailureResult<List<DuoLobby>>(
        NetworkFailure('Erro ao buscar lobbies ativos: $e'),
      );
    }
  }

  @override
  Future<Result<DuoLobby>> createLobby({
    required GamerProfile host,
    required String gameTitle,
    required LobbyMode mode,
    required VoicePreference voicePreference,
    required String notes,
  }) async {
    try {
      final expires = DateTime.now().toUtc().add(const Duration(hours: 2));
      final inserted = await _client
          .from('duo_lobbies')
          .insert(<String, dynamic>{
            'host_id': host.id,
            'mode': mode.name,
            'voice_pref': switch (voicePreference) {
              VoicePreference.discord => 'discord',
              VoicePreference.inGame => 'in_game',
              VoicePreference.textOnly => 'text_only',
            },
            'notes': notes,
            'expires_at': expires.toIso8601String(),
          })
          .select('id')
          .single();

      return Success<DuoLobby>(
        DuoLobby(
          id: inserted['id'] as String,
          hostId: host.id,
          hostDisplayName: host.displayName,
          hostUsername: host.username,
          hostVerified: host.isLivenessVerified,
          gameTitle: gameTitle,
          mode: mode,
          voicePreference: voicePreference,
          notes: notes,
          expiresAt: expires.toLocal(),
          compatibilityScore: 100,
          discordHandle: host.discordHandle,
        ),
      );
    } catch (e) {
      return FailureResult<DuoLobby>(NetworkFailure('Erro ao criar lobby: $e'));
    }
  }
}

/// Production Supabase E2EE Chat repository using [AesGcmE2EECipher].
class SupabaseChatRepository implements IChatRepository {
  SupabaseChatRepository(this._client, this._cipher);

  final SupabaseClient _client;
  final IMessageCipher _cipher;

  @override
  Future<Result<List<ChatMessage>>> fetchMessages(DuoMatch match) async {
    try {
      final rows = await _client
          .from('messages')
          .select(
            'id, match_id, sender_id, ciphertext_b64, nonce_b64, msg_type, created_at, read_at',
          )
          .eq('match_id', match.id)
          .order('created_at', ascending: true)
          .limit(50);

      final decoded = <ChatMessage>[];
      for (final row
          in (rows as List<dynamic>).whereType<Map<String, dynamic>>()) {
        final senderId = row['sender_id'] as String;
        final ciphertext = row['ciphertext_b64'] as String;
        final nonce = row['nonce_b64'] as String;
        final plaintext = await _cipher.decrypt(
          payload: EncryptedPayload(
            ciphertextB64: ciphertext,
            nonceB64: nonce,
            aadUtf8: '${match.id}:$senderId',
          ),
          peerPublicKeyB64: match.peer.e2eePublicKeyB64,
          matchId: match.id,
          senderId: senderId,
        );
        decoded.add(
          ChatMessage(
            id: row['id'].toString(),
            matchId: match.id,
            senderId: senderId,
            ciphertextB64: ciphertext,
            nonceB64: nonce,
            plaintext: plaintext,
            type: _parseMessageType(row['msg_type'] as String?),
            createdAt:
                DateTime.tryParse(row['created_at'] as String? ?? '') ??
                DateTime.now(),
            isRead: row['read_at'] != null,
          ),
        );
      }
      return Success<List<ChatMessage>>(decoded);
    } on AppFailure catch (e) {
      return FailureResult<List<ChatMessage>>(e);
    } catch (e) {
      return FailureResult<List<ChatMessage>>(
        NetworkFailure('Erro ao carregar chat E2EE: $e'),
      );
    }
  }

  @override
  Future<Result<ChatMessage>> sendMessage({
    required DuoMatch match,
    required String senderId,
    required String plaintext,
    ChatMessageType type = ChatMessageType.text,
  }) async {
    try {
      final encrypted = await _cipher.encrypt(
        plaintext: plaintext,
        peerPublicKeyB64: match.peer.e2eePublicKeyB64,
        matchId: match.id,
        senderId: senderId,
      );

      final inserted = await _client
          .from('messages')
          .insert(<String, dynamic>{
            'match_id': match.id,
            'sender_id': senderId,
            'ciphertext_b64': encrypted.ciphertextB64,
            'nonce_b64': encrypted.nonceB64,
            'msg_type': switch (type) {
              ChatMessageType.text => 'text',
              ChatMessageType.icebreaker => 'icebreaker',
              ChatMessageType.lobbyInvite => 'lobby_invite',
              ChatMessageType.imageBlur => 'image_blur',
            },
          })
          .select('id, created_at')
          .single();

      return Success<ChatMessage>(
        ChatMessage(
          id: inserted['id'].toString(),
          matchId: match.id,
          senderId: senderId,
          ciphertextB64: encrypted.ciphertextB64,
          nonceB64: encrypted.nonceB64,
          plaintext: plaintext,
          type: type,
          createdAt:
              DateTime.tryParse(inserted['created_at'] as String? ?? '') ??
              DateTime.now(),
        ),
      );
    } on AppFailure catch (e) {
      return FailureResult<ChatMessage>(e);
    } catch (e) {
      return FailureResult<ChatMessage>(
        NetworkFailure('Erro ao enviar mensagem E2EE: $e'),
      );
    }
  }

  @override
  Stream<List<ChatMessage>> watchMessages(DuoMatch match) {
    return _client
        .from('messages')
        .stream(primaryKey: const <String>['id'])
        .eq('match_id', match.id)
        .order('created_at', ascending: true)
        .asyncMap((rows) async {
          final result = <ChatMessage>[];
          for (final row in rows) {
            final senderId = row['sender_id'] as String;
            final ciphertext = row['ciphertext_b64'] as String;
            final nonce = row['nonce_b64'] as String;
            try {
              final plaintext = await _cipher.decrypt(
                payload: EncryptedPayload(
                  ciphertextB64: ciphertext,
                  nonceB64: nonce,
                  aadUtf8: '${match.id}:$senderId',
                ),
                peerPublicKeyB64: match.peer.e2eePublicKeyB64,
                matchId: match.id,
                senderId: senderId,
              );
              result.add(
                ChatMessage(
                  id: row['id'].toString(),
                  matchId: match.id,
                  senderId: senderId,
                  ciphertextB64: ciphertext,
                  nonceB64: nonce,
                  plaintext: plaintext,
                  type: _parseMessageType(row['msg_type'] as String?),
                  createdAt:
                      DateTime.tryParse(row['created_at'] as String? ?? '') ??
                      DateTime.now(),
                  isRead: row['read_at'] != null,
                ),
              );
            } catch (_) {
              // Skip unreadable message with mismatched key rather than crashing stream.
            }
          }
          return result;
        });
  }
}

ChatMessageType _parseMessageType(String? raw) {
  return switch (raw) {
    'icebreaker' => ChatMessageType.icebreaker,
    'lobby_invite' => ChatMessageType.lobbyInvite,
    'image_blur' => ChatMessageType.imageBlur,
    _ => ChatMessageType.text,
  };
}

GamerProfile _mapProfileRow(Map<String, dynamic> row) {
  final ageYears = (row['age_years'] as num?)?.toInt();
  final birthRaw = row['birth_date'] as String?;
  final birthDate = birthRaw != null
      ? DateTime.tryParse(birthRaw) ?? DateTime(2000)
      : DateTime(2000);
  final age = ageYears != null
      ? (GamerAge.fromYears(ageYears).valueOrNull ??
            GamerAge.fromYears(22).valueOrNull!)
      : (GamerAge.fromBirthDate(birthDate).valueOrNull ??
            GamerAge.fromYears(22).valueOrNull!);
  final maskRaw =
      (row['schedule_mask'] as List<dynamic>? ?? const <dynamic>[0, 0, 0])
          .map((e) => (e as num).toInt())
          .toList();
  final scheduleMask =
      WeeklyScheduleMask.fromChunks(maskRaw).valueOrNull ??
      WeeklyScheduleMask.empty();
  final dnaMap =
      (row['gamer_dna'] as Map<String, dynamic>?) ?? const <String, dynamic>{};

  return GamerProfile(
    id: ((row['id'] ?? row['profile_id']) as String),
    username: (row['username'] as String?) ?? 'player',
    displayName: (row['display_name'] as String?) ?? 'Player',
    age: age,
    gender: (row['gender'] as String?) ?? 'Não informado',
    interestedIn: (row['interested_in'] as List<dynamic>? ?? const <dynamic>[])
        .map((e) => e.toString())
        .toList(),
    bio: (row['bio'] as String?) ?? '',
    promptQuestion: 'Meu encontro co-op perfeito:',
    promptAnswer: 'Uma partida divertida e sem tilt.',
    cityLabel: (row['city_label'] as String?) ?? 'Brasil',
    distanceKmBucket: (row['distance_km_bucket'] as String?) ?? '~10 km',
    approximateDistanceKm: 10.0,
    gamerDna: GamerDna(
      competitiveScore: (dnaMap['competitive'] as num?)?.toInt() ?? 50,
      voicePreferenceScore: (dnaMap['voice'] as num?)?.toInt() ?? 70,
      coopFocusScore: (dnaMap['coop'] as num?)?.toInt() ?? 80,
      nightOwlScore: (dnaMap['night_owl'] as num?)?.toInt() ?? 65,
      archetypeTitle: (dnaMap['archetype'] as String?) ?? 'Tático Tranquilo',
    ),
    scheduleMask: scheduleMask,
    games: const <UserGameEntry>[],
    platforms: const <GamerPlatform>[GamerPlatform.pc],
    ggBadges: const <GgBadgeCode>[],
    isLivenessVerified: (row['is_liveness_verified'] as bool?) ?? false,
    e2eePublicKeyB64: (row['e2ee_public_key'] as String?) ?? '',
    discordHandle: row['discord_handle'] as String?,
    steamId: row['steam_id'] as String?,
    onlyVerifiedFilter: (row['only_verified_filter'] as bool?) ?? false,
    receiverFirstMode: (row['women_or_receiver_first'] as bool?) ?? false,
  );
}
