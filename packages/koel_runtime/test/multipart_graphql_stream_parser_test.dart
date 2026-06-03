@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:koel_core/koel_core.dart';
import 'package:koel_runtime/koel_runtime.dart';
import 'package:test/test.dart';

import '_support.dart';

void main() {
  group('MultipartGraphQLStreamParser', () {
    const parser = MultipartGraphQLStreamParser();

    test('text run yields START → CONTENT ×4 → END in wire order', () async {
      // The default text scenario, authored from the SPIKE-CK-FRAMING raw
      // capture. The injected `AgentStateMessageOutput` (the `ck-<uuid>` element)
      // is omitted to keep this a pure text run — STATE mapping is exercised in
      // its own scenario; the response-level `status` is kept (→ no event).
      final parts = [
        initialPart(),
        incrementalPart([
          textStart(0, 'msg-text-1'),
          responseSuccess(),
          contentDelta(0, 0, 'Hello'),
          contentDelta(0, 1, ', '),
          contentDelta(0, 2, 'world'),
          contentDelta(0, 3, '.'),
          messageSuccess(0),
        ]),
      ];
      final events = await parser
          .parse(streamBytes(multipartBytes(parts)))
          .toList();
      expect(events, const [
        TextMessageStartEvent(messageId: 'msg-text-1', role: 'assistant'),
        TextMessageContentEvent(messageId: 'msg-text-1', delta: 'Hello'),
        TextMessageContentEvent(messageId: 'msg-text-1', delta: ', '),
        TextMessageContentEvent(messageId: 'msg-text-1', delta: 'world'),
        TextMessageContentEvent(messageId: 'msg-text-1', delta: '.'),
        TextMessageEndEvent(messageId: 'msg-text-1'),
      ]);
    });

    test('tool run yields START → ARGS ×2 → END', () async {
      final parts = [
        initialPart(),
        incrementalPart([
          actionStart(0, 'tool-1', 'get_weather'),
          argsDelta(0, 0, '{"city":'),
          argsDelta(0, 1, '"Hanoi"}'),
          messageSuccess(0),
        ]),
      ];
      final events = await parser
          .parse(streamBytes(multipartBytes(parts)))
          .toList();
      expect(events, const [
        ToolCallStartEvent(toolCallId: 'tool-1', toolCallName: 'get_weather'),
        ToolCallArgsEvent(toolCallId: 'tool-1', delta: '{"city":'),
        ToolCallArgsEvent(toolCallId: 'tool-1', delta: '"Hanoi"}'),
        ToolCallEndEvent(toolCallId: 'tool-1'),
      ]);
    });

    test(
      'state output yields STATE_SNAPSHOT (state JSON-string decoded)',
      () async {
        final parts = [
          initialPart(),
          incrementalPart([
            stateOutput(0, 'ck-1', {'count': 1}),
          ]),
        ];
        final events = await parser
            .parse(streamBytes(multipartBytes(parts)))
            .toList();
        expect(events, const [
          StateSnapshotEvent(state: {'count': 1}),
        ]);
      },
    );

    test('the initial seed part alone yields no events', () async {
      final events = await parser
          .parse(streamBytes(multipartBytes([initialPart()])))
          .toList();
      expect(events, isEmpty);
    });

    group('framing edge cases', () {
      test(
        '(a) a delimiter split mid-chunk resolves against the next chunk',
        () async {
          final parts = [
            initialPart(),
            incrementalPart([
              textStart(0, 'm1'),
              contentDelta(0, 0, 'hi'),
              messageSuccess(0),
            ]),
          ];
          final wireStr = multipartString(parts);
          // Cut three bytes into the `\r\n---\r\n` delimiter between part 1 and 2
          // (the prefix is ASCII, so the char offset is a valid byte offset).
          final at = wireStr.indexOf('\r\n---\r\n', 5) + 3;
          final events = await parser
              .parse(streamBytes(utf8.encode(wireStr), cuts: [at]))
              .toList();
          expect(events, const [
            TextMessageStartEvent(messageId: 'm1', role: 'assistant'),
            TextMessageContentEvent(messageId: 'm1', delta: 'hi'),
            TextMessageEndEvent(messageId: 'm1'),
          ]);
        },
      );

      test(
        '(b) extra leading preamble whitespace before the first part is ignored',
        () async {
          final parts = [
            initialPart(),
            incrementalPart([
              textStart(0, 'm1'),
              contentDelta(0, 0, 'hi'),
              messageSuccess(0),
            ]),
          ];
          final wireStr = '\r\n   \r\n${multipartString(parts)}';
          final events = await parser
              .parse(streamBytes(utf8.encode(wireStr)))
              .toList();
          expect(events, const [
            TextMessageStartEvent(messageId: 'm1', role: 'assistant'),
            TextMessageContentEvent(messageId: 'm1', delta: 'hi'),
            TextMessageEndEvent(messageId: 'm1'),
          ]);
        },
      );

      test(
        '(c) the trailing terminator completes the stream; epilogue is ignored',
        () async {
          final parts = [
            initialPart(),
            incrementalPart([
              textStart(0, 'm1'),
              contentDelta(0, 0, 'hi'),
              messageSuccess(0),
            ]),
          ];
          final wireStr = '${multipartString(parts)}trailing epilogue junk\r\n';
          final events = await parser
              .parse(streamBytes(utf8.encode(wireStr)))
              .toList();
          expect(events, const [
            TextMessageStartEvent(messageId: 'm1', role: 'assistant'),
            TextMessageContentEvent(messageId: 'm1', delta: 'hi'),
            TextMessageEndEvent(messageId: 'm1'),
          ]);
        },
      );

      test(
        '(d) a multi-byte UTF-8 sequence split across chunks is preserved',
        () async {
          final parts = [
            initialPart(),
            incrementalPart([
              textStart(0, 'm1'),
              contentDelta(0, 0, 'café'),
              messageSuccess(0),
            ]),
          ];
          final bytes = multipartBytes(parts);
          final splitAt =
              bytes.indexOf(0xC3) + 1; // inside the 2-byte é (0xC3 0xA9)
          final events = await parser
              .parse(streamBytes(bytes, cuts: [splitAt]))
              .toList();
          expect(events, const [
            TextMessageStartEvent(messageId: 'm1', role: 'assistant'),
            TextMessageContentEvent(messageId: 'm1', delta: 'café'),
            TextMessageEndEvent(messageId: 'm1'),
          ]);
        },
      );

      test(
        'every part delivered in its own chunk parses identically',
        () async {
          final parts = [
            initialPart(),
            incrementalPart([
              textStart(0, 'm1'),
              contentDelta(0, 0, 'hi'),
              messageSuccess(0),
            ]),
          ];
          final bytes = multipartBytes(parts);
          // Cut at each byte — maximal fragmentation stress on the buffer.
          final events = await parser
              .parse(
                streamBytes(
                  bytes,
                  cuts: [for (var i = 1; i < bytes.length; i++) i],
                ),
              )
              .toList();
          expect(events, const [
            TextMessageStartEvent(messageId: 'm1', role: 'assistant'),
            TextMessageContentEvent(messageId: 'm1', delta: 'hi'),
            TextMessageEndEvent(messageId: 'm1'),
          ]);
        },
      );
    });

    test(
      'a malformed (non-JSON) part body surfaces ProtocolError(protocolMalformed)',
      () {
        final stream = parser.parse(
          streamBytes(utf8.encode(rawMultipart(['{not valid json']))),
        );
        expect(
          stream,
          emitsError(
            isA<ProtocolError>().having(
              (e) => e.code,
              'code',
              KoelErrorCode.protocolMalformed,
            ),
          ),
        );
      },
    );

    test('a non-object JSON part body is a ProtocolError', () {
      final stream = parser.parse(
        streamBytes(utf8.encode(rawMultipart(['12345']))),
      );
      expect(
        stream,
        emitsError(
          isA<ProtocolError>().having(
            (e) => e.code,
            'code',
            KoelErrorCode.protocolMalformed,
          ),
        ),
      );
    });

    test('empty stream yields nothing and closes cleanly', () {
      expect(parser.parse(const Stream.empty()), emitsDone);
    });

    test('a stream truncated on a bare trailing CR closes cleanly', () async {
      // The byte stream ends mid-`\r\n` (a CR with no following LF, no
      // terminator) — the `_lines` chunk buffer leaves the dangling CR pending
      // and, at end-of-stream, trims it rather than emitting a phantom blank
      // line. Such a fragment never opens a part, so the stream closes with no
      // events (ported `SseParser` trailing-CR-at-EOF tolerance).
      final events = await parser
          .parse(streamBytes(utf8.encode('\r\n---\r')))
          .toList();
      expect(events, isEmpty);
    });

    test('propagates a source-stream error unchanged', () {
      final boom = Stream<List<int>>.error(StateError('boom'));
      expect(parser.parse(boom), emitsError(isA<StateError>()));
    });

    test('AC1: parser file is under the 250 LOC budget (target ~200)', () {
      final lines = File(
        'lib/src/multipart_graphql_stream_parser.dart',
      ).readAsLinesSync().length;
      expect(lines, lessThan(250));
    });
  });
}
