import "dart:async";

import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";
import "package:pdf/pdf.dart";
import "package:pdf/widgets.dart" as pw;
import "package:printing/printing.dart";

import "../../../../core/state/app_providers.dart";
import "../../../../core/theme/app_theme.dart";
import "../../../../shared/widgets/layout_components.dart";
import "../../../../shared/widgets/nutri_avatar.dart";
import "../../../../shared/widgets/shimmer_components.dart";
import "admin_users_notifier.dart";

class AdminUsersPage extends ConsumerStatefulWidget {
  const AdminUsersPage({super.key});
  @override
  ConsumerState<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends ConsumerState<AdminUsersPage> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adminUsersProvider.notifier).loadPageIfNeeded();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _limpiarFiltros() {
    _searchController.clear();
    ref.read(adminUsersProvider.notifier).clearFilters();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminUsersProvider);
    final rolesAsync = ref.watch(rolesStaffProvider);

    return Scaffold(
      backgroundColor: AppTema.grisLienzo,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 32),
            _buildStatsRow(state),
            const SizedBox(height: 32),
            _buildToolbar(state),
            const SizedBox(height: 24),
            _buildRolesFilter(rolesAsync, state),
            const SizedBox(height: 24),
            _buildTable(state),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Gestión del equipo médico",
            style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppTema.azulPrincipal,
                letterSpacing: -0.5)),
        Text(
            "Control institucional de accesos y perfiles profesionales del centro.",
            style: GoogleFonts.inter(
                color: Colors.blueGrey,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildStatsRow(AdminUsersState state) {
    if (state.isLoading && state.users.isEmpty) {
      return const Row(
        children: [
          Expanded(child: NutriResumenCardShimmer()),
          SizedBox(width: 20),
          Expanded(child: NutriResumenCardShimmer()),
          SizedBox(width: 20),
          Expanded(child: NutriResumenCardShimmer()),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: NutriResumenCard(
            titulo: 'ADMINISTRADORES',
            valor: '${state.roleCounts[1] ?? 0}',
            icon: Icons.admin_panel_settings_rounded,
            colorValor: AppTema.azulOscuro,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: NutriResumenCard(
            titulo: 'MEDICOS',
            valor: '${state.roleCounts[2] ?? 0}',
            icon: Icons.medical_services_rounded,
            colorValor: AppTema.azulPrincipal,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: NutriResumenCard(
            titulo: 'NUTRIOLOGOS',
            valor: '${state.roleCounts[3] ?? 0}',
            icon: Icons.restaurant_menu_rounded,
            colorValor: AppTema.verdeSalud,
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar(AdminUsersState state) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: TextField(
              controller: _searchController,
              style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: "Buscar por nombre de profesional...",
                hintStyle: GoogleFonts.inter(
                    color: Colors.grey.shade400, fontSize: 13),
                prefixIcon: const Icon(Icons.search,
                    size: 20, color: Colors.grey),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (v) {
                _searchDebounce?.cancel();
                _searchDebounce =
                    Timer(const Duration(milliseconds: 350), () {
                  ref.read(adminUsersProvider.notifier).setSearchQuery(v);
                });
              },
            ),
          ),
        ),

        const SizedBox(width: 16),
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            onPressed: () => _dialogoUsuario(null),
            style: FilledButton.styleFrom(
              backgroundColor: AppTema.verdeSalud,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              padding: const EdgeInsets.symmetric(horizontal: 24),
            ),
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
            label: Text("Nuevo miembro",
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: -0.5)),
          ),
        ),
      ],
    );
  }

  Future<void> _exportarPDF(AdminUsersState state) async {
    final repo = ref.read(supabaseCrudRepositoryProvider);
    final notifier = ref.read(adminUsersProvider.notifier);

    // Obtener la lista completa correspondiente a los filtros actuales (sin límite de paginación de 5)
    final listadoCompleto = await repo.fetchUsersPage(
      query: state.searchQuery,
      rolIds: notifier.effectiveRolIds,
      activo: state.selectedActivo,
      limit: 1000,
      offset: 0,
    );

    final users = listadoCompleto.items;
    
    // Determinar título del informe y si se debe ocultar la columna Rol
    String tituloReporte = "REPORTE DE PERSONAL MÉDICO Y STAFF";
    bool mostrarRol = true;
    
    if (state.selectedRolIds.length == 1) {
      final idRol = state.selectedRolIds.first;
      mostrarRol = false;
      if (idRol == 1) {
        tituloReporte = "REPORTE DE PERSONAL: ADMINISTRADORES";
      } else if (idRol == 2) {
        tituloReporte = "REPORTE DE PERSONAL: MÉDICOS";
      } else if (idRol == 3) {
        tituloReporte = "REPORTE DE PERSONAL: NUTRICIONISTAS";
      } else if (idRol == 4) {
        tituloReporte = "REPORTE DE PERSONAL: TUTORES";
      }
    }

    final pdf = pw.Document();

    final fontRegular = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();

    // Configuración de anchos de columna de forma estética y proporcional
    final columnWidths = {
      0: const pw.FlexColumnWidth(3.0),    // Nombre Completo
      1: const pw.FlexColumnWidth(2.8),    // Correo Electrónico
      2: const pw.FlexColumnWidth(1.6),    // Cédula
      if (mostrarRol) 3: const pw.FlexColumnWidth(1.8), // Rol
      (mostrarRol ? 4 : 3): const pw.FlexColumnWidth(1.3), // Estado
    };

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Encabezado Corporativo Premium
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        "NutriReuma",
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 26,
                          color: const PdfColor.fromInt(0xFF0171BB),
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        "Portal Profesional de Salud - Centro Clínico",
                        style: pw.TextStyle(
                          font: fontRegular,
                          fontSize: 10,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ),
                  // Sello corporativo vectorizado
                  pw.Container(
                    width: 50,
                    height: 50,
                    decoration: const pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFE0F2FE),
                      shape: pw.BoxShape.circle,
                    ),
                    alignment: pw.Alignment.center,
                    child: pw.Stack(
                      alignment: pw.Alignment.center,
                      children: [
                        pw.Container(
                          width: 32,
                          height: 8,
                          decoration: const pw.BoxDecoration(
                            color: PdfColor.fromInt(0xFFBAE6FD),
                          ),
                        ),
                        pw.Container(
                          width: 8,
                          height: 32,
                          decoration: const pw.BoxDecoration(
                            color: PdfColor.fromInt(0xFFBAE6FD),
                          ),
                        ),
                        pw.Text(
                          "NR",
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 18,
                            color: const PdfColor.fromInt(0xFF005686),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
              // Línea decorativa doble
              pw.Container(
                height: 3,
                color: const PdfColor.fromInt(0xFF0171BB),
              ),
              pw.SizedBox(height: 2),
              pw.Container(
                height: 1.5,
                color: const PdfColor.fromInt(0xFF10B981),
              ),
              pw.SizedBox(height: 20),
              
              // Título del Informe y Metadata
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        tituloReporte,
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 13,
                          color: const PdfColor.fromInt(0xFF1E293B),
                          letterSpacing: 0.5,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        "Filtros aplicados: "
                        "${state.selectedRolIds.isEmpty ? 'Todos los roles' : 'Roles específicos'} | "
                        "${state.selectedActivo == null ? 'Todos los estados' : state.selectedActivo == true ? 'Solo activos' : 'Solo dados de baja'}",
                        style: pw.TextStyle(
                          font: fontRegular,
                          fontSize: 8,
                          color: PdfColors.grey500,
                        ),
                      ),
                    ],
                  ),
                  pw.Text(
                    "Fecha: ${DateTime.now().toLocal().toString().substring(0, 10)}",
                    style: pw.TextStyle(
                      font: fontRegular,
                      fontSize: 9,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              
              // Tabla con bordes limpios sin líneas verticales (Look corporativo moderno)
              pw.Table(
                columnWidths: columnWidths,
                border: const pw.TableBorder(
                  bottom: pw.BorderSide(color: PdfColor.fromInt(0xFFCBD5E1), width: 0.5),
                  horizontalInside: pw.BorderSide(color: PdfColor.fromInt(0xFFE2E8F0), width: 0.5),
                ),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFF0171BB),
                    ),
                    children: [
                      _pdfHeaderCell("Nombre Completo", fontBold, textAlign: pw.TextAlign.left, fontSize: 9.5),
                      _pdfHeaderCell("Correo Electrónico", fontBold, textAlign: pw.TextAlign.left, fontSize: 9.5),
                      _pdfHeaderCell("Cédula", fontBold, textAlign: pw.TextAlign.center, fontSize: 9.5),
                      if (mostrarRol) _pdfHeaderCell("Rol", fontBold, textAlign: pw.TextAlign.center, fontSize: 9.5),
                      _pdfHeaderCell("Estado", fontBold, textAlign: pw.TextAlign.center, fontSize: 9.5),
                    ],
                  ),
                  ...List.generate(users.length, (index) {
                    final u = users[index];
                    final rolesList = u["roles"] as List<dynamic>?;
                    final rolNombre = (rolesList != null && rolesList.isNotEmpty)
                        ? rolesList.map((r) => r["nombre"].toString()).join(", ").toUpperCase()
                        : (u["rol_nombre"]?.toString() ?? "SIN ROL").toUpperCase();
                    final isEven = index % 2 == 0;
                    final isActivo = u["activo"] == true;
                    return pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: isEven ? const PdfColor.fromInt(0xFFF8FAFC) : PdfColors.white,
                      ),
                      children: [
                        _pdfDataCell(
                          _splitNameIntoTwoLines(u["nombre_completo"] ?? "Sin nombre"),
                          fontRegular,
                          textAlign: pw.TextAlign.left,
                          fontSize: 8.5,
                        ),
                        _pdfDataCell(
                          u["email"] ?? "Sin correo",
                          fontRegular,
                          textAlign: pw.TextAlign.left,
                          fontSize: 7.5,
                        ),
                        _pdfDataCell(
                          u["cedula"] ?? "Sin cédula",
                          fontRegular,
                          textAlign: pw.TextAlign.center,
                          fontSize: 8,
                        ),
                        if (mostrarRol) _pdfDataCell(
                          rolNombre,
                          fontBold,
                          textAlign: pw.TextAlign.center,
                          fontSize: 8,
                        ),
                        _pdfDataCell(
                          isActivo ? "ACTIVO" : "DADO DE BAJA",
                          fontBold,
                          textAlign: pw.TextAlign.center,
                          fontSize: 8,
                          textColor: isActivo ? const PdfColor.fromInt(0xFF10B981) : const PdfColor.fromInt(0xFFEF4444),
                        ),
                      ],
                    );
                  }),
                ],
              ),
              pw.Spacer(),
              // Firma / Pie de página corporativo
              pw.Divider(color: const PdfColor.fromInt(0xFFE2E8F0)),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    "Documento oficial de uso interno. Generado digitalmente.",
                    style: pw.TextStyle(
                      font: fontRegular,
                      fontSize: 8,
                      color: PdfColors.grey400,
                    ),
                  ),
                  pw.Text(
                    "Pág. 1 de 1",
                    style: pw.TextStyle(
                      font: fontRegular,
                      fontSize: 8,
                      color: PdfColors.grey400,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'reporte_personal_medico.pdf',
    );
  }

  String _splitNameIntoTwoLines(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.length >= 4) {
      final firstLine = parts.sublist(0, 2).join(" ");
      final secondLine = parts.sublist(2).join(" ");
      return "$firstLine\n$secondLine";
    } else if (parts.length == 3) {
      return "${parts[0]}\n${parts[1]} ${parts[2]}";
    } else if (parts.length == 2) {
      return "${parts[0]}\n${parts[1]}";
    }
    return fullName;
  }

  pw.Widget _pdfHeaderCell(String text, pw.Font font, {
    pw.TextAlign textAlign = pw.TextAlign.left,
    double fontSize = 9.5,
  }) {
    final align = textAlign == pw.TextAlign.center 
        ? pw.Alignment.center 
        : (textAlign == pw.TextAlign.right ? pw.Alignment.centerRight : pw.Alignment.centerLeft);
        
    return pw.Container(
      alignment: align,
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: pw.Text(
        text,
        textAlign: textAlign,
        style: pw.TextStyle(font: font, color: PdfColors.white, fontSize: fontSize),
      ),
    );
  }

  pw.Widget _pdfDataCell(String text, pw.Font font, {
    PdfColor textColor = PdfColors.black,
    pw.TextAlign textAlign = pw.TextAlign.left,
    double fontSize = 8,
  }) {
    final align = textAlign == pw.TextAlign.center 
        ? pw.Alignment.center 
        : (textAlign == pw.TextAlign.right ? pw.Alignment.centerRight : pw.Alignment.centerLeft);
        
    return pw.Container(
      alignment: align,
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        text,
        textAlign: textAlign,
        style: pw.TextStyle(font: font, color: textColor, fontSize: fontSize),
      ),
    );
  }

  Widget _buildRolesFilter(AsyncValue<List<Map<String, dynamic>>> rolesAsync,
      AdminUsersState state) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5EAF2)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.filter_alt_outlined,
                color: AppTema.azulPrincipal,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                "Filtros",
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTema.azulPrincipal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          rolesAsync.maybeWhen(
            data: (roles) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sección 1: Filtrar por rol
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Filtrar por rol",
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                _filterCard(
                                  "Todos",
                                  state.selectedRolIds.isEmpty,
                                  () => ref.read(adminUsersProvider.notifier).clearFilters(),
                                  icon: Icons.people_rounded,
                                ),
                                ...roles.map((r) {
                                  final nombre = r["nombre"].toString().toLowerCase();
                                  IconData cardIcon = Icons.person_rounded;
                                  if (nombre.contains("admin")) {
                                    cardIcon = Icons.admin_panel_settings_rounded;
                                  } else if (nombre.contains("médico") || nombre.contains("medico")) {
                                    cardIcon = Icons.medical_services_rounded;
                                  } else if (nombre.contains("nutricionista")) {
                                    cardIcon = Icons.restaurant_menu_rounded;
                                  }
                                  
                                  final isSelected = state.selectedRolIds.contains(r["id"]);
                                  return _filterCard(
                                    r["nombre"].toString(),
                                    isSelected,
                                    () => ref.read(adminUsersProvider.notifier).toggleRol(r["id"]),
                                    icon: cardIcon,
                                  );
                                }),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      // Separador vertical
                      const SizedBox(width: 24),
                      Container(
                        width: 1,
                        height: 90,
                        color: const Color(0xFFE2E8F0),
                      ),
                      const SizedBox(width: 24),
                      
                      // Sección 2: Filtrar por estado
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Filtrar por estado",
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                _filterCard(
                                  "Todos",
                                  state.selectedActivo == null,
                                  () => ref.read(adminUsersProvider.notifier).setStatusFilter(null),
                                  icon: Icons.all_inclusive_rounded,
                                ),
                                _filterCard(
                                  "Activos",
                                  state.selectedActivo == true,
                                  () => ref.read(adminUsersProvider.notifier).setStatusFilter(true),
                                  icon: Icons.check_circle_rounded,
                                ),
                                _filterCard(
                                  "Dados de baja",
                                  state.selectedActivo == false,
                                  () => ref.read(adminUsersProvider.notifier).setStatusFilter(false),
                                  icon: Icons.cancel_rounded,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (state.activeFilters) ...[
                        OutlinedButton.icon(
                          onPressed: () {
                            _searchController.clear();
                            ref.read(adminUsersProvider.notifier).clearFilters();
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTema.azulPrincipal,
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            textStyle: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text("Limpiar filtros"),
                        ),
                        const SizedBox(width: 12),
                      ],
                      OutlinedButton.icon(
                        onPressed: () => _exportarPDF(state),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTema.azulPrincipal,
                          side: const BorderSide(color: AppTema.azulPrincipal, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          textStyle: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                        label: const Text("Exportar PDF"),
                      ),
                    ],
                  ),
                ],
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _filterCard(String label, bool isSelected, VoidCallback onTap, {required IconData icon}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppTema.pastelCeleste : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppTema.azulPrincipal
                : const Color(0xFFE5EAF2),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTema.azulPrincipal.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppTema.azulPrincipal : const Color(0xFF64748B),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? AppTema.azulOscuro : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTable(AdminUsersState state) {
    if (!state.isLoading && state.users.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.find_in_page_outlined, size: 48, color: Colors.blueGrey.shade300),
            const SizedBox(height: 16),
            Text(
              "No se encontraron profesionales de salud",
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTema.azulOscuro,
              ),
            ),
          ],
        ),
      );
    }

    return NutriTableContainer(
      child: LayoutBuilder(builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final usableWidth = totalWidth - 20;
        final currentRowsPerPage = state.users.isEmpty
            ? 5
            : (state.users.length < AdminUsersNotifier.pageSize
                ? state.users.length
                : AdminUsersNotifier.pageSize);

        return Theme(
          data: Theme.of(context).copyWith(
            cardTheme: const CardThemeData(
                elevation: 0, color: Colors.white, margin: EdgeInsets.zero),
            dividerColor: Colors.transparent,
          ),
          child: PaginatedDataTable(
            header: null,
            rowsPerPage: currentRowsPerPage,
            showFirstLastButtons: true,
            availableRowsPerPage: [currentRowsPerPage],
            onPageChanged: (idx) =>
                ref.read(adminUsersProvider.notifier).loadPage(offset: idx),
            columnSpacing: 0,
            horizontalMargin: 10,
            dividerThickness: 0.0,
            dataRowMinHeight: 70,
            dataRowMaxHeight: double.infinity,
            headingRowColor: WidgetStateProperty.all(AppTema.azulPrincipal),
            columns: [
              _col("PROFESIONAL", width: usableWidth * 0.35),
              _col("ROL / CARGO", width: usableWidth * 0.25),
              _col("ESTADO", width: usableWidth * 0.15, center: true),
              _col("ACCIONES", width: usableWidth * 0.25, center: true),
            ],
            source: _AdminUsersDataSource(
              items: state.users,
              totalRows: state.totalItems,
              offset: state.offset,
              isLoading: state.isLoading,
              onEdit: _dialogoUsuario,
              onToggle: (u) => ref
                  .read(adminUsersProvider.notifier)
                  .toggleUserStatus(u["id"].toString(), u["activo"] == true),
              onDelete: (u) => _eliminarUsuario(u),
              totalWidth: usableWidth,
              context: context,
            ),
          ),
        );
      }),
    );
  }

  DataColumn _col(String label, {required double width, bool center = false}) {
    return DataColumn(
      label: SizedBox(
        width: width,
        child: Container(
          alignment: center ? Alignment.center : Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: Colors.white,
                letterSpacing: 0.5),
          ),
        ),
      ),
    );
  }

  Future<void> _eliminarUsuario(Map<String, dynamic> user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Eliminar acceso"),
        content: Text(
            "¿Estás seguro de eliminar a ${user['nombre_completo']}? Esta acción revocará todos los accesos al sistema."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancelar")),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text("Eliminar")),
        ],
      ),
    );

    if (confirm == true) {
      final String rolName = user["rol_nombre"]?.toString() ?? "Personal";
      final String userName = user["nombre_completo"]?.toString() ?? "Usuario";
      
      if (mounted) {
        await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          barrierColor: Colors.black.withOpacity(0.55),
          builder: (ctx) => _DeleteProgressDialog(
            userName: userName,
            rolName: rolName,
            onDelete: () async {
              return await ref
                  .read(adminUsersProvider.notifier)
                  .deleteUser(user["id"].toString());
            },
          ),
        );
      }
    }
  }

  void _dialogoUsuario(Map<String, dynamic>? user) {
    showDialog(
      context: context,
      builder: (ctx) => _FormularioUsuario(
        user: user,
        onSuccess: () => ref.read(adminUsersProvider.notifier).loadPage(),
      ),
    );
  }
}

