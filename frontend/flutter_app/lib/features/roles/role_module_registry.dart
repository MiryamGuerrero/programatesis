import "package:flutter/material.dart";
import "../../shared/models/app_role.dart";

// --- IMPORTS DIFERIDOS (Code Splitting) ---
// Páginas de Administración
import "../admin/modules/usuarios/admin_users_page.dart" deferred as admin_users;
import "../admin/modules/usuarios/admin_tutors_page.dart" deferred as admin_tutors;
import "../admin/modules/usuarios/admin_audit_page.dart" deferred as admin_audit;

// Páginas de Médico
import "../medico/presentation/supervision_pacientes_page.dart" deferred as medico_pacientes;
import "../medico/modules/catalogo_condiciones/catalogo_condiciones_page.dart" deferred as medico_condiciones;
import "../medico/modules/reglas_medicas/reglas_medicas_page.dart" deferred as medico_reglas;

// Páginas de Tutor
import "../tutor/presentation/mis_pacientes_page.dart" deferred as tutor_inicio;
import "../tutor/presentation/tutor_perfil_page.dart" deferred as tutor_perfil;

// Páginas de Nutricionista
import "../nutricionista/modules/ingredientes/ingredientes_page.dart" deferred as nutri_ingredientes;
import "../nutricionista/modules/recetas/recetas_page.dart" deferred as nutri_recetas;
import "../nutricionista/modules/etiquetas/etiquetas_page.dart" deferred as nutri_etiquetas;
import "../nutricionista/modules/plan_nutricional/plan_manual_page.dart" deferred as nutri_plan;
import "../nutricionista/modules/reglas_nutricionales/reglas_nutricionales_page.dart" deferred as nutri_reglas;
import "../nutricionista/modules/condiciones/condiciones_nutricionales_page.dart" deferred as nutri_condiciones;
import "../nutricionista/modules/configuracion_menu/configuracion_menu_page.dart" deferred as nutri_config;

// Página de Perfil (Común)
import "../perfil/perfil_page.dart" deferred as common_perfil;

class RoleModule {
  final String key;
  final String title;
  final IconData icon;
  final String? category;
  final Widget Function() builder;
  final Future<void> Function()? loader;

  RoleModule({
    required this.key,
    required this.title,
    required this.icon,
    this.category,
    required this.builder,
    this.loader,
  });
}

/// Widget envoltorio para manejar la carga diferida de módulos
class DeferredModuleWidget extends StatefulWidget {
  final Future<void> Function() loader;
  final Widget Function() builder;

  const DeferredModuleWidget({
    super.key,
    required this.loader,
    required this.builder,
  });

  @override
  State<DeferredModuleWidget> createState() => _DeferredModuleWidgetState();
}

class _DeferredModuleWidgetState extends State<DeferredModuleWidget> {
  Future<void>? _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = widget.loader();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasError) {
            return Center(child: Text("Error cargando módulo: ${snapshot.error}"));
          }
          return widget.builder();
        }
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Cargando componentes del módulo...", 
                style: TextStyle(color: Colors.blueGrey, fontSize: 12)),
            ],
          ),
        );
      },
    );
  }
}

