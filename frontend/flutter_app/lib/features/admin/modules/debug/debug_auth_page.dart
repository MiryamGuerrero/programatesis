import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../../core/state/app_providers.dart";
import "../../../../shared/models/app_role.dart";

/// Página de debug para verificar resolución de roles
/// Útil para diagnosticar problemas con autenticación y permisos
class DebugAuthPage extends ConsumerWidget {
  const DebugAuthPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authSession = ref.watch(authSessionProvider);
    final roleAsync = ref.watch(appRoleProvider);
    final authError = ref.watch(authErrorProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Debug: Auth & Roles"),
        backgroundColor: Colors.red[100],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sección: Sesión
            _Section(
              title: "1. Sesión de Supabase",
              child: authSession.when(
                data: (session) {
                  if (session == null) {
                    return const Text("❌ Sin sesión (usuario no autenticado)");
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("✅ Sesión activa"),
                      const SizedBox(height: 8),
                      _KeyValue("User ID", session.user.id),
                      _KeyValue("Email", session.user.email ?? "N/A"),
                      _KeyValue("Proveedor",
                          session.user.appMetadata["provider"] ?? "N/A"),
                      _KeyValue(
                          "Creado", session.user.createdAt.toString() ?? "N/A"),
                      _KeyValue(
                          "Expira", session.expiresAt?.toString() ?? "N/A"),
                      const SizedBox(height: 8),
                      const Text(
                        "📋 App Metadata (del JWT):",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      ..._buildMetadataList(session.user.appMetadata),
                      const SizedBox(height: 8),
                      const Text(
                        "📋 User Metadata (del JWT):",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      ..._buildMetadataList(session.user.userMetadata ?? {}),
                    ],
                  );
                },
                loading: () => const Text("⏳ Cargando sesión..."),
                error: (err, _) => Text("❌ Error: $err"),
              ),
            ),

            const SizedBox(height: 24),

            // Sección: Rol
            _Section(
              title: "2. Resolución de Rol",
              child: roleAsync.when(
                data: (role) {
                  final roleLabel = {
                        AppRole.admin: "👨‍💼 Admin",
                        AppRole.medico: "🩺 Médico",
                        AppRole.nutricionista: "🥗 Nutricionista",
                        AppRole.tutor: "👨‍👧 Tutor",
                      }[role] ??
                      "❓ Desconocido";

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("✅ Rol resuelto: $roleLabel",
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text(
                          "Este rol se obtuvo de (en orden de prioridad):"),
                      const Text(
                          "1. Backend /auth-context (timeout: 6 segundos)"),
                      const Text("2. JWT app_metadata.role"),
                      const Text("3. Tabla usuarios.usuario"),
                      const Text("4. Fallback: 'tutor'"),
                    ],
                  );
                },
                loading: () => const Text("⏳ Resolviendo rol (max 6s)..."),
                error: (err, _) => Text("❌ Error al resolver rol: $err"),
              ),
            ),

            const SizedBox(height: 24),

            // Sección: Errores de Autenticación
            _Section(
              title: "3. Errores de Autenticación",
              child: authError == null
                  ? const Text("✅ Sin errores")
                  : Text("❌ Error: $authError",
                      style: const TextStyle(color: Colors.red)),
            ),

            const SizedBox(height: 24),

            // Sección: Recomendaciones
            const _Section(
              title: "4. Recomendaciones",
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Recommendation(
                    icon: "✅",
                    text:
                        "Si ves un rol (admin/medico/nutricionista/tutor), todo está bien.",
                  ),
                  _Recommendation(
                    icon: "⚠️",
                    text:
                        "Si siempre ves 'tutor', el rol no se sincroniza desde Supabase.",
                  ),
                  _Recommendation(
                    icon: "🔧",
                    text:
                        "Ejecuta: supabase/sql/fix_jwt_role_metadata.sql en Supabase",
                  ),
                  _Recommendation(
                    icon: "⏱️",
                    text:
                        "Si hay timeout, verifica que el backend está en http://localhost:8000",
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildMetadataList(Map<String, dynamic> metadata) {
    if (metadata.isEmpty) {
      return [
        const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text("  (vacío)"))
      ];
    }
    return metadata.entries
        .map((e) => _KeyValue("  ${e.key}", e.value.toString()))
        .toList();
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _KeyValue extends StatelessWidget {
  const _KeyValue(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              "$label:",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontFamily: "monospace"),
            ),
          ),
        ],
      ),
    );
  }
}

class _Recommendation extends StatelessWidget {
  const _Recommendation({required this.icon, required this.text});
  final String icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
