part 'text_segment.dart';
part 'code_block_segment.dart';

/// One piece of a parsed assistant message — either a prose run or a fenced
/// code block (F-E1).
///
/// `MessageContentParser.parse` splits an assistant message string into an
/// ordered `List<MessageSegment>` so a renderer can lay out mixed prose and
/// code without re-parsing markdown per widget. The union is closed at exactly
/// two leaves: [TextSegment] (verbatim prose) and [CodeBlockSegment] (a
/// backtick-fenced block with an optional language hint).
///
/// `sealed` restricts subtyping to this library, so a `switch` over a
/// [MessageSegment] is exhaustive and `koel_lints`'
/// `exhaustive_switch_must_have_default` forces consumers to keep a `default:`
/// arm — the seam that keeps their `switch`es non-crashing if a later minor
/// version adds a member (forward-compat policy). That rule is also why each
/// leaf is a `part of` this library: a sealed type can only be extended within
/// the library that declares it (mirrors `koel_core`'s `AgUiEvent` layout).
///
/// Unlike `AgUiEvent`, a segment is **render-time only** — derived on demand
/// from already-decoded message text, never persisted or wire-decoded — so it
/// carries no codec.
sealed class MessageSegment {
  const MessageSegment();
}
