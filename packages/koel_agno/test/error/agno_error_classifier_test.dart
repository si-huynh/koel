@TestOn('vm')
library;

import 'dart:io';

import 'package:koel_agno/koel_agno.dart';
import 'package:koel_core/koel_core.dart';
import 'package:test/test.dart';

RunAgentInput _input() => const RunAgentInput(threadId: 't', runId: 'r');

void main() {
  group('AgnoErrorClassifier', () {
    const classifier = AgnoErrorClassifier();

    KoelError classify(Object raw) => classifier.classify(raw, null, _input());

    group(
      'maps agno-meaningful HTTP statuses off TransportError.statusCode',
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

        // If AgnoErrorClassifier delegated to bare super (DefaultErrorClassifier),
        // the by-name match would slip a SocketException to unknown. Delegating to
        // the native transportErrorClassifier() keeps the `is`-based refinement.
        expect(result, isA<TransportError>());
        expect(result.code, KoelErrorCode.transportRefused);
      });

      test('an unrecognized failure reaches the agent-error bucket', () {
        final result = classify(StateError('boom'));

        expect(result, isA<AgentError>());
        expect(result.code, KoelErrorCode.unknown);
      });
    });
  });
}
