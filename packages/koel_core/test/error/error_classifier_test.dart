import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:koel_core/src/error/error_classifier.dart';
import 'package:koel_core/src/error/koel_error.dart';
import 'package:koel_core/src/error/koel_error_code.dart';
import 'package:koel_core/src/input/run_agent_input.dart';
import 'package:test/test.dart';

/// Stand-in for `package:http`'s `ClientException`, which is not a koel_core
/// dependency. The classifier matches it by runtime type *name*, so a local
/// class whose name is `ClientException` exercises that path with full fidelity.
class ClientException implements Exception {}

/// An unmapped custom exception, used to drive the `unknown` bucket.
class CustomException implements Exception {}

/// A `SocketException` subtype whose runtime-type *name* is not the bare
/// `SocketException`. Locks the documented name-match caveat (Story 2.3): the
/// base classifier matches `dart:io` shapes by `runtimeType.toString()`, so a
/// renamed/private-impl subtype slips to `unknown` even though `is
/// SocketException` would catch it (the is-vs-name asymmetry). koel_http's
/// `TransportErrorClassifier` (real `is`) is the layer that closes this on the
/// native transport path.
class RenamedSocketException implements SocketException {
  @override
  String get message => 'refused';

  @override
  OSError? get osError => null;

  @override
  InternetAddress? get address => null;

  @override
  int? get port => null;
}

const _input = RunAgentInput(threadId: 't', runId: 'r');

