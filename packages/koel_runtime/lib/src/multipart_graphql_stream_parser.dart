import 'dart:async';
import 'dart:convert';

import 'package:koel_core/koel_core.dart';

import 'conversion/graphql_event_conversion.dart';

/// The wire→domain boundary of `koel_runtime`: a hand-rolled, dependency-free
/// parser that turns the CopilotKit Next.js runtime's `multipart/mixed` (GraphQL
/// `@defer`/`@stream` Incremental Delivery) response bytes into a typed
/// [AgUiEvent] stream (AR-10, D5). The structural mirror of `koel_http`'s
/// `SseParser`, sharing its framing idioms — but with one essential difference:
/// it is **stateful**.
///
/// An SSE `data:` payload already *is* a canonical AG-UI event. A CopilotKit
/// multipart part is not — it is a GraphQL Incremental Delivery patch against one
/// evolving `generateCopilotResponse` document, meaningful only relative to the
/// parts before it. So framing is split in two: this class owns the
/// **framing** (boundary/delimiter/header/body splitting, chunk-boundary
/// buffering, UTF-8 decode) and delegates the **reconstruction** to a per-stream
/// [GraphQLIncrementalConverter].
///
/// **Error contract (two-sided, identical to `SseParser`):**
/// - A non-JSON part body, or a body that is not a JSON object, surfaces as
///   `ProtocolError(protocolMalformed)` on the stream — the wire-sanity boundary.
/// - Building events from a parsed part is never an error; an unmodelled
///   `__typename` is tolerated (skipped), mirroring `AgUiEvent.fromWire`'s
///   `UnknownAgUiEvent` leniency. Source-stream errors propagate unchanged.
///
/// **Out of scope (Story 5.8's job):** `RUN_STARTED`/`RUN_FINISHED`. The runtime
/// re-frames the agent's run-lifecycle into the *response envelope*
/// (`threadId`/`messages`/`hasNext`), not into message outputs, and the initial
/// part carries `runId:null` — which `RunStartedEvent`/`RunFinishedEvent` forbid.
/// The agent owns the `RunAgentInput.{threadId, runId}` and brackets this
/// parser's output with the run-lifecycle events.
///
/// The parser itself is stateless and `const`; the per-stream reconstruction
/// state lives in the [GraphQLIncrementalConverter] [parse] allocates per call,
/// so one instance is safely shared across concurrent streams.
final class MultipartGraphQLStreamParser {
  /// Const default constructor; the parser holds no per-call state.
  const MultipartGraphQLStreamParser();

  /// Decodes [bytes] (a `multipart/mixed; boundary="-"` GraphQL Incremental
  /// Delivery body) into the typed [AgUiEvent]s it carries, in wire order.
  ///
  /// Each part is decoded and fed to a fresh [GraphQLIncrementalConverter]; a
  /// single part can yield zero (the initial seed), one, or many events (the
  /// text run's part yields `START → 4×CONTENT → END`). The terminator
  /// (`-----`) completes the stream.
  Stream<AgUiEvent> parse(Stream<List<int>> bytes) async* {
    final converter = GraphQLIncrementalConverter();
    await for (final body in _parts(bytes)) {
      yield* Stream.fromIterable(converter.ingest(_decode(body)));
    }
  }

  /// Splits [bytes] into per-part JSON body strings, driving a three-phase line
  /// machine over the multipart framing (delimiter `---`, terminator `-----`,
  /// CRLF throughout). Each part is a header block (`Content-Type`,
  /// `Content-Length`, blank line) followed by one JSON object on one line.
  ///
  /// `Content-Length` is informational — framing is driven by the CRLF
  /// delimiter, not the length, so a wrong length can't desync the stream
  /// (`SseParser`'s framing-not-length discipline). An optional leading preamble
  /// (a blank line before the first `---`) is ignored; the terminator ends the
  /// stream cleanly.
  Stream<String> _parts(Stream<List<int>> bytes) async* {
    var phase = _Phase.boundary;
    await for (final line in _lines(bytes)) {
      switch (phase) {
        case _Phase.boundary:
          // `-----` ends the stream; `---` opens a part; anything else is
          // preamble whitespace before the first part and is ignored.
          if (line == _terminator) return;
          if (line == _delimiter) phase = _Phase.headers;
        case _Phase.headers:
          // The blank line closes the header block; Content-Type/Content-Length
          // lines are informational and ignored.
          if (line.isEmpty) phase = _Phase.body;
        case _Phase.body:
          // The part's one-line JSON body; next comes another delimiter.
          yield line;
          phase = _Phase.boundary;
      }
    }
  }

  /// Splits [bytes] into logical lines: UTF-8 stream-decoded (a multi-byte
  /// sequence split across chunks is handled; with `allowMalformed` a truncated
  /// tail decodes to U+FFFD instead of throwing), then broken on `\r\n` / `\r` /
  /// `\n`. A trailing `\r` at a chunk boundary is deferred until the next chunk
  /// so a straddling `\r\n` counts as one break. Identical to `SseParser._lines`.
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

  /// Decodes one part's JSON body. A [FormatException] or a non-object payload
  /// surfaces as `ProtocolError(protocolMalformed)` — byte-identical in spirit
  /// to `SseParser._dispatch`.
  Map<String, dynamic> _decode(String body) {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException catch (e) {
      throw ProtocolError(
        message: 'Malformed multipart GraphQL part body',
        code: KoelErrorCode.protocolMalformed,
        cause: e,
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw ProtocolError(
        message:
            'Multipart GraphQL part body is not a JSON object '
            '(got ${decoded.runtimeType})',
        code: KoelErrorCode.protocolMalformed,
      );
    }
    return decoded;
  }
}

/// The on-wire boundary line (`--` + the `-` boundary token) opening each part.
const _delimiter = '---';

/// The on-wire close-delimiter (`--` + `-` + `--`) ending the multipart body.
const _terminator = '-----';

/// Which segment of a part the line machine is consuming.
enum _Phase { boundary, headers, body }
