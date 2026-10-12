import 'currency_catalog_data.dart';

class CurrencyInfo {
  const CurrencyInfo(
    this.code,
    this.name,
    this.symbol,
    this.digits,
    this.regions,
  );
  final String code, name, symbol;
  final int digits;
  final List<String> regions;
  bool matches(String query) => '$code $name ${regions.join(' ')}'
      .toLowerCase()
      .contains(query.toLowerCase().trim());
}

abstract final class CurrencyCatalog {
  static final all = List<CurrencyInfo>.unmodifiable(
    currencyCatalogRows.map(
      (r) => CurrencyInfo(r.$1, r.$2, r.$3, r.$4, List.unmodifiable(r.$5)),
    ),
  );
  static final byCode = {for (final c in all) c.code: c};
  static CurrencyInfo require(String code) =>
      byCode[code] ??
      (throw const CurrencyFailure('Currency metadata is unavailable.'));
  static const popular = ['PHP', 'USD', 'EUR', 'GBP', 'JPY', 'SGD'];
}

class CurrencyFailure implements Exception {
  const CurrencyFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Exact rational decimal arithmetic. No binary floating point in conversion,
/// aggregation or rounding; round half away from zero only at money boundaries.
class ExactDecimal {
  factory ExactDecimal(BigInt numerator, [BigInt? denominator]) {
    final divisor = denominator ?? BigInt.one;
    if (divisor <= BigInt.zero) throw const CurrencyFailure('Invalid decimal.');
    final gcd = numerator.gcd(divisor);
    return ExactDecimal._(numerator ~/ gcd, divisor ~/ gcd);
  }
  const ExactDecimal._(this.numerator, this.denominator);
  final BigInt numerator, denominator;
  static final zero = ExactDecimal(BigInt.zero);
  static final one = ExactDecimal(BigInt.one);
  factory ExactDecimal.parse(String value) {
    final match = RegExp(r'^(-?)(\d+)(?:\.(\d+))?(?:[eE]([+-]?\d+))?$')
        .firstMatch(value.trim());
    if (match == null || value.length > 160) {
      throw const CurrencyFailure('Invalid conversion amount.');
    }
    final fraction = match[3] ?? '';
    final exponent = int.tryParse(match[4] ?? '0');
    if (exponent == null || exponent.abs() > 100) {
      throw const CurrencyFailure('Invalid conversion amount.');
    }
    var n = BigInt.parse('${match[2]}$fraction');
    if (match[1] == '-') n = -n;
    final scale = fraction.length - exponent;
    return scale >= 0
        ? ExactDecimal(n, BigInt.from(10).pow(scale))
        : ExactDecimal(n * BigInt.from(10).pow(-scale));
  }
  factory ExactDecimal.fromNum(num value) {
    if (!value.isFinite) {
      throw const CurrencyFailure('Invalid conversion amount.');
    }
    return ExactDecimal.parse(value.toString());
  }
  ExactDecimal operator +(ExactDecimal other) => ExactDecimal(
    numerator * other.denominator + other.numerator * denominator,
    denominator * other.denominator,
  );
  ExactDecimal operator -(ExactDecimal other) =>
      this + ExactDecimal(-other.numerator, other.denominator);
  ExactDecimal operator *(ExactDecimal other) => ExactDecimal(
    numerator * other.numerator,
    denominator * other.denominator,
  );
  ExactDecimal operator /(ExactDecimal other) {
    if (other.numerator == BigInt.zero) {
      throw const CurrencyFailure('Missing exchange rate.');
    }
    final n = numerator * other.denominator, d = denominator * other.numerator;
    return d.isNegative ? ExactDecimal(-n, -d) : ExactDecimal(n, d);
  }

  bool get positive => numerator > BigInt.zero;
  int compareTo(ExactDecimal other) =>
      (numerator * other.denominator).compareTo(other.numerator * denominator);
  BigInt roundedUnits(int digits) {
    final scaled = numerator.abs() * BigInt.from(10).pow(digits);
    final units = scaled ~/ denominator;
    final rounded =
        units +
        ((scaled % denominator) * BigInt.two >= denominator
            ? BigInt.one
            : BigInt.zero);
    return numerator.isNegative ? -rounded : rounded;
  }

  String fixed(int digits) {
    final units = roundedUnits(digits),
        text = units.abs().toString().padLeft(digits + 1, '0');
    final sign = units.isNegative ? '-' : '';
    return digits == 0
        ? '$sign$text'
        : '$sign${text.substring(0, text.length - digits)}.${text.substring(text.length - digits)}';
  }

  double toDouble() => numerator.toDouble() / denominator.toDouble();
}

String goalCurrency(Map<String, dynamic> goal) =>
    goal['currencyCode'] is String ? goal['currencyCode'] as String : 'PHP';

/// Strict user input in major units. Preserve old numeric Firestore fields;
/// new writes are quantized and bounded to safely representable minor units.
ExactDecimal? parseCurrencyAmount(String text, String code) {
  final info = CurrencyCatalog.byCode[code];
  if (info == null || text.length > 30) return null;
  final pattern = info.digits == 0
      ? r'^\d+$'
      : '^\\d+(?:\\.\\d{1,${info.digits}})?\$';
  if (!RegExp(pattern).hasMatch(text.trim())) return null;
  final value = ExactDecimal.parse(text);
  if (value.roundedUnits(info.digits) > BigInt.from(9007199254740991)) {
    return null;
  }
  if (value.compareTo(ExactDecimal.parse('1000000000000')) > 0 ||
      ExactDecimal.fromNum(value.toDouble()).compareTo(value) != 0) {
    return null;
  }
  return value;
}

String formatCurrency(ExactDecimal amount, String code) {
  final info = CurrencyCatalog.byCode[code];
  if (info == null) return '$code ${amount.fixed(2)}';
  final fixed = amount.fixed(info.digits);
  final sign = fixed.startsWith('-') ? '-' : '';
  final parts = fixed.replaceFirst('-', '').split('.');
  final whole = parts.first.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]},',
  );
  // ISO code accompanies symbols, avoiding ambiguous dollars, pesos and yen.
  final symbol = info.symbol == code ? '' : info.symbol;
  return '$sign$code $symbol$whole${parts.length == 2 ? '.${parts.last}' : ''}';
}

String originalMoney(num amount, [String code = 'PHP']) => amount.isFinite
    ? formatCurrency(ExactDecimal.fromNum(amount), code)
    : '$code amount unavailable';
