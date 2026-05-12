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
  String? _error;
  List<Map<String, dynamic>> _etiquetas = const [];
  
  // Estados de navegación interna
  bool _isEditing = false;
  Map<String, dynamic>? _etiquetaParaEditar;
  
  // Paginación
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
      final resp = await dio.get('nutricionista/etiquetas', queryParameters: {'q': _query});
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

  Future<void> _deleteEtiqueta(int id, String nombre) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar Etiqueta?'),
        content: Text('¿Estás seguro de que deseas eliminar la etiqueta "$nombre"? Esta acción desvinculará la etiqueta de todos los ingredientes y recetas.'),
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
          NutriSnack.show(context, 'Error al eliminar la etiqueta', isError: true);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing) {
      return EtiquetaFormPage(
        etiquetaInicial: _etiquetaParaEditar,
        onBack: () {
          setState(() {
            _isEditing = false;
            _etiquetaParaEditar = null;
          });
          _loadEtiquetas();
        },
      );
    }

    final filtered = _etiquetas;
    final totalPages = (filtered.length / _pageSize).ceil();
    final start = _currentPage * _pageSize;
    final end = (start + _pageSize) > filtered.length ? filtered.length : (start + _pageSize);
    final pageItems = filtered.isEmpty ? <Map<String, dynamic>>[] : filtered.sublist(start, end);

    return Scaffold(
      backgroundColor: AppTema.grisLienzo,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const SizedBox(height: 32),
            _buildStatsRow(),
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
            if (totalPages > 1) _buildPagination(totalPages),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gestión de Etiquetas',
              style: GoogleFonts.quicksand(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppTema.azulOscuro,
              ),
            ),
            Text(
              'Configura las etiquetas nutricionales y descriptivas para las recetas.',
              style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
        const Spacer(),
        ElevatedButton.icon(
          onPressed: () => setState(() => _isEditing = true),
          icon: const Icon(Icons.add_rounded),
          label: const Text('NUEVA ETIQUETA'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTema.azulPrincipal,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: NutriResumenCard(
            titulo: 'Total Etiquetas',
            valor: _etiquetas.length.toString(),
            icon: Icons.label_rounded,
            colorValor: AppTema.azulPrincipal,
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: (v) {
                _query = v;
                _loadEtiquetas();
              },
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o código...',
                prefixIcon: const Icon(Icons.search_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            onPressed: _loadEtiquetas,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualizar',
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(List<Map<String, dynamic>> items) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 400,
        mainAxisExtent: 240,
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return EtiquetaCard(
          etiqueta: item,
          onTap: () => setState(() {
            _etiquetaParaEditar = item;
            _isEditing = true;
          }),
          onEdit: () => setState(() {
            _etiquetaParaEditar = item;
            _isEditing = true;
          }),
          onDelete: () => _deleteEtiqueta(item['id'], item['nombre_visible'] ?? 'Sin nombre'),
        );
      },
    );
  }

  Widget _buildPagination(int totalPages) {
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Text('Página ${_currentPage + 1} de $totalPages'),
          IconButton(
            onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
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
          TextButton(onPressed: _loadEtiquetas, child: const Text('Reintentar')),
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
          Text('No se encontraron etiquetas.', style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.quicksand(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTema.azulOscuro,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
