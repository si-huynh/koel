import 'dart:async';
import 'dart:io';

import 'package:koel_core/koel_core.dart';
import 'package:koel_http/koel_http.dart';
import 'package:test/test.dart';

/// A minimal run payload — these tests assert on lifecycle hooks, not body shape.
RunAgentInput _input() => const RunAgentInput(threadId: 't', runId: 'r');

const String _runStarted =
    'data: {"type":"RUN_STARTED","threadId":"t","runId":"r"}\n\n';
const String _runFinished =
    'data: {"type":"RUN_FINISHED","threadId":"t","runId":"r"}\n\n';

Uri _uriOf(HttpServer server) =>
    Uri.parse('http://${server.address.host}:${server.port}');

/// A loopback server that replays [body] as a finite `text/event-stream` 200.
Future<Uri> _sseServer(String body) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  addTearDown(() => server.close(force: true));
  server.listen((request) async {
    await request.drain<void>();
    request.response.headers.contentType = ContentType('text', 'event-stream');
    request.response.write(body);
    await request.response.close();
  });
  return _uriOf(server);
}

/// A loopback server that answers every request with [status] and an empty body
/// — the post-headers (non-2xx) failure that still "connected".
Future<Uri> _statusServer(int status) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  addTearDown(() => server.close(force: true));
  server.listen((request) async {
    await request.drain<void>();
    request.response.statusCode = status;
    await request.response.close();
  });
  return _uriOf(server);
}

/// A loopback server that responds [failures] times with HTTP 503 (a connected,
/// retryable `TransportError`) and then replays [successBody] as a 200 — the
/// "transient failure then success" run AC2 exercises. Every attempt receives
/// headers, so every attempt fires `onConnect`.
Future<Uri> _flakyServer({
  required int failures,
  required String successBody,
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  addTearDown(() => server.close(force: true));
  var seen = 0;
  server.listen((request) async {
    await request.drain<void>();
    if (seen++ < failures) {
      request.response.statusCode = HttpStatus.serviceUnavailable;
      await request.response.close();
      return;
    }
    request.response.headers.contentType = ContentType('text', 'event-stream');
    request.response.write(successBody);
    await request.response.close();
  });
  return _uriOf(server);
}

/// A loopback server that flushes headers + a keepalive comment (so `send()`
/// completes and the byte stream is subscribed) then stalls — never another
/// byte, never `close()`. The inter-byte idle trips
/// `response.stream.timeout(readTimeout)`, surfacing a `TimeoutException` *mid
/// connected stream* — the one path that reaches `ConnectionScope.track`'s
/// `onError` arm (a 200 that errors, not the non-2xx direct-disconnect path).
Future<Uri> _idleServer() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  addTearDown(() => server.close(force: true));
  server.listen((request) async {
    await request.drain<void>();
    final res = request.response
      ..bufferOutput = false
      ..headers.contentType = ContentType('text', 'event-stream');
    res.write(': keep-alive\n\n');
    await res.flush();
    // Deliberately never close: hold idle past readTimeout.
  });
  return _uriOf(server);
}

/// What [_longRunningServer] hands back: where to point the agent + a signal that
/// the opening frame has flushed (so a test can cancel mid-stream).
typedef _LongServer = ({Uri uri, Future<void> firstFrame});

