import "package:flutter/material.dart";

import "../../shared/models/app_role.dart";
import "../admin/modules/usuarios/admin_users_page.dart";
import "../medico/modules/diagnostico_oms/diagnostico_page.dart";
import "../medico/modules/registro_clinico/registro_clinico_page.dart";
import "../medico/modules/reglas_medicas/reglas_medicas_page.dart";
import "../../shared/repositories/gestion_tutores_pacientes_page.dart";
import "../nutricionista/modules/ingredientes/ingredientes_page.dart";
import "../nutricionista/modules/plan_nutricional/plan_manual_page.dart";
import "../nutricionista/modules/recetas/recetas_page.dart";
import "../nutricionista/modules/reglas_nutricionales/reglas_nutricionales_page.dart";
import "../tutor/modules/calificacion/calificacion_page.dart";
import "../tutor/modules/consumo/consumo_page.dart";
import "../tutor/modules/plan/plan_page.dart";
import "../tutor/modules/reemplazos/reemplazo_page.dart";
import "../perfil/perfil_page.dart";
import "role_module.dart";

List<RoleModule> modulesForRole(AppRole role) {
  switch (role) {
    case AppRole.admin:
      return [
        RoleModule(
          key: "usuarios",
          title: "Usuarios",
          icon: Icons.manage_accounts,
          builder: () => const AdminUsersPage(),
        ),
        RoleModule(
          key: "perfil",
          title: "Perfil",
          icon: Icons.person,
          builder: () => const PerfilPage(),
        ),
      ];
    case AppRole.medico:
      return [
        RoleModule(
          key: "registro-clinico",
          title: "Registro clinico",
          icon: Icons.monitor_heart,
          builder: () => const RegistroClinicoPage(),
        ),
        RoleModule(
          key: "diagnostico-oms",
          title: "Diagnostico OMS",
          icon: Icons.biotech,
          builder: () => const DiagnosticoPage(),
        ),
        RoleModule(
          key: "reglas-medicas",
          title: "Reglas medicas",
          icon: Icons.rule,
          builder: () => const ReglasMedicasPage(),
        ),
        RoleModule(
          key: "registro-tutor",
          title: "Tutores y Pacientes",
          icon: Icons.group_add,
          builder: () => const GestionTutoresPacientesPage(),
        ),
        RoleModule(
          key: "perfil",
          title: "Perfil",
          icon: Icons.person,
          builder: () => const PerfilPage(),
        ),
      ];
    case AppRole.nutricionista:
      return [
        RoleModule(
          key: "ingredientes",
          title: "Ingredientes",
          icon: Icons.eco,
          builder: () => const IngredientesPage(),
        ),
        RoleModule(
          key: "recetas",
          title: "Recetas",
          icon: Icons.menu_book,
          builder: () => const RecetasPage(),
        ),
        RoleModule(
          key: "plan-manual",
          title: "Plan manual",
          icon: Icons.calendar_view_week,
          builder: () => const PlanManualPage(),
        ),
        RoleModule(
          key: "etiquetas",
          title: "Etiquetas nutr.",
          icon: Icons.policy,
          builder: () => const ReglasNutricionalesPage(),
        ),
        RoleModule(
          key: "perfil",
          title: "Perfil",
          icon: Icons.person,
          builder: () => const PerfilPage(),
        ),
      ];
    case AppRole.tutor:
      return [
        RoleModule(
          key: "plan",
          title: "Mi plan",
          icon: Icons.calendar_month,
          builder: () => const TutorPlanPage(),
        ),
        RoleModule(
          key: "consumo",
          title: "Consumo",
          icon: Icons.check_circle,
          builder: () => const TutorConsumoPage(),
        ),
        RoleModule(
          key: "reemplazos",
          title: "Reemplazos",
          icon: Icons.swap_horiz,
          builder: () => const TutorReemplazoPage(),
        ),
        RoleModule(
          key: "calificar",
          title: "Calificar",
          icon: Icons.star,
          builder: () => const TutorCalificacionPage(),
        ),
        RoleModule(
          key: "perfil",
          title: "Perfil",
          icon: Icons.person,
          builder: () => const PerfilPage(),
        ),
      ];
  }
}

int defaultModuleIndexForRole(AppRole role) {
  if (role == AppRole.nutricionista) {
    return 3;
  }

  return 0;
}