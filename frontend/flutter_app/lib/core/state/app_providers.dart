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

final appRoleProvider = Provider<AppRole>((ref) {
  final session = ref.watch(authSessionProvider).valueOrNull;
  final roleRaw = session?.user.appMetadata["role"] as String?;
  return parseRole(roleRaw);
});

final selectedPatientIdProvider = StateProvider<String?>((ref) => null);

final supabaseCrudRepositoryProvider = Provider<SupabaseCrudRepository>((ref) {
  return SupabaseCrudRepository(ref.watch(supabaseClientProvider));
});

final inteligenciaRepositoryProvider = Provider<InteligenciaApiRepository>((ref) {
  return InteligenciaApiRepository(
    dio: ref.watch(dioProvider),
    supabaseClient: ref.watch(supabaseClientProvider),
  );
});
