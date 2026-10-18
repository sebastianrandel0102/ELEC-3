import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;

import '../design_system.dart';

/// Parse math before Markdown interprets TeX backslashes and underscores.
/// A closing dollar cannot precede a digit, so "$5 and $10" stays currency.
class AiMathInlineSyntax extends md.InlineSyntax {
  AiMathInlineSyntax()
    : super(
        r'\$\$([\s\S]+?)\$\$|\$(?![\s$])([^$\n]*?\S)\$(?![\d$])|'
        r'\\\(([\s\S]+?)\\\)|\\\[([\s\S]+?)\\\]',
      );

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final expression = [
      match[1],
      match[2],
      match[3],
      match[4],
    ].whereType<String>().first;
    parser.addNode(md.Element.text('ai-math', expression));
    return true;
  }
}

/// Do not flash unfinished TeX commands while a streamed formula is arriving.
class AiPendingMathSyntax extends md.InlineSyntax {
  AiPendingMathSyntax()
    : super(r'\$\$[^$]*$|\$(?![\s$\d])[^$\n]*$|\\\([^\n]*$|\\\[[\s\S]*$');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text('ai-math-pending', 'Formatting equation…'));
    return true;
  }
}

class AiMathBlockSyntax extends md.BlockSyntax {
  const AiMathBlockSyntax({this.streaming = false});
  final bool streaming;

  @override
  RegExp get pattern => RegExp(r'^ {0,3}(\$\$|\\\[)');

  @override
  bool canParse(md.BlockParser parser) {
    final match = pattern.firstMatch(parser.current.content);
    if (match == null) return false;
    final closing = match[1] == r'$$' ? r'$$' : r'\]';
    final rest = parser.current.content.substring(match.end);
    final end = rest.indexOf(closing);
    // A formula followed by prose on the same line belongs to inline parsing.
    return end < 0 || rest.substring(end + closing.length).trim().isEmpty;
  }

  @override
  md.Node parse(md.BlockParser parser) {
    final first = pattern.firstMatch(parser.current.content)!;
    final closing = first[1] == r'$$' ? r'$$' : r'\]';
    final lines = <String>[];
    var line = parser.current.content.substring(first.end);
    var complete = false;
    while (true) {
      final end = line.lastIndexOf(closing);
      if (end >= 0 && line.substring(end + closing.length).trim().isEmpty) {
        lines.add(line.substring(0, end));
        parser.advance();
        complete = true;
        break;
      }
      lines.add(line);
      parser.advance();
      if (parser.isDone) break;
      line = parser.current.content;
    }
    return md.Element.text(
      streaming && !complete ? 'ai-math-pending' : 'ai-math-block',
      streaming && !complete ? 'Formatting equation…' : lines.join('\n').trim(),
    );
  }
}

class AiMathBuilder extends MarkdownElementBuilder {
  AiMathBuilder({required this.maxWidth, this.block = false});
  final double maxWidth;
  final bool block;

  @override
  bool isBlockElement() => block;

  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final style = (parentStyle ?? const TextStyle(fontSize: 15)).copyWith(
      color: context.atelierInk,
      height: 1.4,
    );
    // Give wide equations their own scroll area, including at large text sizes.
    final equation = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(vertical: block ? 12 : 2),
        child: Math.tex(
          element.textContent,
          mathStyle: block ? MathStyle.display : MathStyle.text,
          textStyle: style.copyWith(
            fontSize: block
                ? MediaQuery.textScalerOf(context).scale(style.fontSize ?? 15)
                : style.fontSize ?? 15,
          ),
          textScaleFactor: 1,
          onErrorFallback: (_) => SelectableText(
            'Could not format this equation: ${element.textContent}',
            style: style,
            textScaler: block
                ? MediaQuery.textScalerOf(context)
                : TextScaler.noScaling,
          ),
        ),
      ),
    );
    // Keep inline formulas in the paragraph's text flow so a leading symbol
    // does not become a separate line before a long explanation.
    return block
        ? equation
        : Text.rich(
            TextSpan(
              style: style,
              children: [
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: equation,
                ),
              ],
            ),
          );
  }
}

class AiPendingMathBuilder extends MarkdownElementBuilder {
  @override
  Widget visitElementAfter(md.Element element, TextStyle? preferredStyle) =>
      const Text('Formatting equation…', style: TextStyle(color: muted));
}
