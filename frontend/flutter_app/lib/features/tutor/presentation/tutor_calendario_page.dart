import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/state/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import 'tutor_receta_detalle_page.dart';

class TutorCalendarioPage extends ConsumerStatefulWidget {
  const TutorCalendarioPage({super.key});

  @override
  ConsumerState<TutorCalendarioPage> createState() =>
      _TutorCalendarioPageState();
}

class _TutorCalendarioPageState extends ConsumerState<TutorCalendarioPage> {
  late DateTime _selectedDate;
  late DateTime _displayedMonth; // Para el título del header
  final DateTime _today = DateTime.now();

  final ScrollController _scrollController = ScrollController();
  late PageController _monthPageController;
  late PageController _weekPageController;

  // Base para scroll infinito (índice central)
  final int _baseIndex = 1200;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime(_today.year, _today.month, _today.day);
    _displayedMonth = _selectedDate;

    _monthPageController = PageController(initialPage: _baseIndex);
    _weekPageController = PageController(initialPage: _baseIndex);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _monthPageController.dispose();
    _weekPageController.dispose();
    super.dispose();
  }

  void _onDateTapped(DateTime date) {
    setState(() {
      _selectedDate = date;
      _displayedMonth = date;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final idPaciente = ref.watch(selectedPatientIdProvider);
    final planAsync = idPaciente != null
        ? ref.watch(
            planDiarioProvider((idPaciente: idPaciente, fecha: _selectedDate)))
        : const AsyncValue<List<Map<String, dynamic>>>.data([]);

    final diasConPlanAsync = idPaciente != null
        ? ref.watch(diasConPlanProvider((
            idPaciente: idPaciente,
            mes: _displayedMonth.month,
            anio: _displayedMonth.year
          )))
        : const AsyncValue<List<Map<String, dynamic>>>.data([]);

    final List<Map<String, dynamic>> diasConPlan = diasConPlanAsync.maybeWhen(
      data: (dias) => dias,
      orElse: () => [],
    );

    return Container(
      color: colorScheme.surface,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollEndNotification) {
            final double offset = _scrollController.offset;
            if (offset > 0 && offset < 220) {
              final double target = offset < 110 ? 0.0 : 220.0;
              Future.microtask(() => _scrollController.animateTo(target,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.fastOutSlowIn));
            }
          }
          return false;
        },
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: _ExpandableCalendarHeaderDelegate(
                colorAcento: colorScheme.primary,
                colorTitulo: colorScheme.onSurface,
                selectedDay: _selectedDate,
                today: _today,
                displayedMonth: _displayedMonth,
                monthPageController: _monthPageController,
                weekPageController: _weekPageController,
                baseIndex: _baseIndex,
                diasConPlan: diasConPlan,
                onDaySelected: _onDateTapped,
                onMonthPageChanged: (date) =>
                    setState(() => _displayedMonth = date),
                onToggleExpand: () {
                  final target = _scrollController.offset > 110 ? 0.0 : 220.0;
                  _scrollController.animateTo(target,
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.fastOutSlowIn);
                },
                onDragUpdate: (details) {
                  final newOffset =
                      (_scrollController.offset - details.delta.dy)
                          .clamp(0.0, 1000.0);
                  _scrollController.jumpTo(newOffset);
                },
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

                final Map<int, List<Map<String, dynamic>>> grouped = {};
                final List<int> momentOrder = [];
                for (var m in meals) {
                  final idMom = m["id_momento"] as int;
                  if (!grouped.containsKey(idMom)) {
                    grouped[idMom] = [];
                    momentOrder.add(idMom);
                  }
                  grouped[idMom]!.add(m);
                }

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final momId = momentOrder[index];
                        final momentMeals = grouped[momId]!;
                        final momentName =
                            momentMeals.first["momento_nombre"] ?? "Comida";

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.only(top: 16, bottom: 12),
                              child: Text(
                                momentName.toString().toUpperCase(),
                                style: theme.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade600,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ),
                            ...momentMeals.map((m) {
                              final bool isConsumida = m["consumida"] == true;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _CompactRecipeCard(
                                    meal: m, isConsumida: isConsumida),
                              );
                            }),
                          ],
                        );
                      },
                      childCount: momentOrder.length,
                    ),
                  ),
                );
              },
              loading: () => const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator())),
              error: (err, stack) => SliverFillRemaining(
                  child: Center(child: Text("Error: $err"))),
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
          Icon(Icons.no_food_outlined,
              size: 64, color: Colors.grey.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            "Sin plan para este día",
            style: GoogleFonts.montserrat(
                color: Colors.grey, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text("Selecciona otra fecha",
              style: TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      ),
    );
  }
}

