@TestOn('vm')
library;

import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:koel_core/koel_core.dart';
import 'package:koel_runtime/koel_runtime.dart';
import 'package:test/test.dart';

RunAgentInput _input() => const RunAgentInput(threadId: 't', runId: 'r');

void main() {
  group('CopilotRuntimeErrorClassifier', () {
    const classifier = CopilotRuntimeErrorClassifier();

    KoelError classify(Object raw) => classifier.classify(raw, null, _input());

    group(
      'maps the v2 runtime HTTP statuses off TransportError.statusCode',
      () {
        test('401 → businessAuth', () {
          final result = classify(
            const TransportError(
              message: 'AG-UI endpoint returned HTTP 401',
              code: KoelErrorCode.transportClosed,
              statusCode: 401,
            ),
          );

          expect(result, isA<BusinessError>());
          expect(result.code, KoelErrorCode.businessAuth);
          // The original transport failure is preserved as the cause.
          expect((result as BusinessError).cause, isA<TransportError>());
        });

        test('403 → businessForbidden', () {
          final result = classify(
            const TransportError(
              message: 'AG-UI endpoint returned HTTP 403',
              code: KoelErrorCode.transportClosed,
              statusCode: 403,
            ),
          );

          expect(result.code, KoelErrorCode.businessForbidden);
        });

        test('429 → businessRateLimited', () {
          final result = classify(
            const TransportError(
              message: 'AG-UI endpoint returned HTTP 429',
              code: KoelErrorCode.transportClosed,
              statusCode: 429,
            ),
          );

          expect(result.code, KoelErrorCode.businessRateLimited);
        });

        test('500 → agentInternal (the runtime\'s own internal fault)', () {
          final result = classify(
            const TransportError(
              message: 'AG-UI endpoint returned HTTP 500',
              code: KoelErrorCode.transportClosed,
              statusCode: 500,
            ),
          );

          expect(result, isA<AgentError>());
          expect(result.code, KoelErrorCode.agentInternal);
          expect((result as AgentError).cause, isA<TransportError>());
        });
      },
    );

    group('delegates everything else to the native transport classifier', () {
      test('an unmapped status passes through unchanged (idempotent)', () {
        const raw = TransportError(
          message: 'AG-UI endpoint returned HTTP 502',
          code: KoelErrorCode.transportClosed,
          statusCode: 502,
        );

        expect(classify(raw), same(raw));
      });

      test('a TransportError without a statusCode passes through', () {
        const raw = TransportError(
          message: 'Connection failed',
          code: KoelErrorCode.transportRefused,
        );

        expect(classify(raw), same(raw));
      });

      test('an SSE-parser ProtocolError passes through unchanged', () {
        const raw = ProtocolError(
          message: 'Malformed SSE frame',
          code: KoelErrorCode.protocolMalformed,
        );

        expect(classify(raw), same(raw));
      });

      test('socket-wrapper refinement is preserved — a SocketException '
          'classifies transportRefused, NOT unknown (RESOLVED #3: D5 reversed, '
          'so the inner delegate is transportErrorClassifier())', () {
        final result = classify(const SocketException('refused'));

        // The old (5.9) classifier delegated to the framework-free
        // DefaultErrorClassifier (D5 forbade koel_http); the native refinement
        // sees through package:http's `_ClientSocketException` wrapper — the bug
        // a bare DefaultErrorClassifier would slip to unknown on the real path.
        expect(result, isA<TransportError>());
        expect(result.code, KoelErrorCode.transportRefused);
      });

      test('a package:http ClientException classifies transportClosed (the '
          'native classifier defers the by-name arm to super)', () {
        final result = classify(http.ClientException('connection refused'));

        expect(result, isA<TransportError>());
        expect(result.code, KoelErrorCode.transportClosed);
      });

      test('an unrecognized failure reaches the agent-error bucket', () {
        final result = classify(StateError('boom'));

        expect(result, isA<AgentError>());
        expect(result.code, KoelErrorCode.unknown);
      });

      test('an injected inner classifier overrides the default delegate', () {
        const injected = CopilotRuntimeErrorClassifier(
          inner: _ConstantClassifier(),
        );

        // A non-status failure routes to the injected inner, not the native
        // delegate — proves the seam is honored.
        final result = injected.classify(StateError('x'), null, _input());
        expect(result.code, KoelErrorCode.agentRefused);
      });
    });
  });
}

/// A stub [ErrorClassifier] mapping every failure to a single sentinel code —
/// proves [CopilotRuntimeErrorClassifier] routes non-status failures to its
/// injected `inner` delegate rather than the native base.
final class _ConstantClassifier implements ErrorClassifier {
  const _ConstantClassifier();

  @override
  KoelError classify(Object raw, StackTrace? stack, RunAgentInput input) =>
      const AgentError(message: 'constant', code: KoelErrorCode.agentRefused);
}
