import '../../currency_money.dart';
import 'agent_interpretation.dart';

class MoneyCandidate {
  const MoneyCandidate(this.amount, this.evidence);
  final String amount;
  final SlotEvidence evidence;
}

class MoneyExpression {
  MoneyExpression({
    this.currency = '',
    this.amount = '',
    this.ambiguous = false,
    this.approximate = false,
    this.currencyAmbiguous = false,
    this.invalid = false,
    List<MoneyCandidate> candidates = const [],
  }) : candidates = List.unmodifiable(candidates);
  final String currency, amount;
  final bool ambiguous, approximate, currencyAmbiguous, invalid;
  final List<MoneyCandidate> candidates;
}

/// Exact decimal arithmetic, no binary floating point or silent rounding.
class MoneyExpressionParser {
  const MoneyExpressionParser();
  static const units = <String, int>{
    'zero': 0,
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
    'thirteen': 13,
    'fourteen': 14,
    'fifteen': 15,
    'sixteen': 16,
    'seventeen': 17,
    'eighteen': 18,
    'nineteen': 19,
    'twenty': 20,
    'thirty': 30,
    'forty': 40,
    'fifty': 50,
    'sixty': 60,
    'seventy': 70,
    'eighty': 80,
    'ninety': 90,
    'isa': 1,
    'isang': 1,
    'dalawa': 2,
    'dalawang': 2,
    'tatlo': 3,
    'tatlong': 3,
    'apat': 4,
    'apat na': 4,
    'lima': 5,
    'limang': 5,
    'anim': 6,
    'anim na': 6,
    'pito': 7,
    'pitong': 7,
    'walo': 8,
    'walong': 8,
    'siyam': 9,
    'siyam na': 9,
    'sampu': 10,
    'sampung': 10,
    'labing': 10,
    'dalawampu': 20,
    'dalawampung': 20,
    'tatlumpu': 30,
    'tatlumpung': 30,
    'apatnapu': 40,
    'apatnapung': 40,
    'limampu': 50,
    'limampung': 50,
    'animnapu': 60,
    'animnapung': 60,
    'pitumpu': 70,
    'pitumpung': 70,
    'walumpu': 80,
    'walumpung': 80,
    'siyamnapu': 90,
    'siyamnapung': 90,
  };
  static const scales = <String, int>{
    'hundred': 100,
    'daan': 100,
    'daang': 100,
    'thousand': 1000,
    'libo': 1000,
    'libong': 1000,
    'k': 1000,
    'million': 1000000,
    'milyon': 1000000,
    'milyong': 1000000,
  };

  MoneyExpression parse(String text) {
    final lower = text.toLowerCase();
    final currencies = <String>{};
    for (final code in CurrencyCatalog.byCode.keys) {
      if (RegExp('\\b$code\\b', caseSensitive: false).hasMatch(text)) {
        currencies.add(code);
      }
    }
    if (text.contains('₱') || RegExp(r'\b(pesos?|piso)\b').hasMatch(lower)) {
      currencies.add('PHP');
    }
    if (text.contains('€')) currencies.add('EUR');
    if (text.contains('£')) currencies.add('GBP');
    final dollar =
        text.contains(r'$') || RegExp(r'\bdollars?\b').hasMatch(lower);
    final currencyAmbiguous =
        currencies.length > 1 || (dollar && currencies.isEmpty);
    final currency = currencies.length == 1 && !currencyAmbiguous
        ? currencies.single
        : '';
    // Mask calendar dates, clock times, and explicit task/step counts, preserving offsets.
    var work = lower;
    for (final pattern in [
      r'\b\d{4}-\d{2}-\d{2}\b',
      r'\b\d{1,2}/\d{1,2}(?:/\d{2,4})?\b',
      r'\b\d{1,2}:\d{2}(?:\s*[ap]m)?\b',
      r'\b\d{1,2}\s*[ap]m\b',
      r'\b(?:step|hakbang)\s+\d+\b',
      r'\b(?:\d+|one|two|three|four|five|six|tatlo)\s+(?:study\s+)?tasks?\b',
      r'\b(?:january|february|march|april|may|june|july|august|september|october|november|december|enero|pebrero|marso|abril|mayo|hunyo|hulyo|agosto|setyembre|oktubre|nobyembre|disyembre)\s+\d{1,2}(?:,?\s+\d{4})?\b',
      r'\balas\s+(?:\d+|otso|siyete|siete|sais|seis|singko|cinco|nuebe|diyes|dose|una|dos|tres|kuwatro|kwatro)\b',
      r'\b\d{1,2}\s+(?:ng\s+)?(?:january|february|march|april|may|june|july|august|september|october|november|december|enero|pebrero|marso|abril|mayo|hunyo|hulyo|agosto|setyembre|oktubre|nobyembre|disyembre)\s+\d{4}\b',
      r'\b(?:one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve)\s+in the\s+(?:morning|afternoon|evening)\b',
    ]) {
      work = work.replaceAllMapped(RegExp(pattern), (m) => ' ' * m[0]!.length);
    }
    final words = {...units.keys, ...scales.keys}.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    final token =
        '(?:[+-]?\\d[\\d,]*(?:\\.\\d+)?|${words.map(RegExp.escape).join('|')})';
    final pattern = RegExp(
      '(?<![a-z0-9])$token(?:(?:[ -]+|\'t )(?:(?:and|at|na) )?$token)*(?:k)?(?![a-z0-9])',
    );
    final candidates = <MoneyCandidate>[];
    var malformed = false;
    for (final m in pattern.allMatches(work)) {
      final raw = m[0]!.replaceFirst(RegExp(r',$'), '');
      final evidenceEnd = m.start + raw.length;
      // A naked year is a calendar reference, not money.
      if (RegExp(r'^20\d\d$').hasMatch(raw) &&
          RegExp(r'(by|before|deadline|petsa|on)\s*$')
              .hasMatch(work.substring(0, m.start))) {
        continue;
      }
      final value = _number(raw);
      final zeroSaved =
          value == '0' &&
          (RegExp(
                r'\b(?:saved|already have|naipon|initial savings)\s*(?:[a-z]{3}|₱)?\s*$',
              ).hasMatch(work.substring(0, m.start)) ||
              RegExp(r'^\s*(?:saved|naipon)\b')
                  .hasMatch(work.substring(evidenceEnd)));
      if (value == null ||
          value == '0' && !zeroSaved ||
          value.startsWith('-')) {
        malformed = true;
        continue;
      }
      if (currency.isNotEmpty &&
          (parseCurrencyAmount(value, currency) == null ||
              !zeroSaved &&
                  parseCurrencyAmount(value, currency)?.positive != true)) {
        malformed = true;
        continue;
      }
      candidates.add(
        MoneyCandidate(
          value,
          SlotEvidence(
            'amount',
            text.substring(m.start, evidenceEnd),
            m.start,
            evidenceEnd,
          ),
        ),
      );
    }
    if (RegExp(r'\d(?:\.\d+){2,}|\d\s*[-–]\s*\d|\d[eE][+-]?\d')
        .hasMatch(work)) {
      malformed = true;
    }
    final approximate = RegExp(
      r'\b(mga|around|about|approximately|roughly|siguro|baka|maybe)\b',
    ).hasMatch(lower);
    // Decimal point versus thousands separator requires explicit repair.
    if (RegExp(r'\b\d{1,3}\.\d{3}\b(?!\s*(?:k|million|milyon))')
        .hasMatch(work)) {
      malformed = true;
    }
    final ambiguous = malformed || candidates.length > 1 || approximate;
    return MoneyExpression(
      currency: currency,
      invalid: malformed,
      currencyAmbiguous: currencyAmbiguous,
      amount: !ambiguous && candidates.length == 1
          ? candidates.single.amount
          : '',
      ambiguous: ambiguous,
      approximate: approximate,
      candidates: candidates,
    );
  }

