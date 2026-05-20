import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';

// ESTADOS LÓGICOS DE UNA COMIDA
enum EstadoComida { pasado, enCurso, pendiente }

// MODELO DE DATOS DE COMIDA
class ComidaAgenda {
  final String id;
  final String titulo;
  final String subtitulo;
  final TimeOfDay horaInicio;
  final TimeOfDay horaFin;
  final String recetaId;

  ComidaAgenda({
    required this.id,
    required this.titulo,
    required this.subtitulo,
    required this.horaInicio,
    required this.horaFin,
    required this.recetaId,
  });
}

class TutorCalendarioPage extends StatefulWidget {
  const TutorCalendarioPage({super.key});

  @override
  State<TutorCalendarioPage> createState() => _TutorCalendarioPageState();
}

class _TutorCalendarioPageState extends State<TutorCalendarioPage> {
  // 1. GESTIÓN DEL ESTADO ACTIVO (CONTROLADOR MAESTRO)
  DateTime _selectedDate = DateTime(2026, 5, 20); // Inicializado con "Hoy"
  final DateTime _today = DateTime(2026, 5, 20);
  int _currentMonthIndex = 1; // Mayo

  final ScrollController _scrollController = ScrollController();
  final PageController _weekPageController = PageController(initialPage: 3);
  final PageController _monthPageController = PageController(initialPage: 1);

  // BASE DE DATOS SIMULADA
  final Map<DateTime, List<ComidaAgenda>> _database = {
    DateTime(2026, 5, 20): [
      ComidaAgenda(
        id: "1",
        titulo: "Bowl de Acai",
        subtitulo: "Con granola y fresas",
        horaInicio: const TimeOfDay(hour: 7, minute: 0),
        horaFin: const TimeOfDay(hour: 9, minute: 0),
        recetaId: "rec_001",
      ),
      ComidaAgenda(
        id: "2",
        titulo: "Ensalada César Saludable",
        subtitulo: "Proteína: Pollo a la plancha",
        horaInicio: const TimeOfDay(hour: 13, minute: 0),
        horaFin: const TimeOfDay(hour: 15, minute: 0),
        recetaId: "rec_002",
      ),
      ComidaAgenda(
        id: "3",
        titulo: "Salmón al Horno",
        subtitulo: "Con espárragos",
        horaInicio: const TimeOfDay(hour: 19, minute: 0),
        horaFin: const TimeOfDay(hour: 21, minute: 0),
        recetaId: "rec_003",
      ),
    ],
    DateTime(2026, 5, 21): [
      ComidaAgenda(
        id: "4",
        titulo: "Huevos Revueltos",
        subtitulo: "Con espinaca y pan integral",
        horaInicio: const TimeOfDay(hour: 8, minute: 0),
        horaFin: const TimeOfDay(hour: 10, minute: 0),
        recetaId: "rec_004",
      ),
    ],
  };

  // 2. DETALLE INFERIOR (VISTA ESCLAVA - REACTIVA)
  List<ComidaAgenda> get _mealsForSelectedDate {
    final dateKey = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final meals = _database[dateKey] ?? [];
    
    // ORDENAMIENTO CRONOLÓGICO
    meals.sort((a, b) {
      final aMinutes = a.horaInicio.hour * 60 + a.horaInicio.minute;
      final bMinutes = b.horaInicio.hour * 60 + b.horaInicio.minute;
      return aMinutes.compareTo(bMinutes);
    });
    
    return meals;
  }

  // EVALUACIÓN DE RANGO HORARIO (LÓGICA TIEMPO REAL)
  EstadoComida _evaluarEstado(ComidaAgenda comida) {
    // Usamos las 14:00 del día 20 como "hora actual" para el demo
    final now = const TimeOfDay(hour: 14, minute: 0); 
    
    final startMinutes = comida.horaInicio.hour * 60 + comida.horaInicio.minute;
    final endMinutes = comida.horaFin.hour * 60 + comida.horaFin.minute;
    final nowMinutes = now.hour * 60 + now.minute;

    if (nowMinutes > endMinutes) return EstadoComida.pasado;
    if (nowMinutes >= startMinutes && nowMinutes <= endMinutes) return EstadoComida.enCurso;
    return EstadoComida.pendiente;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _weekPageController.dispose();
    _monthPageController.dispose();
    super.dispose();
  }

  void _onDateTapped(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
    // Emitimos evento de sincronización horizontal si es necesario
    _syncHorizontalCalendar(date.day);
  }

