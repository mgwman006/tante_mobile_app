import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

const _richTextTags = {
  'p',
  'div',
  'br',
  'strong',
  'b',
  'em',
  'i',
  'u',
  'ul',
  'ol',
  'li',
  'blockquote',
};

String sanitizeRichHtml(String value) {
  final fragment = html_parser.parseFragment(value);
  return fragment.nodes.map(_sanitizeRichTextNode).join();
}

String _sanitizeRichTextNode(dom.Node node) {
  if (node is dom.Text) {
    return const HtmlEscape(HtmlEscapeMode.element).convert(node.data);
  }
  if (node is! dom.Element) return '';
  final tag = node.localName?.toLowerCase();
  if (tag == 'script' || tag == 'style') return '';

  final children = node.nodes.map(_sanitizeRichTextNode).join();
  if (tag == null || !_richTextTags.contains(tag)) return children;
  if (tag == 'br') return '<br>';
  final normalizedTag = tag == 'div' ? 'p' : tag;
  return '<$normalizedTag>$children</$normalizedTag>';
}

class RichHtmlContent extends StatelessWidget {
  const RichHtmlContent({super.key, required this.html});

  final String html;

  @override
  Widget build(BuildContext context) {
    final fragment = html_parser.parseFragment(sanitizeRichHtml(html));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _renderTermsNodes(context, fragment.nodes),
    );
  }
}

List<Widget> _renderTermsNodes(BuildContext context, List<dom.Node> nodes) {
  final widgets = <Widget>[];
  for (final node in nodes) {
    if (node is dom.Text) {
      if (node.data.trim().isNotEmpty) widgets.add(_termsText(context, [node]));
      continue;
    }
    if (node is! dom.Element) continue;

    switch (node.localName?.toLowerCase()) {
      case 'p':
      case 'div':
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _termsText(context, node.nodes),
          ),
        );
      case 'ul':
      case 'ol':
        final ordered = node.localName?.toLowerCase() == 'ol';
        var index = 0;
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: node.nodes.whereType<dom.Element>().map((item) {
                if (item.localName?.toLowerCase() != 'li') {
                  return const SizedBox.shrink();
                }
                index++;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 26,
                        child: Text(ordered ? '$index.' : '\u2022'),
                      ),
                      Expanded(child: _termsText(context, item.nodes)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        );
      case 'blockquote':
        widgets.add(
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.only(left: 12),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 3,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _renderTermsNodes(context, node.nodes),
            ),
          ),
        );
      default:
        widgets.add(_termsText(context, [node]));
    }
  }
  return widgets;
}

Widget _termsText(BuildContext context, List<dom.Node> nodes) {
  final defaultStyle = DefaultTextStyle.of(context).style;
  return SelectableText.rich(
    TextSpan(
      style: defaultStyle,
      children: nodes
          .map((node) => _termsInlineSpan(node, defaultStyle))
          .toList(),
    ),
  );
}

TextSpan _termsInlineSpan(dom.Node node, TextStyle inheritedStyle) {
  if (node is dom.Text) return TextSpan(text: node.data);
  if (node is! dom.Element) return const TextSpan();
  final tag = node.localName?.toLowerCase();
  if (tag == 'br') return const TextSpan(text: '\n');
  final style = switch (tag) {
    'strong' ||
    'b' => inheritedStyle.merge(const TextStyle(fontWeight: FontWeight.bold)),
    'em' ||
    'i' => inheritedStyle.merge(const TextStyle(fontStyle: FontStyle.italic)),
    'u' => inheritedStyle.merge(
      const TextStyle(decoration: TextDecoration.underline),
    ),
    _ => inheritedStyle,
  };
  return TextSpan(
    style: style,
    children: node.nodes
        .map((child) => _termsInlineSpan(child, style))
        .toList(),
  );
}

class _TextFormatRange {
  const _TextFormatRange(this.start, this.end, this.tag);

  final int start;
  final int end;
  final String tag;
}

class _EditorTerms {
  const _EditorTerms(this.text, this.formats);

  final String text;
  final List<_TextFormatRange> formats;
}

class _RichTermsController extends TextEditingController {
  List<_TextFormatRange> formats = const [];

  void updateFormats(List<_TextFormatRange> updatedFormats) {
    formats = updatedFormats;
    notifyListeners();
  }

