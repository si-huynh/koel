import 'package:koel_core/src/error/koel_error.dart';
import 'package:koel_core/src/error/koel_error_code.dart';
import 'package:koel_core/src/event/ag_ui_event.dart';
import 'package:koel_core/src/event/event_deserializer.dart';
import 'package:test/test.dart';

void main() {
  group('RunStartedEvent', () {
    test('const construction + type membership', () {
      const event = RunStartedEvent(threadId: 't1', runId: 'r1');
      expect(event.threadId, 't1');
      expect(event.runId, 'r1');
      expect(event.parentRunId, isNull);
      expect(event, isA<AgUiEvent>());
      expect(event, isA<RunStartedEvent>());
    });

    test('structural equality + hashCode', () {
      const a = RunStartedEvent(threadId: 't1', runId: 'r1', parentRunId: 'p1');
      const b = RunStartedEvent(threadId: 't1', runId: 'r1', parentRunId: 'p1');
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(
        a,
        isNot(equals(const RunStartedEvent(threadId: 't1', runId: 'r2'))),
      );
    });

    test('copyWith updates one field', () {
      const event = RunStartedEvent(threadId: 't1', runId: 'r1');
      expect(event.copyWith(runId: 'r2').runId, 'r2');
      expect(event.copyWith(runId: 'r2').threadId, 't1');
    });

    test('fromJson decodes fields; parentRunId optional', () {
      final event = RunStartedEvent.fromJson({
        'type': 'RUN_STARTED',
        'threadId': 't1',
        'runId': 'r1',
        'parentRunId': 'p1',
      });
      expect(
        event,
        const RunStartedEvent(threadId: 't1', runId: 'r1', parentRunId: 'p1'),
      );
    });

    test('round-trips via fromJson(toJson()) and deserializeAgUiEvent', () {
      const event = RunStartedEvent(
        threadId: 't1',
        runId: 'r1',
        parentRunId: 'p1',
      );
      expect(RunStartedEvent.fromJson(event.toJson()), equals(event));
      expect(deserializeAgUiEvent(event.toJson()), equals(event));
    });

    test('toJson omits absent parentRunId', () {
      const event = RunStartedEvent(threadId: 't1', runId: 'r1');
      expect(event.toJson(), {
        'type': 'RUN_STARTED',
        'threadId': 't1',
        'runId': 'r1',
      });
    });

    test('missing threadId throws ProtocolError(protocolMalformed)', () {
      expect(
        () => RunStartedEvent.fromJson({'type': 'RUN_STARTED', 'runId': 'r1'}),
        throwsA(
          isA<ProtocolError>().having(
            (e) => e.code,
            'code',
            KoelErrorCode.protocolMalformed,
          ),
        ),
      );
    });

    test('non-String threadId throws ProtocolError(protocolMalformed)', () {
      expect(
        () => RunStartedEvent.fromJson({
          'type': 'RUN_STARTED',
          'threadId': 42,
          'runId': 'r1',
        }),
        throwsA(
          isA<ProtocolError>().having(
            (e) => e.code,
            'code',
            KoelErrorCode.protocolMalformed,
          ),
        ),
      );
    });

    test('non-String parentRunId throws ProtocolError(protocolMalformed)', () {
      expect(
        () => RunStartedEvent.fromJson({
          'type': 'RUN_STARTED',
          'threadId': 't1',
          'runId': 'r1',
          'parentRunId': 42,
        }),
        throwsA(
          isA<ProtocolError>().having(
            (e) => e.code,
            'code',
            KoelErrorCode.protocolMalformed,
          ),
        ),
      );
    });
  });

  group('RunFinishedEvent', () {
    test('const construction + type membership', () {
      const event = RunFinishedEvent(threadId: 't1', runId: 'r1');
      expect(event.threadId, 't1');
      expect(event.runId, 'r1');
      expect(event.result, isNull);
      expect(event, isA<AgUiEvent>());
    });

    test('result holds an arbitrary decoded-JSON value, compared deeply', () {
      const a = RunFinishedEvent(
        threadId: 't1',
        runId: 'r1',
        result: {
          'items': [1, 2, 3],
        },
      );
      final b = RunFinishedEvent(
        threadId: 't1',
        runId: 'r1',
        result: {
          'items': [1, 2, 3],
        },
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('copyWith updates result', () {
      const event = RunFinishedEvent(threadId: 't1', runId: 'r1');
      expect(event.copyWith(result: 42).result, 42);
    });

    test('round-trips with and without result', () {
      const withResult = RunFinishedEvent(
        threadId: 't1',
        runId: 'r1',
        result: {'ok': true},
      );
      const without = RunFinishedEvent(threadId: 't1', runId: 'r1');
      expect(deserializeAgUiEvent(withResult.toJson()), equals(withResult));
      expect(deserializeAgUiEvent(without.toJson()), equals(without));
      expect(without.toJson(), {
        'type': 'RUN_FINISHED',
        'threadId': 't1',
        'runId': 'r1',
      });
    });

    test('missing runId throws ProtocolError(protocolMalformed)', () {
      expect(
        () => RunFinishedEvent.fromJson({
          'type': 'RUN_FINISHED',
          'threadId': 't1',
        }),
        throwsA(
          isA<ProtocolError>().having(
            (e) => e.code,
            'code',
            KoelErrorCode.protocolMalformed,
          ),
        ),
      );
    });
  });

  group('RunErrorEvent ↔ KoelError', () {
    test('const construction + type membership', () {
      const event = RunErrorEvent(
        error: AgentError(message: 'boom', code: KoelErrorCode.agentInternal),
      );
      expect(event.error, isA<AgentError>());
      expect(event, isA<AgUiEvent>());
    });

    test('code = enum name → AgentError(code mapped, agentCode preserved)', () {
      final event = RunErrorEvent.fromJson({
        'type': 'RUN_ERROR',
        'message': 'boom',
        'code': 'agentInternal',
      });
      final error = event.error as AgentError;
      expect(error.message, 'boom');
      expect(error.code, KoelErrorCode.agentInternal);
      expect(error.agentCode, 'agentInternal');
      expect(deserializeAgUiEvent(event.toJson()), equals(event));
      expect(event.toJson(), {
        'type': 'RUN_ERROR',
        'message': 'boom',
        'code': 'agentInternal',
      });
    });

    test(
      'absent code → KoelErrorCode.unknown, agentCode null, code omitted',
      () {
        final event = RunErrorEvent.fromJson({
          'type': 'RUN_ERROR',
          'message': 'boom',
        });
        final error = event.error as AgentError;
        expect(error.code, KoelErrorCode.unknown);
        expect(error.agentCode, isNull);
        expect(event.toJson(), {'type': 'RUN_ERROR', 'message': 'boom'});
        expect(deserializeAgUiEvent(event.toJson()), equals(event));
      },
    );

    test('non-enum backend string → unknown enum, wire string preserved', () {
      final event = RunErrorEvent.fromJson({
        'type': 'RUN_ERROR',
        'message': 'boom',
        'code': 'RATE_LIMIT',
      });
      final error = event.error as AgentError;
      expect(error.code, KoelErrorCode.unknown);
      expect(error.agentCode, 'RATE_LIMIT');
      expect(event.toJson(), {
        'type': 'RUN_ERROR',
        'message': 'boom',
        'code': 'RATE_LIMIT',
      });
      expect(deserializeAgUiEvent(event.toJson()), equals(event));
    });

    test('missing message throws ProtocolError(protocolMalformed)', () {
      expect(
        () => RunErrorEvent.fromJson({'type': 'RUN_ERROR', 'code': 'x'}),
        throwsA(
          isA<ProtocolError>().having(
            (e) => e.code,
            'code',
            KoelErrorCode.protocolMalformed,
          ),
        ),
      );
    });

    test('non-String code throws ProtocolError(protocolMalformed)', () {
      expect(
        () => RunErrorEvent.fromJson({
          'type': 'RUN_ERROR',
          'message': 'boom',
          'code': 42,
        }),
        throwsA(
          isA<ProtocolError>().having(
            (e) => e.code,
            'code',
            KoelErrorCode.protocolMalformed,
          ),
        ),
      );
    });

    test(
      'hand-built AgentError (classified code, null agentCode) keeps code on '
      'toJson',
      () {
        const event = RunErrorEvent(
          error: AgentError(message: 'boom', code: KoelErrorCode.agentInternal),
        );
        expect(event.toJson(), {
          'type': 'RUN_ERROR',
          'message': 'boom',
          'code': 'agentInternal',
        });
      },
    );

    test('hand-built AgentError (unknown code, null agentCode) omits code', () {
      const event = RunErrorEvent(
        error: AgentError(message: 'boom', code: KoelErrorCode.unknown),
      );
      expect(event.toJson(), {'type': 'RUN_ERROR', 'message': 'boom'});
    });
  });
}