  String? _number(String expression) {
    var raw = expression.replaceAll("'t", ' at ').replaceAll('-', ' ');
    // A sign is meaningful, never turn a negative into a positive number.
    if (expression.trim().startsWith('-')) return null;
    raw = raw.replaceAllMapped(RegExp(r'(\d)k\b'), (m) => '${m[1]} thousand');
    final tokens = raw
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && !['and', 'at', 'na'].contains(w))
        .toList();
    var total = BigInt.zero, group = BigInt.zero;
    ExactDecimal? decimal;
    var previousUnit = -1;
    for (var i = 0; i < tokens.length; i++) {
      final t = tokens[i];
      if (RegExp(r'^\+?\d').hasMatch(t)) {
        if (!RegExp(r'^\+?(?:\d+|\d{1,3}(?:,\d{3})+)(?:\.\d+)?$').hasMatch(t)) {
          return null;
        }
        if (group != BigInt.zero || decimal != null) return null;
        try {
          decimal = ExactDecimal.parse(
            t.replaceAll(',', '').replaceAll('+', ''),
          );
        } on CurrencyFailure {
          return null;
        }
      } else if (units.containsKey(t)) {
        final n = units[t]!;
        if (decimal != null || (previousUnit >= 0 && previousUnit < 10)) {
          return null;
        }
        group += BigInt.from(n);
        previousUnit = n;
      } else if (scales.containsKey(t)) {
        final scale = scales[t]!;
        if (decimal != null) {
          final result = decimal * ExactDecimal.parse('$scale');
          if (i != tokens.length - 1 || total != BigInt.zero) return null;
          return _canonical(result);
        }
        if (group == BigInt.zero) return null;
        if (scale == 100) {
          group *= BigInt.from(scale);
        } else {
          total += group * BigInt.from(scale);
          group = BigInt.zero;
        }
        previousUnit = -1;
      } else {
        return null;
      }
    }
    if (decimal != null && tokens.length == 1) {
      return tokens.single.replaceAll(',', '').replaceAll('+', '');
    }
    return decimal == null ? '${total + group}' : _canonical(decimal);
  }

  String? _canonical(ExactDecimal value) {
    // Retain precision; currency validation rejects extra fractional minor units.
    for (var digits = 0; digits <= 8; digits++) {
      final factor = BigInt.from(10).pow(digits);
      if ((value.numerator * factor) % value.denominator == BigInt.zero) {
        final scaled = value.numerator * factor ~/ value.denominator;
        if (digits == 0) return '$scaled';
        final s = scaled.toString().padLeft(digits + 1, '0');
        return '${s.substring(0, s.length - digits)}.${s.substring(s.length - digits)}';
      }
    }
    return null;
  }
}
