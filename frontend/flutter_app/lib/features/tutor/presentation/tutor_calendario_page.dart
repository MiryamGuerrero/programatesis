import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/state/app_providers.dart';
import '../../../core/theme/app_theme.dart';

// ESTADOS LÓGICOS DE UNA COMIDA
enum EstadoComida { pasado, enCurso, pendiente }

class TutorCalendarioPage extends ConsumerStatefulWidget {
  const TutorCalendarioPage({super.key});

  @override
  ConsumerState<TutorCalendarioPage> createState() => _TutorCalendarioPageState();
}

class _TutorCalendarioPageState extends ConsumerState<TutorCalendarioPage> {
  bool _isLoadingState = true;
  late DateTime _selectedDate;
  // Alineado con el contexto de sesión: viernes, 22 de mayo de 2026
  final DateTime _today = DateTime(2026, 5, 22); 
  late int _currentMonthIndex; 
  
  final ScrollController _scrollController = ScrollController();
  late PageController _weekPageController;
  late PageController _monthPageController;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime(_today.year, _today.month, _today.day);
    _currentMonthIndex = _today.month - 4; 
    
    final int initialWeekPage = _getWeekPageIndex(_today);
    _weekPageController = PageController(initialPage: initialWeekPage);
    _monthPageController = PageController(initialPage: _currentMonthIndex);

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _isLoadingState = false);
    });
  }

  int _getWeekPageIndex(DateTime date) {
    final firstDayOfMonth = DateTime(date.year, date.month, 1);
    final diff = date.difference(firstDayOfMonth).inDays;
    return ((diff + firstDayOfMonth.weekday - 1) / 7).floor();
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
    _syncHorizontalCalendar(date.day);
  }

  void _syncHorizontalCalendar(int day) {
    if (!mounted || !_weekPageController.hasClients) return;
    int targetPage = (day <= 3) ? 0 : (day <= 10) ? 1 : (day <= 17) ? 2 : (day <= 24) ? 3 : 4;
    if (_weekPageController.page?.round() != targetPage) {
      _weekPageController.animateToPage(targetPage, duration: const Duration(milliseconds: 300), curve: Curves.fastOutSlowIn);
    }
  }

  EstadoComida _evaluarEstado(Map<String, dynamic> meal) {
    // Por ahora simplificado
    return EstadoComida.pendiente;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final idPaciente = ref.watch(selectedPatientIdProvider);
    final planAsync = idPaciente != null 
        ? ref.watch(planDiarioProvider((idPaciente: idPaciente, fecha: _selectedDate)))
        : const AsyncValue<List<Map<String, dynamic>>>.data([]);

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
                hasDataPredicate: (date) => true,
              ),
            ),

            planAsync.when(
              data: (meals) {
                if (meals.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(context),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.only(top: 20, bottom: 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final meal = meals[index];
                        final estado = _evaluarEstado(meal);
                        return _buildMealItem(context, meal, estado);
                      },
                      childCount: meals.length,
                    ),
                  ),
                );
              },
              loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
              error: (err, stack) => SliverFillRemaining(child: Center(child: Text("Error: $err"))),
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

  Widget _buildMealItem(BuildContext context, Map<String, dynamic> meal, EstadoComida estado) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final String titulo = meal["receta_nombre"] ?? "Comida";
    final String momento = meal["momento_nombre"] ?? "Momento";

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: InkWell(
        onTap: () {
          print("Navegando a receta ID: ${meal["id_receta"]}");
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Column(
                children: [
                  Text(
                    momento,
                    style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.upcoming_outlined, size: 14, color: colorScheme.primary),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              const SizedBox(height: 40, child: VerticalDivider(width: 1)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const Text("Programada", style: TextStyle(fontSize: 12, color: Colors.grey)),
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
                IgnorePointer(
                  ignoring: collapsePercent > 0.5,
                  child: Opacity(
                    opacity: (1 - collapsePercent * 2).clamp(0.0, 1.0),
                    child: PageView.builder(
                      controller: monthPageController,
                      onPageChanged: onMonthChanged,
                      itemCount: 5,
                      itemBuilder: (context, index) => _buildMonthGrid(context, index),
                    ),
                  ),
                ),
                Center(
                  child: IgnorePointer(
                    ignoring: collapsePercent < 0.5,
                    child: Opacity(
                      opacity: collapsePercent > 0.4 ? ((collapsePercent - 0.4) * 2).clamp(0.0, 1.0) : 0.0,
                      child: SizedBox(
                        height: 48,
                        child: PageView.builder(
                          controller: weekPageController,
                          onPageChanged: (index) {
                            final firstDayOfWeek = _getDatesForWeek(2026, today.month, index)[0];
                            if (firstDayOfWeek.month != today.month) {
                              onMonthChanged(firstDayOfWeek.month - 4);
                            }
                          },
                          itemCount: 5,
                          itemBuilder: (context, index) {
                            return _buildCalendarRow(context, _getDatesForWeek(2026, 5, index));
                          },
                        ),
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
              width: double.infinity, height: 28,
              color: Colors.transparent,
              alignment: Alignment.center,
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthGrid(BuildContext context, int monthIndex) {
    final int month = 4 + monthIndex; 
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        children: [
          _buildCalendarRow(context, _getDatesForWeek(2026, month, 0)),
          _buildCalendarRow(context, _getDatesForWeek(2026, month, 1)),
          _buildCalendarRow(context, _getDatesForWeek(2026, month, 2)),
          _buildCalendarRow(context, _getDatesForWeek(2026, month, 3)),
          _buildCalendarRow(context, _getDatesForWeek(2026, month, 4)),
        ],
      ),
    );
  }

  List<DateTime> _getDatesForWeek(int year, int month, int weekIndex) {
    final firstDayOfMonth = DateTime(year, month, 1);
    final firstMonday = firstDayOfMonth.subtract(Duration(days: firstDayOfMonth.weekday - 1));
    return List.generate(7, (i) => firstMonday.add(Duration(days: (weekIndex * 7) + i)));
  }

  Widget _buildDaysHeader(BuildContext context) {
    final theme = Theme.of(context);
    final diasSemana = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: diasSemana.map((dia) => Expanded(child: Center(child: Text(dia, style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8)))))).toList(),
    );
  }

  Widget _buildCalendarRow(BuildContext context, List<DateTime> dates) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(7, (index) {
          final dateForDay = dates[index];
          final bool isSelected = dateForDay.year == selectedDay.year && dateForDay.month == selectedDay.month && dateForDay.day == selectedDay.day;
          final bool isTodayDate = dateForDay.year == today.year && dateForDay.month == today.month && dateForDay.day == today.day;
          final bool isSameMonth = currentMonthName.toLowerCase().contains(_getNombreMes(dateForDay.month).toLowerCase());
          final bool hasData = hasDataPredicate(dateForDay);

          return Expanded(
            child: GestureDetector(
              onTap: () => onDaySelected(dateForDay),
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: 44,
                alignment: Alignment.center,
                color: Colors.transparent, 
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: isSelected ? BoxDecoration(color: colorAcento, shape: BoxShape.circle) : isTodayDate ? BoxDecoration(color: colorAcento.withOpacity(0.15), shape: BoxShape.circle) : null,
                      alignment: Alignment.center,
                      child: Text(
                        dateForDay.day.toString(),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: isSelected ? Colors.white : isTodayDate ? colorAcento : (isSameMonth ? colorTitulo : const Color(0xFFCBD5E1)),
                          fontWeight: (isSelected || isTodayDate) ? FontWeight.bold : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (hasData && !isSelected)
                      Positioned(
                        bottom: 2, 
                        child: Container(width: 4, height: 4, decoration: BoxDecoration(color: isTodayDate ? colorAcento : Colors.grey.shade400, shape: BoxShape.circle))
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  String _getNombreMes(int month) {
    return ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"][month - 1];
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
