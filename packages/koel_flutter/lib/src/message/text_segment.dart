part of 'message_segment.dart';

/// A verbatim run of prose between fenced code blocks.
///
/// [text] is the exact source text of the run with no trimming or markdown
/// stripping — inline backticks, emphasis markers, and links pass through
/// untouched (F-E1 defers rich-content rendering to a future `koel_a2ui`
/// package). The parser never emits a [TextSegment] with empty [text], so a
/// renderer can treat one as always-printable.
final class TextSegment extends MessageSegment {
  /// Wraps a verbatim prose run [text].
  const TextSegment(this.text);

  /// The verbatim prose run.
  final String text;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TextSegment && other.text == text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'TextSegment($text)';
}
