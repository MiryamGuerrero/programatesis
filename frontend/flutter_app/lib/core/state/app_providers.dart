import "package:dio/dio.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:supabase_flutter/supabase_flutter.dart";

import "../../core/network/api_client.dart";
import "../../shared/models/app_role.dart";
import "../../shared/repositories/inteligencia_api_repository.dart";
import "../../shared/repositories/supabase_crud_repository.dart";

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final dioProvider = Provider<Dio>((ref) {
  return buildApiClient();
});

final authSessionProvider = StreamProvider<Session?>((ref) async* {
  final client = ref.watch(supabaseClientProvider);
  yield client.auth.currentSession;

  await for (final event in client.auth.onAuthStateChange) {
    yield event.session;
  }
});

final appRoleProvider = FutureProvider<AppRole>((ref) async {
  final session = ref.watch(authSessionProvider).valueOrNull;
  if (session == null) {
    return AppRole.tutor;
  }

  final sessionRole = _resolveRoleFromSessionMetadata(session);
  if (sessionRole != null) {
    return sessionRole;
  }

  final roleFromApi = await _resolveRoleFromBackend(
    dio: ref.watch(dioProvider),
    accessToken: session.accessToken,
  );
  if (roleFromApi != null) {
    return roleFromApi;
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
  const candidateSchemas = ["dom_identidad_usuarios", "usuarios"];

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
