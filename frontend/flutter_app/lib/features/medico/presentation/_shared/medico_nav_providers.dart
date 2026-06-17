import "package:flutter_riverpod/flutter_riverpod.dart";

enum MedicoView { list, register, control, fixedEdit }

class MedicoNavState {
  final MedicoView currentView;
  final Map<String, dynamic>? selectedPatient;

  MedicoNavState({
    this.currentView = MedicoView.list,
    this.selectedPatient,
  });

  MedicoNavState copyWith({
    MedicoView? currentView,
    Map<String, dynamic>? selectedPatient,
  }) {
    return MedicoNavState(
      currentView: currentView ?? this.currentView,
      selectedPatient: selectedPatient ?? this.selectedPatient,
    );
  }
}

class MedicoNavNotifier extends StateNotifier<MedicoNavState> {
  MedicoNavNotifier() : super(MedicoNavState());

  void setView(MedicoView view, {Map<String, dynamic>? patient}) {
    state = state.copyWith(currentView: view, selectedPatient: patient);
  }

  void goBackToList() {
    state = MedicoNavState(currentView: MedicoView.list, selectedPatient: null);
  }
}

final medicoNavProvider = StateNotifierProvider<MedicoNavNotifier, MedicoNavState>((ref) {
  return MedicoNavNotifier();
});

// Mantener compatibilidad con el código existente que usa estos providers individualmente
final medicoNavViewProvider = Provider<MedicoView>((ref) => ref.watch(medicoNavProvider).currentView);
final selectedPatientProvider = Provider<Map<String, dynamic>?>((ref) => ref.watch(medicoNavProvider).selectedPatient);