void main() {
  final classifier = DefaultErrorClassifier();

  group('DefaultErrorClassifier mapped shapes', () {
    test('TimeoutException → TransportError(transportTimeout)', () {
      final raw = TimeoutException('slow');
      final e = classifier.classify(raw, null, _input);
      expect(e, isA<TransportError>());
      expect(e.code, KoelErrorCode.transportTimeout);
      expect(e.cause, same(raw));
    });

    test('FormatException → ProtocolError(protocolMalformed)', () {
      final raw = FormatException('bad json');
      final e = classifier.classify(raw, null, _input);
      expect(e, isA<ProtocolError>());
      expect(e.code, KoelErrorCode.protocolMalformed);
      expect(e.cause, same(raw));
    });

    test('SocketException → TransportError(transportRefused)', () {
      final raw = SocketException('refused');
      final e = classifier.classify(raw, null, _input);
      expect(e, isA<TransportError>());
      expect(e.code, KoelErrorCode.transportRefused);
      expect(e.cause, same(raw));
    });

    test('HandshakeException → TransportError(transportTlsFail)', () {
      final raw = HandshakeException('tls');
      final e = classifier.classify(raw, null, _input);
      expect(e, isA<TransportError>());
      expect(e.code, KoelErrorCode.transportTlsFail);
      expect(e.cause, same(raw));
    });

    test('HttpException → TransportError(transportClosed)', () {
      final raw = HttpException('closed');
      final e = classifier.classify(raw, null, _input);
      expect(e, isA<TransportError>());
      expect(e.code, KoelErrorCode.transportClosed);
      expect(e.cause, same(raw));
    });

    test('ClientException (by name) → TransportError(transportClosed)', () {
      final raw = ClientException();
      final e = classifier.classify(raw, null, _input);
      expect(e, isA<TransportError>());
      expect(e.code, KoelErrorCode.transportClosed);
      expect(e.cause, same(raw));
    });
  });

  group('DefaultErrorClassifier unknown bucket — never throws', () {
    test('thrown String → AgentError(unknown)', () {
      final e = classifier.classify('boom', null, _input);
      expect(e, isA<AgentError>());
      expect(e.code, KoelErrorCode.unknown);
      expect(e.cause, 'boom');
    });

    test('thrown int → AgentError(unknown)', () {
      final e = classifier.classify(42, null, _input);
      expect(e, isA<AgentError>());
      expect(e.code, KoelErrorCode.unknown);
      expect(e.cause, 42);
    });

    test('ArgumentError → AgentError(unknown)', () {
      final raw = ArgumentError('bad');
      final e = classifier.classify(raw, null, _input);
      expect(e, isA<AgentError>());
      expect(e.code, KoelErrorCode.unknown);
      expect(e.cause, same(raw));
    });

    test('a SocketException subtype with a non-bare runtime name slips to '
        'unknown — the documented is-vs-name asymmetry (Story 2.3)', () {
      final raw = RenamedSocketException();
      // Sanity: it really IS a SocketException — an `is` check would catch it.
      expect(raw, isA<SocketException>());
      // But the base matches dart:io shapes by runtime-type NAME, so the renamed
      // subtype routes to unknown. koel_http's TransportErrorClassifier (real
      // `is`) closes this on the native path.
      final e = classifier.classify(raw, null, _input);
      expect(e, isA<AgentError>());
      expect(e.code, KoelErrorCode.unknown);
      expect(e.cause, same(raw));
    });

    test('an already-classified KoelError round-trips identically', () {
      // Idempotency: re-classifying a typed KoelError (e.g. a ProtocolError
      // thrown upstream by JsonPatch.apply, Story 2.4) must preserve its
      // code/subtype, not re-wrap it into AgentError(unknown).
      const raw = ProtocolError(
        message: 'Malformed payload',
        code: KoelErrorCode.protocolMalformed,
        eventType: 'TEXT_MESSAGE_START',
      );
      final e = classifier.classify(raw, null, _input);
      expect(e, same(raw));
      expect(e.code, KoelErrorCode.protocolMalformed);
    });
  });

  group('DefaultErrorClassifier property-based coverage', () {
    // A deterministic, seeded pool of raw failure shapes — mapped and
    // deliberately-unmapped — drawn ≥ 50 times. Seeded for reproducible
    // failures; no new dependency (package:math only).
    List<Object> buildPool() => <Object>[
      TimeoutException('t'),
      FormatException('f'),
      SocketException('s'),
      HandshakeException('h'),
      HttpException('x'),
      ClientException(),
      StateError('state'),
      ArgumentError('arg'),
      CustomException(),
      'a thrown string',
      7,
      3.14,
      const <String, dynamic>{'thrown': 'map'},
    ];

    test('every draw yields a non-null KoelError with raw as cause', () {
      final rng = Random(0xC0FFEE);
      final pool = buildPool();

      // Bucket via a consumer-style switch over KoelError WITH a `default:`
      // arm — exactly the positive case AC4 wants to analyze clean under
      // koel_lints. (The negative, default-less case belongs to Story 2.8.)
      final counts = <String, int>{};
      for (var i = 0; i < 60; i++) {
        final raw = pool[rng.nextInt(pool.length)];
        final result = classifier.classify(raw, null, _input);

        expect(result.code, isA<KoelErrorCode>());
        expect(result.cause, same(raw));

        // Consumer-style switch STATEMENT over the sealed KoelError WITH a
        // `default:` arm — the positive case AC4 wants analyzing clean under
        // koel_lints. It is deliberately NON-exhaustive (BusinessError routes
        // through `default:`): koel_lints mandates the `default:` for
        // forward-compat (FC-2), and the analyzer would flag it
        // `unreachable_switch_default` if every subtype were enumerated. The
        // forward-compat-correct consumer pattern is exactly this — handle the
        // known arms, default the rest. (The negative, default-less case is
        // Story 2.8's.)
        final String bucket;
        switch (result) {
          case TransportError():
            bucket = 'transport';
          case ProtocolError():
            bucket = 'protocol';
          case AgentError():
            bucket = 'agent';
          default:
            bucket = 'other';
        }
        counts.update(bucket, (n) => n + 1, ifAbsent: () => 1);
      }

      // Sanity: the run touched both a mapped (transport) and an unmapped
      // (agent/unknown) branch given the pool + seed.
      expect(counts['transport'], greaterThan(0));
      expect(counts['agent'], greaterThan(0));
      expect(counts['other'], isNull);
    });
  });
}