  Set<String> _formatsAt(int index) => formats
      .where((format) => format.start <= index && format.end > index)
      .map((format) => format.tag)
      .toSet();

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final effectiveStyle = style ?? const TextStyle();
    final spans = <TextSpan>[];
    var index = 0;
    while (index < text.length) {
      final activeFormats = _formatsAt(index);
      var end = index + 1;
      while (end < text.length && _sameSet(_formatsAt(end), activeFormats)) {
        end++;
      }
      var spanStyle = effectiveStyle;
      if (activeFormats.contains('strong')) {
        spanStyle = spanStyle.merge(
          const TextStyle(fontWeight: FontWeight.bold),
        );
      }
      if (activeFormats.contains('em')) {
        spanStyle = spanStyle.merge(
          const TextStyle(fontStyle: FontStyle.italic),
        );
      }
      if (activeFormats.contains('u')) {
        spanStyle = spanStyle.merge(
          const TextStyle(decoration: TextDecoration.underline),
        );
      }
      spans.add(TextSpan(text: text.substring(index, end), style: spanStyle));
      index = end;
    }
    return TextSpan(style: effectiveStyle, children: spans);
  }
}

bool _sameSet(Set<String> first, Set<String> second) =>
    first.length == second.length && first.containsAll(second);

class RichHtmlEditorDialog extends StatefulWidget {
  const RichHtmlEditorDialog({
    super.key,
    required this.html,
    this.title = 'Edit rich text',
    this.hintText = 'Write here...',
  });

  final String html;
  final String title;
  final String hintText;

  @override
  State<RichHtmlEditorDialog> createState() => _RichHtmlEditorDialogState();
}

class _RichHtmlEditorDialogState extends State<RichHtmlEditorDialog> {
  late final _controller = _makeController(widget.html);
  String _previousText = '';
  bool _showPreview = false;

  static _RichTermsController _makeController(String terms) {
    final parsed = _parseEditorTerms(terms);
    return _RichTermsController()
      ..text = parsed.text
      ..formats = parsed.formats;
  }

