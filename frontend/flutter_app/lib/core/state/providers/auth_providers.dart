import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_config.dart';
import '../../../shared/models/app_role.dart';
import '../../services/deep_link_service.dart';
import 'network_providers.dart';

const Duration _signOutTimeout = Duration(seconds: 3);

final authErrorProvider = StateProvider<String?>((ref) => null);

Future<void> safeSignOut(SupabaseClient client) async {
  try {
    await client.auth.signOut().timeout(_signOutTimeout);
  } catch (_) {
    // Ignore sign-out failures during auth recovery flows.
  }
}

enum AuthFlowIntent { none, setPassword }

final authFlowIntentProvider = StateProvider<AuthFlowIntent>(
  (ref) => AuthFlowIntent.none,
);

Future<String?> resolveValidAccessToken(SupabaseClient client) async {
  var session = client.auth.currentSession;

  if (session == null) {
    return null;
  }

  final nowEpochSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final expiresAt = session.expiresAt;
  final expiresSoon = expiresAt != null && expiresAt <= (nowEpochSeconds + 45);

  if (expiresSoon) {
    try {
      final refreshed = await client.auth.refreshSession();
      session = refreshed.session ?? client.auth.currentSession;
    } catch (_) {
      // Return current token if refresh fails; the 401 retry flow will handle fallback.
    }
  }

  final token = session?.accessToken;
  if (token == null || token.isEmpty) {
    return null;
  }

  return token;
}

Future<Session?> ensureValidSession(
  SupabaseClient client,
  Session? session,
) async {
  if (session == null) {
    return null;
  }

  final nowEpochSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final expiresAt = session.expiresAt;
  final expiresSoon = expiresAt != null && expiresAt <= (nowEpochSeconds + 45);

  if (!expiresSoon) {
    return session;
  }

  try {
    final refreshed = await client.auth.refreshSession();
    return refreshed.session ?? client.auth.currentSession;
  } catch (_) {
    await safeSignOut(client);
    return null;
  }
}

final authSessionProvider = StreamProvider<Session?>((ref) async* {
  final client = ref.watch(supabaseClientProvider);

  // ── DETECCIÓN SINCRÓNICA DE RECOVERY ────────────────────────────────────
  // Con el nuevo bootstrap, Supabase.initialize() ya terminó (incluyendo el
  // intercambio PKCE del `code`). El evento passwordRecovery ya fue emitido
  // por el SDK ANTES de que este provider se monte, por lo que no podemos
  // capturarlo del stream. En su lugar:
  //
  //   WEB: Si hay sesión activa Y la URL al inicio contenía indicios de
  //        recovery (code en query string, o token en fragment), es recovery.
  //
  //   MÓVIL: Si hay sesión activa Y el initialLink del deep link tenía
  //          type=recovery o type=invite, es recovery.
  //
  //   AMBOS: Si hay sesión activa y el SDK ya la estableció como recovery,
  //          el flag _isRecoverySession() lo detecta.
  final currentSession = client.auth.currentSession;
  final isRecovery = _isRecoveryLaunch(client, currentSession);

  if (isRecovery) {
    ref.read(authFlowIntentProvider.notifier).state = AuthFlowIntent.setPassword;
  } else if (kIsWeb && _isPasswordRecoveryUrl()) {
    // Fallback web para flujo implicit legacy (fragment con token).
    ref.read(authFlowIntentProvider.notifier).state = AuthFlowIntent.setPassword;
    await _restoreRecoverySessionFromUrl(client);
  } else if (!kIsWeb) {
    // Móvil — cold start: procesar deep link si el SDK no lo manejó solo.
    final deepLinkSvc = DeepLinkService();
    final initialUri = deepLinkSvc.initialLink;
    if (initialUri != null && !isRecovery) {
      final deepLinkIsRecovery = await _handleMobileDeepLink(client, initialUri);
      if (deepLinkIsRecovery) {
        ref.read(authFlowIntentProvider.notifier).state = AuthFlowIntent.setPassword;
      }
    }
  }

  yield await ensureValidSession(client, client.auth.currentSession);

  // ── Suscripción warm start para móvil ────────────────────────────────────
  if (!kIsWeb) {
    final deepLinkSvc = DeepLinkService();
    late StreamSubscription<Uri> linkSub;
    linkSub = deepLinkSvc.linkStream.listen((uri) async {
      final deepLinkIsRecovery = await _handleMobileDeepLink(client, uri);
      if (deepLinkIsRecovery) {
        ref.read(authFlowIntentProvider.notifier).state = AuthFlowIntent.setPassword;
      }
    });
    ref.onDispose(linkSub.cancel);
  }

  // ── Stream principal de eventos de auth ──────────────────────────────────
  // Captura eventos futuros: warm start en móvil, logout, refresh de sesión, etc.
  await for (final event in client.auth.onAuthStateChange) {
    if (event.event == AuthChangeEvent.passwordRecovery) {
      ref.read(authFlowIntentProvider.notifier).state = AuthFlowIntent.setPassword;
    } else if (event.event == AuthChangeEvent.signedOut) {
      ref.read(authFlowIntentProvider.notifier).state = AuthFlowIntent.none;
    }
    yield await ensureValidSession(
      client,
      event.session ?? client.auth.currentSession,
    );
  }
});

