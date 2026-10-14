import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../design_system.dart';

class AiResponsePart {
  const AiResponsePart(this.text, {this.language});
  final String text;
  final String? language;
}

/// Split complete fenced blocks without changing their whitespace. Markdown
/// runs only after streaming finishes; no HTML execution or external images.
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
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied'), duration: Duration(seconds: 1)),
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
  const AiMarkdownResponse({super.key, required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final part in aiResponseParts(text))
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: part.language != null
              ? AiCodeBlock(code: part.text, language: part.language!)
              : _markdown(context, part.text),
        ),
    ],
  );

  Widget _markdown(BuildContext context, String value) {
    Widget body(String data) => MarkdownBody(
      data: data,
      selectable: true,
      softLineBreak: false,
      imageBuilder: (_, _, _) =>
          const Text('[Image omitted]', style: TextStyle(color: muted)),
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
        p: const TextStyle(color: ink, fontSize: 15, height: 1.7),
        h1: const TextStyle(
          color: ink,
          fontSize: 23,
          fontWeight: FontWeight.w700,
          height: 1.4,
        ),
        h2: const TextStyle(
          color: ink,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          height: 1.4,
        ),
        h3: const TextStyle(
          color: ink,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          height: 1.4,
        ),
        code: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          color: teal,
          backgroundColor: SaveTrackDesign.mist,
        ),
        blockquoteDecoration: BoxDecoration(
          color: SaveTrackDesign.mist,
          borderRadius: BorderRadius.circular(8),
        ),
        tableBorder: TableBorder.all(color: SaveTrackDesign.border),
        tableCellsPadding: const EdgeInsets.all(10),
        blockSpacing: 14,
      ),
    );
    // GFM table blocks get their own horizontal viewport rather than squeezing
    // wide cells into a phone. Other paragraphs keep natural line wrapping.
    final table = RegExp(
      r'^.*\|.*\n[ \t]*\|?[: \t-]+\|[:| \t-]+\n(?:[^\n]*\|[^\n]*(?:\n|$))*',
      multiLine: true,
    );
    final children = <Widget>[];
    var start = 0;
    for (final match in table.allMatches(value)) {
      if (match.start > start) {
        children.add(body(value.substring(start, match.start)));
      }
      children.add(
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(width: 560, child: body(match[0]!)),
        ),
      );
      start = match.end;
    }
    if (start < value.length) children.add(body(value.substring(start)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}
