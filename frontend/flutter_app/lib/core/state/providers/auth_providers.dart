import "dart:convert";
import "package:flutter/foundation.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:http/http.dart" as http;
import "package:supabase_flutter/supabase_flutter.dart";

import "../../config/app_config.dart";
import "../../../shared/models/app_role.dart";
import "network_providers.dart";

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

  if (_isPasswordRecoveryUrl()) {
    ref.read(authFlowIntentProvider.notifier).state =
        AuthFlowIntent.setPassword;
    await _restoreRecoverySessionFromUrl(client);
  }

  yield await ensureValidSession(client, client.auth.currentSession);

  await for (final event in client.auth.onAuthStateChange) {
    if (event.event == AuthChangeEvent.passwordRecovery) {
      ref.read(authFlowIntentProvider.notifier).state =
          AuthFlowIntent.setPassword;
    } else if (event.event == AuthChangeEvent.signedOut) {
      ref.read(authFlowIntentProvider.notifier).state = AuthFlowIntent.none;
    }
    yield await ensureValidSession(
      client,
      event.session ?? client.auth.currentSession,
    );
  }
});

bool _isPasswordRecoveryUrl() {
  if (!kIsWeb) {
    return false;
  }

  final uri = Uri.base;
  final queryType = (uri.queryParameters["type"] ?? "").trim().toLowerCase();
  if (queryType == "recovery") {
    return true;
  }

  final fragment = uri.fragment;
  if (fragment.isEmpty) {
    return false;
  }

  try {
    final params = Uri.splitQueryString(fragment);
    final fragmentType = (params["type"] ?? "").trim().toLowerCase();
    return fragmentType == "recovery";
  } catch (_) {
    return fragment.toLowerCase().contains("type=recovery");
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
