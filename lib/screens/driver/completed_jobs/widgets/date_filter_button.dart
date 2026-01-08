// 📁 lib/screens/driver/completed_jobs/widgets/date_filter_button.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DateFilterButton extends StatelessWidget {
  final DateTimeRange? dateRange;
  final VoidCallback onPressed;
  final VoidCallback onClear;

  const DateFilterButton({
    super.key,
    this.dateRange,
    required this.onPressed,
    required this.onClear,
  });

  static const Color primary = Color(0xFF1E3A5F);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        OutlinedButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.date_range),
          label: Text(
            dateRange == null
                ? "Tarih Filtrele"
                : "${DateFormat('dd MMM yyyy', 'tr_TR').format(dateRange!.start)} - "
                    "${DateFormat('dd MMM yyyy', 'tr_TR').format(dateRange!.end)}",
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: primary,
            side: const BorderSide(color: primary),
          ),
        ),
        if (dateRange != null)
          IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.close),
          ),
      ],
    );
  }
}


