import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:http/testing.dart';
import 'package:koel_core/koel_core.dart';
import 'package:koel_http/koel_http.dart';
// Internal import (same-package): the AC3 test resets the library-private
// abort-not-honored process-once gate so its "exactly one warning" assertion is
// independent of any other test that trips the same gate earlier in the run.
import 'package:koel_http/src/connection/cancellation.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

/// A minimal run payload — these tests assert on cancellation, not body shape.
RunAgentInput _input() => const RunAgentInput(threadId: 't', runId: 'r');

/// What [_longRunningServer] hands back: where to point an agent, plus the two
/// observation points the cancellation assertions hang on.
typedef _Server = ({
  Uri uri,
  Future<void> firstEvent,
  Future<void> writeFailed,
});

/// A loopback SSE server that emits one `TEXT_MESSAGE_CONTENT` every 50 ms after
/// an initial `RUN_STARTED` + `TEXT_MESSAGE_START`, and **never** sends
/// `RUN_FINISHED` — the long-running run a consumer cancels mid-stream (AC1).
///
/// [firstEvent] completes once the opening frames are flushed (so a test can
/// cancel mid-stream); [writeFailed] completes when a subsequent flush throws —
/// i.e. the server observes the client socket gone, proving the abort reached
/// TCP (the detection lags the real close by up to one tick + the RST round-trip,
/// so it bounds *that the connection tore down*, not the sub-50ms budget).
Future<_Server> _longRunningServer() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  addTearDown(() => server.close(force: true));
  final firstEvent = Completer<void>();
  final writeFailed = Completer<void>();

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

    Timer.periodic(const Duration(milliseconds: 50), (timer) async {
      if (writeFailed.isCompleted) {
        timer.cancel();
        return;
      }
      try {
        res.write(
          'data: {"type":"TEXT_MESSAGE_CONTENT","messageId":"m",'
          '"delta":"tick"}\n\n',
        );
        await res.flush();
      } on Object {
        timer.cancel();
        if (!writeFailed.isCompleted) writeFailed.complete();
      }
    });
  });

  return (
    uri: Uri.parse('http://${server.address.host}:${server.port}'),
    firstEvent: firstEvent.future,
    writeFailed: writeFailed.future,
  );
}

/// Like [_longRunningServer] but emits `TOOL_CALL_CHUNK` frames that hold a
/// single tool-call envelope open forever — the long-running run a consumer
/// cancels mid-envelope while transport synthesis (`synthesizeChunks: true`) is
/// live (Story 4.8 trap #6). The opening chunk synthesizes a `ToolCallStartEvent`
/// and the envelope never closes on the wire, so a correct abort must NOT flush
/// a trailing `ToolCallEndEvent`.
Future<_Server> _longRunningChunkServer() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  addTearDown(() => server.close(force: true));
  final firstEvent = Completer<void>();
  final writeFailed = Completer<void>();

  server.listen((request) async {
    await request.drain<void>();
    final res = request.response
      ..bufferOutput = false
      ..headers.contentType = ContentType('text', 'event-stream');

    res.write(
      'data: {"type":"TOOL_CALL_CHUNK","toolCallId":"c","toolCallName":"fn"}'
      '\n\n',
    );
    await res.flush();
    if (!firstEvent.isCompleted) firstEvent.complete();

    Timer.periodic(const Duration(milliseconds: 50), (timer) async {
      if (writeFailed.isCompleted) {
        timer.cancel();
        return;
      }
      try {
        res.write(
          'data: {"type":"TOOL_CALL_CHUNK","toolCallId":"c","delta":"x"}\n\n',
        );
        await res.flush();
      } on Object {
        timer.cancel();
        if (!writeFailed.isCompleted) writeFailed.complete();
      }
    });
  });

  return (
    uri: Uri.parse('http://${server.address.host}:${server.port}'),
    firstEvent: firstEvent.future,
    writeFailed: writeFailed.future,
  );
}