/// Determina si el lanzamiento de la app corresponde a un flujo de recovery.
///
/// Se llama DESPUÉS de que Supabase.initialize() completó, por lo que si
/// había un code PKCE, ya fue intercambiado y hay sesión activa.
bool _isRecoveryLaunch(SupabaseClient client, Session? session) {
  if (session == null) return false;

  if (kIsWeb) {
    // En web con PKCE, el code ya fue consumido y la URL limpiada.
    // Leemos la URL del navegador en el momento exacto del launch (antes de
    // cualquier redirect de Flutter). Si había ?code= o #type=recovery, es recovery.
    return _isPasswordRecoveryUrl();
  }

  // En móvil: el initialLink del deep link capturado antes del initialize.
  final initialUri = DeepLinkService().initialLink;
  if (initialUri == null) return false;

  final params = <String, String>{...initialUri.queryParameters};
  if (initialUri.fragment.isNotEmpty) {
    try {
      params.addAll(Uri.splitQueryString(initialUri.fragment));
    } catch (_) {}
  }
  final type = (params['type'] ?? '').trim().toLowerCase();
  // En PKCE, el deep link es reumanutri://auth/callback?code=...
  // Si hay code sin type explícito en este callback, también es recovery
  // ya que en este proyecto el único flujo que llega aquí es recovery/invite.
  final hasCode = params.containsKey('code');
  return type == 'recovery' || type == 'invite' || hasCode;
}


/// Procesa un deep link entrante en plataforma móvil.
///
/// Devuelve `true` si el link es de tipo recovery/invitation (para que el
/// llamador pueda activar el flujo de configuración de contraseña).
Future<bool> _handleMobileDeepLink(SupabaseClient client, Uri uri) async {
  // Extraemos los parámetros tanto del query string como del fragment
  // (algunos clientes de correo modifican cómo llegan los params).
  final params = <String, String>{
    ...uri.queryParameters,
  };
  if (uri.fragment.isNotEmpty) {
    try {
      params.addAll(Uri.splitQueryString(uri.fragment));
    } catch (_) {}
  }

  final code = (params['code'] ?? '').trim();
  final tokenHash = (params['token_hash'] ?? '').trim();
  final accessToken = (params['access_token'] ?? '').trim();
  final refreshToken = (params['refresh_token'] ?? '').trim();
  final type = (params['type'] ?? '').trim().toLowerCase();

  final isRecoveryType = type == 'recovery' || type == 'invite';

  // ── Flujo PKCE (recomendado): Supabase envía un `code` de un solo uso ──
  if (code.isNotEmpty) {
    try {
      await client.auth.exchangeCodeForSession(code);
      return isRecoveryType ||
          (client.auth.currentSession != null); // la sesión se estableció
    } catch (_) {
      // Caemos al siguiente método si falla.
    }
  }

  // ── Flujo OTP hash (token_hash) ─────────────────────────────────────────
  if (tokenHash.isNotEmpty) {
    try {
      await client.auth.verifyOTP(
        type: isRecoveryType ? OtpType.recovery : OtpType.invite,
        tokenHash: tokenHash,
      );
      return true;
    } catch (_) {}
  }

  // ── Flujo implicit legacy (access_token + refresh_token en el fragment) ──
  if (accessToken.isNotEmpty && refreshToken.isNotEmpty) {
    try {
      await client.auth.setSession(refreshToken);
      return isRecoveryType;
    } catch (_) {}
  }

  return false;
}

bool _isPasswordRecoveryUrl() {
  if (!kIsWeb) {
    return false;
  }

  final uri = Uri.base;

  // Flujo PKCE (nuevo): Supabase redirige con ?code=XXXX en el query string.
  // El `code` en el callback URL siempre indica un flujo de auth desde email
  // (recovery o invite) porque el login normal con OAuth no pasa por aquí.
  if (uri.queryParameters.containsKey('code')) {
    return true;
  }

  // type=recovery explícito en el query string (algunos flujos legacy).
  final queryType = (uri.queryParameters['type'] ?? '').trim().toLowerCase();
  if (queryType == 'recovery' || queryType == 'invite') {
    return true;
  }

  // Flujo implicit legacy: token en el fragment (#access_token=...&type=recovery).
  final fragment = uri.fragment;
  if (fragment.isEmpty) {
    return false;
  }

  try {
    final params = Uri.splitQueryString(fragment);
    final fragmentType = (params['type'] ?? '').trim().toLowerCase();
    return fragmentType == 'recovery' || fragmentType == 'invite';
  } catch (_) {
    return fragment.toLowerCase().contains('type=recovery') ||
        fragment.toLowerCase().contains('type=invite');
  }
}

Map<String, String> _recoveryUrlParams() {
  final params = <String, String>{
    ...Uri.base.queryParameters,
  };

  final fragment = Uri.base.fragment;
  if (fragment.isNotEmpty) {
    try {
      params.addAll(Uri.splitQueryString(fragment));
    } catch (_) {
      // Ignore malformed fragments.
    }
  }

  return params;
}

