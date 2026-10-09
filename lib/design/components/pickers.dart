import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

bool _isCupertino(BuildContext context) {
  final p = Theme.of(context).platform;
  return p == TargetPlatform.iOS || p == TargetPlatform.macOS;
}

/// The platform's date picker: a wheel in a sheet on iOS, the Material calendar on Android
/// (UNIFIED_PRODUCT_SPEC §1, principle 6).
Future<DateTime?> pickDate(
  BuildContext context, {
  required DateTime initial,
  required DateTime first,
  required DateTime last,
  String title = 'Choose a date',
}) async {
  if (!_isCupertino(context)) {
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      helpText: title,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
  }
  var value = initial;
  return showModalBottomSheet<DateTime>(
    context: context,
    showDragHandle: false,
    builder: (context) => _CupertinoSheet(
      title: title,
      onDone: () => Navigator.of(context).pop(value),
      child: CupertinoDatePicker(
        mode: CupertinoDatePickerMode.date,
        initialDateTime: initial,
        minimumDate: first,
        maximumDate: last,
        dateOrder: DatePickerDateOrder.dmy,
        onDateTimeChanged: (d) => value = d,
      ),
    ),
  );
}

/// The platform's time picker (S-52): wheel on iOS, Material dial on Android.
Future<TimeOfDay?> pickTime(
  BuildContext context, {
  required TimeOfDay initial,
  String title = 'Choose a time',
}) async {
  if (!_isCupertino(context)) {
    return showTimePicker(context: context, initialTime: initial, helpText: title);
  }
  var value = initial;
  return showModalBottomSheet<TimeOfDay>(
    context: context,
    showDragHandle: false,
    builder: (context) => _CupertinoSheet(
      title: title,
      onDone: () => Navigator.of(context).pop(value),
      child: CupertinoDatePicker(
        mode: CupertinoDatePickerMode.time,
        initialDateTime: DateTime(2000, 1, 1, initial.hour, initial.minute),
        use24hFormat: MediaQuery.alwaysUse24HourFormatOf(context),
        onDateTimeChanged: (d) => value = TimeOfDay(hour: d.hour, minute: d.minute),
      ),
    ),
  );
}

class _CupertinoSheet extends StatelessWidget {
  const _CupertinoSheet({required this.title, required this.onDone, required this.child});

  final String title;
  final VoidCallback onDone;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.s, vertical: Space.xs),
            child: Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                Expanded(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TypeScale.titleSmall.copyWith(color: c.textPrimary),
                  ),
                ),
                TextButton(onPressed: onDone, child: const Text('Done')),
              ],
            ),
          ),
          SizedBox(height: 216, child: child),
        ],
      ),
    );
  }
}
