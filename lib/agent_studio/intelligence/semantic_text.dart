/// Source offsets always refer to the original utterance, including whitespace.
class SemanticSpan {
  const SemanticSpan(this.start, this.end);
  final int start, end;
  String text(String source) => source.substring(start, end);
  bool contains(int offset) => start <= offset && offset < end;
}

enum SemanticObject { goal, task, reminder, mission, scenario }

class SemanticToken extends SemanticSpan {
  const SemanticToken(super.start, super.end, this.value);
  final String value;
}

/// A small lexical layer, shared by title, command and role resolution. Quoted
/// literals are opaque data: punctuation, numbers and verbs inside cannot act.
class SemanticText {
  SemanticText(this.source) {
    var quote = '', quoteStart = -1;
    for (var i = 0; i < source.length; i++) {
      final ch = source[i];
      if (quote.isEmpty) {
        if (ch == '"' ||
            ch == '“' ||
            ch == '‘' ||
            ch == "'" && (i == 0 || !RegExp(r'\w').hasMatch(source[i - 1]))) {
          quote = ch == '“'
              ? '”'
              : ch == '‘'
              ? '’'
              : ch;
          quoteStart = i;
        }
      } else if (ch == quote &&
          (i == 0 || source[i - 1] != '\\') &&
          !(ch == "'" &&
              i > 0 &&
              i + 1 < source.length &&
              RegExp(r'\w').hasMatch(source[i - 1]) &&
              RegExp(r'\w').hasMatch(source[i + 1]))) {
        quotes.add(SemanticSpan(quoteStart, i + 1));
        quote = '';
      }
    }
    unclosedQuote = quote.isNotEmpty;
    tokens.addAll(
      RegExp(r"[\p{L}\p{N}_]+(?:['’\-][\p{L}\p{N}_]+)*|[^\s]", unicode: true)
          .allMatches(source)
          .map(
            (m) => SemanticToken(
              m.start,
              m.end,
              m[0]!.toLowerCase().replaceAll('’', "'"),
            ),
          ),
    );
  }
  final String source;
  final List<SemanticSpan> quotes = [];
  final List<SemanticToken> tokens = [];
  bool unclosedQuote = false;

  bool quoted(int offset) => quotes.any((s) => s.contains(offset));
  SemanticSpan? quoteAt(int offset) =>
      quotes.where((s) => s.contains(offset)).firstOrNull;
  String mask(Iterable<SemanticSpan> spans) {
    final units = source.codeUnits.toList();
    for (final span in spans) {
      for (var i = span.start; i < span.end; i++) {
        units[i] = 32;
      }
    }
    return String.fromCharCodes(units);
  }

  String get withoutQuotes => mask(quotes);

  static SemanticObject? object(String word) =>
      switch (word.replaceFirst(RegExp(r"'s$"), '')) {
        'goal' ||
        'goals' ||
        'fund' ||
        'ipon' ||
        'pag-iipunan' => SemanticObject.goal,
        'task' ||
        'tasks' ||
        'to-do' ||
        'gawain' ||
        'activity' => SemanticObject.task,
        'reminder' ||
        'remind' ||
        'pa-remind' ||
        'i-remind' ||
        'paalala' ||
        'ipaalala' ||
        'alarm' => SemanticObject.reminder,
        'mission' => SemanticObject.mission,
        'scenario' || 'simulation' => SemanticObject.scenario,
        _ => null,
      };

  /// Only starts a new scope at an explicit action/object boundary. Field
  /// declarations stay with their object regardless of clause/field order.
  List<SemanticSpan> get commands {
    final work = withoutQuotes;
    final boundaries = RegExp(
      r'(?:[,;.!]\s*|\s+(?:and|then|tapos|with)\s+)(?=(?:(?:a|an|the|my|new|savings)\s+)*(?:create\b|make\b|build\b|add\b|remind\b|reminder\b|paalala\b|goal\b|task\b|mission\b|scenario\b|gawa\b))',
      caseSensitive: false,
    );
    final parts = <SemanticSpan>[];
    var start = 0;
    for (final m in boundaries.allMatches(work)) {
      // A leading polite/filler comma does not establish an object scope.
      if (!tokens.any(
        (t) =>
            t.start >= start &&
            t.end <= m.start &&
            !quoted(t.start) &&
            object(t.value) != null,
      )) {
        continue;
      }
      parts.add(SemanticSpan(start, m.start));
      start = m.end;
    }
    parts.add(SemanticSpan(start, source.length));
    return parts;
  }

  static String commandText(String text) => text.trim().replaceFirst(
    RegExp(
      r'^(?:(?:please|pls|plz|uhm|um|ah|pakiusap|pakisuyo)[,\s]+)+',
      caseSensitive: false,
    ),
    '',
  );
}
