class DateExpression {
  const DateExpression({
    this.date,
    this.time = '',
    this.weekday,
    this.frequency = '',
    this.ambiguousDate = false,
    this.ambiguousTime = false,
    this.unsupportedRecurrence = false,
  });
  final DateTime? date;
  final String time, frequency;
  final int? weekday;
  final bool ambiguousDate, ambiguousTime, unsupportedRecurrence;
}

/// Calendar arithmetic uses the supplied application clock, never a model clock.
class DateExpressionParser {
  const DateExpressionParser();
  static const days = [
    ['monday', 'lunes'],
    ['tuesday', 'martes'],
    ['wednesday', 'miyerkules'],
    ['thursday', 'huwebes'],
    ['friday', 'biyernes'],
    ['saturday', 'sabado'],
    ['sunday', 'linggo'],
  ];
  static const months = [
    ['january', 'enero'],
    ['february', 'pebrero'],
    ['march', 'marso'],
    ['april', 'abril'],
    ['may', 'mayo'],
    ['june', 'hunyo'],
    ['july', 'hulyo'],
    ['august', 'agosto'],
    ['september', 'setyembre'],
    ['october', 'oktubre'],
    ['november', 'nobyembre'],
    ['december', 'disyembre'],
  ];
  DateExpression parse(String text, DateTime now) {
    final lower = text.toLowerCase();
    final today = DateTime(now.year, now.month, now.day);
    var badDate = false, badTime = false;
    final dates = <DateTime>[];
    void add(int y, int m, int d) {
      final date = DateTime(y, m, d);
      if (date.year != y ||
          date.month != m ||
          date.day != d ||
          date.isBefore(today)) {
        badDate = true;
      } else {
        dates.add(date);
      }
    }

    for (final iso in RegExp(
      r'\b(\d{4})-(\d{2})-(\d{2})\b',
    ).allMatches(lower)) {
      add(int.parse(iso[1]!), int.parse(iso[2]!), int.parse(iso[3]!));
    }
    final monthPattern = months.expand((m) => m).join('|');
    for (final m in RegExp(
      '\\b($monthPattern)\\s+(\\d{1,2})(?:,?\\s+(\\d{4}))?\\b',
    ).allMatches(lower)) {
      if (m[3] == null) {
        badDate = true;
        continue;
      }
      add(
        int.parse(m[3]!),
        months.indexWhere((v) => v.contains(m[1])) + 1,
        int.parse(m[2]!),
      );
    }
    for (final m in RegExp(
      '\\b(\\d{1,2})\\s+(?:ng\\s+)?($monthPattern)\\s+(\\d{4})\\b',
    ).allMatches(lower)) {
      add(
        int.parse(m[3]!),
        months.indexWhere((v) => v.contains(m[2])) + 1,
        int.parse(m[1]!),
      );
    }
    if (RegExp(r'\b(day after tomorrow|makalawa)\b').hasMatch(lower)) {
      dates.add(DateTime(now.year, now.month, now.day + 2));
    } else if (RegExp(r'\b(tomorrow|bukas)\b').hasMatch(lower)) {
      dates.add(DateTime(now.year, now.month, now.day + 1));
    }
    if (RegExp(r'\b(today|ngayon|mamaya)\b').hasMatch(lower)) dates.add(today);
    final weekdays = <int>[];
    for (var i = 0; i < days.length; i++) {
      if (days[i].any((d) => RegExp('\\b$d\\b').hasMatch(lower))) {
        weekdays.add(i + 1);
      }
    }
    final weekday = weekdays.length == 1 ? weekdays.single : null;
    final recurring = RegExp(
      r'\b(every|tuwing|weekly|lingguhan|daily|araw-araw|bawat)\b',
    ).hasMatch(lower);
    var frequency = recurring
        ? (RegExp(r'\b(daily|araw-araw|bawat araw)\b').hasMatch(lower)
              ? 'daily'
              : 'weekly')
        : '';
    if (weekday != null && !recurring) {
      // "Next Friday" has differing conventions; require the calendar date.
      if (RegExp(r'\b(next|susunod|darating)\b').hasMatch(lower)) {
        badDate = true;
      } else {
        final delta = (weekday - today.weekday + 7) % 7;
        if (delta == 0) {
          badDate = true;
        } else {
          dates.add(DateTime(now.year, now.month, now.day + delta));
        }
      }
    }
    if (weekdays.length > 1 ||
        RegExp(r'\b\d{1,2}/\d{1,2}(?:/\d{2,4})?\b').hasMatch(lower)) {
      badDate = true;
    }
    if (RegExp('\\b(?:by|before|bago|sa)\\s+(?:$monthPattern)\\b(?!\\s+\\d)')
        .hasMatch(lower)) {
      badDate = true;
    }
    final unsupported = RegExp(r'\b(monthly|buwanan|payday|sweldo|sahod)\b')
        .hasMatch(lower);
    if (unsupported) frequency = '';
    final times = <String>[];
    for (final m in RegExp(
      r'\b(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b',
    ).allMatches(lower)) {
      final h = int.parse(m[1]!), minute = int.parse(m[2] ?? '0');
      if (h < 1 || h > 12 || minute > 59) {
        badTime = true;
        continue;
      }
      times.add(
        '${(h % 12 + (m[3] == 'pm' ? 12 : 0)).toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
      );
    }
    if (times.isEmpty) {
      for (final m in RegExp(r'\b(\d{1,2}):(\d{2})\b').allMatches(lower)) {
        final h = int.parse(m[1]!), minute = int.parse(m[2]!);
        if (h > 23 || minute > 59) {
          badTime = true;
          continue;
        }
        // A 12-hour clock without AM/PM is intentionally unresolved.
        if (h >= 1 && h <= 12) {
          badTime = true;
          continue;
        }
        times.add('${h.toString().padLeft(2, '0')}:${m[2]}');
      }
    }
    const spokenHours = {
      'una': 1,
      'dos': 2,
      'tres': 3,
      'kwatro': 4,
      'kuwatro': 4,
      'singko': 5,
      'cinco': 5,
      'sais': 6,
      'seis': 6,
      'siyete': 7,
      'siete': 7,
      'otso': 8,
      'nuebe': 9,
      'diyes': 10,
      'onse': 11,
      'dose': 12,
      'one': 1,
      'two': 2,
      'three': 3,
      'four': 4,
      'five': 5,
      'six': 6,
      'seven': 7,
      'eight': 8,
      'nine': 9,
      'ten': 10,
      'eleven': 11,
      'twelve': 12,
    };
    final spoken = RegExp(
      '\\b(?:alas\\s+)?(${spokenHours.keys.join('|')}|\\d{1,2})(?:\\s+(?:ng|in the))?\\s*(umaga|hapon|gabi|morning|afternoon|evening)\\b',
    ).firstMatch(lower);
    if (spoken != null) {
      final h = spokenHours[spoken[1]] ?? int.tryParse(spoken[1]!) ?? 0;
      if (h < 1 || h > 12) {
        badTime = true;
      } else {
        times.add(
          '${(h % 12 + (['umaga', 'morning'].contains(spoken[2]) ? 0 : 12)).toString().padLeft(2, '0')}:00',
        );
      }
    } else if (RegExp(
      r'\balas\s+\w+\b|\b(after lunch|before bed|mamayang gabi)\b',
    ).hasMatch(lower)) {
      badTime = true;
    }
    if (times.toSet().length > 1) badTime = true;
    if (dates.toSet().length > 1) badDate = true;
    return DateExpression(
      date: badDate ? null : dates.firstOrNull,
      time: badTime ? '' : times.firstOrNull ?? '',
      weekday: weekday,
      frequency: frequency,
      ambiguousDate: badDate,
      ambiguousTime: badTime,
      unsupportedRecurrence: unsupported,
    );
  }
}