class _ExpandableCalendarHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Color colorAcento;
  final Color colorTitulo;
  final DateTime selectedDay;
  final DateTime today;
  final DateTime displayedMonth;
  final PageController monthPageController;
  final PageController weekPageController;
  final int baseIndex;
  final List<Map<String, dynamic>> diasConPlan;
  final Function(DateTime) onDaySelected;
  final Function(DateTime) onMonthPageChanged;
  final Function(DragUpdateDetails) onDragUpdate;
  final VoidCallback onToggleExpand;

  static const List<Color> _planColors = [
    Color(0xFF3B82F6), // blue
    Color(0xFF10B981), // emerald
    Color(0xFFF59E0B), // amber
    Color(0xFF8B5CF6), // violet
    Color(0xFFEC4899), // pink
    Color(0xFFF43F5E), // rose
    Color(0xFF14B8A6), // teal
  ];

  Color _getColorForPlan(int idPlan) {
    return _planColors[idPlan % _planColors.length];
  }

  _ExpandableCalendarHeaderDelegate({
    required this.colorAcento,
    required this.colorTitulo,
    required this.selectedDay,
    required this.today,
    required this.displayedMonth,
    required this.monthPageController,
    required this.weekPageController,
    required this.baseIndex,
    required this.diasConPlan,
    required this.onDaySelected,
    required this.onMonthPageChanged,
    required this.onDragUpdate,
    required this.onToggleExpand,
  });

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final theme = Theme.of(context);
    final double collapsePercent =
        (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final String currentMonthName =
        DateFormat('MMMM yyyy', 'es').format(displayedMonth);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
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
                  Text(currentMonthName.toUpperCase(),
                      style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                  Icon(Icons.calendar_month_outlined,
                      color: colorAcento, size: 20),
                ],
              ),
            ),
          ),
          _buildDaysHeader(context),
          Expanded(
            child: Stack(
              children: [
                // VISTA MENSUAL (PageView)
                IgnorePointer(
                  ignoring: collapsePercent > 0.5,
                  child: Opacity(
                    opacity: (1 - collapsePercent * 2).clamp(0.0, 1.0),
                    child: PageView.builder(
                      controller: monthPageController,
                      onPageChanged: (index) {
                        final newMonth = DateTime(
                            today.year, today.month + (index - baseIndex), 1);
                        onMonthPageChanged(newMonth);
                      },
                      itemBuilder: (context, index) {
                        final monthDate = DateTime(
                            today.year, today.month + (index - baseIndex), 1);
                        return _buildMonthGrid(context, monthDate);
                      },
                    ),
                  ),
                ),
                // VISTA SEMANAL (PageView)
                Center(
                  child: IgnorePointer(
                    ignoring: collapsePercent < 0.5,
                    child: Opacity(
                      opacity: collapsePercent > 0.4
                          ? ((collapsePercent - 0.4) * 2).clamp(0.0, 1.0)
                          : 0.0,
                      child: SizedBox(
                        height: 48,
                        child: PageView.builder(
                          controller: weekPageController,
                          onPageChanged: (index) {
                            final firstDayOfWeek = today
                                .subtract(Duration(days: today.weekday - 1))
                                .add(Duration(days: (index - baseIndex) * 7));
                            onMonthPageChanged(firstDayOfWeek);
                          },
                          itemBuilder: (context, index) {
                            final firstDayOfWeek = today
                                .subtract(Duration(days: today.weekday - 1))
                                .add(Duration(days: (index - baseIndex) * 7));
                            final weekDates = List.generate(7,
                                (i) => firstDayOfWeek.add(Duration(days: i)));
                            return _buildCalendarRow(context, weekDates,
                                isMonthView: false);
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
              width: double.infinity,
              height: 28,
              color: Colors.transparent,
              alignment: Alignment.center,
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthGrid(BuildContext context, DateTime baseDate) {
    final firstDayOfMonth = DateTime(baseDate.year, baseDate.month, 1);
    final firstMonday =
        firstDayOfMonth.subtract(Duration(days: firstDayOfMonth.weekday - 1));

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (weekIdx) {
          final weekDates = List.generate(
              7,
              (dayIdx) =>
                  firstMonday.add(Duration(days: (weekIdx * 7) + dayIdx)));
          return _buildCalendarRow(context, weekDates,
              currentMonth: baseDate.month);
        }),
      ),
    );
  }

  Widget _buildDaysHeader(BuildContext context) {
    final theme = Theme.of(context);
    final diasSemana = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: diasSemana
          .map((dia) => Expanded(
              child: Center(
                  child: Text(dia,
                      style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF94A3B8))))))
          .toList(),
    );
  }

  Widget _buildCalendarRow(BuildContext context, List<DateTime> dates,
      {int? currentMonth, bool isMonthView = true}) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: dates.map((dateForDay) {
          final bool isSelected = dateForDay.year == selectedDay.year &&
              dateForDay.month == selectedDay.month &&
              dateForDay.day == selectedDay.day;
          final bool isTodayDate = dateForDay.year == today.year &&
              dateForDay.month == today.month &&
              dateForDay.day == today.day;

          final bool isLeadingTrailing =
              currentMonth != null && dateForDay.month != currentMonth;

          final hasPlanMap = diasConPlan.where((d) {
            final DateTime dt = d['fecha'];
            return dt.year == dateForDay.year &&
                dt.month == dateForDay.month &&
                dt.day == dateForDay.day;
          }).toList();

          final bool hasPlan = hasPlanMap.isNotEmpty;
          Color? planColor;
          if (hasPlan) {
            planColor = _getColorForPlan(hasPlanMap.first['id_plan'] as int);
          }

          BoxDecoration? decoration;
          Color textColor = colorTitulo;

          if (isSelected) {
            decoration = BoxDecoration(
                color: planColor ?? colorAcento, shape: BoxShape.circle);
            textColor = Colors.white;
          } else if (hasPlan) {
            decoration = BoxDecoration(
                color: planColor!.withOpacity(0.2), shape: BoxShape.circle);
            textColor = planColor;
          } else if (isTodayDate) {
            decoration = BoxDecoration(
                color: colorAcento.withOpacity(0.15), shape: BoxShape.circle);
            textColor = colorAcento;
          } else if (isLeadingTrailing) {
            textColor = const Color(0xFFCBD5E1);
          }

          return Expanded(
            child: GestureDetector(
              onTap: () => onDaySelected(dateForDay),
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: 44,
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: decoration,
                      alignment: Alignment.center,
                      child: Text(
                        dateForDay.day.toString(),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: textColor,
                          fontWeight: (isSelected || isTodayDate || hasPlan)
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  double get maxExtent => 340.0;
  @override
  double get minExtent => 160.0;
  @override
  bool shouldRebuild(covariant _ExpandableCalendarHeaderDelegate oldDelegate) {
    return oldDelegate.selectedDay != selectedDay ||
        oldDelegate.today != today ||
        oldDelegate.displayedMonth != displayedMonth ||
        oldDelegate.diasConPlan != diasConPlan;
  }
}

class _CompactRecipeCard extends StatelessWidget {
  final Map<String, dynamic> meal;
  final bool isConsumida;
  const _CompactRecipeCard({required this.meal, this.isConsumida = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String url = meal["receta_url_imagen"] ?? "";
    final String nombre = meal["receta_nombre"] ?? "Sin nombre";
    final String? desc = meal["receta_descripcion"];

    return Card(
      elevation: 0,
      color: isConsumida ? Colors.grey.shade50 : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isConsumida
            ? BorderSide(color: AppTema.verdeSalud.withOpacity(0.5), width: 1.5)
            : BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        onTap: () {
          final idReceta = meal["id_receta"];
          if (idReceta != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    TutorRecetaDetallePage(idReceta: idReceta as int),
              ),
            );
          }
        },
        contentPadding: const EdgeInsets.all(12),
        leading: Stack(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: url.isNotEmpty
                  ? Image.network(url,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) =>
                          const Icon(Icons.fastfood, color: Colors.grey))
                  : const Icon(Icons.fastfood, color: Colors.grey),
            ),
            if (isConsumida)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                      color: AppTema.verdeSalud, shape: BoxShape.circle),
                  child: const Icon(Icons.check, size: 12, color: Colors.white),
                ),
              ),
          ],
        ),
        title: Text(
          nombre,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: isConsumida ? Colors.grey : null,
            decoration: isConsumida ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: isConsumida
            ? const Text("Consumida",
                style: TextStyle(
                    color: AppTema.verdeSalud,
                    fontWeight: FontWeight.bold,
                    fontSize: 12))
            : (desc != null
                ? Text(desc,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12))
                : null),
        trailing:
            const Icon(Icons.chevron_right, size: 20, color: Color(0xFFCBD5E1)),
      ),
    );
  }
}
