@TestOn('browser')
// The mid-stream-cancel test asserts on real fetch/ReadableStream startup and
// AbortController-driven TCP teardown, whose timing is at the mercy of headless
// Chrome on a shared CI runner (occasionally the first frame or the abort
// observation slips past the window; a fresh fetch on re-run resolves it). Retry
// makes the timing-dependent assertions reliable without weakening them; a genuine
// regression fails all attempts (Story 9.4).
@Retry(2)
library;

import 'dart:async';

import 'package:koel_core/koel_core.dart';
import 'package:koel_http/koel_http.dart';
import 'package:test/test.dart';

/// A minimal run payload — these tests assert on transport behavior, not body
/// shape.
RunAgentInput _input() => const RunAgentInput(threadId: 't', runId: 'r');

/// Hang-guard for the fetch/ReadableStream synchronization points (`firstSeen`,
/// `server.aborted`). It bounds *that* the awaited Future resolves at all — NOT a
/// latency budget (the <50 ms abort budget is asserted separately via the
/// Stopwatch) — so it is sized well above worst-case headless-Chrome startup on a
/// loaded runner. A 5s guard flaked on CI (Story 9.4); 20s fires a clear message
/// before the 30s test-default, and `@Retry` (above) covers the rare case where a
/// frame or the abort is not observed at all in the window.
const _syncWait = Duration(seconds: 20);

/// What [_server] hands back: where to point an agent, the inbound
/// `Authorization` header the server saw, and (long mode) a future that
/// completes when the server observes the fetch's TCP teardown.
typedef _Server = ({
  Uri uri,
  Future<String?> authorization,
  Future<void> aborted,
});

/// Spawns the `web_transport_server.dart` mock on the VM side (a browser suite
/// has no `dart:io`) in [mode], and resolves once it reports its bound port.
Future<_Server> _server(String mode) async {
  final channel = spawnHybridUri('web_transport_server.dart', message: mode);
  final ready = Completer<int>();
  final authorization = Completer<String?>();
  final aborted = Completer<void>();

  channel.stream.listen((message) {
    final map = (message as Map).cast<String, Object?>();
    switch (map['type']) {
      case 'ready':
        ready.complete(map['port']! as int);
      case 'request':
        if (!authorization.isCompleted) {
          authorization.complete(map['authorization'] as String?);
        }
      case 'aborted':
        if (!aborted.isCompleted) aborted.complete();
    }
  });
  // Closing the channel kills the hybrid isolate (and frees its socket).
  addTearDown(channel.sink.close);

  final port = await ready.future;
  return (
    uri: Uri.parse('http://127.0.0.1:$port'),
    authorization: authorization.future,
    aborted: aborted.future,
  );
}

void main() {
  group('WebTransport (fetch + ReadableStream + AbortController)', () {
    test('custom Authorization header flows through fetch, SSE parses back '
        '(AC1)', () async {
      final server = await _server('echo');
      final agent = HttpAgent(
        url: server.uri,
        interceptors: [
          AuthInterceptor(
            headers: () async => {'Authorization': 'Bearer web-token'},
          ),
        ],
      );

      final events = await agent.run(_input()).toList();

      // The server saw the AuthInterceptor's header verbatim — proving headers
      // ride `RequestInit.headers` on web (EventSource could not do this, D4).
      expect(await server.authorization, 'Bearer web-token');
      // And the streamed SSE bytes parsed back into the typed events (matched by
      // interface — the freezed concrete types are library-private).
      expect(events, [
        isA<RunStartedEvent>(),
        isA<TextMessageStartEvent>(),
        isA<TextMessageContentEvent>(),
        isA<TextMessageEndEvent>(),
        isA<RunFinishedEvent>(),
      ]);
    });

    test('mid-stream cancel aborts the fetch promptly, drops events after '
        '(AC1 <50 ms)', () async {
      final server = await _server('long');
      final agent = HttpAgent(url: server.uri);

      final events = <AgUiEvent>[];
      final firstSeen = Completer<void>();
      final sub = agent.run(_input()).listen((event) {
        events.add(event);
        if (!firstSeen.isCompleted) firstSeen.complete();
      });
      addTearDown(sub.cancel);

      await firstSeen.future.timeout(_syncWait);
      final countAtCancel = events.length;

      final clock = Stopwatch()..start();
      await sub.cancel();
      // `abortOnCancel` fires `AbortController.abort()` synchronously and returns
      // without awaiting teardown, so the consumer's `cancel()` never blocks on
      // the socket — the web rendition of native's <50 ms budget assertion.
      expect(clock.elapsedMilliseconds, lessThan(50));

      // Silent drop: even as the server keeps ticking, nothing arrives.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(events, hasLength(countAtCancel));

      // The unique web proof: `AbortController.abort()` really tore the fetch's
      // TCP connection down — the server's next flush failed.
      await server.aborted.timeout(_syncWait);
    });

    test('non-2xx status surfaces a terminal RunErrorEvent, same as native '
        '(AC1 parity)', () async {
      final server = await _server('error');
      final agent = HttpAgent(url: server.uri);

      final events = await agent.run(_input()).toList();

      final error = (events.single as RunErrorEvent).error as TransportError;
      expect(error.code, KoelErrorCode.transportClosed);
      expect(error.statusCode, 500);
    });
  });
}
