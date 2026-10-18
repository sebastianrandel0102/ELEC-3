import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../design_system.dart';
import 'ai_math.dart';

class AiResponsePart {
  const AiResponsePart(this.text, {this.language});
  final String text;
  final String? language;
}

/// Split complete fenced blocks without changing their whitespace. Markdown
/// never changes code contents; no HTML execution or external images.
List<AiResponsePart> aiResponseParts(String text) {
  final parts = <AiResponsePart>[];
  final lines = RegExp(r'[^\n]*\n|[^\n]+$')
      .allMatches(text)
      .map((m) => m[0]!)
      .toList();
  final body = StringBuffer(), code = StringBuffer();
  String? fence, language;
  for (final line in lines) {
    final marker = RegExp(r'^\s{0,3}(`{3,}|~{3,})([^\r\n]*)[\r\n]*$')
        .firstMatch(line);
    if (fence == null && marker != null) {
      if (body.isNotEmpty) {
        parts.add(AiResponsePart(body.toString()));
        body.clear();
      }
      fence = marker[1];
      language = marker[2]!.trim();
    } else if (fence != null &&
        marker != null &&
        marker[1]![0] == fence[0] &&
        marker[1]!.length >= fence.length &&
        marker[2]!.trim().isEmpty) {
      parts.add(AiResponsePart(code.toString(), language: language));
      code.clear();
      fence = null;
      language = null;
    } else if (fence != null) {
      code.write(line);
    } else {
      body.write(line);
    }
  }
  if (fence != null) {
    parts.add(AiResponsePart(code.toString(), language: language));
  }
  if (body.isNotEmpty) parts.add(AiResponsePart(body.toString()));
  return parts;
}

bool isSafeAiLink(String href) {
  final uri = Uri.tryParse(href);
  return uri != null &&
      ['https', 'http'].contains(uri.scheme.toLowerCase()) &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty;
}

Future<void> copyAiText(BuildContext context, String text) async {
  var copied = false;
  try {
    await Clipboard.setData(ClipboardData(text: text));
    copied = true;
  } catch (_) {
    // Clipboard access can fail on web or be denied by the platform.
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          copied ? 'Copied' : 'Could not copy. Try selecting the text.',
        ),
        duration: Duration(seconds: copied ? 1 : 3),
      ),
    );
  }
}

class AiCodeBlock extends StatelessWidget {
  const AiCodeBlock({super.key, required this.code, required this.language});
  final String code, language;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: SaveTrackDesign.obsidian,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 14, right: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  language.isEmpty ? 'Code' : language,
                  style: const TextStyle(color: mint, fontSize: 12),
                ),
              ),
              IconButton(
                tooltip: 'Copy code',
                onPressed: () => copyAiText(context, code),
                icon: const Icon(Icons.copy_rounded, size: 17, color: mint),
              ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
          child: SelectableText(
            code,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              height: 1.7,
              color: Colors.white,
            ),
          ),
        ),
      ],
    ),
  );
}

