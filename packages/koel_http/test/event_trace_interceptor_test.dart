@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:koel_core/koel_core.dart';
import 'package:koel_http/koel_http.dart';
import 'package:test/test.dart';

/// A minimal run payload — these tests assert on trace entries, not body shape.
RunAgentInput _input() => const RunAgentInput(threadId: 't', runId: 'r');

/// A `Sink<TraceEntry>` backed by a growable list — the consumer-owned sink the
/// interceptor writes to. Records `closed` so a test can prove the interceptor
/// never closes a sink it does not own.
class _ListSink implements Sink<TraceEntry> {
  final entries = <TraceEntry>[];
  var closed = false;

  @override
  void add(TraceEntry data) => entries.add(data);

  @override
  void close() => closed = true;
}

/// Reads the raw wire payloads of a synthesized fixture (skipping the `_session`
/// header). Mirrors the loader the other koel_http suites use.
Future<List<Map<String, dynamic>>> _fixturePayloads(String name) async {
  final uri = Uri.parse(
    'package:koel_test/src/fixtures/synthesized/$name.jsonl',
  );
  final resolved = await Isolate.resolvePackageUri(uri);
  final lines = (await File.fromUri(
    resolved!,
  ).readAsLines()).where((line) => line.trim().isNotEmpty).toList();
  return [
    for (final line in lines.skip(1))
      (jsonDecode(line) as Map<String, dynamic>)['payload']
          as Map<String, dynamic>,
  ];
}

/// Frames wire payloads as a `text/event-stream` body (`data: <json>\n\n`).
String _sseBody(List<Map<String, dynamic>> payloads) =>
    payloads.map((p) => 'data: ${jsonEncode(p)}\n\n').join();

/// A loopback server that answers any request with [body] as a complete SSE
/// response, then closes.
Future<Uri> _sseServer(String body) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  addTearDown(() => server.close(force: true));
  server.listen((request) async {
    await request.drain<void>();
    request.response.headers.contentType = ContentType('text', 'event-stream');
    request.response.write(body);
    await request.response.close();
  });
  return Uri.parse('http://${server.address.host}:${server.port}');
}

/// A terminal agent emitting a fixed list of events per run — injects a typed
/// terminal event without a server.
class _StubAgent implements AbstractAgent {
  _StubAgent(this._events);
  final List<AgUiEvent> _events;

  @override
  Stream<AgUiEvent> run(RunAgentInput input) =>
      Stream<AgUiEvent>.fromIterable(_events);
}

void main() {
  group('EventTraceInterceptor', () {
    test('is an Interceptor; TraceEntry has value equality + copyWith '
        '(AC2 surface + freezed)', () {
      final sink = _ListSink();
      expect(EventTraceInterceptor(sink: sink), isA<Interceptor>());

      final a = TraceEntry(
        timestamp: DateTime.utc(2026),
        phase: TracePhase.event,
        runDuration: const Duration(milliseconds: 5),
      );
      final b = TraceEntry(
        timestamp: DateTime.utc(2026),
        phase: TracePhase.event,
        runDuration: const Duration(milliseconds: 5),
      );
      expect(a, equals(b), reason: 'freezed value equality');
      expect(a.copyWith(phase: TracePhase.response).phase, TracePhase.response);
      expect(a.copyWith(phase: TracePhase.response), isNot(equals(a)));
    });

    test('every AgUiEvent produces one entry, bracketed by request/response '
        '(AC2)', () async {
      final sink = _ListSink();
      final body = _sseBody(await _fixturePayloads('text_only_run'));
      final uri = await _sseServer(body);
      final agent = HttpAgent(
        url: uri,
        interceptors: [EventTraceInterceptor(sink: sink)],
      );

      final events = await agent.run(_input()).toList();

      // No terminal error in the happy fixture.
      expect(events.whereType<RunErrorEvent>(), isEmpty);

      final entries = sink.entries;
      expect(entries.first.phase, TracePhase.request);
      expect(entries.first.event, isNull);
      expect(entries.first.runDuration, Duration.zero);
      expect(entries.last.phase, TracePhase.response);
      expect(entries.last.event, isNull);

      // One `event` entry per emitted AgUiEvent — count and order match the raw
      // stream.
      final eventEntries = entries
          .where((e) => e.phase == TracePhase.event)
          .toList();
      expect(eventEntries, hasLength(events.length));
      for (var i = 0; i < events.length; i++) {
        expect(eventEntries[i].event, same(events[i]));
      }

      // runDuration never goes backwards.
      for (var i = 1; i < entries.length; i++) {
        expect(
          entries[i].runDuration,
          greaterThanOrEqualTo(entries[i - 1].runDuration),
        );
      }

      // The interceptor never closes the consumer's sink.
      expect(sink.closed, isFalse);
    });

    test('a terminal RunErrorEvent surfaces as a single error entry, not an '
        'event entry (AC2 error phase)', () async {
      final sink = _ListSink();
      const error = RunErrorEvent(
        error: ProtocolError(
          message: 'malformed frame',
          code: KoelErrorCode.protocolMalformed,
        ),
      );
      final chain = InterceptorChain(
        interceptors: [EventTraceInterceptor(sink: sink)],
        agent: _StubAgent(const [error]),
      );

      await chain.proceed(_input()).toList();

      final phases = sink.entries.map((e) => e.phase).toList();
      // request marker, then the error (no `event` entry, no trailing
      // `response`).
      expect(phases, [TracePhase.request, TracePhase.error]);
      expect(sink.entries.where((e) => e.phase == TracePhase.event), isEmpty);
      final errorEntry = sink.entries.firstWhere(
        (e) => e.phase == TracePhase.error,
      );
      expect(errorEntry.event, same(error));
    });
  });
}
