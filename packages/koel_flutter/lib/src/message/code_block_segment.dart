part of 'message_segment.dart';

/// A backtick-fenced code block lifted out of an assistant message.
///
/// [code] is the block body — the lines strictly between the opening and
/// closing fence, joined by `'\n'`, with no trailing newline. An empty body
/// (open fence immediately followed by close, or by EOF) yields `code == ''`.
///
/// [language] is the fence's info string, trimmed — e.g. `'dart'` for
/// `` ```dart ``. It is `''` when the fence carried no info string. The whole
/// trimmed info string is kept verbatim (a rare multi-word info like
/// `dart title=x` is preserved as-is for the consumer to split); the parser
/// does not split on whitespace.
final class CodeBlockSegment extends MessageSegment {
  /// Wraps a code block's [code] body and its fence [language] info string.
  const CodeBlockSegment({required this.language, required this.code});

  /// The fence's trimmed info string, or `''` when the fence carried none.
  final String language;

  /// The verbatim block body, lines joined by `'\n'`, no trailing newline.
  final String code;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CodeBlockSegment &&
          other.language == language &&
          other.code == code;

  @override
  int get hashCode => Object.hash(language, code);

  @override
  String toString() => 'CodeBlockSegment(language: $language, code: $code)';
}
