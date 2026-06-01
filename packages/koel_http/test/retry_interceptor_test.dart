@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:koel_core/koel_core.dart';
import 'package:koel_http/koel_http.dart';
import 'package:test/test.dart';

/// A minimal run payload for tests that do not assert on the body.
RunAgentInput _input() => const RunAgentInput(threadId: 't', runId: 'r');

/// Reads the raw wire payloads of a synthesized fixture (skipping the `_session`
/// header) — the bytes a real SSE endpoint would emit. Mirrors the loader the
/// `HttpAgent` suite uses.
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

/// An ephemeral loopback `HttpServer` that answers the first [failures] requests
/// with `500` and every request after that with [successBody] as SSE. The
/// per-request counter is what makes "fails N times then succeeds" deterministic
/// across a `RetryInterceptor`'s re-POSTs. Registers its own teardown.
Future<HttpServer> _flakyServer(
  String successBody, {
  required int failures,
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  addTearDown(() => server.close(force: true));
  var seen = 0;
  server.listen((request) async {
    await request.drain<void>();
    seen++;
    if (seen <= failures) {
      request.response.statusCode = HttpStatus.internalServerError;
      await request.response.close();
      return;
    }
    request.response.headers.contentType = ContentType('text', 'event-stream');
    request.response.write(successBody);
    await request.response.close();
  });
  return server;
}

Uri _serverUri(HttpServer server) =>
    Uri.parse('http://${server.address.host}:${server.port}');

/// A terminal agent that emits a single pre-built event each run and counts its
/// invocations — the AC5 fixture that injects a typed failure without reaching
/// for (Epic-5) HTTP-status classification.
class _StubAgent implements AbstractAgent {
  _StubAgent(this._build);

  final AgUiEvent Function() _build;
  var runs = 0;

  @override
  Stream<AgUiEvent> run(RunAgentInput input) {
    runs++;
    return Stream<AgUiEvent>.value(_build());
  }
}

void main() {
  group('RetryInterceptor', () {
    test('public ctor matches Addendum A.2 surface (AC1)', () {
      // All-default and all-explicit both compile; `jitter` is a `double`.
      expect(RetryInterceptor(), isA<Interceptor>());
      final explicit = RetryInterceptor(
        maxAttempts: 5,
        baseDelay: const Duration(seconds: 1),
        maxDelay: const Duration(seconds: 30),
        jitter: 0.2,
        shouldRetry: (error, attempt) => true,
      );
      expect(explicit.jitter, isA<double>());
      expect(explicit.maxAttempts, 5);
    });

    test(
      'fails 3 times then succeeds: 3 retries, onReconnectAttempt x3 (AC2)',
      () async {
        final body = _sseBody(await _fixturePayloads('text_only_run'));
        final server = await _flakyServer(body, failures: 3);
        final attempts = <(int, Duration)>[];
        final agent = HttpAgent(
          url: _serverUri(server),
          retry: const RetryPolicy(
            maxAttempts: 3,
            baseDelay: Duration(milliseconds: 2),
          ),
          onReconnectAttempt: (attempt, delay) =>
              attempts.add((attempt, delay)),
        );

        final events = await agent.run(_input()).toList();

        // The eventual run succeeds — no terminal error, a RunFinished closes it.
        expect(events.whereType<RunErrorEvent>(), isEmpty);
        expect(events.last, isA<RunFinishedEvent>());
        // onReconnectAttempt fired once per retry, 1-based, in order.
        expect(attempts.map((a) => a.$1), [1, 2, 3]);
        // Each delay sits within its step's ±20% jitter band (RetryPolicy
        // jitter:true ⇒ 0.2). Counts + bands, never wall-clock equality.
        for (final (attempt, delay) in attempts) {
          final baseMicros = 2000 * (1 << (attempt - 1));
          expect(
            delay.inMicroseconds,
            greaterThanOrEqualTo((baseMicros * 0.8).floor()),
          );
          expect(
            delay.inMicroseconds,
            lessThanOrEqualTo((baseMicros * 1.2).ceil()),
          );
        }
      },
    );

    test('emits ConnectionResumed before the first event of the recovered '
        'attempt, none before the first attempt (AC3)', () async {
      final body = _sseBody(await _fixturePayloads('text_only_run'));
      final server = await _flakyServer(body, failures: 3);
      final agent = HttpAgent(
        url: _serverUri(server),
        retry: const RetryPolicy(
          maxAttempts: 3,
          baseDelay: Duration(milliseconds: 2),
        ),
      );

      final events = await agent.run(_input()).toList();

      // The three failed attempts produced no domain events, so the recovered
      // attempt's resume marker is the very first event out.
      final resumed = events.first as CustomEvent;
      expect(resumed.name, RetryInterceptor.connectionResumedEventName);
      expect(resumed.value, {'attempt': 3});
      expect(events[1], isA<RunStartedEvent>());
      // Exactly one resume marker (one recovery), and none precedes attempt 0.
      expect(
        events.whereType<CustomEvent>().where(
          (e) => e.name == RetryInterceptor.connectionResumedEventName,
        ),
        hasLength(1),
      );
    });

    test('exhausts the budget after maxAttempts+1 failures: terminal '
        'TransportError(transportClosed) with the last cause (AC4)', () async {
      // Always fails: 6 failures (initial + 5 retries) over the default cap.
      final server = await _flakyServer('', failures: 1 << 20);
      final agent = HttpAgent(
        url: _serverUri(server),
        retry: const RetryPolicy(
          maxAttempts: 5,
          baseDelay: Duration(milliseconds: 1),
        ),
      );

      final events = await agent.run(_input()).toList();

      final error = (events.last as RunErrorEvent).error;
      expect(error, isA<TransportError>());
      expect(error.code, KoelErrorCode.transportClosed);
      // The underlying cause is the last attempt's failure.
      expect(error.cause, isA<TransportError>());
    });

    test(
      'shouldRetry=false for businessAuth: no retry, original error unchanged '
      '(AC5)',
      () async {
        final agent = _StubAgent(
          () => const RunErrorEvent(
            error: BusinessError(
              message: 'auth',
              code: KoelErrorCode.businessAuth,
            ),
          ),
        );
        final chain = InterceptorChain(
          interceptors: [
            RetryInterceptor(
              shouldRetry: (e, n) =>
                  !(e is BusinessError && e.code == KoelErrorCode.businessAuth),
            ),
          ],
          agent: agent,
        );

        final events = await chain.proceed(_input()).toList();

        // Exactly one attempt — the failure short-circuited before any backoff.
        expect(agent.runs, 1);
        expect(events, hasLength(1));
        final error = (events.single as RunErrorEvent).error;
        expect(error, isA<BusinessError>());
        expect(error.code, KoelErrorCode.businessAuth);
      },
    );

    test(
      'a throwing shouldRetry surfaces a terminal error, never hangs',
      () async {
        // Review hardening: shouldRetry runs inside the inner subscription's
        // onData callback, outside the chain transformer's error coverage. A throw
        // must be surfaced as a terminal RunErrorEvent, not left to strand the
        // controller open (which would hang the consumer forever).
        final agent = _StubAgent(
          () => const RunErrorEvent(
            error: TransportError(
              message: 'boom',
              code: KoelErrorCode.transportClosed,
            ),
          ),
        );
        final chain = InterceptorChain(
          interceptors: [
            RetryInterceptor(
              baseDelay: const Duration(milliseconds: 1),
              shouldRetry: (e, n) => throw StateError('predicate blew up'),
            ),
          ],
          agent: agent,
        );

        final events = await chain
            .proceed(_input())
            .toList()
            .timeout(const Duration(seconds: 2));

        expect(agent.runs, 1); // No retry — the predicate never decided.
        expect(events.last, isA<RunErrorEvent>());
      },
    );

    test(
      'a throwing onReconnectAttempt does not abort a recoverable run',
      () async {
        // Review hardening: the observer is fire-and-forget telemetry; a throw must
        // not abort (or hang) a run that would otherwise recover.
        final body = _sseBody(await _fixturePayloads('text_only_run'));
        final server = await _flakyServer(body, failures: 1);
        final agent = HttpAgent(
          url: _serverUri(server),
          retry: const RetryPolicy(
            maxAttempts: 3,
            baseDelay: Duration(milliseconds: 2),
          ),
          onReconnectAttempt: (attempt, delay) =>
              throw StateError('observer blew up'),
        );

        final events = await agent
            .run(_input())
            .toList()
            .timeout(const Duration(seconds: 2));

        expect(events.whereType<RunErrorEvent>(), isEmpty);
        expect(events.last, isA<RunFinishedEvent>());
      },
    );

    group('retryBackoff', () {
      test('no jitter is exact exponential and clamps at maxDelay', () {
        final random = Random(1);
        Duration delay(int attempt, Duration base, Duration max) =>
            retryBackoff(
              attempt,
              baseDelay: base,
              maxDelay: max,
              jitter: 0,
              random: random,
            );

        const base = Duration(milliseconds: 10);
        const max = Duration(seconds: 30);
        expect(delay(1, base, max), const Duration(milliseconds: 10));
        expect(delay(2, base, max), const Duration(milliseconds: 20));
        expect(delay(3, base, max), const Duration(milliseconds: 40));
        // A large attempt clamps to maxDelay rather than overflowing.
        expect(
          delay(20, const Duration(seconds: 1), const Duration(seconds: 30)),
          const Duration(seconds: 30),
        );
      });

      test('every delay stays within the symmetric jitter band', () {
        final random = Random(7);
        const base = Duration(milliseconds: 10);
        const max = Duration(milliseconds: 100);
        const jitter = 0.2;
        for (var attempt = 1; attempt <= 6; attempt++) {
          final delay = retryBackoff(
            attempt,
            baseDelay: base,
            maxDelay: max,
            jitter: jitter,
            random: random,
          );
          final rawBase = (10000 * (1 << (attempt - 1))).clamp(0, 100000);
          expect(
            delay.inMicroseconds,
            greaterThanOrEqualTo((rawBase * (1 - jitter)).floor()),
          );
          expect(
            delay.inMicroseconds,
            lessThanOrEqualTo((rawBase * (1 + jitter)).ceil()),
          );
        }
      });
    });
  });
}
