import "package:flutter/foundation.dart";
import "package:dio/dio.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:supabase_flutter/supabase_flutter.dart";

import "../../core/network/api_client.dart";
import "../../features/admin/data/admin_accounts_supabase_repository.dart";
import "../../shared/models/app_role.dart";
import "../../shared/repositories/inteligencia_api_repository.dart";
import "../../shared/repositories/supabase_crud_repository.dart";

final authErrorProvider = StateProvider<String?>((ref) => null);

enum AuthFlowIntent { none, setPassword }

final authFlowIntentProvider = StateProvider<AuthFlowIntent>(
  (ref) => AuthFlowIntent.none,
);

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final dioProvider = Provider<Dio>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final dio = buildApiClient();

  dio.interceptors.add(
    QueuedInterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _resolveValidAccessToken(client);
        if (token != null && token.isNotEmpty) {
          options.headers["Authorization"] = "Bearer $token";
        } else {
          options.headers.remove("Authorization");
        }

        return handler.next(options);
      },
      onError: (error, handler) async {
        final statusCode = error.response?.statusCode;
        final request = error.requestOptions;
        final alreadyRetried = request.extra["auth_retry"] == true;

        if (statusCode == 403) {
          final data = error.response?.data;
          if (data is Map && data["detail"] == "Account deactivated") {
            try {
              ref.read(authErrorProvider.notifier).state = "Tu cuenta ha sido desactivada. Contacta al administrador.";
              await client.auth.signOut();
            } catch (_) {}
          }
        }

        if (statusCode == 401 && !alreadyRetried) {
          try {
            final refreshed = await client.auth.refreshSession();
            final newToken =
                refreshed.session?.accessToken ?? client.auth.currentSession?.accessToken;

            if (newToken != null && newToken.isNotEmpty) {
              request.headers["Authorization"] = "Bearer $newToken";
              request.extra["auth_retry"] = true;

              final retried = await dio.fetch<dynamic>(request);
              return handler.resolve(retried);
            }
          } catch (_) {
            // Fall through to force sign-out below.
          }

          try {
            await client.auth.signOut();
          } catch (_) {
            // Ignore sign-out errors; original 401 is still returned.
          }
        }

        return handler.next(error);
      },
    ),
  );

  return dio;
});

Future<String?> _resolveValidAccessToken(SupabaseClient client) async {
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

Future<Session?> _ensureValidSession(
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
    try {
      await client.auth.signOut();
    } catch (_) {
      // Ignore sign-out errors.
    }
    return null;
  }
}

final authSessionProvider = StreamProvider<Session?>((ref) async* {
  final client = ref.watch(supabaseClientProvider);

  if (_isPasswordRecoveryUrl()) {
    ref.read(authFlowIntentProvider.notifier).state = AuthFlowIntent.setPassword;
    await _restoreRecoverySessionFromUrl(client);
  }

  yield await _ensureValidSession(client, client.auth.currentSession);

  await for (final event in client.auth.onAuthStateChange) {
    if (event.event == AuthChangeEvent.passwordRecovery) {
      ref.read(authFlowIntentProvider.notifier).state = AuthFlowIntent.setPassword;
    } else if (event.event == AuthChangeEvent.signedOut) {
      ref.read(authFlowIntentProvider.notifier).state = AuthFlowIntent.none;
    }
    yield await _ensureValidSession(client, event.session);
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

  // 1. Validar SIEMPRE contra el backend primero para ejecutar reglas de seguridad
  // (esto garantiza que el usuario no este desactivado, sin importar su rol).
  final roleFromApi = await _resolveRoleFromBackend(
    dio: ref.watch(dioProvider),
    accessToken: session.accessToken,
  );

  // Si el backend rechazo el token (cuenta inactiva), el interceptor ya guardo el error.
  // Abortamos de inmediato para no dar acceso accidental.
  if (ref.read(authErrorProvider) != null) {
    return AppRole.tutor;
  }

  if (roleFromApi != null) {
    return roleFromApi;
  }

  // 2. Fallbacks locales (metadatos de sesion y base de datos)
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

final selectedPatientIdProvider = StateProvider<String?>((ref) => null);

final supabaseCrudRepositoryProvider = Provider<SupabaseCrudRepository>((ref) {
  return SupabaseCrudRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(dioProvider),
  );
});

final adminAccountsRepositoryProvider =
    Provider<AdminAccountsSupabaseRepository>((ref) {
  return AdminAccountsSupabaseRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(dioProvider),
  );
});

final inteligenciaRepositoryProvider =
    Provider<InteligenciaApiRepository>((ref) {
  return InteligenciaApiRepository(
    dio: ref.watch(dioProvider),
    supabaseClient: ref.watch(supabaseClientProvider),
  );
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
  required Dio dio,
  required String accessToken,
}) async {
  try {
    final response = await dio.get(
      "/auth-context",
      options: Options(
        headers: {
          "Authorization": "Bearer $accessToken",
        },
      ),
    );

    final data = response.data;
    if (data is! Map) {
      return null;
    }

    return tryParseRole(data["role"]);
  } catch (_) {
    return null;
  }
}

Future<AppRole?> _resolveRoleFromUsersTable({
  required SupabaseClient client,
  required String userId,
  required String? email,
}) async {
  const candidateSchemas = ["usuarios"];

  for (final schema in candidateSchemas) {
    try {
      final rowById = await client
          .schema(schema)
          .from("usuario")
          .select("id_rol")
          .eq("id", userId)
          .maybeSingle();

      final roleById = tryParseRole(rowById?["id_rol"]);
      if (roleById != null) {
        return roleById;
      }
    } catch (_) {
      // Ignore and try next schema.
    }
  }

  if (email == null || email.trim().isEmpty) {
    return null;
  }

  for (final schema in candidateSchemas) {
    try {
      final rowByEmail = await client
          .schema(schema)
          .from("usuario")
          .select("id_rol")
          .eq("email", email.trim())
          .maybeSingle();

      final roleByEmail = tryParseRole(rowByEmail?["id_rol"]);
      if (roleByEmail != null) {
        return roleByEmail;
      }
    } catch (_) {
      // Ignore and try next schema.
    }
  }

  return null;
}
