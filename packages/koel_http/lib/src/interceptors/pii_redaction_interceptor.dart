import 'package:koel_core/koel_core.dart';

/// Scrubs consumer-supplied [patterns] out of the **free-text content** an
/// `AgUiEvent` carries, replacing every match with `[REDACTED]` before the event
/// reaches subscribers or the reducer (Story 4.7 / FR-I2). **Default-OFF** — it
/// does nothing unless a consumer adds it to `HttpAgent(interceptors: …)`.
///
/// ```dart
/// HttpAgent(
///   url: endpoint,
///   interceptors: [
///     PIIRedactionInterceptor(patterns: [
///       RegExp(r'\b\d{4}-\d{4}-\d{4}-\d{4}\b'), // card numbers
///       RegExp(r'\b[\w.]+@[\w.]+\b'),           // emails
///     ]),
///   ],
/// );
/// ```
///
/// **What gets redacted — and what must not.** Only the human-readable *content*
/// fields are scrubbed: assistant text (`TextMessageContentEvent.delta`), tool
/// arguments (`ToolCallArgsEvent.delta`), tool results (`ToolCallResultEvent.
/// content`), reasoning text (`ReasoningMessageContentEvent.delta`), and the
/// optional `delta` of the convenience chunk events. **Structural identifiers —
/// `messageId`, `toolCallId`, `role`, `stepName`, `runId`, `CustomEvent.value`,
/// the encrypted reasoning blob — are never touched.** They route and correlate
/// the stream (the reducer keys deltas by `messageId`; `RetryInterceptor` rides a
/// reserved `CustomEvent`); scrubbing them would corrupt the protocol, not
/// protect a user. Redaction changes what a human *reads*, never what the SDK
/// *routes on*.
///
/// **Pattern is `RegExp` or `String`.** `List<Pattern>` accepts both — the
/// `dart:core` `Pattern` interface is implemented by `RegExp` and `String` alike,
/// and matching runs through `Pattern.allMatches`, so one code path covers regex
/// and literal matches.
///
/// **Order-independent, marker-safe.** All patterns are matched against the
/// *original* text in a single pass; overlapping matches coalesce into one
/// `[REDACTED]`. So the result does not depend on the order of [patterns], a
/// pattern can never re-match a marker an earlier pattern inserted, and an
/// empty-matching pattern (e.g. `\d*`) redacts only its non-empty matches rather
/// than splicing the marker between every character.
///
/// **Pre-pipeline, not a transform.** This is an [Interceptor] (it wraps
/// `chain.proceed` *before* the chunks/verify/apply/reduce pipeline), distinct
/// from the Epic-6 `KoelClient.transforms` post-reduce `StreamTransformer` path.
/// Redacting here guarantees the cleartext never reaches the reducer, the
/// subscribers, or persisted session storage.
///
/// `final` — there is no Epic-5 subclass (unlike `AuthInterceptor`).
final class PIIRedactionInterceptor implements Interceptor {
  /// Creates a redactor that replaces every match of every entry in [patterns]
  /// with `[REDACTED]` in the event stream's content fields (Addendum A.2).
  ///
  /// [patterns] must be non-empty: an empty list is a redactor that scrubs
  /// nothing — a privacy control that silently fails *open*. This throws
  /// [ArgumentError] rather than asserting so the guard survives release/AOT
  /// builds (where `assert`s are stripped), where a fail-open redactor is most
  /// dangerous.
  PIIRedactionInterceptor({required List<Pattern> patterns})
    : _patterns = List.unmodifiable(patterns) {
    if (patterns.isEmpty) {
      throw ArgumentError.value(patterns, 'patterns', 'must not be empty');
    }
  }

  final List<Pattern> _patterns;

  static const String _replacement = '[REDACTED]';

  @override
  Stream<AgUiEvent> intercept(InterceptorChain chain, RunAgentInput input) {
    // A pure, stateless per-event transform: `.map` is the whole job (the
    // `Interceptor` contract's own example shape). No `StreamController` wrapper
    // — redaction observes no lifecycle and `.map` forwards cancel transparently.
    return chain.proceed(input).map(_redact);
  }

  /// Returns [event] with its content field scrubbed, or [event] unchanged when
  /// it carries no redactable text. The final `_ => event` arm is the
  /// `exhaustive_switch_must_have_default` seam: a future `AgUiEvent` subtype
  /// passes through untouched rather than failing to compile.
  AgUiEvent _redact(AgUiEvent event) => switch (event) {
    TextMessageContentEvent e => e.copyWith(delta: _scrub(e.delta)),
    ToolCallArgsEvent e => e.copyWith(delta: _scrub(e.delta)),
    ToolCallResultEvent e => e.copyWith(content: _scrub(e.content)),
    ReasoningMessageContentEvent e => e.copyWith(delta: _scrub(e.delta)),
    TextMessageChunkEvent e when e.delta != null => e.copyWith(
      delta: _scrub(e.delta!),
    ),
    ToolCallChunkEvent e when e.delta != null => e.copyWith(
      delta: _scrub(e.delta!),
    ),
    ReasoningMessageChunkEvent e when e.delta != null => e.copyWith(
      delta: _scrub(e.delta!),
    ),
    _ => event,
  };

  /// Replaces every pattern match in [text] with [_replacement] in a single pass
  /// over the **original** string.
  ///
  /// This is deliberately not a fold of `replaceAll` calls. Folding rewrites the
  /// accumulator, which leaks three ways: (a) an empty-match pattern (`\d*`)
  /// splices the marker between every character; (b) a later pattern re-matches
  /// the `[REDACTED]` an earlier one inserted, corrupting the marker; (c) the
  /// result depends on pattern order. Matching the original text once, dropping
  /// empty matches, and coalescing overlapping spans removes all three: the
  /// marker is never re-scanned, and the output is order-independent.
  String _scrub(String text) {
    if (text.isEmpty) return text;

    // Every non-empty match of every pattern, against the untouched original.
    final matches = <Match>[
      for (final pattern in _patterns)
        for (final m in pattern.allMatches(text))
          if (m.end > m.start) m,
    ];
    if (matches.isEmpty) return text;

    // Sort by start (then end) so a single left-to-right pass can coalesce
    // overlapping spans — making the result independent of pattern order.
    matches.sort(
      (a, b) => a.start != b.start ? a.start - b.start : a.end - b.end,
    );

    final buffer = StringBuffer();
    var cursor = 0; // first index of `text` not yet emitted
    for (final m in matches) {
      if (m.start >= cursor) {
        // Disjoint from the previous redaction: emit the gap, then one marker.
        buffer
          ..write(text.substring(cursor, m.start))
          ..write(_replacement);
        cursor = m.end;
      } else if (m.end > cursor) {
        // Overlaps the previous redaction but reaches further: extend the span
        // (the marker is already written — just swallow the matched tail).
        cursor = m.end;
      }
      // Otherwise fully inside an already-redacted span — nothing to do.
    }
    buffer.write(text.substring(cursor));
    return buffer.toString();
  }
}
