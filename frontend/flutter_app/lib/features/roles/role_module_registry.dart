import "package:flutter/material.dart";
import "../../shared/models/app_role.dart";

// Páginas de Administración
import "../admin/modules/usuarios/admin_users_page.dart";
import "../admin/modules/usuarios/admin_tutors_page.dart";
import "../admin/modules/catalogos/admin_catalogs_page.dart";

// Páginas de Médico
import "../medico/presentation/supervision_pacientes_page.dart";
import "../medico/modules/catalogo_condiciones/catalogo_condiciones_page.dart";
import "../medico/modules/reglas_medicas/reglas_medicas_page.dart";

// Páginas de Tutor
import "../tutor/presentation/tutor_home_page.dart";
import "../tutor/presentation/plan_diario_page.dart";

// Páginas de Nutricionista
import "../nutricionista/modules/ingredientes/ingredientes_page.dart";
import "../nutricionista/modules/sustitutos/sustitutos_page.dart";
import "../nutricionista/modules/recetas/recetas_page.dart";
import "../nutricionista/modules/etiquetas/etiquetas_page.dart";
import "../nutricionista/modules/plan_nutricional/plan_manual_page.dart";
import "../nutricionista/modules/reglas_nutricionales/reglas_nutricionales_page.dart";
import "../nutricionista/modules/condiciones/condiciones_nutricionales_page.dart";

// Página de Perfil (Común)
import "../perfil/perfil_page.dart";

class RoleModule {
  final String key;
  final String title;
  final IconData icon;
  final Widget Function() builder;

  RoleModule({
    required this.key,
    required this.title,
    required this.icon,
    required this.builder,
  });
}

List<RoleModule> modulesForRole(AppRole role) {
  final perfilItem = RoleModule(
    key: "perfil",
    title: "Mi Perfil",
    icon: Icons.account_circle_outlined,
    builder: () => const PerfilPage(),
  );

  switch (role) {
    case AppRole.admin:
      return [
        RoleModule(
          key: "personal",
          title: "Equipo Médico",
          icon: Icons.assignment_ind_rounded,
          builder: () => const AdminUsersPage(),
        ),
        RoleModule(
          key: "tutores",
          title: "Cuentas Tutores",
          icon: Icons.supervised_user_circle_rounded,
          builder: () => const AdminTutorsPage(),
        ),
        perfilItem,
      ];

    case AppRole.medico:
      return [
        RoleModule(
          key: "pacientes",
          title: "Gestión de Pacientes",
          icon: Icons.people_outline_rounded,
          builder: () => const SupervisionPacientesPage(),
        ),
        RoleModule(
          key: "condiciones",
          title: "Catálogo de Condiciones",
          icon: Icons.table_chart_outlined,
          builder: () => const CatalogoCondicionesPage(),
        ),
        RoleModule(
          key: "reglas",
          title: "Reglas Clínicas",
          icon: Icons.rule_folder_outlined,
          builder: () => const ReglasMedicasPage(),
        ),
        perfilItem,
      ];

    case AppRole.tutor:
      return [
        RoleModule(
          key: "inicio",
          title: "Mi Paciente",
          icon: Icons.dashboard_rounded,
          builder: () => const TutorHomePage(idPaciente: "ID_PENDIENTE", nombrePaciente: "Paciente"),
        ),
        RoleModule(
          key: "plan",
          title: "Plan del Día",
          icon: Icons.restaurant_menu_rounded,
          builder: () => const PlanDiarioPage(idPaciente: "ID_PENDIENTE", fecha: "2026-04-22"),
        ),
        perfilItem,
      ];

    case AppRole.nutricionista:
      return [
        RoleModule(
          key: "ingredientes",
          title: "Ingredientes",
          icon: Icons.egg_alt_rounded,
          builder: () => const IngredientesPage(),
        ),
        RoleModule(
          key: "sustitutos",
          title: "Sustitutos",
          icon: Icons.swap_horiz_rounded,
          builder: () => const SustitutosPage(),
        ),
        RoleModule(
          key: "recetas",
          title: "Recetas",
          icon: Icons.menu_book_rounded,
          builder: () => const RecetasPage(),
        ),
        RoleModule(
          key: "etiquetas",
          title: "Etiquetas",
          icon: Icons.label_rounded,
          builder: () => const EtiquetasPage(),
        ),
        RoleModule(
          key: "plan_manual",
          title: "Plan Manual",
          icon: Icons.calendar_month_rounded,
          builder: () => const PlanManualPage(),
        ),
        RoleModule(
          key: "reglas_nutri",
          title: "Reglas Nutricionales",
          icon: Icons.rule_rounded,
          builder: () => const ReglasNutricionalesPage(),
        ),
        RoleModule(
          key: "condiciones_nutri",
          title: "Condiciones",
          icon: Icons.health_and_safety_rounded,
          builder: () => const CondicionesNutricionalesPage(),
        ),
        perfilItem,
      ];
    
    default:
      return [perfilItem];
  }
}

int defaultModuleIndexForRole(AppRole role) => 0;
