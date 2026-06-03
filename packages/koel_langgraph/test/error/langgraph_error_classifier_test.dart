@TestOn('vm')
library;

import 'dart:io';

import 'package:koel_core/koel_core.dart';
import 'package:koel_langgraph/koel_langgraph.dart';
import 'package:test/test.dart';

RunAgentInput _input() => const RunAgentInput(threadId: 't', runId: 'r');

void main() {
  group('LangGraphErrorClassifier', () {
    const classifier = LangGraphErrorClassifier();

    KoelError classify(Object raw) => classifier.classify(raw, null, _input());

    group(
      'maps the x-api-key middleware HTTP statuses off TransportError.statusCode',
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
      },
    );

    group('delegates everything else to the native transport classifier', () {
      test('an unmapped status passes through unchanged', () {
        const raw = TransportError(
          message: 'AG-UI endpoint returned HTTP 500',
          code: KoelErrorCode.transportClosed,
          statusCode: 500,
        );

        // Idempotent passthrough of an already-typed KoelError.
        expect(classify(raw), same(raw));
      });

      test('a TransportError without a statusCode passes through', () {
        const raw = TransportError(
          message: 'Connection failed',
          code: KoelErrorCode.transportRefused,
        );

        expect(classify(raw), same(raw));
      });

      test('socket-wrapper refinement is preserved — a SocketException '
          'classifies transportRefused, NOT unknown', () {
        final result = classify(const SocketException('refused'));

        // If LangGraphErrorClassifier delegated to bare super
        // (DefaultErrorClassifier), the by-name match would slip a
        // SocketException to unknown. Delegating to the native
        // transportErrorClassifier() keeps the `is`-based refinement.
        expect(result, isA<TransportError>());
        expect(result.code, KoelErrorCode.transportRefused);
      });

      test('an unrecognized failure reaches the agent-error bucket', () {
        final result = classify(StateError('boom'));

        expect(result, isA<AgentError>());
        expect(result.code, KoelErrorCode.unknown);
      });

      test('an injected inner classifier overrides the default delegate', () {
        const classifier = LangGraphErrorClassifier(
          inner: _ConstantClassifier(),
        );

        // A non-status failure routes to the injected inner, not the platform
        // transport classifier — proves the seam is honored.
        final result = classifier.classify(StateError('x'), null, _input());
        expect(result.code, KoelErrorCode.agentRefused);
      });
    });
  });
}

/// A stub [ErrorClassifier] that maps every failure to a single sentinel code —
/// proves [LangGraphErrorClassifier] routes non-status failures to its injected
/// `inner` delegate rather than the platform default.
final class _ConstantClassifier implements ErrorClassifier {
  const _ConstantClassifier();

  @override
  KoelError classify(Object raw, StackTrace? stack, RunAgentInput input) =>
      const AgentError(message: 'constant', code: KoelErrorCode.agentRefused);
}
