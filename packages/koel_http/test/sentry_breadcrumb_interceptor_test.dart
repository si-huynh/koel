import 'dart:async';

import 'package:koel_core/koel_core.dart';
import 'package:koel_http/koel_http.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

/// A minimal run payload — these tests assert on breadcrumbs, not body shape.
RunAgentInput _input() => const RunAgentInput(threadId: 't', runId: 'r');

/// A terminal agent emitting a fixed list of events per run.
class _StubAgent implements AbstractAgent {
  _StubAgent(this._events);
  final List<AgUiEvent> _events;

  @override
  Stream<AgUiEvent> run(RunAgentInput input) =>
      Stream<AgUiEvent>.fromIterable(_events);
}

/// A `Hub` that records the breadcrumbs added to it. `noSuchMethod` absorbs the
/// rest of the (large) `Hub` surface the interceptor never calls.
class _RecordingHub implements Hub {
  final crumbs = <Breadcrumb>[];

  @override
  Future<void> addBreadcrumb(Breadcrumb crumb, {Hint? hint}) async =>
      crumbs.add(crumb);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A `Hub` whose `addBreadcrumb` always throws — proves the side channel never
/// disrupts the run.
class _ThrowingHub implements Hub {
  @override
  Future<void> addBreadcrumb(Breadcrumb crumb, {Hint? hint}) async =>
      throw StateError('hub is angry');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<List<AgUiEvent>> _run(
  List<AgUiEvent> events, {
  Interceptor? interceptor,
}) {
  final chain = InterceptorChain(
    interceptors: interceptor == null ? const [] : [interceptor],
    agent: _StubAgent(events),
  );
  return chain.proceed(_input()).toList();
}

void main() {
  group('SentryBreadcrumbInterceptor', () {
    test('is an Interceptor; constructs with and without an injected Hub', () {
      expect(SentryBreadcrumbInterceptor(), isA<Interceptor>());
      expect(
        SentryBreadcrumbInterceptor(hub: _RecordingHub()),
        isA<Interceptor>(),
      );
    });

    test('adds one content-free breadcrumb per event (AC1)', () async {
      final hub = _RecordingHub();
      const events = [
        RunStartedEvent(threadId: 't', runId: 'r'),
        TextMessageStartEvent(messageId: 'm', role: 'assistant'),
        TextMessageContentEvent(
          messageId: 'm',
          delta: 'sensitive 4111-1111-1111-1111',
        ),
        RunFinishedEvent(threadId: 't', runId: 'r'),
      ];

      final out = await _run(
        events,
        interceptor: SentryBreadcrumbInterceptor(hub: hub),
      );

      // Stream forwarded untouched.
      expect(out, hasLength(events.length));
      // One breadcrumb per emitted event.
      expect(hub.crumbs, hasLength(events.length));
      for (final crumb in hub.crumbs) {
        expect(crumb.category, 'koel.event');
        expect(crumb.level, SentryLevel.info);
        // No event content ever reaches a breadcrumb.
        expect(crumb.message, isNot(contains('4111')));
        expect(crumb.message, isNot(contains('sensitive')));
        expect(crumb.data ?? const {}, isNot(contains('delta')));
      }
    });

    test(
      'tags a terminal RunErrorEvent at error level with its code',
      () async {
        final hub = _RecordingHub();
        const error = RunErrorEvent(
          error: ProtocolError(
            message: 'malformed frame',
            code: KoelErrorCode.protocolMalformed,
          ),
        );

        await _run(const [
          error,
        ], interceptor: SentryBreadcrumbInterceptor(hub: hub));

        final crumb = hub.crumbs.single;
        expect(crumb.level, SentryLevel.error);
        expect(crumb.data, {'code': KoelErrorCode.protocolMalformed.name});
        // The error *message* (which may carry detail) is not breadcrumbed.
        expect(crumb.message, isNot(contains('malformed frame')));
      },
    );

    test('a throwing or uninitialised hub never disrupts the run', () async {
      // Throwing hub: the run still completes with every event.
      final thrown = await _run(const [
        RunStartedEvent(threadId: 't', runId: 'r'),
        RunFinishedEvent(threadId: 't', runId: 'r'),
      ], interceptor: SentryBreadcrumbInterceptor(hub: _ThrowingHub()));
      expect(thrown, hasLength(2));

      // Default HubAdapter() with Sentry never initialised — a silent no-op.
      final defaulted = await _run(const [
        RunStartedEvent(threadId: 't', runId: 'r'),
      ], interceptor: SentryBreadcrumbInterceptor());
      expect(defaulted, hasLength(1));
    });

    test('default-off: no interceptor records no breadcrumb (AC3)', () async {
      final hub = _RecordingHub();
      await _run(const [RunStartedEvent(threadId: 't', runId: 'r')]);
      expect(hub.crumbs, isEmpty);
    });
  });
}
