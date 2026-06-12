import "package:flutter_riverpod/flutter_riverpod.dart";
import "auth_providers.dart";
import "network_providers.dart";
import "../../data/repositories/supabase_crud_repository.dart";
import "../../../features/admin/data/admin_accounts_supabase_repository.dart";
import "../../data/repositories/inteligencia_api_repository.dart";

final selectedPatientIdProvider = StateProvider<String?>((ref) => null);

final miPerfilProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final session = ref.watch(authSessionProvider).valueOrNull;
  if (session == null) {
    return {};
  }

  final repo = ref.watch(supabaseCrudRepositoryProvider);
  return await repo.fetchMyProfile();
});

final tipSaludableProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dio = ref.read(dioProvider);
  final resp = await dio.get('tutor/tips-saludables');
  ref.keepAlive();
  return Map<String, dynamic>.from(resp.data);
});

final usersListProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(supabaseCrudRepositoryProvider).fetchUsers();
});

final patientsListProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(supabaseCrudRepositoryProvider).fetchPatients();
});

final misPacientesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(supabaseCrudRepositoryProvider).fetchMyPatients();
});

final patientExpedienteProvider =
    FutureProvider.family<Map<String, dynamic>, String>(
        (ref, idPaciente) async {
  final repo = ref.watch(supabaseCrudRepositoryProvider);
  return await repo.fetchExpedienteCompleto(idPaciente);
});

final planDiarioProvider = FutureProvider.family<List<Map<String, dynamic>>,
    ({String idPaciente, DateTime fecha})>((ref, arg) async {
  final repo = ref.watch(supabaseCrudRepositoryProvider);
  return await repo.fetchPlanItemsByPaciente(arg.idPaciente, fecha: arg.fecha);
});

final diasConPlanProvider = FutureProvider.family<List<Map<String, dynamic>>,
    ({String idPaciente, int mes, int anio})>((ref, arg) async {
  final dio = ref.watch(dioProvider);
  final resp =
      await dio.get('tutor/dias-con-plan/${arg.idPaciente}', queryParameters: {
    'mes': arg.mes,
    'anio': arg.anio,
  });
  final List<dynamic> data = resp.data;
  return data
      .map((d) => {
            "fecha": DateTime.parse(d['fecha'].toString()),
            "id_plan": d['id_plan'] as int,
          })
      .toList();
});

final listaComprasProvider = FutureProvider.family<
    Map<String, List<Map<String, dynamic>>>,
    ({String idPaciente, DateTime start, DateTime end})>((ref, arg) async {
  final repo = ref.watch(supabaseCrudRepositoryProvider);
  return await repo.fetchShoppingList(arg.idPaciente,
      start: arg.start, end: arg.end);
});

// NAVEGACIÓN INTERNA MÉDICO
enum MedicoView { list, register, control, fixedEdit }

final medicoNavProvider = StateProvider<MedicoView>((ref) => MedicoView.list);
final selectedPatientProvider =
    StateProvider<Map<String, dynamic>?>((ref) => null);

final supabaseCrudRepositoryProvider = Provider<SupabaseCrudRepository>((ref) {
  return SupabaseCrudRepository(
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
  );
});
