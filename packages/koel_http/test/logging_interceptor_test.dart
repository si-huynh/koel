import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:koel_core/koel_core.dart';
import 'package:koel_http/koel_http.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

/// A minimal run payload — these tests assert on log records, not body shape.
RunAgentInput _input() => const RunAgentInput(threadId: 't', runId: 'r');

/// Reads the raw wire payloads of a synthesized fixture (skipping the `_session`
/// header). Mirrors the loader the `RetryInterceptor`/`HttpAgent` suites use.
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
/// response, then closes — the happy-path run the lifecycle assertions drive.
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

/// A loopback SSE server that flushes `RUN_STARTED` + `TEXT_MESSAGE_START`, then
/// emits a `TEXT_MESSAGE_CONTENT` every 25 ms and **never** finishes — the
/// long-running run a consumer cancels mid-stream (AC3).
Future<({Uri uri, Future<void> firstEvent})> _slowServer() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  addTearDown(() => server.close(force: true));
  final firstEvent = Completer<void>();
  server.listen((request) async {
    await request.drain<void>();
    final res = request.response
      ..bufferOutput = false
      ..headers.contentType = ContentType('text', 'event-stream');
    res
      ..write('data: {"type":"RUN_STARTED","threadId":"t","runId":"r"}\n\n')
      ..write(
        'data: {"type":"TEXT_MESSAGE_START","messageId":"m",'
        '"role":"assistant"}\n\n',
      );
    await res.flush();
    if (!firstEvent.isCompleted) firstEvent.complete();
    Timer.periodic(const Duration(milliseconds: 25), (timer) async {
      try {
        res.write(
          'data: {"type":"TEXT_MESSAGE_CONTENT","messageId":"m",'
          '"delta":"tick"}\n\n',
        );
        await res.flush();
      } on Object {
        timer.cancel();
      }
    });
  });
  return (
    uri: Uri.parse('http://${server.address.host}:${server.port}'),
    firstEvent: firstEvent.future,
  );
}

/// A terminal agent emitting a single pre-built event per run — injects a typed
/// terminal `RunErrorEvent` without a server (the `RetryInterceptor` suite's
/// fixture).
class _StubAgent implements AbstractAgent {
  _StubAgent(this._build);
  final AgUiEvent Function() _build;

  @override
  Stream<AgUiEvent> run(RunAgentInput input) =>
      Stream<AgUiEvent>.value(_build());
}

/// Captures every `koel_http.logging` record with the root logger wide open,
/// restoring the prior level on teardown.
List<LogRecord> _captureLogs() {
  final records = <LogRecord>[];
  final previousLevel = Logger.root.level;
  Logger.root.level = Level.ALL;
  final sub = Logger.root.onRecord
      .where((r) => r.loggerName == 'koel_http.logging')
      .listen(records.add);
  addTearDown(() async {
    await sub.cancel();
    Logger.root.level = previousLevel;
  });
  return records;
}

void main() {
  group('LoggingInterceptor', () {
    test('is an Interceptor at default and explicit level (AC1 surface)', () {
      expect(LoggingInterceptor(), isA<Interceptor>());
      expect(LoggingInterceptor(level: Level.FINE), isA<Interceptor>());
    });

    test('at Level.FINE logs the full run lifecycle (AC1)', () async {
      final records = _captureLogs();
      final body = _sseBody(await _fixturePayloads('text_only_run'));
      final uri = await _sseServer(body);
      final agent = HttpAgent(
        url: uri,
        interceptors: [LoggingInterceptor(level: Level.FINE)],
      );

      await agent.run(_input()).toList();

      final infos = records
          .where((r) => r.level == Level.INFO)
          .map((r) => r.message)
          .toList();
      expect(
        infos.any((m) => m.startsWith('run started')),
        isTrue,
        reason: 'request start logs at INFO',
      );
      expect(
        infos.any((m) => m.startsWith('response started')),
        isTrue,
        reason: 'response start logs at INFO',
      );
      expect(
        infos.any((m) => m.startsWith('run completed')),
        isTrue,
        reason: 'graceful completion logs at INFO',
      );
      expect(
        records.where(
          (r) => r.level == Level.FINE && r.message.startsWith('event:'),
        ),
        isNotEmpty,
        reason: 'per-event tail logs at FINE',
      );
    });

    test(
      'at default Level.INFO suppresses FINE per-event, keeps INFO lifecycle '
      '(AC1 threshold)',
      () async {
        final records = _captureLogs();
        final body = _sseBody(await _fixturePayloads('text_only_run'));
        final uri = await _sseServer(body);
        final agent = HttpAgent(url: uri, interceptors: [LoggingInterceptor()]);

        await agent.run(_input()).toList();

        expect(
          records.where((r) => r.level == Level.FINE),
          isEmpty,
          reason: 'FINE per-event is below the default INFO threshold',
        );
        expect(records.where((r) => r.level == Level.INFO), isNotEmpty);
      },
    );

    test(
      'terminal ProtocolError → SEVERE, other KoelError → WARNING (AC1 error '
      'level)',
      () async {
        final records = _captureLogs();

        Future<void> runWith(KoelError error) {
          final chain = InterceptorChain(
            interceptors: [LoggingInterceptor()],
            agent: _StubAgent(() => RunErrorEvent(error: error)),
          );
          return chain.proceed(_input()).toList();
        }

        await runWith(
          const ProtocolError(
            message: 'malformed frame',
            code: KoelErrorCode.protocolMalformed,
          ),
        );
        expect(
          records.where((r) => r.level == Level.SEVERE),
          hasLength(1),
          reason: 'ProtocolError is unrecoverable → SEVERE',
        );

        records.clear();
        await runWith(
          const TransportError(
            message: 'socket closed',
            code: KoelErrorCode.transportClosed,
          ),
        );
        expect(
          records.where((r) => r.level == Level.WARNING),
          hasLength(1),
          reason: 'non-protocol KoelError → WARNING',
        );
        expect(records.where((r) => r.level == Level.SEVERE), isEmpty);
      },
    );

    test('at Level.FINE: per-event FINE then exactly one FINE cancellation drop '
        'per run (AC3)', () async {
      final records = _captureLogs();
      final server = await _slowServer();
      final agent = HttpAgent(
        url: server.uri,
        interceptors: [LoggingInterceptor(level: Level.FINE)],
      );

      final firstSeen = Completer<void>();
      final sub = agent.run(_input()).listen((_) {
        if (!firstSeen.isCompleted) firstSeen.complete();
      });
      addTearDown(sub.cancel);
      await firstSeen.future.timeout(const Duration(seconds: 2));

      expect(
        records.where(
          (r) => r.level == Level.FINE && r.message.startsWith('event:'),
        ),
        isNotEmpty,
        reason: 'per-event FINE records appear before cancel',
      );

      await sub.cancel();
      // Let any (incorrect) further records arrive before asserting the count.
      await Future<void>.delayed(const Duration(milliseconds: 80));

      final drops = records
          .where(
            (r) =>
                r.level == Level.FINE && r.message.startsWith('run cancelled'),
          )
          .toList();
      expect(
        drops,
        hasLength(1),
        reason:
            'one FINE cancellation drop per cancelled run (not '
            'process-once)',
      );
    });
  });
}