  @override
  void initState() {
    super.initState();
    _previousText = _controller.text;
    _controller.addListener(_handleTextChange);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChange);
    _controller.dispose();
    super.dispose();
  }

  void _handleTextChange() {
    final newText = _controller.text;
    if (newText == _previousText) return;
    final oldText = _previousText;
    var prefix = 0;
    while (prefix < oldText.length &&
        prefix < newText.length &&
        oldText[prefix] == newText[prefix]) {
      prefix++;
    }
    var suffix = 0;
    while (suffix < oldText.length - prefix &&
        suffix < newText.length - prefix &&
        oldText[oldText.length - suffix - 1] ==
            newText[newText.length - suffix - 1]) {
      suffix++;
    }
    final oldEnd = oldText.length - suffix;
    final newEnd = newText.length - suffix;
    final change = newEnd - oldEnd;

    int mapPosition(int position, {required bool isEnd}) {
      if (position <= prefix) return position;
      if (position >= oldEnd) return position + change;
      return isEnd ? newEnd : prefix;
    }

    _controller.formats = _controller.formats
        .map(
          (format) => _TextFormatRange(
            mapPosition(format.start, isEnd: false),
            mapPosition(format.end, isEnd: true),
            format.tag,
          ),
        )
        .where((format) => format.end > format.start)
        .toList();
    _previousText = newText;
    if (mounted) setState(() {});
  }

  void _toggleFormat(String tag) {
    final selection = _controller.selection;
    if (!selection.isValid || selection.isCollapsed) return;
    setState(() {
      final applied = _controller.formats.any(
        (format) =>
            format.tag == tag &&
            format.start <= selection.start &&
            format.end >= selection.end,
      );
      if (applied) {
        _controller.updateFormats(
          _controller.formats.where((format) {
            return format.tag != tag ||
                format.end <= selection.start ||
                format.start >= selection.end;
          }).toList(),
        );
      } else {
        _controller.updateFormats([
          ..._controller.formats,
          _TextFormatRange(selection.start, selection.end, tag),
        ]);
      }
    });
  }

  void _insertBlockPrefix(String prefix, {bool numbered = false}) {
    final selection = _controller.selection;
    final text = _controller.text;
    final selectionStart = selection.isValid ? selection.start : text.length;
    final selectionEnd = selection.isValid ? selection.end : text.length;
    final lineStart = selectionStart == 0
        ? 0
        : text.lastIndexOf('\n', selectionStart - 1) + 1;
    final nextBreak = text.indexOf('\n', selectionEnd);
    final lineEnd = nextBreak < 0 ? text.length : nextBreak;
    final lines = text.substring(lineStart, lineEnd).split('\n');
    final marker = RegExp(r'^(?:\u2022 |\d+\. |> )');
    final replacement = lines.indexed
        .map((entry) {
          final line = entry.$2.replaceFirst(marker, '');
          return '${numbered ? '${entry.$1 + 1}. ' : prefix}$line';
        })
        .join('\n');
    final updatedText = text.replaceRange(lineStart, lineEnd, replacement);
    _controller.value = TextEditingValue(
      text: updatedText,
      selection: TextSelection.collapsed(
        offset: lineStart + replacement.length,
      ),
    );
    setState(() => _showPreview = false);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 560,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Bold',
                  onPressed: () => _toggleFormat('strong'),
                  icon: const Icon(Icons.format_bold),
                ),
                IconButton(
                  tooltip: 'Italic',
                  onPressed: () => _toggleFormat('em'),
                  icon: const Icon(Icons.format_italic),
                ),
                IconButton(
                  tooltip: 'Underline',
                  onPressed: () => _toggleFormat('u'),
                  icon: const Icon(Icons.format_underline),
                ),
                IconButton(
                  tooltip: 'Bulleted list',
                  onPressed: () => _insertBlockPrefix('\u2022 '),
                  icon: const Icon(Icons.format_list_bulleted),
                ),
                IconButton(
                  tooltip: 'Numbered list',
                  onPressed: () => _insertBlockPrefix('', numbered: true),
                  icon: const Icon(Icons.format_list_numbered),
                ),
                IconButton(
                  tooltip: 'Block quote',
                  onPressed: () => _insertBlockPrefix('> '),
                  icon: const Icon(Icons.format_quote),
                ),
                TextButton.icon(
                  onPressed: () => setState(() => _showPreview = !_showPreview),
                  icon: Icon(
                    _showPreview
                        ? Icons.edit_outlined
                        : Icons.visibility_outlined,
                  ),
                  label: Text(_showPreview ? 'Edit' : 'Preview'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: _showPreview
                ? SingleChildScrollView(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: RichHtmlContent(
                        html: _serializeEditorTerms(
                          _controller.text,
                          _controller.formats,
                        ),
                      ),
                    ),
                  )
                : TextField(
                    controller: _controller,
                    style: Theme.of(context).textTheme.bodyLarge,
                    minLines: 8,
                    maxLines: 14,
                    keyboardType: TextInputType.multiline,
                    decoration: InputDecoration(
                      hintText: widget.hintText,
                      border: OutlineInputBorder(),
                    ),
                  ),
          ),
          if (!_showPreview)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Select text to format. Use list buttons to start a list.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(
          context,
          sanitizeRichHtml(
            _serializeEditorTerms(_controller.text, _controller.formats),
          ),
        ),
        child: const Text('Save'),
      ),
    ],
  );
}

_EditorTerms _parseEditorTerms(String html) {
  final document = html_parser.parseFragment(sanitizeRichHtml(html));
  final text = StringBuffer();
  final formats = <_TextFormatRange>[];

  void ensureLineBreak() {
    if (text.isNotEmpty && !text.toString().endsWith('\n')) text.write('\n');
  }

  void appendText(String value, Set<String> activeFormats) {
    if (value.isEmpty) return;
    final start = text.length;
    text.write(value);
    for (final tag in activeFormats) {
      formats.add(_TextFormatRange(start, start + value.length, tag));
    }
  }

  void parseNodes(List<dom.Node> nodes, Set<String> activeFormats) {
    for (final node in nodes) {
      if (node is dom.Text) {
        if (node.data.trim().isEmpty && node.data.contains('\n')) continue;
        appendText(node.data, activeFormats);
        continue;
      }
      if (node is! dom.Element) continue;
      final tag = node.localName?.toLowerCase();
      if (tag == 'br') {
        text.write('\n');
      } else if (tag == 'p' || tag == 'div') {
        ensureLineBreak();
        parseNodes(node.nodes, activeFormats);
        ensureLineBreak();
      } else if (tag == 'ul' || tag == 'ol') {
        var index = 0;
        for (final item in node.children.where(
          (element) => element.localName?.toLowerCase() == 'li',
        )) {
          ensureLineBreak();
          index++;
          appendText(tag == 'ul' ? '\u2022 ' : '$index. ', const {});
          parseNodes(item.nodes, activeFormats);
          ensureLineBreak();
        }
      } else if (tag == 'li') {
        ensureLineBreak();
        parseNodes(node.nodes, activeFormats);
        ensureLineBreak();
      } else if (tag == 'blockquote') {
        ensureLineBreak();
        appendText('> ', const {});
        parseNodes(node.nodes, activeFormats);
        ensureLineBreak();
      } else {
        final nextFormats = {...activeFormats};
        if (tag == 'strong' || tag == 'b') nextFormats.add('strong');
        if (tag == 'em' || tag == 'i') nextFormats.add('em');
        if (tag == 'u') nextFormats.add('u');
        parseNodes(node.nodes, nextFormats);
      }
    }
  }

  parseNodes(document.nodes, const {});
  var plainText = text.toString();
  while (plainText.endsWith('\n')) {
    plainText = plainText.substring(0, plainText.length - 1);
  }
  return _EditorTerms(
    plainText,
    formats.where((format) => format.end <= plainText.length).toList(),
  );
}

