@TestOn('vm')
library;

import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:koel_core/koel_core.dart';
import 'package:koel_http/koel_http.dart';
import 'package:koel_langgraph/koel_langgraph.dart';
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
    url: Uri.parse('http://host:8003/agent'),
    client: h.client,
    interceptors: [interceptor],
  ).run(_input()).toList();
  return h.captured.single;
}

void main() {
  group('LangGraphAuthInterceptor', () {
    test(
      'apiKey == null is a no-op — no x-api-key header on the wire',
      () async {
        final request = await _runWith(LangGraphAuthInterceptor(apiKey: null));

        expect(
          request.headers.keys.map((k) => k.toLowerCase()),
          isNot(contains('x-api-key')),
        );
      },
    );

    test(
      'non-null apiKey injects the value under x-api-key — not Bearer',
      () async {
        final request = await _runWith(LangGraphAuthInterceptor(apiKey: 'abc'));

        // `http` lowercases header keys on the wire.
        expect(request.headers['x-api-key'], 'abc');
        // LangGraph is x-api-key, not Authorization: Bearer.
        expect(
          request.headers.keys.map((k) => k.toLowerCase()),
          isNot(contains('authorization')),
        );
        expect(request.headers['x-api-key'], isNot(startsWith('Bearer')));
        // The key never leaks onto the body (stripped before encode).
        expect(request.body, isNot(contains('abc')));
      },
    );

    test('a padded non-blank apiKey is trimmed on the wire — no stray '
        'whitespace / newline reaches the header', () async {
      final request = await _runWith(
        LangGraphAuthInterceptor(apiKey: '  abc\n'),
      );

      // Surrounding whitespace is a caller typo, never a valid key; an
      // un-trimmed trailing newline would also be a header-injection vector.
      expect(request.headers['x-api-key'], 'abc');
    });

    test('a blank apiKey (empty or whitespace) is a no-op, not a blank '
        'x-api-key header', () async {
      for (final blank in const ['', '   ']) {
        final request = await _runWith(LangGraphAuthInterceptor(apiKey: blank));

        expect(
          request.headers.keys.map((k) => k.toLowerCase()),
          isNot(contains('x-api-key')),
          reason:
              'apiKey ${blank.isEmpty ? '(empty)' : '(whitespace)'} '
              'must emit no x-api-key header',
        );
      }
    });
  });
}
