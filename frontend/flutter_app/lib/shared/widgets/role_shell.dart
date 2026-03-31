import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";

import "../../features/auth/login_page.dart";
import "../../features/admin/modules/catalogos/admin_catalogs_page.dart";
import "../../features/admin/modules/usuarios/admin_users_page.dart";
import "../../features/medico/modules/diagnostico_oms/diagnostico_page.dart";
import "../../features/medico/modules/registro_clinico/registro_clinico_page.dart";
import "../../features/medico/modules/reglas_medicas/reglas_medicas_page.dart";
import "../../features/nutricionista/modules/ingredientes/ingredientes_page.dart";
import "../../features/nutricionista/modules/plan_nutricional/plan_manual_page.dart";
import "../../features/nutricionista/modules/recetas/recetas_page.dart";
import "../../features/nutricionista/modules/reglas_nutricionales/reglas_nutricionales_page.dart";
import "../../features/tutor/modules/calificacion/calificacion_page.dart";
import "../../features/tutor/modules/consumo/consumo_page.dart";
import "../../features/tutor/modules/plan/plan_page.dart";
import "../../features/tutor/modules/reemplazos/reemplazo_page.dart";
import "../models/app_role.dart";

class RoleShell extends StatefulWidget {
  const RoleShell({super.key, required this.role});

  final AppRole role;

  @override
  State<RoleShell> createState() => _RoleShellState();
}

class _RoleShellState extends State<RoleShell> {
  int _index = 0;
  bool _signingOut = false;

  @override
  Widget build(BuildContext context) {
    final modules = _modulesForRole(widget.role);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isWide = MediaQuery.of(context).size.width >= 960;

    if (_index >= modules.length) {
      _index = 0;
    }

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 78,
        flexibleSpace: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.primary.withValues(alpha: 0.18),
                colors.secondary.withValues(alpha: 0.12),
                const Color(0xFFFFF8F3),
              ],
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.role.label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.78),
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              modules[_index].title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.tonalIcon(
              onPressed: _signingOut ? null : _handleSignOut,
              icon: _signingOut
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.logout),
              label: Text(_signingOut ? "Saliendo..." : "Cerrar sesion"),
            ),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF7FFF8),
              Color(0xFFEFFAFD),
              Color(0xFFFFFDF7),
            ],
          ),
        ),
        child: Row(
          children: [
            if (isWide) _buildWideNavigation(context, modules),
            Expanded(
              child: _buildModulePanel(context, modules, isWide),
            ),
          ],
        ),
      ),
      bottomNavigationBar:
          isWide ? null : _buildMobileNavigation(context, modules),
    );
  }

  Future<void> _handleSignOut() async {
    setState(() => _signingOut = true);

    var remoteFailed = false;
    var localFailed = false;

    try {
      await Supabase.instance.client.auth
          .signOut()
          .timeout(const Duration(seconds: 6));
    } catch (_) {
      remoteFailed = true;
    }

    try {
      await Supabase.instance.client.auth
          .signOut(scope: SignOutScope.local)
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      localFailed = true;
    }

    if (mounted && remoteFailed && localFailed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "No se pudo cerrar sesion. Intenta nuevamente en unos segundos.",
          ),
        ),
      );
    }

    if (mounted && remoteFailed && !localFailed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Sesion local cerrada. Se omitio cierre remoto."),
        ),
      );
    }

    if (mounted && (!remoteFailed || !localFailed)) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => const LoginPage(),
        ),
        (_) => false,
      );
    }

    if (mounted) {
      setState(() => _signingOut = false);
    }
  }

  Widget _buildWideNavigation(BuildContext context, List<_RoleModule> modules) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colors.outline.withValues(alpha: 0.24)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A30414A),
              blurRadius: 22,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: NavigationRail(
            minWidth: 84,
            minExtendedWidth: 240,
            extended: true,
            useIndicator: true,
            groupAlignment: -0.75,
            selectedIndex: _index,
            onDestinationSelected: (value) => setState(() => _index = value),
            labelType: NavigationRailLabelType.none,
            backgroundColor: Colors.transparent,
            destinations: [
              for (final module in modules)
                NavigationRailDestination(
                  icon: Icon(module.icon),
                  label: Text(module.title),
                ),
            ],
            leading: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF81C784), Color(0xFF4CAF50)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.spa_rounded, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 140,
                      child: Text(
                        "Reuma Nutri",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModulePanel(
    BuildContext context,
    List<_RoleModule> modules,
    bool isWide,
  ) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(isWide ? 8 : 16, 16, 16, 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: 0.93),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colors.outline.withValues(alpha: 0.2)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A2A3D47),
              blurRadius: 24,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(isWide ? 20 : 14),
          child: IndexedStack(
            index: _index,
            children: [
              for (final module in modules) module.builder(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileNavigation(
      BuildContext context, List<_RoleModule> modules) {
    final colors = Theme.of(context).colorScheme;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.outline.withValues(alpha: 0.24)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A30414A),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: NavigationBar(
          backgroundColor: Colors.transparent,
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