class _AdminUsersDataSource extends DataTableSource {
  final List<Map<String, dynamic>> items;
  final int totalRows;
  final int offset;
  final bool isLoading;
  final Function(Map<String, dynamic>) onEdit;
  final Function(Map<String, dynamic>) onToggle;
  final Function(Map<String, dynamic>) onDelete;
  final double totalWidth;
  final BuildContext context;

  _AdminUsersDataSource({
    required this.items,
    required this.totalRows,
    required this.offset,
    required this.isLoading,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
    required this.totalWidth,
    required this.context,
  });

  @override
  DataRow? getRow(int index) {
    final rowColor = index % 2 == 0 ? Colors.white : const Color(0xFFF8FAFC);

    if (isLoading) {
      return DataRow(
        color: WidgetStateProperty.all(rowColor),
        cells: [
        DataCell(SizedBox(
          width: totalWidth * 0.35,
          child: Row(
            children: [
              const NutriShimmer(
                  width: 32,
                  height: 32,
                  borderRadius: BorderRadius.all(Radius.circular(16))),
              const SizedBox(width: 12),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const NutriShimmer(width: 120, height: 12),
                  const SizedBox(height: 4),
                  NutriShimmer(
                      width: 180,
                      height: 10,
                      borderRadius: BorderRadius.circular(4)),
                ],
              ),
            ],
          ),
        )),
        DataCell(SizedBox(
            width: totalWidth * 0.25,
            child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: NutriShimmer(width: 80, height: 10)))),
        DataCell(SizedBox(
            width: totalWidth * 0.15,
            child: const Center(child: NutriShimmer(width: 60, height: 20)))),
        DataCell(SizedBox(
          width: totalWidth * 0.25,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              NutriShimmer(
                  width: 24,
                  height: 24,
                  borderRadius: BorderRadius.circular(12)),
              const SizedBox(width: 8),
              NutriShimmer(
                  width: 24,
                  height: 24,
                  borderRadius: BorderRadius.circular(12)),
              const SizedBox(width: 8),
              NutriShimmer(
                  width: 24,
                  height: 24,
                  borderRadius: BorderRadius.circular(12)),
            ],
          ),
        )),
      ]);
    }

    final localIndex = index - offset;
    if (localIndex < 0 || localIndex >= items.length) return null;
    final u = items[localIndex];

    return DataRow(
      color: WidgetStateProperty.all(rowColor),
      cells: [
      DataCell(SizedBox(
        width: totalWidth * 0.35,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 12),
          child: Row(
            children: [
              NutriAvatar(
                  nombreCompleto: u["nombre_completo"] ?? "?", radio: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                      Text(u["nombre_completo"] ?? "Sin nombre",
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              color: AppTema.azulOscuro)),
                      Text(u["email"] ?? "",
                          style: GoogleFonts.inter(
                              fontSize: 11, color: Colors.blueGrey)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        )),
        DataCell(SizedBox(
          width: totalWidth * 0.25,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Builder(
              builder: (context) {
                final roles = u["roles"] as List<dynamic>?;
                final text = (roles != null && roles.isNotEmpty)
                    ? roles.map((r) => r["nombre"].toString()).join(", ")
                    : (u["rol_nombre"]?.toString() ?? "Personal");
                return Text(text,
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTema.azulPrincipal));
              }
            ),
          ),
        )),
      DataCell(SizedBox(
        width: totalWidth * 0.15,
        child: Center(
          child: _StatusBadge(isActive: u["activo"] == true),
        ),
      )),
      DataCell(SizedBox(
        width: totalWidth * 0.25,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _HoverActionButton(
                  icon: Icons.edit_note_rounded,
                  label: "Editar",
                  color: Colors.blueGrey,
                  onTap: () => onEdit(u)),
              const SizedBox(width: 12),
              _HoverActionButton(
                  icon: u["activo"] == true
                      ? Icons.block_flipped
                      : Icons.check_circle_outline,
                  label: u["activo"] == true ? "Baja" : "Alta",
                  color: u["activo"] == true ? Colors.orange : Colors.green,
                  onTap: () => onToggle(u)),
              const SizedBox(width: 12),
              _HoverActionButton(
                  icon: Icons.delete_outline_rounded,
                  label: "Borrar",
                  color: Colors.redAccent,
                  onTap: () => onDelete(u)),
            ],
          ),
        ),
      )),
    ]);
  }

  @override
  bool get isRowCountApproximate => false;
  @override
  int get rowCount => (isLoading && totalRows == 0) ? 5 : totalRows;
  @override
  int get selectedRowCount => 0;
}