/// Wraps [_inner] and records the instant koel aborts the connection — either by
/// closing the client or by cancelling the live response subscription. The
/// `<50 ms` budget (NFR-8, AC1's "`Client.close()` invokes within 50 ms") is
/// measured against [abortedAt], read off the test-owned [_clock]. Doubles as the
/// AC2 "custom interceptor-wrapped client": cancel must reach the socket through
/// this delegating layer.
class _InstrumentedClient extends http.BaseClient {
  _InstrumentedClient(this._inner, this._clock);

  final http.Client _inner;
  final Stopwatch _clock;

  /// Elapsed on [_clock] when koel first aborted, or null if never aborted.
  Duration? abortedAt;

  void _markAborted() => abortedAt ??= _clock.elapsed;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _inner.send(request);
    final controller = StreamController<List<int>>(sync: true);
    StreamSubscription<List<int>>? sub;
    controller
      ..onListen = () {
        sub = response.stream.listen(
          controller.add,
          onError: controller.addError,
          onDone: controller.close,
        );
      }
      ..onPause = () {
        sub?.pause();
      }
      ..onResume = () {
        sub?.resume();
      }
      ..onCancel = () {
        _markAborted();
        return sub?.cancel();
      };
    return http.StreamedResponse(
      controller.stream,
      response.statusCode,
      contentLength: response.contentLength,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  @override
  void close() {
    _markAborted();
    _inner.close();
  }
}

/// A client that **ignores abort** (AC3): its response body keeps emitting and
/// its subscription's `cancel()` never completes, so koel's abort budget
/// elapses and the silent-drop fallback engages.
http.Client _nonHonoringClient() {
  return MockClient.streaming((request, bodyStream) async {
    final controller = StreamController<List<int>>();
    final tick = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!controller.isClosed) {
        controller.add(
          utf8.encode(
            'data: {"type":"TEXT_MESSAGE_CONTENT","messageId":"m",'
            '"delta":"x"}\n\n',
          ),
        );
      }
    });
    // The defining trait: cancelling this stream hangs forever. koel cannot
    // force the client to release it — it must silent-drop and warn.
    controller.onCancel = () {
      tick.cancel();
      return Completer<void>().future;
    };
    return http.StreamedResponse(
      controller.stream,
      200,
      headers: const {'content-type': 'text/event-stream'},
    );
  });
}

