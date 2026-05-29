import 'package:koel_core/src/error/koel_error.dart';
import 'package:koel_core/src/error/koel_error_code.dart';
import 'package:test/test.dart';

void main() {
  group('TransportError', () {
    const cause = 'boom';

    test('const construction reads back base getters + specialization', () {
      const e = TransportError(
        message: 'Connection failed',
        code: KoelErrorCode.transportRefused,
        cause: cause,
        statusCode: 503,
      );
      expect(e.message, 'Connection failed');
      expect(e.code, KoelErrorCode.transportRefused);
      expect(e.cause, cause);
      expect(e.statusCode, 503);
    });

    test('cause and statusCode are optional', () {
      const e = TransportError(
        message: 'Request timed out',
        code: KoelErrorCode.transportTimeout,
      );
      expect(e.cause, isNull);
      expect(e.statusCode, isNull);
    });

    test('is both a KoelError and an Exception', () {
      const e = TransportError(
        message: 'x',
        code: KoelErrorCode.transportClosed,
      );
      expect(e, isA<KoelError>());
      expect(e, isA<Exception>());
    });

    test('structural equality and hashCode', () {
      const a = TransportError(
        message: 'x',
        code: KoelErrorCode.transportTimeout,
        statusCode: 504,
      );
      const b = TransportError(
        message: 'x',
        code: KoelErrorCode.transportTimeout,
        statusCode: 504,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('differing on any field breaks equality', () {
      const base = TransportError(
        message: 'x',
        code: KoelErrorCode.transportTimeout,
        statusCode: 504,
      );
      expect(
        base,
        isNot(
          equals(
            const TransportError(
              message: 'y',
              code: KoelErrorCode.transportTimeout,
              statusCode: 504,
            ),
          ),
        ),
      );
      expect(
        base,
        isNot(
          equals(
            const TransportError(
              message: 'x',
              code: KoelErrorCode.transportClosed,
              statusCode: 504,
            ),
          ),
        ),
      );
      expect(
        base,
        isNot(
          equals(
            const TransportError(
              message: 'x',
              code: KoelErrorCode.transportTimeout,
              statusCode: 500,
            ),
          ),
        ),
      );
    });

    test('copyWith updates one field and leaves others identical', () {
      const e = TransportError(
        message: 'x',
        code: KoelErrorCode.transportTimeout,
        statusCode: 504,
      );
      final updated = e.copyWith(statusCode: 500);
      expect(updated.statusCode, 500);
      expect(updated.message, e.message);
      expect(updated.code, e.code);
    });
  });

  group('ProtocolError', () {
    test('const construction reads back base getters + eventType', () {
      const e = ProtocolError(
        message: 'Malformed payload',
        code: KoelErrorCode.protocolMalformed,
        cause: 42,
        eventType: 'TEXT_MESSAGE_START',
      );
      expect(e.message, 'Malformed payload');
      expect(e.code, KoelErrorCode.protocolMalformed);
      expect(e.cause, 42);
      expect(e.eventType, 'TEXT_MESSAGE_START');
    });

    test('is both a KoelError and an Exception', () {
      const e = ProtocolError(
        message: 'x',
        code: KoelErrorCode.protocolUnknownEvent,
      );
      expect(e, isA<KoelError>());
      expect(e, isA<Exception>());
    });

    test('structural equality, inequality, copyWith', () {
      const a = ProtocolError(
        message: 'x',
        code: KoelErrorCode.protocolMalformed,
        eventType: 'A',
      );
      const b = ProtocolError(
        message: 'x',
        code: KoelErrorCode.protocolMalformed,
        eventType: 'A',
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(a.copyWith(eventType: 'B'))));
      expect(a.copyWith(eventType: 'B').message, a.message);
    });
  });

  group('AgentError', () {
    test('const construction reads back base getters + agentCode', () {
      const e = AgentError(
        message: 'Unclassified failure',
        code: KoelErrorCode.unknown,
        cause: 'raw',
        agentCode: 'E_TOOL',
      );
      expect(e.message, 'Unclassified failure');
      expect(e.code, KoelErrorCode.unknown);
      expect(e.cause, 'raw');
      expect(e.agentCode, 'E_TOOL');
    });

    test('is both a KoelError and an Exception', () {
      const e = AgentError(message: 'x', code: KoelErrorCode.agentInternal);
      expect(e, isA<KoelError>());
      expect(e, isA<Exception>());
    });

    test('structural equality, inequality, copyWith', () {
      const a = AgentError(
        message: 'x',
        code: KoelErrorCode.agentRefused,
        agentCode: 'A',
      );
      const b = AgentError(
        message: 'x',
        code: KoelErrorCode.agentRefused,
        agentCode: 'A',
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(a.copyWith(agentCode: 'B'))));
      expect(a.copyWith(agentCode: 'B').code, a.code);
    });
  });

  group('BusinessError', () {
    test('const construction reads back base getters + details', () {
      const e = BusinessError(
        message: 'Rate limited',
        code: KoelErrorCode.businessRateLimited,
        details: {'retryAfter': 30},
      );
      expect(e.message, 'Rate limited');
      expect(e.code, KoelErrorCode.businessRateLimited);
      expect(e.cause, isNull);
      expect(e.details, {'retryAfter': 30});
    });

    test('details defaults to an empty map', () {
      const e = BusinessError(
        message: 'x',
        code: KoelErrorCode.businessForbidden,
      );
      expect(e.details, <String, dynamic>{});
    });

    test('is both a KoelError and an Exception', () {
      const e = BusinessError(message: 'x', code: KoelErrorCode.businessAuth);
      expect(e, isA<KoelError>());
      expect(e, isA<Exception>());
    });

    test(
      'deep structural equality over distinct but content-equal details',
      () {
        BusinessError build() => BusinessError(
          message: 'x',
          code: KoelErrorCode.businessQuotaExceeded,
          details: {
            'limits': {
              'list': [1, 2, 3],
              'flag': true,
            },
          },
        );
        final a = build();
        final b = build();
        expect(identical(a.details, b.details), isFalse);
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      },
    );

    test('differing details breaks equality; copyWith preserves rest', () {
      final a = BusinessError(
        message: 'x',
        code: KoelErrorCode.businessQuotaExceeded,
        details: {'k': 1},
      );
      final b = BusinessError(
        message: 'x',
        code: KoelErrorCode.businessQuotaExceeded,
        details: {'k': 2},
      );
      expect(a, isNot(equals(b)));
      final updated = a.copyWith(message: 'y');
      expect(updated.message, 'y');
      expect(updated.details, a.details);
    });
  });

  test('a consumer switch over KoelError pattern-matches subtypes', () {
    // Forward-compat-correct consumer form: handle the known arms, route the
    // rest through `_` (the switch-expression analog of `default:` that
    // koel_lints requires per FC-2). Deliberately non-exhaustive so the
    // analyzer does not flag `unreachable_switch_default`.
    String describe(KoelError e) => switch (e) {
      TransportError() => 'transport',
      BusinessError() => 'business',
      _ => 'other',
    };
    expect(
      describe(
        const TransportError(message: 'x', code: KoelErrorCode.transportClosed),
      ),
      'transport',
    );
    expect(
      describe(
        const BusinessError(message: 'x', code: KoelErrorCode.businessAuth),
      ),
      'business',
    );
    expect(
      describe(
        const ProtocolError(
          message: 'x',
          code: KoelErrorCode.protocolMalformed,
        ),
      ),
      'other',
    );
  });
}
