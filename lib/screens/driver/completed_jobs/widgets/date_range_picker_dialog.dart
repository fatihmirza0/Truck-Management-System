// 📁 lib/screens/driver/completed_jobs/widgets/date_range_picker_dialog.dart
import 'package:flutter/material.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';

class DateRangePickerDialog {
  static Future<DateTimeRange?> show(
    BuildContext context,
    DateTimeRange? currentRange,
  ) async {
    List<DateTime?> tempValues = currentRange == null
        ? []
        : [currentRange.start, currentRange.end];

    final result = await showModalBottomSheet<DateTimeRange?>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Tarih Aralığı Seç",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 300,
                    child: CalendarDatePicker2(
                      config: CalendarDatePicker2Config(
                        calendarType: CalendarDatePicker2Type.range,
                        selectedDayHighlightColor: const Color(0xFF1E3A5F),
                        selectedRangeHighlightColor:
                            const Color(0xFF1E3A5F).withValues(alpha: 0.25),
                        dayTextStyle: const TextStyle(color: Color(0xFF0F172A)),
                        weekdayLabelTextStyle:
                            const TextStyle(fontWeight: FontWeight.w600),
                        controlsTextStyle:
                            const TextStyle(fontWeight: FontWeight.w600),
                        firstDayOfWeek: 1,
                      ),
                      value: tempValues,
                      onValueChanged: (values) {
                        setModalState(() => tempValues = values);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text("İptal"),
                        ),
                      ),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E3A5F),
                          ),
                          onPressed: () {
                            if (tempValues.length == 2 &&
                                tempValues[0] != null &&
                                tempValues[1] != null) {
                              Navigator.pop(
                                ctx,
                                DateTimeRange(
                                  start: tempValues[0]!,
                                  end: tempValues[1]!,
                                ),
                              );
                            } else {
                              Navigator.pop(ctx);
                            }
                          },
                          child: const Text(
                            "Uygula",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    return result;
  }
}



