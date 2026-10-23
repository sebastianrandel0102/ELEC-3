part of 'design_system.dart';

/// Keep the existing date bounds and result contract on both platforms. The
/// wheel edits a local draft; only Done returns a value to the owning form.
Future<DateTime?> showSaveTrackDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String? helpText,
}) {
  if (Theme.of(context).platform != TargetPlatform.iOS) {
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: helpText,
    );
  }
  DateTime day(DateTime value) => DateTime(value.year, value.month, value.day);
  var selected = day(initialDate);
  return _showWheelPicker<DateTime>(
    context: context,
    title: helpText ?? 'Choose date',
    result: () => selected,
    picker: CupertinoDatePicker(
      mode: CupertinoDatePickerMode.date,
      initialDateTime: selected,
      minimumDate: day(firstDate),
      maximumDate: day(lastDate),
      onDateTimeChanged: (value) => selected = day(value),
    ),
  );
}

Future<TimeOfDay?> showSaveTrackTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
  String? helpText,
  String? confirmText,
  TimePickerEntryMode initialEntryMode = TimePickerEntryMode.dial,
  TransitionBuilder? builder,
}) {
  if (Theme.of(context).platform != TargetPlatform.iOS) {
    return showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: helpText,
      confirmText: confirmText,
      initialEntryMode: initialEntryMode,
      builder: builder,
    );
  }
  var selected = initialTime;
  return _showWheelPicker<TimeOfDay>(
    context: context,
    title: helpText ?? 'Choose time',
    confirmText: confirmText ?? 'Done',
    result: () => selected,
    picker: CupertinoDatePicker(
      mode: CupertinoDatePickerMode.time,
      use24hFormat: MediaQuery.alwaysUse24HourFormatOf(context),
      initialDateTime: DateTime(
        2026,
        1,
        1,
        initialTime.hour,
        initialTime.minute,
      ),
      onDateTimeChanged: (value) => selected = TimeOfDay.fromDateTime(value),
    ),
  );
}

Future<T?> _showWheelPicker<T>({
  required BuildContext context,
  required String title,
  required T Function() result,
  required Widget picker,
  String confirmText = 'Done',
}) => showModalBottomSheet<T>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  constraints: const BoxConstraints(maxWidth: 600),
  builder: (sheet) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(sheet),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(sheet, result()),
                  child: Text(confirmText),
                ),
              ],
            ),
            Semantics(
              header: true,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(sheet).textTheme.titleMedium,
              ),
            ),
            SizedBox(
              height: 216,
              child: CupertinoTheme(
                data: CupertinoThemeData(
                  brightness: Theme.of(sheet).brightness,
                  primaryColor: sheet.atelierAccent,
                ),
                child: picker,
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);
