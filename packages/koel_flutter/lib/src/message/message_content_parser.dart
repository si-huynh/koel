import 'message_segment.dart';

/// Splits an assistant message string into an ordered `List<MessageSegment>`
/// of prose runs and backtick-fenced code blocks (F-E1).
///
/// `parse` is a **total pure function** of its input — it never throws and
/// holds no state, so a single `const MessageContentParser()` can be shared. It
/// is a render-time helper: it takes already-decoded assistant text (the
/// accumulated `Message` content after a run completes) and derives segments on
/// demand for display. It touches no `koel_core` state, reducer, or storage.
///
/// **What splits.** Only a line that is (after ≤3 leading spaces) a run of ≥3
/// backticks opens a [CodeBlockSegment]; the run length sets the close
/// threshold and the trimmed remainder becomes [CodeBlockSegment.language]. A
/// line of ≥that-many backticks with only trailing whitespace closes it; an
/// unclosed block runs to end-of-input. Everything else is verbatim
/// [TextSegment] text — including inline backticks like `` `foo()` ``, which
/// never open a fence because the line does not *start* with the backtick run.
///
/// **Out of scope** (deferred to the future `koel_a2ui` package): tilde
/// (`~~~`) fences, 4-space indented code, inline-code segmentation, and images
/// or other rich content. This is a deliberately narrow fenced-block split, not
/// a CommonMark renderer.
class MessageContentParser {
  /// Creates a stateless parser. `const` so a shared instance allocates once.
  const MessageContentParser();

  static const int _space = 0x20;
  static const int _tab = 0x09;
  static const int _backtick = 0x60;

  /// Matches a CRLF, a lone CR, or an LF — the three CommonMark line endings.
  static final RegExp _lineEnding = RegExp(r'\r\n|\r|\n');

  /// Parses [content] into alternating [TextSegment]/[CodeBlockSegment]s.
  ///
  /// The result never contains a [TextSegment] with empty [TextSegment.text]
  /// and never two adjacent [TextSegment]s — empty prose runs are suppressed,
  /// which is what makes prose and code strictly alternate. An empty [content]
  /// yields an empty list. CRLF, lone CR, and LF are all treated as line
  /// breaks (CommonMark), and bodies and prose runs are rejoined with `'\n'`.
  List<MessageSegment> parse(String content) {
    if (content.isEmpty) return const [];

    final segments = <MessageSegment>[];
    // Split on any of CRLF / lone CR / LF — CommonMark treats all three as line
    // endings, so the carriage return never leaks into a fence test or a body.
    final lines = content.split(_lineEnding);

    // Pending prose lines, flushed as one TextSegment when a fence opens or at
    // end-of-input — only if the joined run is non-empty (alternation guard).
    final textRun = <String>[];
    void flushText() {
      if (textRun.isEmpty) return;
      final text = textRun.join('\n');
      if (text.isNotEmpty) segments.add(TextSegment(text));
      textRun.clear();
    }

    // Non-null only while inside a code block. Holds the open fence's backtick
    // length and language, plus the accumulated body lines.
    int? fenceLen;
    String language = '';
    final codeLines = <String>[];

    for (final line in lines) {
      if (fenceLen == null) {
        final open = _openFence(line);
        if (open != null) {
          flushText();
          fenceLen = open.length;
          language = open.info;
          codeLines.clear();
        } else {
          textRun.add(line);
        }
      } else {
        if (_isCloseFence(line, fenceLen)) {
          segments.add(
            CodeBlockSegment(language: language, code: codeLines.join('\n')),
          );
          fenceLen = null;
        } else {
          codeLines.add(line);
        }
      }
    }

    // End-of-input: an unclosed block runs to EOF; otherwise flush pending prose.
    if (fenceLen != null) {
      segments.add(
        CodeBlockSegment(language: language, code: codeLines.join('\n')),
      );
    } else {
      flushText();
    }

    return segments;
  }

  /// Recognizes an opening fence: after ≤3 leading spaces, a run of ≥3
  /// backticks. Returns the run length and the trimmed info string, or `null`
  /// if [line] is not a fence.
  _OpenFence? _openFence(String line) {
    final start = _leadingSpaces(line);
    if (start > 3) return null;
    var i = start;
    while (i < line.length && line.codeUnitAt(i) == _backtick) {
      i++;
    }
    final ticks = i - start;
    if (ticks < 3) return null;
    return _OpenFence(ticks, line.substring(i).trim());
  }

  /// Recognizes a closing fence for an open block of [fenceLen] backticks:
  /// after ≤3 leading spaces, ≥[fenceLen] backticks followed by only optional
  /// trailing whitespace (no info string).
  bool _isCloseFence(String line, int fenceLen) {
    final start = _leadingSpaces(line);
    if (start > 3) return false;
    var i = start;
    while (i < line.length && line.codeUnitAt(i) == _backtick) {
      i++;
    }
    if (i - start < fenceLen) return false;
    for (; i < line.length; i++) {
      final c = line.codeUnitAt(i);
      if (c != _space && c != _tab) return false;
    }
    return true;
  }

  /// Counts leading space (U+0020) characters in [line].
  int _leadingSpaces(String line) {
    var n = 0;
    while (n < line.length && line.codeUnitAt(n) == _space) {
      n++;
    }
    return n;
  }
}

/// An opening fence's backtick-run [length] and trimmed [info] string.
class _OpenFence {
  const _OpenFence(this.length, this.info);

  final int length;
  final String info;
}
