import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

Future<DateTime?> showCustomDatePicker(
  BuildContext context, {
  DateTime? initialDate,
  required Color colorActivo,
  required Color colorTexto,
}) {
  return showDialog<DateTime>(
    context: context,
    builder: (ctx) => _CustomDatePickerModal(
      initialDate: initialDate,
      colorActivo: colorActivo,
      colorTexto: colorTexto,
    ),
  );
}

class _CustomDatePickerModal extends StatefulWidget {
  final DateTime? initialDate;
  final Color colorActivo;
  final Color colorTexto;

  const _CustomDatePickerModal({
    this.initialDate,
    required this.colorActivo,
    required this.colorTexto,
  });

  @override
  State<_CustomDatePickerModal> createState() => _CustomDatePickerModalState();
}

class _CustomDatePickerModalState extends State<_CustomDatePickerModal> {
  late TextEditingController _dayCtrl;
  late TextEditingController _monthCtrl;
  late TextEditingController _yearCtrl;

  final FocusNode _dayNode = FocusNode();
  final FocusNode _monthNode = FocusNode();
  final FocusNode _yearNode = FocusNode();

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _dayCtrl = TextEditingController(
        text: widget.initialDate != null
            ? widget.initialDate!.day.toString().padLeft(2, '0')
            : '');
    _monthCtrl = TextEditingController(
        text: widget.initialDate != null
            ? widget.initialDate!.month.toString().padLeft(2, '0')
            : '');
    _yearCtrl = TextEditingController(
        text: widget.initialDate != null
            ? widget.initialDate!.year.toString()
            : '');
  }

  @override
  void dispose() {
    _dayCtrl.dispose();
    _monthCtrl.dispose();
    _yearCtrl.dispose();
    _dayNode.dispose();
    _monthNode.dispose();
    _yearNode.dispose();
    super.dispose();
  }

  void _validateAndSubmit() {
    setState(() => _errorMessage = null);

    final dStr = _dayCtrl.text.trim();
    final mStr = _monthCtrl.text.trim();
    final yStr = _yearCtrl.text.trim();

    if (dStr.isEmpty || mStr.isEmpty || yStr.isEmpty) {
      setState(() => _errorMessage = "Por favor, complete todos los campos.");
      return;
    }

    final d = int.tryParse(dStr);
    final m = int.tryParse(mStr);
    final y = int.tryParse(yStr);

    if (d == null || m == null || y == null) {
      setState(() => _errorMessage = "Ingrese valores numéricos válidos.");
      return;
    }

    if (m < 1 || m > 12) {
      setState(() => _errorMessage = "Mes inválido (1-12).");
      return;
    }

    final maxDays = _getDaysInMonth(y, m);
    if (d < 1 || d > maxDays) {
      setState(() => _errorMessage = "Día inválido para este mes.");
      return;
    }

    final date = DateTime(y, m, d);
    final today = DateTime.now();
    
    int age = today.year - date.year;
    if (today.month < date.month ||
        (today.month == date.month && today.day < date.day)) {
      age--;
    }

    if (age < 3 || age > 17) {
      setState(() => _errorMessage =
          "La edad debe estar entre 3 y 17 años (actual: $age).");
      return;
    }

    Navigator.of(context).pop(date);
  }

  int _getDaysInMonth(int year, int month) {
    if (month == 2) {
      final isLeapYear = (year % 4 == 0) && (year % 100 != 0 || year % 400 == 0);
      return isLeapYear ? 29 : 28;
    }
    const days = [31, -1, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    return days[month - 1];
  }

  Widget _buildField(String label, String hint, TextEditingController ctrl,
      FocusNode node, FocusNode? nextNode, int maxLength) {
    return Expanded(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8),
            child: TextField(
              controller: ctrl,
              focusNode: node,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(maxLength),
              ],
              onChanged: (val) {
                if (val.length == maxLength && nextNode != null) {
                  FocusScope.of(context).requestFocus(nextNode);
                }
              },
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: widget.colorTexto),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: GoogleFonts.inter(color: Colors.grey.shade400),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: widget.colorActivo, width: 2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: widget.colorActivo, width: 3),
                ),
              ),
            ),
          ),
          Positioned(
            left: 12,
            top: 0,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: widget.colorActivo,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Ingresar fecha",
                  style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: widget.colorTexto),
                ),
                Icon(Icons.calendar_month_outlined, color: widget.colorTexto, size: 20),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: Colors.grey.shade200, height: 1),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildField("Día", "dd", _dayCtrl, _dayNode, _monthNode, 2),
                const SizedBox(width: 10),
                _buildField("Mes", "mm", _monthCtrl, _monthNode, _yearNode, 2),
                const SizedBox(width: 10),
                _buildField("Año", "yyyy", _yearCtrl, _yearNode, null, 4),
              ],
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 16, color: Colors.red.shade700),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.red.shade700),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    "Cancelar",
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: widget.colorActivo),
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: _validateAndSubmit,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    "Aceptar",
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: widget.colorActivo),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
