import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";

import "../../features/admin/presentation/admin_catalogs_page.dart";
import "../../features/admin/presentation/admin_users_page.dart";
import "../../features/medico/presentation/diagnostico_page.dart";
import "../../features/medico/presentation/registro_clinico_page.dart";
import "../../features/medico/presentation/reglas_medicas_page.dart";
import "../../features/nutricionista/presentation/ingredientes_page.dart";
import "../../features/nutricionista/presentation/plan_manual_page.dart";
import "../../features/nutricionista/presentation/recetas_page.dart";
import "../../features/nutricionista/presentation/reglas_nutricionales_page.dart";
import "../../features/tutor/presentation/calificacion_page.dart";
import "../../features/tutor/presentation/consumo_page.dart";
import "../../features/tutor/presentation/plan_page.dart";
import "../../features/tutor/presentation/reemplazo_page.dart";
import "../models/app_role.dart";

class RoleShell extends StatefulWidget {
  const RoleShell({super.key, required this.role});

  final AppRole role;

  @override
  State<RoleShell> createState() => _RoleShellState();
}

class _RoleShellState extends State<RoleShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final modules = _modulesForRole(widget.role);
    final isWide = MediaQuery.of(context).size.width >= 900;

    if (_index >= modules.length) {
      _index = 0;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.role.label} | ${modules[_index].title}"),
        actions: [
          IconButton(
            tooltip: "Cerrar sesion",
            onPressed: () async => Supabase.instance.client.auth.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Row(
        children: [
          if (isWide)
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: (value) => setState(() => _index = value),
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final module in modules)
                  NavigationRailDestination(
                    icon: Icon(module.icon),
                    label: Text(module.title),
                  ),
              ],
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: modules[_index].builder(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (value) => setState(() => _index = value),
              destinations: [
                for (final module in modules)
                  NavigationDestination(
                    icon: Icon(module.icon),
                    label: module.title,
                  ),
              ],
            ),
    );
  }

  List<_RoleModule> _modulesForRole(AppRole role) {
    switch (role) {
      case AppRole.admin:
        return [
          _RoleModule(
            title: "Usuarios",
            icon: Icons.manage_accounts,
            builder: () => const AdminUsersPage(),
          ),
          _RoleModule(
            title: "Catalogos",
            icon: Icons.view_list,
            builder: () => const AdminCatalogsPage(),
          ),
        ];
      case AppRole.medico:
        return [
          _RoleModule(
            title: "Registro clinico",
            icon: Icons.monitor_heart,
            builder: () => const RegistroClinicoPage(),
          ),
          _RoleModule(
            title: "Diagnostico OMS",
            icon: Icons.biotech,
            builder: () => const DiagnosticoPage(),
          ),
          _RoleModule(
            title: "Reglas medicas",
            icon: Icons.rule,
            builder: () => const ReglasMedicasPage(),
          ),
        ];
      case AppRole.nutricionista:
        return [
          _RoleModule(
            title: "Ingredientes",
            icon: Icons.eco,
            builder: () => const IngredientesPage(),
          ),
          _RoleModule(
            title: "Recetas",
            icon: Icons.menu_book,
            builder: () => const RecetasPage(),
          ),
          _RoleModule(
            title: "Plan manual",
            icon: Icons.calendar_view_week,
            builder: () => const PlanManualPage(),
          ),
          _RoleModule(
            title: "Reglas nutr.",
            icon: Icons.policy,
            builder: () => const ReglasNutricionalesPage(),
          ),
        ];
      case AppRole.tutor:
        return [
          _RoleModule(
            title: "Mi plan",
            icon: Icons.calendar_month,
            builder: () => const TutorPlanPage(),
          ),
          _RoleModule(
            title: "Consumo",
            icon: Icons.check_circle,
            builder: () => const TutorConsumoPage(),
          ),
          _RoleModule(
            title: "Reemplazos",
            icon: Icons.swap_horiz,
            builder: () => const TutorReemplazoPage(),
          ),
          _RoleModule(
            title: "Calificar",
            icon: Icons.star,
            builder: () => const TutorCalificacionPage(),
          ),
        ];
    }
  }
}

class _RoleModule {
  _RoleModule({
    required this.title,
    required this.icon,
    required this.builder,
  });

  final String title;
  final IconData icon;
  final Widget Function() builder;
}
