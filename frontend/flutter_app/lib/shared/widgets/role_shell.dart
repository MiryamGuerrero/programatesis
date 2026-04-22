import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";

import "../../features/roles/role_module.dart";
import "../../features/roles/role_module_registry.dart";
import "../models/app_role.dart";

class RoleShell extends StatefulWidget {
  const RoleShell({required this.role, super.key});

  final AppRole role;

  @override
  State<RoleShell> createState() => _RoleShellState();
}

class _RoleShellState extends State<RoleShell> {
  static const Color _tealPrimary = Color(0xFF0D9488);
  static const Color _tealPrimaryDark = Color(0xFF0F766E);

  late List<RoleModule> _modules;
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _loadModules();
  }

  @override
  void didUpdateWidget(covariant RoleShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.role != widget.role) {
      _loadModules();
    }
  }

  void _loadModules() {
    final modules = modulesForRole(widget.role);
    final defaultIndex = defaultModuleIndexForRole(widget.role);
    _modules = modules;
    _selectedIndex =
        modules.isEmpty ? 0 : defaultIndex.clamp(0, modules.length - 1);
  }

  RoleModule get _currentModule {
    if (_modules.isEmpty) {
      return RoleModule(
        key: "empty",
        title: "Sin modulos",
        icon: Icons.block,
        builder: () => const _EmptyModuleState(),
      );
    }
    return _modules[_selectedIndex];
  }

  Future<void> _signOut() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Cerrar sesion"),
          content: const Text(
            "Vas a salir de la plataforma. Tus cambios ya guardados no se perderan.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("Cancelar"),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text("Salir"),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true || !mounted) {
      return;
    }

    await Supabase.instance.client.auth.signOut();
  }

  void _selectModule(int index) {
    if (index < 0 || index >= _modules.length) {
      return;
    }

    if (_selectedIndex == index) {
      return;
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _openModulesSheet() async {
    if (_modules.isEmpty) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Secciones disponibles",
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _modules.length,
                    itemBuilder: (context, index) {
                      final module = _modules[index];
                      final selected = index == _selectedIndex;
                      return ListTile(
                        selected: selected,
                        leading: Icon(module.icon),
                        title: Text(module.title),
                        subtitle: Text(_moduleDescription(module.key)),
                        onTap: () {
                          Navigator.of(context).pop();
                          _selectModule(index);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_modules.isEmpty) {
      return const Scaffold(
        body: Center(
          child: _EmptyModuleState(),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width >= 1100) {
          return _buildWideWebLayout(context);
        }
        if (width >= 760) {
          return _buildMediumWebLayout(context);
        }
        return _buildMobileLayout(context);
      },
    );
  }

  Widget _buildWideWebLayout(BuildContext context) {
    final module = _currentModule;

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            Container(
              width: 290,
              margin: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFDFEFF),
                    Color(0xFFF5FBFA),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFDCE8F2)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x120F2D46),
                    blurRadius: 18,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _BrandPanel(role: widget.role),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                      itemCount: _modules.length,
                      itemBuilder: (context, index) {
                        final module = _modules[index];
                        final selected = _selectedIndex == index;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: _ModuleTile(
                            module: module,
                            selected: selected,
                            subtitle: _moduleDescription(module.key),
                            onTap: () => _selectModule(index),
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: OutlinedButton.icon(
                      onPressed: _signOut,
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text("Cerrar sesion"),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(2, 14, 16, 14),
                child: _RoleWorkspace(
                  module: module,
                  role: widget.role,
                  onShowModules: _openModulesSheet,
                  onSignOut: _signOut,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediumWebLayout(BuildContext context) {
    final module = _currentModule;

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _selectModule,
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Tooltip(
                  message: "Secciones",
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(13),
                      gradient: const LinearGradient(
                        colors: [
                          _tealPrimaryDark,
                          _tealPrimary,
                        ],
                      ),
                    ),
                    child: const Icon(Icons.spa_rounded, color: Colors.white),
                  ),
                ),
              ),
              destinations: [
                for (final module in _modules)
                  NavigationRailDestination(
                    icon: Icon(module.icon),
                    label: Text(module.title),
                  ),
              ],
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: IconButton(
                    tooltip: "Cerrar sesion",
                    onPressed: _signOut,
                    icon: const Icon(Icons.logout),
                  ),
                ),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 14, 14, 14),
                child: _RoleWorkspace(
                  module: module,
                  role: widget.role,
                  onShowModules: _openModulesSheet,
                  onSignOut: _signOut,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    final module = _currentModule;
    final destinations = _mobileDestinations();
    final navIndex = _mobileSelectedIndex();

    return Scaffold(
      appBar: AppBar(
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: Text(
            module.title,
            key: ValueKey(module.key),
          ),
        ),
        actions: [
          IconButton(
            tooltip: "Todas las secciones",
            onPressed: _openModulesSheet,
            icon: const Icon(Icons.widgets_rounded),
          ),
          IconButton(
            tooltip: "Cerrar sesion",
            onPressed: _signOut,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: _RoleWorkspace(
            module: module,
            role: widget.role,
            compact: true,
            onShowModules: _openModulesSheet,
            onSignOut: _signOut,
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navIndex,
        onDestinationSelected: (index) {
          if (index == destinations.length - 1 && _modules.length > 4) {
            _openModulesSheet();
            return;
          }

          final targetIndex = index < 4 ? index : _selectedIndex;
          _selectModule(targetIndex);
        },
        destinations: destinations,
      ),
    );
  }

  List<NavigationDestination> _mobileDestinations() {
    final visible = _modules.take(4).toList();
    final destinations = <NavigationDestination>[
      for (final module in visible)
        NavigationDestination(
          icon: Icon(module.icon),
          label: _shortLabel(module.title),
        ),
    ];

    if (_modules.length > 4) {
      destinations.add(
        const NavigationDestination(
          icon: Icon(Icons.more_horiz_rounded),
          label: "Mas",
        ),
      );
    }

    return destinations;
  }

  int _mobileSelectedIndex() {
    if (_modules.length <= 4) {
      return _selectedIndex;
    }
    return _selectedIndex <= 3 ? _selectedIndex : 4;
  }

  String _shortLabel(String title) {
    if (title.length <= 14) {
      return title;
    }

    final chunks = title.split(" ");
    if (chunks.isNotEmpty && chunks.first.length <= 14) {
      return chunks.first;
    }

    return "Seccion";
  }

  String _moduleDescription(String key) {
    switch (key) {
      case "usuarios":
        return "Altas, cambios de estado y control de accesos.";
      case "gestion-pacientes":
        return "Vincula pacientes con tutores y mantiene datos base.";
      case "registro-clinico":
        return "Captura medidas clinicas y observaciones del paciente.";
      case "diagnostico-oms":
        return "Interpreta IMC y curvas OMS para soporte de decision.";
      case "alergias-condiciones-temporales":
        return "Registra restricciones de salud activas del paciente.";
      case "catalogo-condiciones":
        return "Administra condiciones medicas maestras.";
      case "reglas-medicas":
        return "Define reglas de seguridad clinica.";
      case "consulta-evolucion":
        return "Visualiza la progresion clinica por periodos.";
      case "ingredientes":
        return "Gestiona ingredientes y estado de disponibilidad.";
      case "recetas":
        return "Mantiene recetas base para los planes.";
      case "plan-manual":
        return "Construye planes alimentarios manuales.";
      case "etiquetas":
        return "Configura etiquetas y reglas nutricionales.";
      case "plan":
        return "Revisa plan del paciente por fecha y momento.";
      case "consumo":
        return "Registra cumplimiento real del plan alimentario.";
      case "reemplazos":
        return "Busca equivalencias de ingredientes y platos.";
      case "calificar":
        return "Valora recetas para mejorar sugerencias.";
      case "perfil":
        return "Actualiza datos personales y contacto.";
      default:
        return "Gestiona informacion en este modulo.";
    }
  }
}

class _RoleWorkspace extends StatelessWidget {
  const _RoleWorkspace({
    required this.module,
    required this.role,
    required this.onShowModules,
    required this.onSignOut,
    this.compact = false,
  });

  final RoleModule module;
  final AppRole role;
  final VoidCallback onShowModules;
  final VoidCallback onSignOut;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: EdgeInsets.fromLTRB(
            compact ? 14 : 18,
            compact ? 12 : 16,
            compact ? 14 : 18,
            compact ? 12 : 16,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.3),
            ),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFE8F6F4),
                Color(0xFFF4FAFF),
                Color(0xFFFFF7EE),
              ],
            ),
          ),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF0F766E),
                      Color(0xFF0D9488),
                    ],
                  ),
                ),
                child: Icon(module.icon, color: Colors.white),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: compact ? 260 : 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      child: Text(
                        module.title,
                        key: ValueKey(module.key),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _roleGuidance(role),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: onShowModules,
                icon: const Icon(Icons.dashboard_customize_rounded),
                label: const Text("Secciones"),
              ),
              FilledButton.tonalIcon(
                onPressed: onSignOut,
                icon: const Icon(Icons.logout),
                label: const Text("Salir"),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeIn,
            child: Container(
              key: ValueKey(module.key),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.28),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x100F2D46),
                    blurRadius: 18,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(compact ? 12 : 16),
                child: module.builder(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _roleGuidance(AppRole role) {
    switch (role) {
      case AppRole.admin:
        return "Controla usuarios y seguridad con acciones trazables.";
      case AppRole.medico:
        return "Consulta historia clinica y aplica criterios de riesgo.";
      case AppRole.nutricionista:
        return "Diseña planes y reglas nutricionales basadas en evidencia.";
      case AppRole.tutor:
        return "Sigue plan del paciente y registra consumo diario.";
    }
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel({required this.role});

  final AppRole role;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFD7E6F2)),
          color: Colors.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(13),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF0F766E),
                        Color(0xFF0D9488),
                      ],
                    ),
                  ),
                  child: const Icon(Icons.monitor_heart_rounded,
                      color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Reuma Nutri",
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: const Color(0x140D9488),
                border: Border.all(color: const Color(0x330D9488)),
              ),
              child: Text(
                "Rol activo: ${role.label}",
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F766E),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Navega por tareas de forma clara y consistente.",
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({
    required this.module,
    required this.selected,
    required this.subtitle,
    required this.onTap,
  });

  final RoleModule module;
  final bool selected;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0x1F0D9488) : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  color: selected
                      ? const Color(0x260D9488)
                      : const Color(0x0A334155),
                ),
                child: Icon(
                  module.icon,
                  size: 20,
                  color: selected
                      ? const Color(0xFF0D9488)
                      : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      module.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight:
                            selected ? FontWeight.w900 : FontWeight.w700,
                        color: const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF0D9488),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyModuleState extends StatelessWidget {
  const _EmptyModuleState();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.folder_off_rounded,
            size: 42, color: Color(0xFF94A3B8)),
        const SizedBox(height: 8),
        Text(
          "No hay modulos disponibles",
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }
}
