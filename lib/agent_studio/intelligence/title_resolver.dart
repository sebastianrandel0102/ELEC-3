import 'semantic_text.dart';

enum SlotOrigin {
  explicitNaming,
  inferredPurpose,
  contextFollowUp,
  userCorrection,
  missing;

  String get identifier => switch (this) {
    explicitNaming => 'explicit_user_title',
    inferredPurpose => 'inferred_from_purpose',
    contextFollowUp => 'context_followup',
    userCorrection => 'user_corrected',
    missing => 'missing',
  };
}

class ResolvedTitle {
  const ResolvedTitle({
    this.value = '',
    this.origin = SlotOrigin.missing,
    this.evidence,
    this.relation = '',
    this.purpose = '',
    this.purposeEvidence,
  });
  final String value, relation, purpose;
  final SlotOrigin origin;
  final SemanticSpan? evidence, purposeEvidence;
  bool get present => value.isNotEmpty;
  bool get requiresConfirmation => origin == SlotOrigin.inferredPurpose;
  ResolvedTitle withOrigin(SlotOrigin value) => ResolvedTitle(
    value: this.value,
    origin: value,
    evidence: evidence,
    relation: relation,
    purpose: purpose,
    purposeEvidence: purposeEvidence,
  );
}

/// Shared naming relations, directional field assignment, literal spans and
/// purpose roles. No domain has a private list of recognizable product names.
class UniversalTitleResolver {
  const UniversalTitleResolver();
  ResolvedTitle resolve(
    SemanticText text,
    SemanticObject domain, {
    bool contextual = false,
    bool pendingTitle = false,
  }) {
    final source = text.source;
    final tokens = text.tokens;
    final nounIndexes = <int>[];
    for (var i = 0; i < tokens.length; i++) {
      if (!text.quoted(tokens[i].start) &&
          SemanticText.object(tokens[i].value) == domain) {
        nounIndexes.add(i);
      }
    }
    if (nounIndexes.isEmpty && domain == SemanticObject.goal) {
      final savings = tokens.indexWhere(
        (t) => t.value == 'savings' && !text.quoted(t.start),
      );
      if (savings >= 0) nounIndexes.add(savings);
    }
    if (nounIndexes.isEmpty && !contextual) return const ResolvedTitle();
    final noun = nounIndexes.firstOrNull;
    ResolvedTitle? explicit;
    // Token relationships carry the naming role; value boundaries are resolved
    // separately, so quoted titles never become commands or amount fields.
    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      if (text.quoted(token.start)) continue;
      final word = token.value;
      final before = tokens
          .take(i)
          .where((t) => !text.quoted(t.start))
          .toList();
      final nearest = before
          .map((t) => SemanticText.object(t.value))
          .whereType<SemanticObject>()
          .lastOrNull;
      if (nearest != null && nearest != domain && i != noun) continue;
      int? valueIndex;
      if (['called', 'named', 'titled'].contains(word)) {
        valueIndex = i + 1;
      } else if ([
        'name',
        'title',
        'call',
        'label',
        'pangalan',
        'pangalanan',
        'tawag',
        'tawagin',
        'ipangalan',
      ].contains(word)) {
        var j = i + 1;
        while (j < tokens.length) {
          final w = tokens[j].value;
          if (['step', 'hakbang'].contains(w) &&
              j + 1 < tokens.length &&
              int.tryParse(tokens[j + 1].value) != null) {
            j += 2;
            continue;
          }
          if (_link.contains(w) ||
              SemanticText.object(w) == domain ||
              ['first', 'second', 'third'].contains(w) &&
                  j + 1 < tokens.length &&
                  SemanticText.object(tokens[j + 1].value) == domain ||
              w == 'the' &&
                  j + 2 < tokens.length &&
                  ['first', 'second', 'third'].contains(tokens[j + 1].value) &&
                  SemanticText.object(tokens[j + 2].value) == domain ||
              ['my', 'the', 'a', 'an'].contains(w) &&
                  j + 1 < tokens.length &&
                  SemanticText.object(tokens[j + 1].value) == domain) {
            j++;
          } else {
            break;
          }
        }
        // "Laptop as title" assigns the value backwards.
        if (j >= tokens.length || _punctuation.contains(tokens[j].value)) {
          continue;
        }
        valueIndex = j;
      } else if (noun != null &&
          i == noun &&
          i + 1 < tokens.length &&
          tokens[i + 1].value == 'na') {
        valueIndex = i + 2;
      }
      if (valueIndex == null || valueIndex >= tokens.length) continue;
      final start = tokens[valueIndex].start;
      // Ignore words such as "Called" embedded in an already resolved title.
      if (explicit?.evidence?.contains(token.start) == true) continue;
      final candidate = _value(text, start, word);
      if (candidate.present) explicit = candidate;
    }
    // Inverse assignment: "put Laptop as the goal name", "Laptop as title".
    final reverse = RegExp(
      r'\b(?:put|use|make|gawin mong|gawin mo|gawing)?\s*(.+?)\s+(?:as|ang|for|the|my)\s+(?:(?:my|the|a|goal|task|reminder|mission|scenario|savings)\s+)*(?:name|title|pangalan)\b',
      caseSensitive: false,
    ).firstMatch(source);
    if (explicit == null && reverse != null && !text.quoted(reverse.start)) {
      var value = SemanticText.commandText(reverse[1]!);
      value = value.replaceFirst(
        RegExp(
          r'^(?:please\s+)?(?:put|use|make|set\s+up|gawin\s+mong|gawin\s+mo)\s+',
          caseSensitive: false,
        ),
        '',
      );
      final start = source.indexOf(value, reverse.start);
      if (start >= 0 && !_looksLikeInstruction(value)) {
        explicit = _literal(
          text,
          start,
          start + value.length,
          'inverse_assignment',
        );
      }
    }
    if (explicit == null) {
      final suffix = RegExp(
        r'(?:^|[,;.])\s*([^,;.]+?)\s+(?:title|name)\s*(?=[.!;]|$)',
        caseSensitive: false,
      ).firstMatch(source);
      if (suffix != null && !_looksLikeInstruction(suffix[1]!)) {
        final value = suffix[1]!.trim();
        final start = source.indexOf(value, suffix.start);
        explicit = _literal(
          text,
          start,
          start + value.length,
          'suffix_assignment',
        );
      }
    }
    if (explicit == null && domain == SemanticObject.task) {
      final addition = RegExp(
        r'\b(?:add|put)\s+(.+?)\s+(?:to|on|in)\s+(?:my\s+)?(?:tasks|planner)\b',
        caseSensitive: false,
      ).firstMatch(source);
      if (addition != null &&
          !['this', 'it'].contains(addition[1]!.trim().toLowerCase())) {
        final value = addition[1]!.trim();
        final start = source.indexOf(value, addition.start);
        explicit = _literal(
          text,
          start,
          start + value.length,
          'planner_addition',
        );
      }
    }
    if (explicit != null) {
      final correction = RegExp(
        r'(?:—|–|-)?\s*\b(?:sorry|actually|wait|ay hindi|instead)\b[,\s]*',
        caseSensitive: false,
      ).allMatches(text.withoutQuotes).lastOrNull;
      if (correction != null && correction.start >= explicit.evidence!.end) {
        final corrected = _value(text, correction.end, 'correction');
        if (corrected.present && !_looksLikeInstruction(corrected.value)) {
          explicit = corrected.withOrigin(SlotOrigin.userCorrection);
        }
      }
    }
    final purpose = _purpose(
      text,
      noun == null ? 0 : tokens[noun].end,
      excluding: explicit?.evidence,
    );
    if (explicit != null) {
      return ResolvedTitle(
        value: explicit.value,
        origin:
            _corrected(
              text.mask([
                ...text.quotes,
                if (explicit.evidence != null) explicit.evidence!,
              ]),
            )
            ? SlotOrigin.userCorrection
            : explicit.origin,
        evidence: explicit.evidence,
        relation: explicit.relation,
        purpose: purpose.value,
        purposeEvidence: purpose.evidence,
      );
    }
    if (domain == SemanticObject.reminder) {
      final purposeMarker = RegExp(
        r'\b(?:remind me to|ipaalala (?:mo )?(?:sa akin )?(?:na )?)\s*',
        caseSensitive: false,
      ).firstMatch(source);
      if (purposeMarker != null) {
        final inferred = _value(text, purposeMarker.end, 'purpose');
        if (inferred.present) {
          return ResolvedTitle(
            value: inferred.value,
            origin: SlotOrigin.inferredPurpose,
            evidence: inferred.evidence,
            relation: 'purpose',
            purpose: inferred.value,
            purposeEvidence: inferred.evidence,
          );
        }
      }
    }
    if (purpose.present && domain == SemanticObject.goal) {
      return ResolvedTitle(
        value: purpose.value,
        origin: SlotOrigin.inferredPurpose,
        evidence: purpose.evidence,
        relation: purpose.relation,
        purpose: purpose.value,
        purposeEvidence: purpose.evidence,
      );
    }
    final leadingComma = RegExp(r'(?<!\d),|,(?!\d)')
        .firstMatch(text.withoutQuotes);
    if (noun != null && explicit == null && leadingComma != null) {
      final subject = source.substring(0, leadingComma.start).trim();
      if (subject.isNotEmpty &&
          !_looksLikeInstruction(subject) &&
          !tokens.any(
            (t) =>
                t.start < leadingComma.start &&
                SemanticText.object(t.value) != null,
          ) &&
          !RegExp(
            r'\d|\b(?:prepare|deposit|save|saving|dagdagan|maghulog|maglagay|if|kung|kapag)\b',
            caseSensitive: false,
          ).hasMatch(subject) &&
          !RegExp(
            r'^(?:please|uhm|pakiusap|target|deadline|by|amount|priority)\b',
            caseSensitive: false,
          ).hasMatch(subject)) {
        return _literal(
          text,
          source.indexOf(subject),
          source.indexOf(subject) + subject.length,
          'fronted_subject',
        );
      }
    }
    if (noun != null) {
      var j = noun + 1;
      while (j < tokens.length &&
          [':', '-', 'is', 'ay', 'ko'].contains(tokens[j].value)) {
        j++;
      }
      if (j == noun + 1 &&
          j < tokens.length &&
          ['my', 'the', 'a', 'an'].contains(tokens[j].value)) {
        j++;
      }
      if (j < tokens.length &&
          !_fieldStart(tokens[j].value) &&
          ![
            'for',
            'para',
            'pang',
            'to',
            'sa',
            'every',
            'tuwing',
            'at',
            'called',
            'named',
            'titled',
          ].contains(tokens[j].value)) {
        final candidate = _value(text, tokens[j].start, 'object_title');
        if (candidate.present && !_looksLikeInstruction(candidate.value)) {
          return candidate;
        }
      }
      // Prenominal titles: "make a Laptop goal" / "Laptop as my goal".
      final prefix = source.substring(0, tokens[noun].start);
      final m = RegExp(
        r'^(?:(?:please|uhm|pakiusap)[,\s]+)*(?:(?:create|make|new|set\s+up|build|gawa|add)\s+)(?:a\s+|an\s+)?(.+?)(?:\s+as\s+(?:my|a|the)\s+)?$',
        caseSensitive: false,
      ).firstMatch(prefix);
      if (m != null) {
        final value = domain == SemanticObject.goal
            ? m[1]!.trim().replaceFirst(
                RegExp(r'\s+savings$', caseSensitive: false),
                '',
              )
            : m[1]!.trim();
        if (domain == SemanticObject.task &&
            tokens[noun].value == 'tasks' &&
            RegExp(
              r'^(?:[1-6]|one|two|three|four|five|six|tatlo)\b',
              caseSensitive: false,
            ).hasMatch(value)) {
          return const ResolvedTitle();
        }
        if (![
              'savings',
              'new',
              'a',
              'new savings',
              'me',
              'me a',
              'me an',
              'mo ako',
              'mo akong',
              'ka ng',
              'a new',
              'a savings',
            ].contains(value.toLowerCase()) &&
            !_looksLikeInstruction(value)) {
          final start = source.indexOf(value, m.start);
          return _literal(
            text,
            start,
            start + value.length,
            'prenominal_title',
          );
        }
      }
    }
    if (contextual && pendingTitle) {
      final clean = SemanticText.commandText(source);
      if (!_looksLikeInstruction(clean) &&
          clean.length <= 104 &&
          !RegExp(
            r'^(?:yes|no|oo|hindi|cancel|stop|\d|target|deadline|bukas|tomorrow|priority)\b',
            caseSensitive: false,
          ).hasMatch(clean)) {
        return _value(
          text,
          source.indexOf(clean),
          'pending_title',
        ).withOrigin(SlotOrigin.contextFollowUp);
      }
    }
    return const ResolvedTitle();
  }

  static const _link = {
    'it',
    'this',
    'that',
    'is',
    'ay',
    'should',
    'be',
    'to',
    'as',
    'ng',
    'sa',
    'ko',
    'mo',
    'mong',
    'na',
    'ang',
    ':',
    '=',
  };
  static const _punctuation = {'.', ',', ';', '!', '?'};
  static bool _fieldStart(String word) => {
    'target',
    'amount',
    'worth',
    'deadline',
    'due',
    'priority',
    'frequency',
    'every',
    'tuwing',
    'with',
    'by',
  }.contains(word);
  static bool _looksLikeInstruction(String value) =>
      value.trim().isEmpty ||
      RegExp(
        r"\b(?:create|make|add|gawa|gawan|remind|set up|goal for|goal called|ayusin|pakiayos|edit|only if|to my|into my)\b|^(?:wag|huwag|cancel|stop|never|not|do not|don't|PHP\b|USD\b|EUR\b|goal\b|named|called|titled|tomorrow|today|bukas|ngayon|next|ako|mo|every|tuwing|at|target|amount|\d)",
        caseSensitive: false,
      ).hasMatch(value);
  static bool _corrected(String value) => RegExp(
    r'\b(?:actually|sorry|instead|palitan|mali|pala|ay hindi)\b',
    caseSensitive: false,
  ).hasMatch(value);

  ResolvedTitle _purpose(
    SemanticText text,
    int after, {
    SemanticSpan? excluding,
  }) {
    final m =
        RegExp(
              r'\b(?:for|para\s+sa|pang|to\s+buy|pambili\s+ng|sa)\s+(?:(?:a|an|my|the|bagong)\s+)?',
              caseSensitive: false,
            )
            .allMatches(text.withoutQuotes)
            .where(
              (m) => m.start >= after && excluding?.contains(m.start) != true,
            )
            .firstOrNull;
    if (m == null) return const ResolvedTitle();
    final end = _end(text, m.end, purpose: true);
    return _literal(text, m.end, end, 'purpose');
  }

  ResolvedTitle _value(SemanticText text, int start, String relation) {
    while (start < text.source.length &&
        RegExp(r'\s').hasMatch(text.source[start])) {
      start++;
    }
    final quote = text.quoteAt(start);
    if (quote != null && quote.start == start) {
      return _literal(text, start + 1, quote.end - 1, relation);
    }
    return _literal(text, start, _end(text, start), relation);
  }

  int _end(SemanticText text, int start, {bool purpose = false}) {
    final tail = text.source.substring(start);
    final boundary = RegExp(
      r",(?!(?<=\d,)\d)|[;!?]|\.(?!\d)|\s+(?:(?:with\s+)?(?:target|amount|worth|deadline|due|priority)\b|(?:by|before|bago|at|on)\s+(?:\d|tomorrow|today|bukas|next|january|february|march|april|may|june|july|august|september|october|november|december|monday|tuesday|wednesday|thursday|friday|saturday|sunday|alas|seven)|(?:but|pero|draft\s+only|plan\s+lang|do\s+not|don't|huwag|wag)\b|tomorrow\b|today\b|bukas\b|ngayon\b|every\b|tuwing\b|alas\b|(?:and|tapos|then)\s+(?:create|add|make|remind|gawa)\b|(?:sorry|actually|wait|instead)\b)",
      caseSensitive: false,
    );
    var end = text.source.length;
    final repair = RegExp(
      r'[—–-]\s*(?=sorry\b|actually\b|wait\b|no\b|ay hindi\b)',
      caseSensitive: false,
    ).firstMatch(tail);
    if (repair != null) end = start + repair.start;
    for (final m in boundary.allMatches(tail)) {
      if (RegExp(
        r'\bfor$',
        caseSensitive: false,
      ).hasMatch(tail.substring(0, m.start).trim())) {
        continue;
      }
      if (!text.quoted(start + m.start)) {
        if (start + m.start < end) end = start + m.start;
        break;
      }
    }
    if (purpose) {
      final naming = RegExp(
        r'\s+(?:called|named|titled|name it|title is|ko)\b',
        caseSensitive: false,
      ).firstMatch(tail);
      if (naming != null && start + naming.start < end) {
        end = start + naming.start;
      }
    }
    return end;
  }

  ResolvedTitle _literal(
    SemanticText text,
    int start,
    int end,
    String relation,
  ) {
    while (start < end && RegExp(r'\s').hasMatch(text.source[start])) {
      start++;
    }
    while (end > start && RegExp(r'\s').hasMatch(text.source[end - 1])) {
      end--;
    }
    var value = text.source
        .substring(start, end)
        .replaceAll(RegExp(r'\s+'), ' ');
    if (value.isEmpty ||
        value.length > 100 ||
        RegExp(r'[\x00-\x1f]').hasMatch(value)) {
      return const ResolvedTitle();
    }
    return ResolvedTitle(
      value: value,
      origin: SlotOrigin.explicitNaming,
      evidence: SemanticSpan(start, end),
      relation: relation,
    );
  }
}