  void _syncHorizontalCalendar(int day) {
    if (!mounted || !_weekPageController.hasClients) return;
    int targetPage = (day <= 3) ? 0 : (day <= 10) ? 1 : (day <= 17) ? 2 : (day <= 24) ? 3 : 4;
    if (_weekPageController.page?.round() != targetPage) {
      _weekPageController.animateToPage(targetPage, duration: const Duration(milliseconds: 300), curve: Curves.fastOutSlowIn);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final filteredMeals = _mealsForSelectedDate;

    return Container(
      color: colorScheme.surface,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollEndNotification) {
            final double offset = _scrollController.offset;
            if (offset > 0 && offset < 220) {
              final double target = offset < 110 ? 0.0 : 220.0;
              Future.microtask(() => _scrollController.animateTo(target, duration: const Duration(milliseconds: 300), curve: Curves.fastOutSlowIn));
            }
          }
          return false;
        },
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            // MAESTRO: CABECERA DEL CALENDARIO
            SliverPersistentHeader(
              pinned: true,
              delegate: _TeamsCalendarHeaderDelegate(
                colorAcento: colorScheme.primary,
                colorTitulo: colorScheme.onSurface,
                selectedDay: _selectedDate,
                today: _today,
                currentMonthName: ["Abril", "Mayo", "Junio", "Julio", "Agosto"][_currentMonthIndex],
                monthPageController: _monthPageController,
                weekPageController: _weekPageController,
                onDaySelected: _onDateTapped,
                onMonthChanged: (index) => setState(() => _currentMonthIndex = index),
                onToggleExpand: () {
                  final target = _scrollController.offset > 110 ? 0.0 : 220.0;
                  _scrollController.animateTo(target, duration: const Duration(milliseconds: 350), curve: Curves.fastOutSlowIn);
                },
                onDragUpdate: (details) {
                  final newOffset = (_scrollController.offset - details.delta.dy).clamp(0.0, 1000.0);
                  _scrollController.jumpTo(newOffset);
                },
                hasDataPredicate: (date) => _database.containsKey(DateTime(date.year, date.month, date.day)),
              ),
            ),

            // ESCLAVO: LISTA DE COMIDAS / EMPTY STATES
            if (filteredMeals.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(context),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.only(top: 20, bottom: 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final meal = filteredMeals[index];
                      final estado = _evaluarEstado(meal);
                      return _buildMealItem(context, meal, estado);
                    },
                    childCount: filteredMeals.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_today_outlined, size: 64, color: Colors.grey.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            "No hay un plan nutricional para este día",
            style: GoogleFonts.montserrat(color: Colors.grey, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text("Selecciona otra fecha en el calendario", style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildMealItem(BuildContext context, ComidaAgenda meal, EstadoComida estado) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    switch (estado) {
      case EstadoComida.pasado:
        statusColor = Colors.grey;
        statusLabel = "Pasado";
        statusIcon = Icons.history;
        break;
      case EstadoComida.enCurso:
        statusColor = AppTema.verdeSalud;
        statusLabel = "En curso";
        statusIcon = Icons.timer_outlined;
        break;
      case EstadoComida.pendiente:
        statusColor = colorScheme.primary;
        statusLabel = "Pendiente";
        statusIcon = Icons.upcoming_outlined;
        break;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
        border: estado == EstadoComida.enCurso ? Border.all(color: AppTema.verdeSalud.withOpacity(0.5), width: 2) : null,
      ),
      child: InkWell(
        onTap: () {
          // CONTROLADOR DE RUTAS (NAVEGACIÓN POR ID)
          print("Navegando a receta ID: ${meal.recetaId}");
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // HORA Y ESTADO
              Column(
                children: [
                  Text(
                    "${meal.horaInicio.format(context)}",
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Icon(statusIcon, size: 14, color: statusColor),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              const VerticalDivider(width: 1),
              const SizedBox(width: 16),
              // INFO COMIDA
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(meal.titulo, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    Text(meal.subtitulo, style: theme.textTheme.bodySmall),
                    if (estado == EstadoComida.enCurso)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text("¡Es hora de comer!", style: TextStyle(color: AppTema.verdeSalud, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeamsCalendarHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Color colorAcento;
  final Color colorTitulo;
  final DateTime selectedDay;
  final DateTime today;
  final String currentMonthName;
  final PageController monthPageController;
  final PageController weekPageController;
  final Function(DateTime) onDaySelected;
  final Function(int) onMonthChanged;
  final Function(DragUpdateDetails) onDragUpdate;
  final VoidCallback onToggleExpand;
  final bool Function(DateTime) hasDataPredicate;

  _TeamsCalendarHeaderDelegate({
    required this.colorAcento,
    required this.colorTitulo,
    required this.selectedDay,
    required this.today,
    required this.currentMonthName,
    required this.monthPageController,
    required this.weekPageController,
    required this.onDaySelected,
    required this.onMonthChanged,
    required this.onDragUpdate,
    required this.onToggleExpand,
    required this.hasDataPredicate,
  });

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final theme = Theme.of(context);
    final double collapsePercent = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: onToggleExpand,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("$currentMonthName 2026", style: theme.textTheme.titleLarge),
                  Icon(Icons.calendar_month_outlined, color: colorAcento, size: 20),
                ],
              ),
            ),
          ),
          _buildDaysHeader(context),
          Expanded(
            child: Stack(
              children: [
                if (collapsePercent < 0.7)
                  Opacity(
                    opacity: (1 - collapsePercent * 1.5).clamp(0.0, 1.0),
                    child: PageView.builder(
                      controller: monthPageController,
                      onPageChanged: onMonthChanged,
                      itemCount: 5,
                      itemBuilder: (context, index) => _buildMonthGrid(context, index),
                    ),
                  ),
                Center(
                  child: Opacity(
                    opacity: collapsePercent > 0.4 ? ((collapsePercent - 0.4) * 2).clamp(0.0, 1.0) : 0.0,
                    child: SizedBox(
                      height: 55,
                      child: PageView(
                        controller: weekPageController,
                        children: [
                          _buildCalendarRow(context, [27, 28, 29, 30, 1, 2, 3], monthOffset: -1),
                          _buildCalendarRow(context, [4, 5, 6, 7, 8, 9, 10], monthOffset: 0),
                          _buildCalendarRow(context, [11, 12, 13, 14, 15, 16, 17], monthOffset: 0),
                          _buildCalendarRow(context, [18, 19, 20, 21, 22, 23, 24], monthOffset: 0),
                          _buildCalendarRow(context, [25, 26, 27, 28, 29, 30, 31], monthOffset: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onVerticalDragUpdate: onDragUpdate,
            onTap: onToggleExpand,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: double.infinity, height: 24,
              alignment: Alignment.center,
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthGrid(BuildContext context, int monthIndex) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        children: [
          _buildCalendarRow(context, [27, 28, 29, 30, 1, 2, 3], monthOffset: monthIndex - 1, isCurrentMonth: [false, false, false, false, true, true, true]),
          _buildCalendarRow(context, [4, 5, 6, 7, 8, 9, 10], monthOffset: monthIndex - 1),
          _buildCalendarRow(context, [11, 12, 13, 14, 15, 16, 17], monthOffset: monthIndex - 1),
          _buildCalendarRow(context, [18, 19, 20, 21, 22, 23, 24], monthOffset: monthIndex - 1),
          _buildCalendarRow(context, [25, 26, 27, 28, 29, 30, 31], monthOffset: monthIndex - 1),
        ],
      ),
    );
  }

  Widget _buildDaysHeader(BuildContext context) {
    final theme = Theme.of(context);
    final diasSemana = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: diasSemana.map((dia) => Text(dia, style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8)))).toList(),
    );
  }

  Widget _buildCalendarRow(BuildContext context, List<int> dias, {required int monthOffset, List<bool>? isCurrentMonth}) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: List.generate(7, (index) {
        final dia = dias[index];
        final DateTime dateForDay = DateTime(2026, 4 + monthOffset + 1, dia);
        
        final bool isSelected = dateForDay.year == selectedDay.year && dateForDay.month == selectedDay.month && dateForDay.day == selectedDay.day;
        final bool isTodayDate = dateForDay.year == today.year && dateForDay.month == today.month && dateForDay.day == today.day;
        final currentMonth = isCurrentMonth == null || isCurrentMonth[index];
        final bool hasData = hasDataPredicate(dateForDay);

        return Expanded(
          child: GestureDetector(
            onTap: () => onDaySelected(dateForDay),
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              height: 48,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: isSelected ? BoxDecoration(color: colorAcento, shape: BoxShape.circle) : isTodayDate ? BoxDecoration(color: colorAcento.withOpacity(0.15), shape: BoxShape.circle) : null,
                    alignment: Alignment.center,
                    child: Text(
                      dia.toString(),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: isSelected ? Colors.white : isTodayDate ? colorAcento : (currentMonth ? colorTitulo : const Color(0xFFCBD5E1)),
                        fontWeight: (isSelected || isTodayDate) ? FontWeight.bold : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (hasData && !isSelected)
                    Positioned(bottom: 6, child: Container(width: 4, height: 4, decoration: BoxDecoration(color: isTodayDate ? colorAcento : Colors.grey.shade400, shape: BoxShape.circle))),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  @override
  double get maxExtent => 380.0;
  @override
  double get minExtent => 160.0;
  @override
  bool shouldRebuild(covariant _TeamsCalendarHeaderDelegate oldDelegate) {
    return oldDelegate.selectedDay != selectedDay || oldDelegate.today != today || oldDelegate.currentMonthName != currentMonthName;
  }
}
