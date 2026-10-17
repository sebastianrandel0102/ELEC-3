import 'dart:convert';
import 'dart:io';

/// Reproducible physical code-line inventory. Blank lines and comments are
/// excluded; string contents count as code. Generated files and JSON do not.
int codeLines(String source) {
  var block = false, quote = '', triple = false, hasCode = false, count = 0;
  for (var i = 0; i < source.length; i++) {
    final char = source[i], next = i + 1 < source.length ? source[i + 1] : '';
    if (char == '\n') {
      if (hasCode) count++;
      hasCode = false;
      continue;
    }
    if (block) {
      if (char == '*' && next == '/') {
        block = false;
        i++;
      }
      continue;
    }
    if (quote.isNotEmpty) {
      if (char.trim().isNotEmpty) hasCode = true;
      if (char == '\\') {
        i++;
        continue;
      }
      if (char == quote) {
        if (!triple) {
          quote = '';
        } else if (i + 2 < source.length &&
            source.substring(i, i + 3) == quote * 3) {
          quote = '';
          triple = false;
          i += 2;
        }
      }
      continue;
    }
    if (char == '/' && next == '*') {
      block = true;
      i++;
      continue;
    }
    if (char == '/' && next == '/') {
      while (i < source.length && source[i] != '\n') {
        i++;
      }
      if (hasCode) count++;
      hasCode = false;
      continue;
    }
    if (char == '"' || char == "'") {
      quote = char;
      triple = i + 2 < source.length && source.substring(i, i + 3) == char * 3;
      if (triple) i += 2;
    }
    if (char.trim().isNotEmpty) hasCode = true;
  }
  return count + (hasCode ? 1 : 0);
}

void main() {
  final categories = <String, List<String>>{};
  void add(String category, File file) => categories
      .putIfAbsent(category, () => [])
      .add(file.path.replaceAll('\\', '/'));
  for (final f
      in Directory('lib/agent_studio')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
    add('productionDart', f);
  }
  for (final root in [
    'android/app/src/main/kotlin/com/example/myproject/agent',
    'android/app/src/test/kotlin/com/example/myproject/agent',
  ]) {
    for (final f
        in Directory(root)
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.kt'))) {
      add(root.contains('/test/') ? 'kotlinTests' : 'productionKotlin', f);
    }
  }
  for (final f in Directory('test').listSync().whereType<File>().where(
    (f) =>
        f.path.replaceAll('\\', '/').split('/').last.startsWith('agent_') &&
        f.path.endsWith('.dart'),
  )) {
    add(
      f.path.contains('widgets')
          ? 'widgetTests'
          : f.path.contains('backend') || f.path.contains('validation')
          ? 'repositoryIntegrationTests'
          : 'unitAndEngineIntegrationTests',
      f,
    );
  }
  add(
    'evaluationFixtures',
    File('test/fixtures/universal_intelligence_cases.dart'),
  );
  add('evaluationTools', File('tools/measure_agent_source.dart'));
  final report = {
    'definition': 'Physical nonblank noncomment source lines; excludes JSON, generated code, lockfiles and dependencies',
    'categories': {
      for (final e in categories.entries)
        e.key: {
          'files': {
            for (final path in e.value)
              path: codeLines(File(path).readAsStringSync()),
          },
          'lines': e.value.fold<int>(
            0,
            (n, path) => n + codeLines(File(path).readAsStringSync()),
          ),
        },
    },
  };
  final file = File('build/reports/agent_universal_source_lines.json');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(report)}\n',
  );
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(report));
}