/// A loopback server that flushes `RUN_STARTED` then a `TEXT_MESSAGE_CONTENT`
/// every 50 ms and **never** finishes — the long-running run a consumer cancels.
Future<_LongServer> _longRunningServer() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  addTearDown(() => server.close(force: true));
  final firstFrame = Completer<void>();
  server.listen((request) async {
    await request.drain<void>();
    final res = request.response
      ..bufferOutput = false
      ..headers.contentType = ContentType('text', 'event-stream');
    res.write(_runStarted);
    await res.flush();
    if (!firstFrame.isCompleted) firstFrame.complete();

    Timer.periodic(const Duration(milliseconds: 50), (timer) async {
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
  return (uri: _uriOf(server), firstFrame: firstFrame.future);
}

void main() {
  group('connection lifecycle hooks (FR-B6)', () {
    test('AC1: a clean run fires onConnect once, onDisconnect(null) once, and '
        'never onReconnectAttempt', () async {
      final uri = await _sseServer(_runStarted + _runFinished);
      var connects = 0;
      final disconnects = <Object?>[];
      var reconnects = 0;
      final agent = HttpAgent(
        url: uri,
        onConnect: () => connects++,
        onDisconnect: disconnects.add,
        onReconnectAttempt: (_, _) => reconnects++,
      );

      final events = await agent.run(_input()).toList();

      expect(connects, 1);
      expect(disconnects, [null], reason: 'graceful close → null cause');
      expect(reconnects, 0, reason: 'no retry occurred');
      expect(events.last, isA<RunFinishedEvent>());
    });

    test(
      'AC1: a non-2xx response fires onConnect once and onDisconnect with the '
      'TransportError cause',
      () async {
        final uri = await _statusServer(500);
        var connects = 0;
        final disconnects = <Object?>[];
        final agent = HttpAgent(
          url: uri,
          onConnect: () => connects++,
          onDisconnect: disconnects.add,
        );

        final events = await agent.run(_input()).toList();

        expect(
          connects,
          1,
          reason: 'headers received → connected, status-agnostic',
        );
        expect(disconnects, hasLength(1));
        expect(
          disconnects.single,
          isA<TransportError>().having((e) => e.statusCode, 'statusCode', 500),
        );
        expect(
          events.single,
          isA<RunErrorEvent>(),
          reason: 'the run still surfaces the terminal error event',
        );
      },
    );

    test('AC1: a mid-stream error fires onDisconnect once with the stream error '
        'as cause (track onError arm)', () async {
      // A connected 200 stream that errors mid-flight (idle past readTimeout →
      // `TimeoutException`) is the only path through `ConnectionScope.track`'s
      // `onError` — distinct from the non-2xx test above, which exercises the
      // terminal's direct `disconnect()` call. The raw stream error reaches the
      // hook *below* the chain's classifier, so the cause is the unclassified
      // `TimeoutException`; the run still surfaces a terminal `RunErrorEvent`.
      final uri = await _idleServer();
      var connects = 0;
      final disconnects = <Object?>[];
      final agent = HttpAgent(
        url: uri,
        readTimeout: const Duration(milliseconds: 100),
        onConnect: () => connects++,
        onDisconnect: disconnects.add,
      );

      final events = await agent.run(_input()).toList();

      expect(connects, 1, reason: 'headers received → connected');
      expect(disconnects, hasLength(1));
      expect(
        disconnects.single,
        isA<TimeoutException>(),
        reason: 'the raw mid-stream error is the disconnect cause',
      );
      expect(
        (events.last as RunErrorEvent).error.code,
        KoelErrorCode.transportTimeout,
        reason: 'the error is still forwarded to the terminal event',
      );
    });

    test(
      'AC2: 2 transient failures then success → onConnect ×3, '
      'onReconnectAttempt ×2 with delays, onDisconnect ×3 (paired)',
      () async {
        final uri = await _flakyServer(
          failures: 2,
          successBody: _runStarted + _runFinished,
        );
        var connects = 0;
        final disconnects = <Object?>[];
        final reconnects = <({int attempt, Duration delay})>[];
        final agent = HttpAgent(
          url: uri,
          retry: const RetryPolicy(
            maxAttempts: 3,
            baseDelay: Duration(milliseconds: 1),
            jitter: false,
          ),
          onConnect: () => connects++,
          onDisconnect: disconnects.add,
          onReconnectAttempt: (attempt, delay) =>
              reconnects.add((attempt: attempt, delay: delay)),
        );

        final events = await agent.run(_input()).toList();

        expect(connects, 3, reason: 'one onConnect per physical connection');
        expect(
          reconnects.map((r) => r.attempt),
          [1, 2],
          reason: '1-based attempt index, once per scheduled retry',
        );
        expect(
          reconnects.every((r) => r.delay > Duration.zero),
          isTrue,
          reason: 'each backoff delay is computed and positive',
        );
        expect(disconnects, hasLength(3));
        expect(disconnects.take(2), everyElement(isA<TransportError>()));
        expect(
          disconnects.last,
          isNull,
          reason: 'the recovered run closed cleanly',
        );
        // Pairing invariant: every connection that received headers disconnects
        // exactly once.
        expect(connects, disconnects.length);
        expect(events.whereType<RunErrorEvent>(), isEmpty);
        expect(events.last, isA<RunFinishedEvent>());
      },
    );

    test('a consumer cancel mid-stream fires onDisconnect(null) exactly once '
        '(trap #5)', () async {
      final server = await _longRunningServer();
      var connects = 0;
      final disconnects = <Object?>[];
      final agent = HttpAgent(
        url: server.uri,
        onConnect: () => connects++,
        onDisconnect: disconnects.add,
      );

      final sub = agent.run(_input()).listen((_) {});
      await server.firstFrame.timeout(const Duration(seconds: 2));
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await sub.cancel();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(connects, 1);
      expect(disconnects, [null], reason: 'cancel is a clean disconnect');
    });

    test(
      'a throwing onConnect/onDisconnect never breaks the run (trap #7)',
      () async {
        final uri = await _sseServer(_runStarted + _runFinished);
        var disconnects = 0;
        final agent = HttpAgent(
          url: uri,
          onConnect: () => throw StateError('boom-connect'),
          onDisconnect: (_) {
            disconnects++;
            throw StateError('boom-disconnect');
          },
        );

        // If a throwing observer escaped, `toList()` would reject.
        final events = await agent.run(_input()).toList();

        expect(events.last, isA<RunFinishedEvent>());
        expect(
          disconnects,
          1,
          reason:
              'the once-guard still fires onDisconnect exactly once even '
              'when the observer throws',
        );
      },
    );

    test(
      'AC3: a DevTools-style observer subscribes via the public ctor closures '
      'with no access to private state',
      () async {
        // Epic 8 wires `DevToolsObserver` by passing its own closures here — the
        // hooks are the public subscription seam; `ConnectionLifecycle` stays
        // internal and is never imported.
        final uri = await _sseServer(_runStarted + _runFinished);
        final seen = <String>[];
        final agent = HttpAgent(
          url: uri,
          onConnect: () => seen.add('connect'),
          onDisconnect: (_) => seen.add('disconnect'),
        );

        await agent.run(_input()).toList();

        expect(seen, ['connect', 'disconnect']);
      },
    );
  });
}