Future<void> _restoreRecoverySessionFromUrl(SupabaseClient client) async {
  if (!kIsWeb) {
    return;
  }

  final params = _recoveryUrlParams();
  final code = (params["code"] ?? "").trim();
  final tokenHash = (params["token_hash"] ?? "").trim();
  final refreshToken = (params["refresh_token"] ?? "").trim();

  if (code.isNotEmpty) {
    try {
      await client.auth.exchangeCodeForSession(code);
      return;
    } catch (_) {
      // Fall through to alternate recovery strategies.
    }
  }

  if (tokenHash.isNotEmpty) {
    try {
      await client.auth.verifyOTP(
        type: OtpType.recovery,
        tokenHash: tokenHash,
      );
      return;
    } catch (_) {
      // Fall through to alternate recovery strategies.
    }
  }

  if (refreshToken.isNotEmpty) {
    try {
      await client.auth.setSession(refreshToken);
      return;
    } catch (_) {
      // Keep graceful behavior if URL payload is not enough.
    }
  }
}

final appRoleProvider = FutureProvider<AppRole>((ref) async {
  final session = ref.watch(authSessionProvider).valueOrNull;
  if (session == null) {
    return AppRole.tutor;
  }

  final roleFromApi = await _resolveRoleFromBackend(
    accessToken: session.accessToken,
    onAccountDeactivated: () {
      ref.read(authErrorProvider.notifier).state =
          "Tu cuenta ha sido desactivada. Contacta al administrador.";
    },
  );

  if (ref.read(authErrorProvider) != null) {
    return AppRole.tutor;
  }

  if (roleFromApi != null) {
    return roleFromApi;
  }

  final sessionRole = _resolveRoleFromSessionMetadata(session);
  if (sessionRole != null) {
    return sessionRole;
  }

  final roleFromUsersTable = await _resolveRoleFromUsersTable(
    client: ref.watch(supabaseClientProvider),
    userId: session.user.id,
    email: session.user.email,
  );

  return roleFromUsersTable ?? AppRole.tutor;
});

AppRole? _resolveRoleFromSessionMetadata(Session session) {
  final candidates = <dynamic>[
    session.user.appMetadata["role"],
    session.user.appMetadata["rol"],
    session.user.appMetadata["id_rol"],
    session.user.userMetadata?["role"],
    session.user.userMetadata?["rol"],
    session.user.userMetadata?["id_rol"],
  ];

  for (final candidate in candidates) {
    final role = tryParseRole(candidate);
    if (role != null) {
      return role;
    }
  }

  return null;
}

Future<AppRole?> _resolveRoleFromBackend({
  required String accessToken,
  required VoidCallback onAccountDeactivated,
}) async {
  for (var attempt = 0; attempt < 2; attempt++) {
    try {
      final response = await http.get(
        Uri.parse("${AppConfig.fastApiBaseUrl}auth-context"),
        headers: {
          "Authorization": "Bearer $accessToken",
          "Accept": "application/json",
        },
      );

      if (response.statusCode == 403) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded["detail"] == "Account deactivated") {
          onAccountDeactivated();
        }
        return null;
      }

      if (response.statusCode != 200) {
        continue;
      }

      final data = jsonDecode(response.body);
      if (data is! Map) {
        return null;
      }

      return tryParseRole(data["role"]);
    } catch (_) {
      // Retry once to smooth transient startup races between frontend and backend.
    }
  }

  return null;
}

Future<AppRole?> _resolveRoleFromUsersTable({
  required SupabaseClient client,
  required String userId,
  required String? email,
}) async {
  const candidateSchemas = ["usuarios"];
  final trimmedEmail = email?.trim();

  for (final schema in candidateSchemas) {
    final roleByAuthUserId = await _resolveRoleByColumn(
      client: client,
      schema: schema,
      column: "auth_user_id",
      value: userId,
    );
    if (roleByAuthUserId != null) {
      return roleByAuthUserId;
    }

    final roleById = await _resolveRoleByColumn(
      client: client,
      schema: schema,
      column: "id",
      value: userId,
    );
    if (roleById != null) {
      return roleById;
    }
  }

  if (trimmedEmail == null || trimmedEmail.isEmpty) {
    return null;
  }

  for (final schema in candidateSchemas) {
    final roleByEmail = await _resolveRoleByColumn(
      client: client,
      schema: schema,
      column: "email",
      value: trimmedEmail,
    );
    if (roleByEmail != null) {
      return roleByEmail;
    }
  }

  return null;
}

Future<AppRole?> _resolveRoleByColumn({
  required SupabaseClient client,
  required String schema,
  required String column,
  required String value,
}) async {
  try {
    final row = await client
        .schema(schema)
        .from("usuario")
        .select("id_rol")
        .eq(column, value)
        .maybeSingle();

    return tryParseRole(row?["id_rol"]);
  } catch (_) {
    return null;
  }
}
