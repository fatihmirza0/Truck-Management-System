import 'package:flutter/material.dart';

class CompletedJobsFilters extends StatelessWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final String? selectedDriverName;
  final bool exportingPdf;
  final bool exportingExcel;
  final VoidCallback onPickDateRange;
  final VoidCallback onClearDate;
  final VoidCallback onOpenDriverSelector;
  final VoidCallback onClearDriver;
  final VoidCallback onRunPdfExport;
  final VoidCallback onRunExcelExport;

  static const Color accent = Color(0xFF1E3A5F);
  static const Color border = Color(0xFFE2E8F0);
  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);

  const CompletedJobsFilters({
    super.key,
    this.startDate,
    this.endDate,
    this.selectedDriverName,
    required this.exportingPdf,
    required this.exportingExcel,
    required this.onPickDateRange,
    required this.onClearDate,
    required this.onOpenDriverSelector,
    required this.onClearDriver,
    required this.onRunPdfExport,
    required this.onRunExcelExport,
  });

  String _formatDateShort(DateTime d) {
    return "${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          // LEFT SIDE - FILTERS
          _pill(
            icon: Icons.date_range,
            text: startDate == null
                ? "Tarih"
                : "${_formatDateShort(startDate!)} → ${_formatDateShort(endDate ?? startDate!)}",
            onTap: onPickDateRange,
            onClear: startDate == null ? null : onClearDate,
          ),
          const SizedBox(width: 8),
          _pill(
            icon: Icons.person_outline,
            text: selectedDriverName ?? "Şoför",
            onTap: onOpenDriverSelector,
            onClear: selectedDriverName == null ? null : onClearDriver,
          ),

          const Spacer(),

          // RIGHT SIDE - EXPORT BUTTONS
          _pill(
            icon: Icons.picture_as_pdf,
            text: exportingPdf ? "..." : "PDF",
            onTap: onRunPdfExport,
            loading: exportingPdf,
            primary: true,
          ),
          const SizedBox(width: 8),
          _pill(
            icon: Icons.table_chart,
            text: exportingExcel ? "..." : "Excel",
            onTap: onRunExcelExport,
            loading: exportingExcel,
          ),
        ],
      ),
    );
  }

  Widget _pill({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    VoidCallback? onClear,
    bool loading = false,
    bool primary = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: primary ? accent : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: primary ? accent : border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading) ...[
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
                const SizedBox(width: 6),
              ] else ...[
                Icon(
                  icon,
                  size: 16,
                  color: primary ? Colors.white : textMuted,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                text,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: primary ? Colors.white : textDark,
                ),
              ),
              if (onClear != null && !loading) ...[
                const SizedBox(width: 6),
                InkWell(
                  onTap: onClear,
                  borderRadius: BorderRadius.circular(6),
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: primary ? Colors.white.withValues(alpha: 0.9) : textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
