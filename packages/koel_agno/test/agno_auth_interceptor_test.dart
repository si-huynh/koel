@TestOn('vm')
library;

import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:koel_agno/koel_agno.dart';
import 'package:koel_core/koel_core.dart';
import 'package:koel_http/koel_http.dart';
import 'package:test/test.dart';

/// A minimal run payload — the body is irrelevant; only the headers are asserted.
RunAgentInput _input() => const RunAgentInput(threadId: 't', runId: 'r');

/// A request-capturing [MockClient] replaying an empty `text/event-stream` body.
({MockClient client, List<Request> captured}) _capturingClient() {
  final captured = <Request>[];
  final client = MockClient((request) async {
    captured.add(request);
    return Response(
      '',
      200,
      headers: const {'content-type': 'text/event-stream'},
    );
  });
  return (client: client, captured: captured);
}

/// Runs a fixed input through a plain [HttpAgent] carrying [interceptor],
/// returning the single captured request.
Future<Request> _runWith(Interceptor interceptor) async {
  final h = _capturingClient();
  await HttpAgent(
    url: Uri.parse('http://host:8002/agno-chat'),
    client: h.client,
    interceptors: [interceptor],
  ).run(_input()).toList();
  return h.captured.single;
}

void main() {
  group('AgnoAuthInterceptor', () {
    test(
      'token == null is a no-op — no Authorization header on the wire',
      () async {
        final request = await _runWith(AgnoAuthInterceptor(token: null));

        expect(
          request.headers.keys.map((k) => k.toLowerCase()),
          isNot(contains('authorization')),
        );
      },
    );

    test('non-null token injects Authorization: Bearer <token>', () async {
      final request = await _runWith(AgnoAuthInterceptor(token: 'abc'));

      // `http` lowercases header keys on the wire.
      expect(request.headers['authorization'], 'Bearer abc');
      // The token never leaks onto the body (stripped before encode).
      expect(request.body, isNot(contains('abc')));
    });

    test('a padded non-blank token is trimmed inside the Bearer header — no '
        'stray whitespace / newline reaches the wire', () async {
      final request = await _runWith(AgnoAuthInterceptor(token: '  abc\n'));

      // Surrounding whitespace is a caller typo, never a valid token; an
      // un-trimmed trailing newline would also be a header-injection vector.
      expect(request.headers['authorization'], 'Bearer abc');
    });

    test('a blank token (empty or whitespace) is a no-op, not a blank '
        '`Bearer ` header', () async {
      for (final blank in const ['', '   ']) {
        final request = await _runWith(AgnoAuthInterceptor(token: blank));

        expect(
          request.headers.keys.map((k) => k.toLowerCase()),
          isNot(contains('authorization')),
          reason:
              'token ${blank.isEmpty ? '(empty)' : '(whitespace)'} '
              'must emit no Authorization header',
        );
      }
    });
  });
}
