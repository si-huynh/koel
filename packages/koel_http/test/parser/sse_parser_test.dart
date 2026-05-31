import 'dart:convert';
import 'dart:io';

import 'package:koel_core/koel_core.dart';
import 'package:koel_http/koel_http.dart';
import 'package:test/test.dart';

/// Encodes each string part into its own `List<int>` chunk so a fixture can
/// control exactly where the byte stream is split.
Stream<List<int>> chunks(List<String> parts) =>
    Stream.fromIterable(parts.map(utf8.encode));

/// A single-chunk byte stream from one wire string.
Stream<List<int>> wire(String s) => chunks([s]);

/// Wire JSON for a `TEXT_MESSAGE_CONTENT` frame with [id]/[delta].
String content(String id, String delta) => jsonEncode({
  'type': 'TEXT_MESSAGE_CONTENT',
  'messageId': id,
  'delta': delta,
});

void main() {
  group('SseParser', () {
    const parser = SseParser();

    test('decodes a single LF-terminated frame to a typed event', () async {
      final events = await parser
          .parse(wire('data: ${content('m', 'hi')}\n\n'))
          .toList();
      expect(events, [
        const TextMessageContentEvent(messageId: 'm', delta: 'hi'),
      ]);
    });

    test('handles CRLF line endings', () async {
      final events = await parser
          .parse(wire('data: ${content('m', 'hi')}\r\n\r\n'))
          .toList();
      expect(events, [
        const TextMessageContentEvent(messageId: 'm', delta: 'hi'),
      ]);
    });

    test('handles bare-CR line endings', () async {
      final events = await parser
          .parse(wire('data: ${content('m', 'hi')}\r\r'))
          .toList();
      expect(events, [
        const TextMessageContentEvent(messageId: 'm', delta: 'hi'),
      ]);
    });

    test('handles mixed CR / LF / CRLF terminators across frames', () async {
      final src =
          'data: ${content('a', '1')}\r\n\r'
          'data: ${content('b', '2')}\n\n';
      final events = await parser.parse(wire(src)).toList();
      expect(events, [
        const TextMessageContentEvent(messageId: 'a', delta: '1'),
        const TextMessageContentEvent(messageId: 'b', delta: '2'),
      ]);
    });

    test(
      'joins multi-line data fields with newlines before decoding',
      () async {
        // The JSON object is split across two `data:` lines; the parser rejoins
        // them with `\n` into one valid payload.
        const src =
            'data: {"type":"TEXT_MESSAGE_CONTENT",\n'
            'data: "messageId":"m","delta":"hi"}\n\n';
        final events = await parser.parse(wire(src)).toList();
        expect(events, [
          const TextMessageContentEvent(messageId: 'm', delta: 'hi'),
        ]);
      },
    );

    test('strips a leading BOM exactly once', () async {
      final events = await parser
          .parse(wire('﻿data: ${content('m', 'hi')}\n\n'))
          .toList();
      expect(events, [
        const TextMessageContentEvent(messageId: 'm', delta: 'hi'),
      ]);
    });

    test('ignores comment lines', () async {
      final src =
          ': this is a comment\n'
          'data: ${content('m', 'hi')}\n\n';
      final events = await parser.parse(wire(src)).toList();
      expect(events, [
        const TextMessageContentEvent(messageId: 'm', delta: 'hi'),
      ]);
    });

    test('parses event:/id:/retry: fields without polluting data', () async {
      final src =
          'event: message\n'
          'id: 42\n'
          'retry: 3000\n'
          'data: ${content('m', 'hi')}\n\n';
      final events = await parser.parse(wire(src)).toList();
      expect(events, [
        const TextMessageContentEvent(messageId: 'm', delta: 'hi'),
      ]);
    });

    group('partial chunks split mid-field', () {
      test('one frame delivered across multiple chunks', () async {
        final src = 'data: ${content('m', 'hi')}\n\n';
        final mid = src.length ~/ 2;
        final events = await parser
            .parse(chunks([src.substring(0, mid), src.substring(mid)]))
            .toList();
        expect(events, [
          const TextMessageContentEvent(messageId: 'm', delta: 'hi'),
        ]);
      });

      test(
        'CRLF split across the chunk boundary counts as one break',
        () async {
          // First chunk ends on the lone `\r`; the `\n` arrives next chunk.
          final events = await parser
              .parse(chunks(['data: ${content('m', 'hi')}\r', '\n\r\n']))
              .toList();
          expect(events, [
            const TextMessageContentEvent(messageId: 'm', delta: 'hi'),
          ]);
        },
      );

      test(
        'a multi-byte UTF-8 sequence split across chunks is preserved',
        () async {
          // "café" — the é is two UTF-8 bytes; split between them.
          final payload = utf8.encode('data: ${content('m', 'café')}\n\n');
          // Find a safe split point inside the 2-byte é (0xC3 0xA9).
          final splitAt = payload.indexOf(0xC3) + 1;
          final events = await parser
              .parse(
                Stream.fromIterable([
                  payload.sublist(0, splitAt),
                  payload.sublist(splitAt),
                ]),
              )
              .toList();
          expect(events, [
            const TextMessageContentEvent(messageId: 'm', delta: 'café'),
          ]);
        },
      );
    });

    test(
      'unknown event type deserializes to UnknownAgUiEvent (no throw)',
      () async {
        const src = 'data: {"type":"NOPE_NOT_REAL","x":1}\n\n';
        final events = await parser.parse(wire(src)).toList();
        expect(events, hasLength(1));
        final event = events.single;
        expect(event, isA<UnknownAgUiEvent>());
        expect((event as UnknownAgUiEvent).type, 'NOPE_NOT_REAL');
      },
    );

    test(
      'malformed wire JSON surfaces as ProtocolError(protocolMalformed)',
      () {
        final stream = parser.parse(wire('data: {not valid json\n\n'));
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

    test('a non-object JSON data payload is a ProtocolError', () {
      final stream = parser.parse(wire('data: 12345\n\n'));
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

    test('comments-only stream dispatches nothing', () async {
      final events = await parser.parse(wire(': a\n: b\n\n')).toList();
      expect(events, isEmpty);
    });

    test('an event:-only frame (no data) dispatches nothing', () async {
      final events = await parser.parse(wire('event: ping\n\n')).toList();
      expect(events, isEmpty);
    });

    test(
      'an empty data: frame dispatches nothing (no spurious error)',
      () async {
        // `data:\n\n` accumulates only an empty payload — it carries no AG-UI
        // event and must not be fed to jsonDecode (which would tear down the
        // stream with a ProtocolError).
        final events = await parser.parse(wire('data:\n\n')).toList();
        expect(events, isEmpty);
      },
    );

    test('a colon-less bare `data` line dispatches nothing', () async {
      final events = await parser.parse(wire('data\n\n')).toList();
      expect(events, isEmpty);
    });

    test('a multi-byte sequence truncated at EOF surfaces as ProtocolError, '
        'not a raw FormatException', () {
      // Final byte is a lone UTF-8 lead byte (0xC3) with no continuation.
      // allowMalformed decodes it to U+FFFD, so the malformed *data* surfaces
      // through the parser's own error contract rather than leaking the
      // decoder's FormatException.
      final stream = parser.parse(
        Stream.fromIterable([
          [...utf8.encode('data: {"type":"X"'), 0xC3],
        ]),
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

    test('flushes a final frame that lacks a trailing blank line', () async {
      // No closing `\n\n` — EOF must still dispatch the accumulated frame.
      final events = await parser
          .parse(wire('data: ${content('m', 'hi')}'))
          .toList();
      expect(events, [
        const TextMessageContentEvent(messageId: 'm', delta: 'hi'),
      ]);
    });

    test('propagates a source-stream error unchanged', () {
      final boom = Stream<List<int>>.error(StateError('boom'));
      expect(parser.parse(boom), emitsError(isA<StateError>()));
    });

    test('decodes a sequence of frames in wire order', () async {
      final src =
          'data: ${content('a', '1')}\n\n'
          'data: ${content('b', '2')}\n\n'
          'data: ${content('c', '3')}\n\n';
      final events = await parser.parse(wire(src)).toList();
      expect(events, [
        const TextMessageContentEvent(messageId: 'a', delta: '1'),
        const TextMessageContentEvent(messageId: 'b', delta: '2'),
        const TextMessageContentEvent(messageId: 'c', delta: '3'),
      ]);
    });

    test('AC4: parser file is under the 250 LOC budget (target ~150)', () {
      final lines = File('lib/src/sse_parser.dart').readAsLinesSync().length;
      expect(lines, lessThan(250));
    });
  });
}