class _StatusBadge extends StatelessWidget {
  final bool isActive;
  const _StatusBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppTema.verdeSalud : Colors.redAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6)),
      child: Text(
        isActive ? "Activo" : "Inactivo",
        style: GoogleFonts.montserrat(
            color: color, fontWeight: FontWeight.w800, fontSize: 10),
      ),
    );
  }
}

class _HoverActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _HoverActionButton(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  State<_HoverActionButton> createState() => _HoverActionButtonState();
}

class _HoverActionButtonState extends State<_HoverActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onHover: (hovered) {
        setState(() {
          _isHovered = hovered;
        });
      },
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(12),
      hoverColor: Colors.transparent,
      splashColor: widget.color.withValues(alpha: 0.2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _isHovered
              ? widget.color.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: _isHovered
                  ? widget.color.withValues(alpha: 0.2)
                  : Colors.transparent),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, color: widget.color, size: 20),
            const SizedBox(height: 4),
            Text(widget.label,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: widget.color,
                    height: 1.0)),
          ],
        ),
      ),
    );
  }
}

class _FormularioUsuario extends ConsumerStatefulWidget {
  final Map<String, dynamic>? user;
  final VoidCallback onSuccess;
  const _FormularioUsuario({this.user, required this.onSuccess});
  @override
  ConsumerState<_FormularioUsuario> createState() => _FormularioUsuarioState();
}