class AiMarkdownResponse extends StatelessWidget {
  const AiMarkdownResponse({
    super.key,
    required this.text,
    this.streaming = false,
    this.foregroundColor,
  });
  final String text;
  final bool streaming;
  final Color? foregroundColor;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final part in aiResponseParts(text))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: part.language != null
                ? AiCodeBlock(code: part.text, language: part.language!)
                : _markdown(context, part.text, constraints.maxWidth),
          ),
      ],
    ),
  );

  Widget _markdown(BuildContext context, String value, double maxWidth) {
    final foregroundColor = this.foregroundColor ?? context.atelierInk;
    Widget body(String data) => MarkdownBody(
      data: data,
      blockSyntaxes: [AiMathBlockSyntax(streaming: streaming)],
      inlineSyntaxes: [
        AiMathInlineSyntax(),
        if (streaming) AiPendingMathSyntax(),
      ],
      builders: {
        'ai-math': AiMathBuilder(maxWidth: maxWidth),
        'ai-math-block': AiMathBuilder(maxWidth: maxWidth, block: true),
        'ai-math-pending': AiPendingMathBuilder(),
      },
      selectable: true,
      softLineBreak: true,
      imageBuilder: (_, _, _) => Text(
        '[Image omitted]',
        style: TextStyle(color: context.atelierMuted),
      ),
      onTapLink: (_, href, _) async {
        if (href == null || !isSafeAiLink(href)) return;
        final approved = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Open this link?'),
            content: SelectableText(href),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Open'),
              ),
            ],
          ),
        );
        if (approved == true) {
          try {
            final opened = await launchUrl(
              Uri.parse(href),
              mode: LaunchMode.externalApplication,
            );
            if (!opened && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Could not open this link.')),
              );
            }
          } catch (_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Could not open this link.')),
              );
            }
          }
        }
      },
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: TextStyle(color: foregroundColor, fontSize: 15, height: 1.7),
        h1: TextStyle(
          color: foregroundColor,
          fontSize: 23,
          fontWeight: FontWeight.w700,
          height: 1.4,
        ),
        h2: TextStyle(
          color: foregroundColor,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          height: 1.4,
        ),
        h3: TextStyle(
          color: foregroundColor,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          height: 1.4,
        ),
        code: TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          color: context.atelierAccent,
          backgroundColor: context.atelierTonal,
        ),
        blockquoteDecoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Theme.of(context).colorScheme.surfaceContainerHigh
              : SaveTrackDesign.mist,
          borderRadius: BorderRadius.circular(8),
        ),
        blockquote: TextStyle(
          color: foregroundColor,
          fontSize: 15,
          height: 1.7,
        ),
        listBullet: TextStyle(color: context.atelierAccent, fontSize: 15),
        tableHead: TextStyle(
          color: foregroundColor,
          fontWeight: FontWeight.w700,
        ),
        tableBody: TextStyle(color: foregroundColor, fontSize: 14, height: 1.6),
        tableHeadAlign: TextAlign.left,
        tableBorder: TableBorder.all(color: context.atelierBorder),
        tableColumnWidth: const FlexColumnWidth(),
        tableVerticalAlignment: TableCellVerticalAlignment.top,
        tableCellsPadding: const EdgeInsets.all(10),
        blockSpacing: 14,
      ),
    );
    // GFM table blocks get their own horizontal viewport rather than squeezing
    // wide cells into a phone. Other paragraphs keep natural line wrapping.
    final structured = RegExp(
      r'(^.*\|.*\n[ \t]*\|?[: \t-]+\|[:| \t-]+\n(?:[^\n]*\|[^\n]*(?:\n|$))*)|(^ {0,3}>[^\n]*(?:\n {0,3}>[^\n]*)*)',
      multiLine: true,
    );
    final children = <Widget>[];
    var start = 0;
    for (final match in structured.allMatches(value)) {
      if (match.start > start) {
        children.add(body(value.substring(start, match.start)));
      }
      if (match[1] != null) {
        children.add(AiComparisonCard(child: body(match[1]!)));
      } else {
        final quote = match[2]!.replaceAll(
          RegExp(r'^ {0,3}> ?', multiLine: true),
          '',
        );
        children.add(AiInsightCard(child: body(quote)));
      }
      start = match.end;
    }
    if (start < value.length) children.add(body(value.substring(start)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

/// Render only content present in the answer; never infer financial facts.
class AiInsightCard extends StatelessWidget {
  const AiInsightCard({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(vertical: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: context.atelierTonal,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: context.atelierBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Icon(
            Icons.lightbulb_outline_rounded,
            color: context.atelierAccent,
            size: 20,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

class AiComparisonCard extends StatelessWidget {
  const AiComparisonCard({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(vertical: 12),
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: context.atelierSurface,
      border: Border.all(color: context.atelierBorder),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(
                Icons.table_chart_outlined,
                size: 18,
                color: context.atelierAccent,
              ),
              Text(
                'At a glance',
                style: TextStyle(
                  color: context.atelierInk,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Scroll to explore →',
                style: TextStyle(color: context.atelierMuted, fontSize: 11),
              ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: SizedBox(width: 560, child: child),
        ),
      ],
    ),
  );
}