String _serializeEditorTerms(String text, List<_TextFormatRange> formats) {
  if (text.isEmpty) return '';
  final lines = text.split('\n');
  final output = StringBuffer();
  final blockKinds = <String>[];
  var offset = 0;

  for (var index = 0; index < lines.length; index++) {
    final line = lines[index];
    final match = RegExp(r'^(\u2022 |\d+\. |> )').firstMatch(line);
    final kind = match == null
        ? 'p'
        : match.group(0)!.startsWith('> ')
        ? 'blockquote'
        : match.group(0)!.startsWith('\u2022 ')
        ? 'ul'
        : 'ol';
    final markerLength = match?.end ?? 0;
    final content = _serializeInlineText(
      line.substring(markerLength),
      offset + markerLength,
      formats,
    );
    if (kind == 'ul' || kind == 'ol') {
      blockKinds.add(kind);
      if (index + 1 == lines.length || _lineKind(lines[index + 1]) != kind) {
        output.write('<$kind>');
        final start = index - blockKinds.length + 1;
        var lineOffset = offset;
        for (var lineIndex = 0; lineIndex < start; lineIndex++) {
          lineOffset += lines[lineIndex].length + 1;
        }
        for (var lineIndex = start; lineIndex <= index; lineIndex++) {
          final listLine = lines[lineIndex];
          final listMatch = RegExp(r'^(\u2022 |\d+\. )').firstMatch(listLine)!;
          output.write(
            '<li>${_serializeInlineText(listLine.substring(listMatch.end), lineOffset + listMatch.end, formats)}</li>',
          );
          lineOffset += listLine.length + 1;
        }
        output.write('</$kind>');
        blockKinds.clear();
      }
    } else {
      blockKinds.clear();
      if (kind == 'blockquote') {
        output.write('<blockquote><p>$content</p></blockquote>');
      } else {
        output.write('<p>$content</p>');
      }
    }
    offset += line.length + (index + 1 < lines.length ? 1 : 0);
  }
  return output.toString();
}

String _lineKind(String line) {
  if (line.startsWith('\u2022 ')) return 'ul';
  if (RegExp(r'^\d+\. ').hasMatch(line)) return 'ol';
  return 'p';
}

String _serializeInlineText(
  String text,
  int globalOffset,
  List<_TextFormatRange> formats,
) {
  final output = StringBuffer();
  var index = 0;
  while (index < text.length) {
    final active = formats
        .where(
          (format) =>
              format.start <= globalOffset + index &&
              format.end > globalOffset + index,
        )
        .map((format) => format.tag)
        .toSet();
    var end = index + 1;
    while (end < text.length) {
      final next = formats
          .where(
            (format) =>
                format.start <= globalOffset + end &&
                format.end > globalOffset + end,
          )
          .map((format) => format.tag)
          .toSet();
      if (!_sameSet(active, next)) break;
      end++;
    }
    final value = const HtmlEscape(
      HtmlEscapeMode.element,
    ).convert(text.substring(index, end));
    var encoded = value;
    if (active.contains('u')) encoded = '<u>$encoded</u>';
    if (active.contains('em')) encoded = '<em>$encoded</em>';
    if (active.contains('strong')) encoded = '<strong>$encoded</strong>';
    output.write(encoded);
    index = end;
  }
  return output.toString();
}