class _FormularioUsuarioState extends ConsumerState<_FormularioUsuario> {
  final _emailCtrl = TextEditingController();
  final _nombreCtrl = TextEditingController();
  final _cedulaCtrl = TextEditingController();
  
  // Controllers for titles and institutions
  final _tituloAdminCtrl = TextEditingController();
  final _instAdminCtrl = TextEditingController();
  bool _checkedAdmin = false;

  final _tituloMedicoCtrl = TextEditingController();
  final _instMedicoCtrl = TextEditingController();
  bool _checkedMedico = false;

  final _tituloNutriCtrl = TextEditingController();
  final _instNutriCtrl = TextEditingController();
  bool _checkedNutri = false;

  bool _saving = false;

  String? _emailErrorText;
  String? _cedulaErrorText;
  String? _generalErrorText;

  @override
  void initState() {
    super.initState();
    if (widget.user != null) {
      _emailCtrl.text = widget.user!["email"] ?? "";
      _nombreCtrl.text = widget.user!["nombre_completo"] ?? "";
      _cedulaCtrl.text = widget.user!["cedula"] ?? "";
      
      final int? activeRolId = widget.user!["id_rol"];
      final roles = widget.user!["roles"] as List<dynamic>? ?? [];
      
      if (roles.isNotEmpty) {
        for (final r in roles) {
          final id = r["id"] as int;
          final String title = r["titulo_profesional"]?.toString() ?? "";
          final String inst = r["institucion_titulo"]?.toString() ?? "";
          
          if (id == 1) {
            _checkedAdmin = true;
            _tituloAdminCtrl.text = title;
            _instAdminCtrl.text = inst;
          } else if (id == 2) {
            _checkedMedico = true;
            _tituloMedicoCtrl.text = title;
            _instMedicoCtrl.text = inst;
          } else if (id == 3) {
            _checkedNutri = true;
            _tituloNutriCtrl.text = title;
            _instNutriCtrl.text = inst;
          }
        }
      } else if (activeRolId != null) {
        if (activeRolId == 1) {
          _checkedAdmin = true;
          _tituloAdminCtrl.text = "Administrador del Sistema";
          _instAdminCtrl.text = "Departamento de Tecnología";
        } else if (activeRolId == 2) {
          _checkedMedico = true;
          _tituloMedicoCtrl.text = "Doctor Reumatólogo";
          _instMedicoCtrl.text = "Universidad de Especialidades Médicas";
        } else if (activeRolId == 3) {
          _checkedNutri = true;
          _tituloNutriCtrl.text = "Nutricionista Clínico";
          _instNutriCtrl.text = "Universidad de Nutrición y Salud";
        }
      }
    } else {
      // Default unchecked, let them check what they need.
      _checkedMedico = true;
      _tituloMedicoCtrl.text = "Doctor Reumatólogo";
      _instMedicoCtrl.text = "Universidad de Especialidades Médicas";
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nombreCtrl.dispose();
    _cedulaCtrl.dispose();
    _tituloAdminCtrl.dispose();
    _instAdminCtrl.dispose();
    _tituloMedicoCtrl.dispose();
    _instMedicoCtrl.dispose();
    _tituloNutriCtrl.dispose();
    _instNutriCtrl.dispose();
    super.dispose();
  }

  Widget _buildRoleToggle({
    required String label,
    required String description,
    required bool checked,
    required ValueChanged<bool?> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: checked ? AppTema.verdeSalud.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: checked ? AppTema.verdeSalud.withValues(alpha: 0.4) : const Color(0xFFE2E8F0),
          width: checked ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: checked,
              onChanged: onChanged,
              activeColor: AppTema.verdeSalud,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: checked ? AppTema.verdeSalud : AppTema.azulOscuro,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    color: Colors.blueGrey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputMini(
    TextEditingController controller,
    String label,
    String hint,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 4),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppTema.verdeSalud,
            ),
          ),
        ),
        SizedBox(
          height: 38,
          child: TextField(
            controller: controller,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF334155),
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.inter(
                color: AppTema.verdeSalud.withValues(alpha: 0.5),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              filled: true,
              fillColor: AppTema.verdeSalud.withValues(alpha: 0.04),
              prefixIcon: Icon(icon, size: 14, color: AppTema.verdeSalud),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppTema.verdeSalud.withValues(alpha: 0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppTema.verdeSalud.withValues(alpha: 0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTema.verdeSalud, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.user != null;

    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 780,
        constraints: const BoxConstraints(maxWidth: 780, maxHeight: 580),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE5EAF2)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.10),
              blurRadius: 28,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppTema.azulPrincipal,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isEdit ? Icons.edit_rounded : Icons.person_add_alt_1_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    isEdit
                        ? "Editar Miembro del Equipo"
                        : "Nuevo Miembro del Equipo",
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTema.azulOscuro,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  color: const Color(0xFF64748B),
                  iconSize: 22,
                  tooltip: "Cerrar",
                  splashRadius: 20,
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Columna Izquierda: Datos de Acceso
                  Expanded(
                    flex: 10,
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 18.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _input(
                              _nombreCtrl,
                              "Nombre completo",
                              "Ingresar nombre completo",
                              Icons.badge_outlined,
                            ),
                            const SizedBox(height: 16),
                            _input(
                              _emailCtrl,
                              "Correo electrónico",
                              "usuario@nutrireuma.com",
                              Icons.mail_outline,
                              errorText: _emailErrorText,
                            ),
                            const SizedBox(height: 16),
                            _input(
                              _cedulaCtrl,
                              "Cédula",
                              "Número de cédula",
                              Icons.person_outline_rounded,
                              keyboardType: TextInputType.number,
                              errorText: _cedulaErrorText,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // Divisor vertical sutil
                  Container(
                    width: 1.2,
                    color: const Color(0xFFE2E8F0),
                    margin: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  
                  // Columna Derecha: Roles y Especialidades
                  Expanded(
                    flex: 12,
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 4, bottom: 12),
                              child: Text(
                                "Roles y Títulos Profesionales",
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppTema.azulOscuro,
                                ),
                              ),
                            ),
                            
                            // Administrador checkbox and fields
                            _buildRoleToggle(
                              label: "Administrador",
                              description: "Administra el personal, configura parámetros globales y visualiza auditorías de atención.",
                              checked: _checkedAdmin,
                              onChanged: (val) {
                                setState(() {
                                  _checkedAdmin = val ?? false;
                                  if (_checkedAdmin && _tituloAdminCtrl.text.isEmpty) {
                                    _tituloAdminCtrl.text = "Administrador del Sistema";
                                  }
                                  if (_checkedAdmin && _instAdminCtrl.text.isEmpty) {
                                    _instAdminCtrl.text = "Departamento de Tecnología";
                                  }
                                });
                              },
                            ),
                            if (_checkedAdmin) ...[
                              Container(
                                margin: const EdgeInsets.only(left: 12.0, bottom: 12.0),
                                padding: const EdgeInsets.only(left: 16.0, top: 4.0, bottom: 8.0),
                                decoration: BoxDecoration(
                                  border: Border(
                                    left: BorderSide(
                                      color: AppTema.verdeSalud.withValues(alpha: 0.5),
                                      width: 2.0,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _inputMini(_tituloAdminCtrl, "Título Profesional del Administrador", "Ej. Administrador del Sistema", Icons.badge_outlined),
                                    const SizedBox(height: 8),
                                    _inputMini(_instAdminCtrl, "Lugar de obtención / Institución", "Ej. Departamento de Tecnología", Icons.account_balance_rounded),
                                  ],
                                ),
                              ),
                            ],
                            
                            // Médico checkbox and fields
                            _buildRoleToggle(
                              label: "Médico",
                              description: "Acceso clínico completo: evaluaciones médicas de pacientes, escalas y control de brotes.",
                              checked: _checkedMedico,
                              onChanged: (val) {
                                setState(() {
                                  _checkedMedico = val ?? false;
                                  if (_checkedMedico && _tituloMedicoCtrl.text.isEmpty) {
                                    _tituloMedicoCtrl.text = "Doctor Reumatólogo";
                                  }
                                  if (_checkedMedico && _instMedicoCtrl.text.isEmpty) {
                                    _instMedicoCtrl.text = "Universidad de Especialidades Médicas";
                                  }
                                });
                              },
                            ),
                            if (_checkedMedico) ...[
                              Container(
                                margin: const EdgeInsets.only(left: 12.0, bottom: 12.0),
                                padding: const EdgeInsets.only(left: 16.0, top: 4.0, bottom: 8.0),
                                decoration: BoxDecoration(
                                  border: Border(
                                    left: BorderSide(
                                      color: AppTema.verdeSalud.withValues(alpha: 0.5),
                                      width: 2.0,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _inputMini(_tituloMedicoCtrl, "Título Profesional del Médico", "Ej. Doctor Reumatólogo", Icons.badge_outlined),
                                    const SizedBox(height: 8),
                                    _inputMini(_instMedicoCtrl, "Lugar de obtención del título", "Ej. Universidad Central del Ecuador", Icons.account_balance_rounded),
                                  ],
                                ),
                              ),
                            ],
                            
                            // Nutricionista checkbox and fields
                            _buildRoleToggle(
                              label: "Nutricionista",
                              description: "Acceso a planes nutricionales: dietas personalizadas, recetas y restricciones alimentarias.",
                              checked: _checkedNutri,
                              onChanged: (val) {
                                setState(() {
                                  _checkedNutri = val ?? false;
                                  if (_checkedNutri && _tituloNutriCtrl.text.isEmpty) {
                                    _tituloNutriCtrl.text = "Nutricionista Clínico";
                                  }
                                  if (_checkedNutri && _instNutriCtrl.text.isEmpty) {
                                    _instNutriCtrl.text = "Universidad de Nutrición y Salud";
                                  }
                                });
                              },
                            ),
                            if (_checkedNutri) ...[
                              Container(
                                margin: const EdgeInsets.only(left: 12.0, bottom: 12.0),
                                padding: const EdgeInsets.only(left: 16.0, top: 4.0, bottom: 8.0),
                                decoration: BoxDecoration(
                                  border: Border(
                                    left: BorderSide(
                                      color: AppTema.verdeSalud.withValues(alpha: 0.5),
                                      width: 2.0,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _inputMini(_tituloNutriCtrl, "Título Profesional del Nutricionista", "Ej. Nutricionista Clínico", Icons.badge_outlined),
                                    const SizedBox(height: 8),
                                    _inputMini(_instNutriCtrl, "Lugar de obtención del título", "Ej. Universidad de Nutrición y Salud", Icons.account_balance_rounded),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTema.pastelCeleste,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTema.azulPrincipal.withValues(alpha: 0.3),
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_rounded,
                    color: AppTema.azulPrincipal,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isEdit
                          ? "Actualiza los datos de acceso y perfil profesional."
                          : "Al guardar, se enviará una invitación por correo para que configure su contraseña.",
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTema.azulPrincipal,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
                    textStyle: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  child: const Text("Cancelar"),
                ),
                const SizedBox(width: 18),
                SizedBox(
                  width: 148,
                  height: 46,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTema.azulPrincipal,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      textStyle: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    child: Text(_saving ? "Guardando..." : "Guardar"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _input(
    TextEditingController controller,
    String label,
    String hint,
    IconData icon, {
    bool obscure = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? errorText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTema.azulOscuro,
            ),
          ),
        ),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xFF334155),
            fontWeight: FontWeight.w600,
          ),
          decoration: _inputDecor(hint, icon).copyWith(errorText: errorText),
        ),
      ],
    );
  }

  InputDecoration _inputDecor(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(
          color: Colors.grey.shade400,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: const Color(0xFFF1F5F9),
        prefixIcon: Icon(icon, size: 20, color: Colors.blueGrey.shade400),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTema.azulPrincipal, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        errorMaxLines: 4,
        errorStyle: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: Colors.redAccent,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      );

  Future<void> _save() async {
    setState(() {
      _emailErrorText = null;
      _cedulaErrorText = null;
      _generalErrorText = null;
    });

    if (_nombreCtrl.text.isEmpty || _emailCtrl.text.isEmpty) {
      NutriSnack.show(context, "Por favor complete los campos obligatorios",
          isError: true);
      return;
    }

    final String cedulaVal = _cedulaCtrl.text.trim();
    if (cedulaVal.isNotEmpty) {
      if (cedulaVal.length != 10) {
        NutriSnack.show(context, "La cédula debe contener exactamente 10 dígitos numéricos", isError: true);
        return;
      }
    }

    final List<Map<String, dynamic>> rolesAsignados = [];
    if (_checkedAdmin) {
      rolesAsignados.add({
        "id_rol": 1,
        "titulo_profesional": _tituloAdminCtrl.text.trim(),
        "institucion_titulo": _instAdminCtrl.text.trim(),
      });
    }
    if (_checkedMedico) {
      rolesAsignados.add({
        "id_rol": 2,
        "titulo_profesional": _tituloMedicoCtrl.text.trim(),
        "institucion_titulo": _instMedicoCtrl.text.trim(),
      });
    }
    if (_checkedNutri) {
      rolesAsignados.add({
        "id_rol": 3,
        "titulo_profesional": _tituloNutriCtrl.text.trim(),
        "institucion_titulo": _instNutriCtrl.text.trim(),
      });
    }

    if (rolesAsignados.isEmpty) {
      NutriSnack.show(context, "Debe seleccionar al menos un rol para el usuario",
          isError: true);
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      final int primaryRolId = rolesAsignados.first["id_rol"] as int;

      if (widget.user != null) {
        await repo.updateUser(
          userId: widget.user!["id"].toString(),
          nombreCompleto: _nombreCtrl.text,
          email: _emailCtrl.text,
          cedula: _cedulaCtrl.text,
          idRol: primaryRolId,
          rolesAsignados: rolesAsignados,
        );
      } else {
        await repo.createUser(
          email: _emailCtrl.text,
          nombreCompleto: _nombreCtrl.text,
          idRol: primaryRolId,
          rolesAsignados: rolesAsignados,
          cedula: _cedulaCtrl.text,
        );
      }
      widget.onSuccess();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        String errorMsg = e.toString();
        if (e is DioException) {
          final data = e.response?.data;
          if (data is Map && data.containsKey('detail')) {
            errorMsg = data['detail'].toString();
          } else if (data is Map && data.containsKey('message')) {
            errorMsg = data['message'].toString();
          } else {
            errorMsg = e.message ?? errorMsg;
          }
        }
        
        setState(() {
          final lower = errorMsg.toLowerCase();
          if (lower.contains('cédula') || lower.contains('cedula')) {
             _cedulaErrorText = errorMsg;
          } else if (lower.contains('correo') || lower.contains('email')) {
             _emailErrorText = errorMsg;
          } else {
             _generalErrorText = errorMsg;
          }
        });
        
        if (_generalErrorText != null) {
          NutriSnack.show(context, "Error al guardar: $_generalErrorText", isError: true);
        }
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

final rolesStaffProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final allRoles = await ref
      .watch(supabaseCrudRepositoryProvider)
      .fetchCatalog("usuarios", "rol");
  final allowedRoles = [
    "médico",
    "nutricionista",
    "administrador",
    "médico/a",
    "medico",
    "admin"
  ];
  return allRoles.where((r) {
    final nombre = r["nombre"].toString().toLowerCase();
    return allowedRoles.any((allowed) => nombre.contains(allowed));
  }).toList();
});

class _DeleteProgressDialog extends StatefulWidget {
  final String userName;
  final String rolName;
  final Future<bool> Function() onDelete;

  const _DeleteProgressDialog({
    required this.userName,
    required this.rolName,
    required this.onDelete,
  });

  @override
  State<_DeleteProgressDialog> createState() => _DeleteProgressDialogState();
}

class _DeleteProgressDialogState extends State<_DeleteProgressDialog> {
  late String _statusText;
  bool _isCompleted = false;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _statusText = "Eliminando a ${widget.userName} (${widget.rolName})...";
    _ejecutarEliminacion();
  }

  Future<void> _ejecutarEliminacion() async {
    await Future.delayed(const Duration(milliseconds: 500));
    final exito = await widget.onDelete();
    if (mounted) {
      setState(() {
        _isCompleted = true;
        _isSuccess = exito;
        _statusText = exito ? "Borrado con éxito" : "Error al eliminar";
      });
      
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) {
        Navigator.of(context).pop(exito);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Center(
        child: Container(
          width: 320,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!_isCompleted)
                const SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 3.5,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTema.azulPrincipal),
                  ),
                )
              else if (_isSuccess)
                const Icon(
                  Icons.check_circle_outline_rounded,
                  color: AppTema.verdeSalud,
                  size: 48,
                )
              else
                const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.redAccent,
                  size: 48,
                ),
              const SizedBox(height: 20),
              Text(
                _statusText,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTema.azulOscuro,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
