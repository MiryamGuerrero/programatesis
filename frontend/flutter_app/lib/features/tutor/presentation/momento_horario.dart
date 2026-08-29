/// Determina si la hora actual está dentro de la ventana de tiempo de un
/// momento de comida (hora_inicio <= ahora <= hora_fin). Si faltan los datos
/// del horario se considera que ya no se puede marcar.
bool puedeMarcarConsumida({
  String? horaInicio,
  String? horaFin,
  DateTime? ahora,
}) {
  final now = ahora ?? DateTime.now();
  final start = _aMinutos(horaInicio);
  final end = _aMinutos(horaFin);
  if (start == null || end == null) return false;
  final current = now.hour * 60 + now.minute;
  return current >= start && current <= end;
}

/// Devuelve true si el momento de comida YA PASÓ (la hora actual supera
/// la hora_fin). Útil para distinguir entre "aún no llegó" y "ya venció".
bool momentoYaPaso({
  String? horaFin,
  DateTime? ahora,
}) {
  final now = ahora ?? DateTime.now();
  final end = _aMinutos(horaFin);
  if (end == null) return false;
  final current = now.hour * 60 + now.minute;
  return current > end;
}

int? _aMinutos(String? hora) {
  if (hora == null) return null;
  final partes = hora.split(':');
  if (partes.length < 2) return null;
  final h = int.tryParse(partes[0]);
  final m = int.tryParse(partes[1]);
  if (h == null || m == null) return null;
  return h * 60 + m;
}

String _dosDigitos(int v) => v.toString().padLeft(2, '0');

/// Fecha local actual en formato 'yyyy-MM-dd'.
String fechaHoyIso({DateTime? ahora}) {
  final now = ahora ?? DateTime.now();
  return '${now.year}-${_dosDigitos(now.month)}-${_dosDigitos(now.day)}';
}

/// Hora local actual en formato 'HH:mm'.
String horaActualHhMm({DateTime? ahora}) {
  final now = ahora ?? DateTime.now();
  return '${_dosDigitos(now.hour)}:${_dosDigitos(now.minute)}';
}