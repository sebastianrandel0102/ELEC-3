import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:myproject/ai_coach/ai_math.dart';
import 'package:myproject/ai_coach/ai_response.dart';

import 'ai_coach_fixtures.dart' show integralAnswer;
import 'redesign_test.dart' as preview;
import 'ui_preview_fonts.dart';

void main() {
  setUpAll(() async {
    await loadManropeForPreviews();
    await loadAiMathFontsForPreviews();
  });

  List<md.Node> parse(String text, {bool streaming = false}) => md.Document(
    blockSyntaxes: [AiMathBlockSyntax(streaming: streaming)],
    inlineSyntaxes: [
      AiMathInlineSyntax(),
      if (streaming) AiPendingMathSyntax(),
    ],
    extensionSet: md.ExtensionSet.gitHubFlavored,
  ).parseLines(text.split('\n'));

  List<md.Element> elements(List<md.Node> nodes, String tag) => [
    for (final node in nodes)
      if (node is md.Element) ...[
        if (node.tag == tag) node,
        ...elements(node.children ?? [], tag),
      ],
  ];

  test('dollar and backslash delimiters preserve TeX', () {
    final nodes = parse(
      r'Inline $x$ and \(x^2\).'
      '\n\n'
      r'$$\int x\,dx = \frac{x^2}{2} + C$$'
      '\n\n'
      r'\['
      '\n'
      r'\frac{1}{2}'
      '\n'
      r'\]',
    );
    expect(elements(nodes, 'ai-math').map((e) => e.textContent), ['x', 'x^2']);
    expect(elements(nodes, 'ai-math-block').map((e) => e.textContent), [
      r'\int x\,dx = \frac{x^2}{2} + C',
      r'\frac{1}{2}',
    ]);
  });

  test('currency, escaped dollars and code remain literal', () {
    final nodes = parse(
      r'Save $5 and $10; pay \$20. Code: `$x$`.'
      '\n\n'
      '```tex\n'
      r'$$\frac{x^2}{2}$$'
      '\n```',
    );
    expect(elements(nodes, 'ai-math'), isEmpty);
    expect(elements(nodes, 'ai-math-block'), isEmpty);
    expect(elements(nodes, 'code').map((e) => e.textContent), [
      r'$x$',
      r'$$\frac{x^2}{2}$$'
          '\n',
    ]);
  });

  test('display delimiters followed by prose do not consume the paragraph', () {
    final nodes = parse(r'$$x^2$$ is the result.');
    expect(elements(nodes, 'ai-math').single.textContent, 'x^2');
    expect(elements(nodes, 'ai-math-block'), isEmpty);
    expect(nodes.single.textContent, contains('is the result.'));
  });

  test('streaming waits for complete inline and display formulas', () {
    for (final text in [
      r'Answer: $\frac{x',
      r'Answer: \(\frac{x',
      r'$$'
          '\n'
          r'\frac{x',
    ]) {
      final nodes = parse(text, streaming: true);
      expect(elements(nodes, 'ai-math-pending'), hasLength(1));
      expect(elements(nodes, 'ai-math'), isEmpty);
      expect(elements(nodes, 'ai-math-block'), isEmpty);
    }
    expect(
      elements(parse(r'Answer: $x$', streaming: true), 'ai-math'),
      hasLength(1),
    );
    expect(
      elements(parse(r'Save $5 and $10', streaming: true), 'ai-math-pending'),
      isEmpty,
    );
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'integral and long equations fit a 320px phone at scale $scale',
      (tester) async {
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        await preview.mount(
          tester,
          const Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: AiMarkdownResponse(
                text:
                    '$integralAnswer\n\n'
                    r'$$\sum_{n=1}^{100} (x_n^2 + y_n^2 + z_n^2 + a_n^2 + b_n^2 + c_n^2) = 123456789$$',
              ),
            ),
          ),
          size: const Size(320, 844),
          scale: scale,
        );
        expect(find.byType(Math), findsWidgets);
        expect(find.textContaining('Could not format'), findsNothing);
        expect(tester.takeException(), isNull);
        final constantParagraph = tester.widget<SelectableText>(
          find.byWidgetPredicate(
            (w) =>
                w is SelectableText &&
                (w.textSpan?.toPlainText().contains('is any constant') ??
                    false),
          ),
        );
        expect(
          constantParagraph.textSpan!.toPlainText(),
          startsWith('\uFFFC is any constant'),
        );
        final horizontal = find.byWidgetPredicate(
          (w) =>
              w is SingleChildScrollView &&
              w.scrollDirection == Axis.horizontal,
        );
        expect(horizontal, findsWidgets);
        await preview.capture(tester, 'ai-math-320-scale-$scale');
        await tester.ensureVisible(horizontal.last);
        await tester.pumpAndSettle();
        await tester.drag(horizontal.last, const Offset(-160, 0));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final scrollable = tester.state<ScrollableState>(
          find.descendant(
            of: horizontal.last,
            matching: find.byType(Scrollable),
          ),
        );
        expect(scrollable.position.pixels, greaterThan(0));
      },
    );
  }

  testWidgets('unsupported TeX gives a readable fallback without crashing', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AiMarkdownResponse(text: r'$\unknowncommand{x}$')),
      ),
    );
    expect(
      find.textContaining('Could not format this equation:'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
