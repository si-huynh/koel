import 'dart:async';
import 'dart:convert';

import 'package:koel_core/koel_core.dart';

/// The wire→domain boundary of `koel_http`: a hand-rolled, dependency-free SSE
/// parser that turns a raw byte stream into a typed [AgUiEvent] stream (AR-8).
///
/// [parse] does the whole job — UTF-8 stream decode (BOM-stripped) → RFC 8895 /
/// WHATWG `text/event-stream` framing → `jsonDecode` of each frame's
/// accumulated `data` → [AgUiEvent.fromWire]. The SSE frame (the `event`/`data`/
/// `id`/`retry` fields) is an internal intermediate; it is never exported, and
/// AG-UI's event type lives in the JSON `data` payload's `type`, not the SSE
/// `event:` line.
///
/// **Error contract (two-sided):**
/// - Corrupt `data` JSON (a [FormatException] from `jsonDecode`, or a payload
///   that is not a JSON object) surfaces as `ProtocolError(protocolMalformed)`
///   on the stream — the FR-A11 wire-sanity boundary, the same mapping
///   `DefaultErrorClassifier` applies to a [FormatException].
/// - Well-formed JSON carrying an unrecognized `type` is **not** an error: it
///   deserializes to `UnknownAgUiEvent` via the total [AgUiEvent.fromWire]
///   (FR-A6). The one-line rule: *`jsonDecode` failing is a `ProtocolError`;
///   `fromWire` of a parsed map is never an error.*
///
/// Stateless and `const` — all per-call state lives inside [parse]'s generator,
/// so one instance is safely shared across concurrent streams.
final class SseParser {
  /// Const default constructor; the parser holds no per-call state.
  const SseParser();

  /// Decodes [bytes] (a `text/event-stream` byte stream) into the typed
  /// [AgUiEvent]s it carries, in wire order.
  ///
  /// Framing is RFC 8895 / WHATWG `event-stream`: lines terminate on `\r\n`,
  /// `\r`, or `\n` (a `\r` straddling a chunk boundary is resolved against the
  /// next chunk); a leading `:` marks a comment; `field:value` strips one
  /// optional leading space; a blank line dispatches the accumulated frame;
  /// `data` lines are joined with `\n` and the single trailing `\n` is dropped
  /// at dispatch. The `event`/`id`/`retry` fields are recognized SSE fields and
  /// are kept out of the `data` payload; their retention (Last-Event-ID,
  /// reconnect `retry`) lands with reconnect support in Story 4.4.
  ///
  /// A frame with no `data` line (comment-only or `event:`-only) dispatches
  /// nothing. A final frame whose data is not closed by a blank line is still
  /// flushed when [bytes] completes. Source stream errors propagate unchanged;
  /// corrupt `data` JSON surfaces as `ProtocolError(protocolMalformed)` (see
  /// the class contract).
  Stream<AgUiEvent> parse(Stream<List<int>> bytes) async* {
    final data = StringBuffer();
    await for (final line in _lines(bytes)) {
      final event = _consume(line, data);
      if (event != null) yield event;
    }
    // EOF: flush a final frame whose data was never closed by a blank line.
    final tail = _consume('', data);
    if (tail != null) yield tail;
  }

  /// Splits [bytes] into logical SSE lines: UTF-8 stream-decoded (a multi-byte
  /// sequence split across chunks is handled; `Utf8Decoder` strips a leading BOM
  /// itself, and with `allowMalformed` a sequence left truncated at end-of-stream
  /// decodes to U+FFFD instead of throwing — matching EventSource leniency rather
  /// than leaking a raw `FormatException`), then broken on `\r\n` / `\r` / `\n`.
  /// A trailing `\r` at a chunk boundary is deferred until the next chunk so a
  /// straddling `\r\n` counts as one break.
  Stream<String> _lines(Stream<List<int>> bytes) async* {
    var pending = '';
    await for (final text in bytes.transform(
      const Utf8Decoder(allowMalformed: true),
    )) {
      pending += text;
      var start = 0;
      var i = 0;
      while (i < pending.length) {
        final c = pending.codeUnitAt(i);
        if (c != 0x0A && c != 0x0D) {
          i++;
          continue;
        }
        // A CR at the very end might be the first half of a chunk-straddling
        // CRLF — leave it for the next chunk to resolve.
        if (c == 0x0D && i == pending.length - 1) break;
        yield pending.substring(start, i);
        i += (c == 0x0D && pending.codeUnitAt(i + 1) == 0x0A) ? 2 : 1;
        start = i;
      }
      pending = pending.substring(start);
    }
    if (pending.endsWith('\r')) {
      pending = pending.substring(0, pending.length - 1);
    }
    if (pending.isNotEmpty) yield pending;
  }

  /// Folds one SSE [line] into the [data] accumulator, returning the dispatched
  /// [AgUiEvent] on a blank line (frame boundary) or `null` otherwise.
  AgUiEvent? _consume(String line, StringBuffer data) {
    if (line.isEmpty) {
      if (data.isEmpty) return null;
      final raw = data.toString();
      data.clear();
      // `data` lines were joined with a trailing `\n`; drop the final one.
      final payload = raw.endsWith('\n')
          ? raw.substring(0, raw.length - 1)
          : raw;
      // A frame whose only `data` content is empty (e.g. `data:\n\n`) carries no
      // AG-UI event — dispatch nothing rather than feeding `""` to `jsonDecode`.
      if (payload.isEmpty) return null;
      return _dispatch(payload);
    }
    if (line.startsWith(':')) return null; // comment line — ignored
    final colon = line.indexOf(':');
    final field = colon == -1 ? line : line.substring(0, colon);
    // Only `data` accumulates; `event`/`id`/`retry` and unknown fields are
    // recognized SSE fields the dispatch does not consume (see [parse]).
    if (field == 'data') {
      var value = colon == -1 ? '' : line.substring(colon + 1);
      if (value.startsWith(' ')) value = value.substring(1);
      data
        ..write(value)
        ..write('\n');
    }
    return null;
  }

  /// Decodes a frame's accumulated `data` JSON and dispatches it through the
  /// total [AgUiEvent.fromWire]. Corrupt JSON — a [FormatException] or a
  /// non-object payload — surfaces as `ProtocolError(protocolMalformed)`,
  /// mirroring `DefaultErrorClassifier`'s [FormatException] arm without
  /// threading a `RunAgentInput` through this transport-internal boundary.
  AgUiEvent _dispatch(String data) {
    final Object? decoded;
    try {
      decoded = jsonDecode(data);
    } on FormatException catch (e) {
      throw ProtocolError(
        message: 'Malformed SSE data payload',
        code: KoelErrorCode.protocolMalformed,
        cause: e,
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw ProtocolError(
        message:
            'SSE data payload is not a JSON object '
            '(got ${decoded.runtimeType})',
        code: KoelErrorCode.protocolMalformed,
      );
    }
    return AgUiEvent.fromWire(decoded);
  }
}
