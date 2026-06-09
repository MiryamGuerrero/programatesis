import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/state/app_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/layout_components.dart';
import 'widgets/etiqueta_card.dart';
import 'etiqueta_form_page.dart';

class EtiquetasPage extends ConsumerStatefulWidget {
  const EtiquetasPage({super.key});

  @override
  ConsumerState<EtiquetasPage> createState() => _EtiquetasPageState();
}

class _EtiquetasPageState extends ConsumerState<EtiquetasPage> {
  String _query = "";
  bool _loading = false;
  String _estadoFiltro = 'todas';
  String _tipoFiltro = 'todas';
  String? _error;
  List<Map<String, dynamic>> _etiquetas = const [];

  int _currentPage = 0;
  final int _pageSize = 12;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadEtiquetas);
  }

  Future<void> _loadEtiquetas() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final resp = await dio
          .get('nutricionista/etiquetas', queryParameters: {'q': _query});
      if (!mounted) return;
      setState(() {
        _etiquetas = List<Map<String, dynamic>>.from(resp.data);
        _currentPage = 0;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _abrirFormulario([Map<String, dynamic>? etiqueta]) async {
    final exito = await showDialog<bool>(
      context: context,
      builder: (context) => EtiquetaFormDialog(etiquetaInicial: etiqueta),
    );

    if (exito == true) {
      _loadEtiquetas();
    }
  }

  Future<void> _deleteEtiqueta(int id, String nombre) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar etiqueta'),
        content: Text(
          '¿Deseas eliminar la etiqueta "$nombre"? Esta acción la desvinculará de ingredientes y recetas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCELAR'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ELIMINAR'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final dio = ref.read(dioProvider);
        await dio.delete('nutricionista/etiquetas/$id');
        if (mounted) {
          NutriSnack.show(context, 'Etiqueta eliminada con éxito');
          _loadEtiquetas();
        }
      } catch (e) {
        if (mounted) {
          NutriSnack.show(context, 'Error al eliminar la etiqueta',
              isError: true);
        }
      }
    }
  }

  bool _matchesTipo(Map<String, dynamic> etiqueta, String tipo) {
    if (tipo == 'todas') return true;
    final text = [
      etiqueta['nombre_visible'],
      etiqueta['descripcion'],
      etiqueta['codigo'],
    ].whereType<Object>().join(' ').toLowerCase();

    switch (tipo) {
      case 'gluten':
        return text.contains('gluten');
      case 'lactosa':
        return text.contains('lactosa');
      case 'sodio':
        return text.contains('sodio') || text.contains('sal');
      case 'azucar':
        return text.contains('azucar') || text.contains('azúcar');
      case 'vegetariana':
        return text.contains('veget') || text.contains('vegan');
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _etiquetas.where((e) {
      final activa = e['activa'] != false;
      if (_estadoFiltro == 'activas' && !activa) return false;
      if (_estadoFiltro == 'inactivas' && activa) return false;
      return _matchesTipo(e, _tipoFiltro);
    }).toList();
    final totalPages = (filtered.length / _pageSize).ceil();
    final start = _currentPage * _pageSize;
    final end = (start + _pageSize) > filtered.length
        ? filtered.length
        : (start + _pageSize);
    final pageItems = filtered.isEmpty
        ? <Map<String, dynamic>>[]
        : filtered.sublist(start, end);

    return Scaffold(
      backgroundColor: AppTema.grisLienzo,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const SizedBox(height: 32),
            _buildStatsRow(filtered.length),
            const SizedBox(height: 32),
            _buildToolbar(),
            const SizedBox(height: 24),
            if (_loading && _etiquetas.isEmpty)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              _buildErrorState()
            else if (filtered.isEmpty)
              _buildEmptyState()
            else
              _buildGrid(pageItems),
            if (filtered.isNotEmpty)
              _buildFooter(start + 1, end, filtered.length, totalPages),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gestión de Etiquetas',
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppTema.azulPrincipal,
            letterSpacing: -0.5,
          ),
        ),
        Text(
          'Configura las etiquetas nutricionales y descriptivas para las recetas.',
          style: GoogleFonts.inter(
            color: Colors.blueGrey,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(int visibles) {
    final activas = _etiquetas.where((e) => e['activa'] != false).length;

    return Row(
      children: [
        Expanded(
          child: NutriResumenCard(
            titulo: 'TOTAL ETIQUETAS',
            valor: _etiquetas.length.toString(),
            icon: Icons.label_rounded,
            colorValor: AppTema.azulPrincipal,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: NutriResumenCard(
            titulo: 'ACTIVAS',
            valor: activas.toString(),
            icon: Icons.check_circle_rounded,
            colorValor: AppTema.verdeSalud,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: NutriResumenCard(
            titulo: 'VISIBLES',
            valor: visibles.toString(),
            icon: Icons.filter_alt_rounded,
            colorValor: AppTema.azulOscuro,
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 560;
              final search = _buildSearchField();
              final action = _buildCreateButton();

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    search,
                    const SizedBox(height: 12),
                    action,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: search),
                  const SizedBox(width: 20),
                  action,
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          _buildFilters(),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
        onChanged: (v) {
          _query = v;
          _loadEtiquetas();
        },
        decoration: InputDecoration(
          hintText: 'Buscar por nombre o código...',
          hintStyle:
              GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 12),
          prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildCreateButton() {
    return SizedBox(
      height: 48,
      child: FilledButton.icon(
        onPressed: () => _abrirFormulario(),
        style: FilledButton.styleFrom(
          backgroundColor: AppTema.verdeSalud,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
        icon: const Icon(Icons.add_circle, size: 20, color: Colors.white),
        label: Text(
          'NUEVA ETIQUETA',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Filtros',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Colors.grey.shade600,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _filterChip('Todas', _estadoFiltro == 'todas',
                () => _setEstadoFiltro('todas')),
            _filterChip('Activas', _estadoFiltro == 'activas',
                () => _setEstadoFiltro('activas')),
            _filterChip('Inactivas', _estadoFiltro == 'inactivas',
                () => _setEstadoFiltro('inactivas')),
            _filterChip('Gluten', _tipoFiltro == 'gluten',
                () => _setTipoFiltro('gluten')),
            _filterChip('Lactosa', _tipoFiltro == 'lactosa',
                () => _setTipoFiltro('lactosa')),
            _filterChip(
                'Sodio', _tipoFiltro == 'sodio', () => _setTipoFiltro('sodio')),
            _filterChip('Azúcar', _tipoFiltro == 'azucar',
                () => _setTipoFiltro('azucar')),
            _filterChip('Vegetarianas', _tipoFiltro == 'vegetariana',
                () => _setTipoFiltro('vegetariana')),
            if (_tipoFiltro != 'todas')
              _filterChip('Quitar tipo', false, () => _setTipoFiltro('todas')),
          ],
        ),
      ],
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return FilterChip(
      selected: selected,
      label: Text(
        label,
        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
      ),
      selectedColor: AppTema.verdeSalud,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppTema.azulOscuro,
      ),
      side: BorderSide(
        color: selected
            ? AppTema.verdeSalud
            : AppTema.azulPrincipal.withValues(alpha: 0.18),
      ),
      onSelected: (_) => onTap(),
    );
  }

  void _setEstadoFiltro(String value) {
    setState(() {
      _estadoFiltro = value;
      _currentPage = 0;
    });
  }

  void _setTipoFiltro(String value) {
    setState(() {
      _tipoFiltro = value;
      _currentPage = 0;
    });
  }

  Widget _buildGrid(List<Map<String, dynamic>> items) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 360,
        mainAxisExtent: 210,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return EtiquetaCard(
          etiqueta: item,
          onTap: () => _abrirFormulario(item),
          onEdit: () => _abrirFormulario(item),
          onDelete: () => _deleteEtiqueta(
              item['id'], item['nombre_visible'] ?? 'Sin nombre'),
        );
      },
    );
  }

  Widget _buildFooter(int start, int end, int total, int totalPages) {
    if (totalPages <= 1) {
      return Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Text(
          'Mostrando $start a $end de $total etiquetas',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed:
                _currentPage > 0 ? () => setState(() => _currentPage--) : null,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Text(
            'Página ${_currentPage + 1} de $totalPages',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          IconButton(
            onPressed: _currentPage < totalPages - 1
                ? () => setState(() => _currentPage++)
                : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text('Error: $_error'),
          TextButton(
              onPressed: _loadEtiquetas, child: const Text('Reintentar')),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          Icon(Icons.label_off_rounded, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No se encontraron etiquetas.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