List<RoleModule> modulesForRole(AppRole role) {
  final perfilItem = RoleModule(
    key: "perfil",
    title: "Mi perfil",
    icon: Icons.account_circle_outlined,
    category: "CUENTA",
    builder: () => DeferredModuleWidget(
            key: const ValueKey("perfil"),
      loader: () => common_perfil.loadLibrary(),
      builder: () => common_perfil.PerfilPage(),
    ),
  );

  switch (role) {
    case AppRole.admin:
      return [
        RoleModule(
          key: "personal",
          title: "Equipo médico",
          icon: Icons.assignment_ind_rounded,
          category: "GESTIÓN DE USUARIOS",
          builder: () => DeferredModuleWidget(
            key: const ValueKey("personal"),
            loader: () => admin_users.loadLibrary(),
            builder: () => admin_users.AdminUsersPage(),
          ),
        ),
        RoleModule(
          key: "tutores",
          title: "Cuentas de tutores",
          icon: Icons.supervised_user_circle_rounded,
          category: "GESTIÓN DE USUARIOS",
          builder: () => DeferredModuleWidget(
            key: const ValueKey("tutores"),
            loader: () => admin_tutors.loadLibrary(),
            builder: () => admin_tutors.AdminTutorsPage(),
          ),
        ),
        RoleModule(
          key: "auditoria",
          title: "Auditoría de atenciones",
          icon: Icons.analytics_outlined,
          category: "SISTEMA",
          builder: () => DeferredModuleWidget(
            key: const ValueKey("auditoria"),
            loader: () => admin_audit.loadLibrary(),
            builder: () => admin_audit.AdminAuditPage(),
          ),
        ),
        perfilItem,
      ];

    case AppRole.medico:
      return [
        RoleModule(
          key: "pacientes",
          title: "Gestión de pacientes",
          icon: Icons.people_outline_rounded,
          category: "GESTIÓN DE PACIENTES",
          builder: () => DeferredModuleWidget(
            key: const ValueKey("pacientes"),
            loader: () => medico_pacientes.loadLibrary(),
            builder: () => medico_pacientes.SupervisionPacientesPage(),
          ),
        ),
        RoleModule(
          key: "condiciones",
          title: "Catálogo de condiciones",
          icon: Icons.table_chart_outlined,
          category: "CONFIGURACIÓN DEL SISTEMA",
          builder: () => DeferredModuleWidget(
            key: const ValueKey("condiciones"),
            loader: () => medico_condiciones.loadLibrary(),
            builder: () => medico_condiciones.CatalogoCondicionesPage(),
          ),
        ),
        RoleModule(
          key: "reglas",
          title: "Reglas clínicas",
          icon: Icons.rule_folder_outlined,
          category: "CONFIGURACIÓN DEL SISTEMA",
          builder: () => DeferredModuleWidget(
            key: const ValueKey("reglas"),
            loader: () => medico_reglas.loadLibrary(),
            builder: () => medico_reglas.ReglasMedicasPage(),
          ),
        ),
        perfilItem,
      ];

    case AppRole.tutor:
      return [
        RoleModule(
          key: "inicio",
          title: "Mi paciente",
          icon: Icons.dashboard_rounded,
          builder: () => DeferredModuleWidget(
            key: const ValueKey("inicio"),
            loader: () => tutor_inicio.loadLibrary(),
            builder: () => tutor_inicio.MisPacientesPage(),
          ),
        ),
        RoleModule(
          key: "perfil",
          title: "Mi perfil",
          icon: Icons.account_circle_outlined,
          builder: () => DeferredModuleWidget(
            key: const ValueKey("perfil"),
            loader: () => tutor_perfil.loadLibrary(),
            builder: () => tutor_perfil.TutorPerfilPage(),
          ),
        ),
      ];

    case AppRole.nutricionista:
      return [
        RoleModule(
          key: "plan_manual",
          title: "Plan nutricional",
          icon: Icons.calendar_month_rounded,
          category: "GESTIÓN DE PACIENTES",
          builder: () => DeferredModuleWidget(
            key: const ValueKey("plan_manual"),
            loader: () => nutri_plan.loadLibrary(),
            builder: () => nutri_plan.PlanManualPage(),
          ),
        ),
        RoleModule(
          key: "ingredientes",
          title: "Ingredientes",
          icon: Icons.egg_alt_rounded,
          category: "RECETAS E INGREDIENTES",
          builder: () => DeferredModuleWidget(
            key: const ValueKey("ingredientes"),
            loader: () => nutri_ingredientes.loadLibrary(),
            builder: () => nutri_ingredientes.IngredientesPage(),
          ),
        ),
        RoleModule(
          key: "etiquetas",
          title: "Etiquetas",
          icon: Icons.label_rounded,
          category: "RECETAS E INGREDIENTES",
          builder: () => DeferredModuleWidget(
            key: const ValueKey("etiquetas"),
            loader: () => nutri_etiquetas.loadLibrary(),
            builder: () => nutri_etiquetas.EtiquetasPage(),
          ),
        ),
        RoleModule(
          key: "recetas",
          title: "Recetas",
          icon: Icons.menu_book_rounded,
          category: "RECETAS E INGREDIENTES",
          builder: () => DeferredModuleWidget(
            key: const ValueKey("recetas"),
            loader: () => nutri_recetas.loadLibrary(),
            builder: () => nutri_recetas.RecetasPage(),
          ),
        ),
        RoleModule(
          key: "configuracion_menu",
          title: "Menú y horarios",
          icon: Icons.schedule_rounded,
          category: "CONFIGURACIÓN DEL SISTEMA",
          builder: () => DeferredModuleWidget(
            key: const ValueKey("configuracion_menu"),
            loader: () => nutri_config.loadLibrary(),
            builder: () => nutri_config.ConfiguracionMenuPage(),
          ),
        ),
        RoleModule(
          key: "condiciones_nutri",
          title: "Condiciones",
          icon: Icons.health_and_safety_rounded,
          category: "CONFIGURACIÓN DEL SISTEMA",
          builder: () => DeferredModuleWidget(
            key: const ValueKey("condiciones_nutri"),
            loader: () => nutri_condiciones.loadLibrary(),
            builder: () => nutri_condiciones.CondicionesNutricionalesPage(),
          ),
        ),
        RoleModule(
          key: "reglas_nutri",
          title: "Reglas nutricionales",
          icon: Icons.rule_rounded,
          category: "CONFIGURACIÓN DEL SISTEMA",
          builder: () => DeferredModuleWidget(
            key: const ValueKey("reglas_nutri"),
            loader: () => nutri_reglas.loadLibrary(),
            builder: () => nutri_reglas.ReglasNutricionalesPage(),
          ),
        ),
        perfilItem,
      ];
  }
}

int defaultModuleIndexForRole(AppRole role) => 0;