void main() {
  group('cancellation', () {
    test('aborts the connection within 50 ms of cancel, no events after '
        '(AC1)', () async {
      final server = await _longRunningServer();
      final clock = Stopwatch();
      final client = _InstrumentedClient(IOClient(), clock);
      final agent = HttpAgent(url: server.uri, client: client);

      final events = <AgUiEvent>[];
      final firstSeen = Completer<void>();
      final sub = agent.run(_input()).listen((e) {
        events.add(e);
        if (!firstSeen.isCompleted) firstSeen.complete();
      });
      addTearDown(sub.cancel);

      await firstSeen.future.timeout(const Duration(seconds: 2));
      final countAtCancel = events.length;

      clock.start();
      await sub.cancel();

      expect(client.abortedAt, isNotNull, reason: 'cancel reached the socket');
      expect(
        client.abortedAt!.inMilliseconds,
        lessThan(50),
        reason: 'abort invoked within the NFR-8 budget',
      );

      // Nothing emits after cancel even as the server keeps ticking.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(events, hasLength(countAtCancel));
    });

    test('onDisconnect(null) fires once on cancel without extending the <50 ms '
        'abort budget (Story 4.9)', () async {
      final server = await _longRunningServer();
      final clock = Stopwatch();
      final client = _InstrumentedClient(IOClient(), clock);
      var connects = 0;
      final disconnects = <Object?>[];
      // The lifecycle `track` wrapper sits *inside* `abortOnCancel`. Firing the
      // (fire-and-forget) onDisconnect on cancel must not push the abort past
      // NFR-8 — the abort fires first and independently.
      final agent = HttpAgent(
        url: server.uri,
        client: client,
        onConnect: () => connects++,
        onDisconnect: disconnects.add,
      );

      final firstSeen = Completer<void>();
      final sub = agent.run(_input()).listen((_) {
        if (!firstSeen.isCompleted) firstSeen.complete();
      });
      addTearDown(sub.cancel);

      await firstSeen.future.timeout(const Duration(seconds: 2));
      expect(connects, 1, reason: 'onConnect fired once on headers-received');

      clock.start();
      await sub.cancel();

      expect(client.abortedAt, isNotNull, reason: 'cancel reached the socket');
      expect(
        client.abortedAt!.inMilliseconds,
        lessThan(50),
        reason: 'the onDisconnect wrapper does not extend the abort budget',
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        disconnects,
        [null],
        reason: 'cancel fires onDisconnect exactly once with a null cause',
      );
    });

    test('owned default client really tears the socket down on cancel '
        '(AC1)', () async {
      final server = await _longRunningServer();
      // No injected client → HttpAgent owns a default `http.Client()`.
      final agent = HttpAgent(url: server.uri);

      final firstSeen = Completer<void>();
      final sub = agent.run(_input()).listen((_) {
        if (!firstSeen.isCompleted) firstSeen.complete();
      });
      addTearDown(sub.cancel);

      await firstSeen.future.timeout(const Duration(seconds: 2));
      await sub.cancel();

      // The owned client closes with `force: true`; the server's next writes
      // fail once the socket is gone — proving a real TCP teardown, not just a
      // koel-side drop.
      await server.writeFailed.timeout(const Duration(seconds: 2));
    });

    test('synthesis on — cancel mid-chunk-envelope aborts <50 ms and flushes '
        'no trailing END (trap #6)', () async {
      final server = await _longRunningChunkServer();
      final clock = Stopwatch();
      final client = _InstrumentedClient(IOClient(), clock);
      // Default `synthesizeChunks: true` → `chunksStage` is live in the terminal,
      // beneath the abort gate. A correct abort cancels upstream WITHOUT running
      // the stage's onDone flush, so the open envelope yields no `END`.
      final agent = HttpAgent(url: server.uri, client: client);

      final events = <AgUiEvent>[];
      final firstSeen = Completer<void>();
      final sub = agent.run(_input()).listen((e) {
        events.add(e);
        if (!firstSeen.isCompleted) firstSeen.complete();
      });
      addTearDown(sub.cancel);

      await firstSeen.future.timeout(const Duration(seconds: 2));
      final countAtCancel = events.length;
      // The first synthesized event is the START — proving synthesis was live.
      expect(events.first, isA<ToolCallStartEvent>());

      clock.start();
      await sub.cancel();

      expect(client.abortedAt, isNotNull, reason: 'cancel reached the socket');
      expect(
        client.abortedAt!.inMilliseconds,
        lessThan(50),
        reason: 'abort invoked within the NFR-8 budget with synthesis on',
      );

      // Nothing emits after cancel — and crucially the open tool-call envelope
      // is never flushed to a `ToolCallEndEvent` after the abort gate closes.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(events, hasLength(countAtCancel));
      expect(events.whereType<ToolCallEndEvent>(), isEmpty);
    });

    group('verified-client matrix (AC2)', () {
      final inners = <String, http.Client Function()>{
        'default http.Client()': http.Client.new,
        'IOClient': IOClient.new,
      };

      for (final entry in inners.entries) {
        test('cancel propagates through ${entry.key}', () async {
          final server = await _longRunningServer();
          final clock = Stopwatch();
          final client = _InstrumentedClient(entry.value(), clock);
          final agent = HttpAgent(url: server.uri, client: client);

          final events = <AgUiEvent>[];
          final firstSeen = Completer<void>();
          final sub = agent.run(_input()).listen((e) {
            events.add(e);
            if (!firstSeen.isCompleted) firstSeen.complete();
          });
          addTearDown(sub.cancel);

          await firstSeen.future.timeout(const Duration(seconds: 2));
          final countAtCancel = events.length;

          clock.start();
          await sub.cancel();

          expect(client.abortedAt, isNotNull);
          expect(client.abortedAt!.inMilliseconds, lessThan(50));

          await Future<void>.delayed(const Duration(milliseconds: 200));
          expect(events, hasLength(countAtCancel));
        });
      }

      test(
        'cancel propagates through a custom interceptor-wrapped client',
        () async {
          final server = await _longRunningServer();
          final clock = Stopwatch();
          // `_InstrumentedClient` *is* a delegating wrapper around `IOClient` — the
          // wrapped-client row. Its `send` forwards to the inner, and cancel must
          // reach the inner's socket through it.
          final client = _InstrumentedClient(IOClient(), clock);
          final agent = HttpAgent(url: server.uri, client: client);

          final firstSeen = Completer<void>();
          final sub = agent.run(_input()).listen((_) {
            if (!firstSeen.isCompleted) firstSeen.complete();
          });
          addTearDown(sub.cancel);

          await firstSeen.future.timeout(const Duration(seconds: 2));
          clock.start();
          await sub.cancel();

          expect(client.abortedAt, isNotNull);
          expect(client.abortedAt!.inMilliseconds, lessThan(50));
        },
      );

      // The `BrowserClient` / web-`AbortController` matrix row lands in Story
      // 4.10: `BrowserClient` imports `package:web` (un-loadable on the VM) and
      // koel_http's web transport is a throwing stub until then. Web abort
      // (`AbortController.abort()` ↔ `cancel()`, < 50 ms) is AR-23 / Gap G-1.
    });

    test(
      'client that ignores abort → silent drop + one process-wide WARNING (AC3)',
      () async {
        // Clear the process-once gate so this assertion is deterministic even if
        // another non-honoring test (e.g. AC4) tripped it earlier in the run.
        resetAbortNotHonoredWarning();
        Logger.root.level = Level.ALL;
        final warnings = <LogRecord>[];
        final logSub = Logger.root.onRecord
            .where(
              (r) =>
                  r.level == Level.WARNING &&
                  r.loggerName == 'koel_http.cancellation',
            )
            .listen(warnings.add);
        addTearDown(logSub.cancel);

        Future<void> cancelOnce() async {
          final agent = HttpAgent(
            url: Uri.parse('http://127.0.0.1:1'),
            client: _nonHonoringClient(),
          );
          final events = <AgUiEvent>[];
          final firstSeen = Completer<void>();
          final sub = agent.run(_input()).listen((e) {
            events.add(e);
            if (!firstSeen.isCompleted) firstSeen.complete();
          });
          await firstSeen.future.timeout(const Duration(seconds: 2));
          final countAtCancel = events.length;

          await sub.cancel();
          // Past the 50 ms abort budget so the watchdog has fired.
          await Future<void>.delayed(const Duration(milliseconds: 150));
          expect(
            events,
            hasLength(countAtCancel),
            reason: 'silent drop: no events after cancel',
          );
        }

        // Multiple cancellations through a non-honoring client...
        await cancelOnce();
        await cancelOnce();
        await cancelOnce();

        // ...emit the warning exactly once per process (runtime-once flag).
        expect(warnings, hasLength(1));
      },
    );

    group('drives the reducer to RunPhase.cancelled (AC4)', () {
      test('regardless of TCP outcome — honoring client', () async {
        final server = await _longRunningServer();
        final client = KoelClient(agent: HttpAgent(url: server.uri));
        addTearDown(client.dispose);

        final session = client.newSession();
        final firstEvent = Completer<void>();
        final evSub = session.events.listen((_) {
          if (!firstEvent.isCompleted) firstEvent.complete();
        });
        addTearDown(evSub.cancel);

        final sendFuture = session.send('hi');
        await firstEvent.future.timeout(const Duration(seconds: 2));
        session.cancel();
        await sendFuture;

        expect(session.state.phase, RunPhase.cancelled);
      });

      test('regardless of TCP outcome — client that ignores abort', () async {
        final client = KoelClient(
          agent: HttpAgent(
            url: Uri.parse('http://127.0.0.1:1'),
            client: _nonHonoringClient(),
          ),
        );
        addTearDown(client.dispose);

        final session = client.newSession();
        final firstEvent = Completer<void>();
        final evSub = session.events.listen((_) {
          if (!firstEvent.isCompleted) firstEvent.complete();
        });
        addTearDown(evSub.cancel);

        final sendFuture = session.send('hi');
        await firstEvent.future.timeout(const Duration(seconds: 2));
        session.cancel();
        await sendFuture;

        expect(session.state.phase, RunPhase.cancelled);
      });
    });
  });
}
