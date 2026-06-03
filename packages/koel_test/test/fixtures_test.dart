import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

/// Story 3.2 structural validation of the synthesized fixture set + storage
/// layout. This suite validates **JSON structure only** — it never decodes a
/// `payload` into an `AgUiEvent`, because the wire deserializer is internal to
/// `koel_core` (not on its public barrel). Semantic payload→event decoding is
/// Story 3.3's `FixtureLoader`. `Directory.current` is the package root under
/// `dart test` / `melos run test`, so paths resolve from there (same pattern as
/// `koel_core/test/event/full_event_sweep_test.dart`).
void main() {
  const fixturesDir = 'lib/src/fixtures';
  const synthesizedDir = '$fixturesDir/synthesized';

  /// The six core scenarios required verbatim by AC1, plus the coverage sweep.
  const coreScenarios = <String>{
    'text_only_run',
    'tool_call_basic',
    'state_delta_basic',
    'reasoning_with_encrypted_value',
    'error_path',
    'cancellation',
  };
  const coverageFixture = 'all_event_types';

  /// The four backend fixture dirs (all exist from Story 3.2).
  const backendDirs = <String>{
    'dojo',
    'agno',
    'langgraph',
    'copilotkit_runtime',
  };

  /// Backend dirs still awaiting their Epic-5 capture — they hold only a
  /// `.placeholder` and no `.jsonl`. `agno` graduated in Story 5.3 (real
  /// `text_only_run.jsonl` captured), so it is no longer pending.
  const pendingCaptureDirs = <String>{
    'dojo',
    'langgraph',
    'copilotkit_runtime',
  };

  /// The `_session` header fields AC2 names.
  const requiredSessionFields = <String>{
    'koelVersion',
    'adapter',
    'captured',
    'threadId',
    'runId',
    'synthesized',
  };

  /// The full closed set of AG-UI wire types (mirrors `koel_core`'s internal
  /// `eventTypeRegistry` and `koel_core/test/event/full_event_sweep.jsonl`).
  /// Frozen here because the registry is not exported from the public barrel;
  /// a coverage gap fails loudly with the missing type named.
  const registeredWireTypes = <String>{
    'RUN_STARTED',
    'RUN_FINISHED',
    'RUN_ERROR',
    'STEP_STARTED',
    'STEP_FINISHED',
    'TEXT_MESSAGE_START',
    'TEXT_MESSAGE_CONTENT',
    'TEXT_MESSAGE_END',
    'TEXT_MESSAGE_CHUNK',
    'TOOL_CALL_START',
    'TOOL_CALL_ARGS',
    'TOOL_CALL_END',
    'TOOL_CALL_RESULT',
    'TOOL_CALL_CHUNK',
    'STATE_SNAPSHOT',
    'STATE_DELTA',
    'MESSAGES_SNAPSHOT',
    'ACTIVITY_SNAPSHOT',
    'ACTIVITY_DELTA',
    'REASONING_START',
    'REASONING_END',
    'REASONING_MESSAGE_START',
    'REASONING_MESSAGE_CONTENT',
    'REASONING_MESSAGE_END',
    'REASONING_MESSAGE_CHUNK',
    'REASONING_ENCRYPTED_VALUE',
    'RAW',
    'CUSTOM',
  };

  /// Non-blank physical lines of a fixture file, in order.
  List<String> linesOf(String path) => File(
    path,
  ).readAsLinesSync().where((line) => line.trim().isNotEmpty).toList();

  List<File> synthesizedFixtures() => Directory(synthesizedDir)
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.jsonl'))
      .toList();

  group('fixture storage layout (AC1, AC4)', () {
    test('the five fixture subdirectories exist', () {
      for (final dir in {'synthesized', ...backendDirs}) {
        expect(
          Directory('$fixturesDir/$dir').existsSync(),
          isTrue,
          reason: 'missing fixture subdirectory: $dir',
        );
      }
    });

    test('synthesized/ holds at least one .jsonl fixture', () {
      expect(
        synthesizedFixtures(),
        isNotEmpty,
        reason: 'no .jsonl fixtures found under $synthesizedDir',
      );
    });

    test('synthesized/ contains the six core scenarios + coverage sweep', () {
      for (final name in {...coreScenarios, coverageFixture}) {
        expect(
          File('$synthesizedDir/$name.jsonl').existsSync(),
          isTrue,
          reason: 'missing synthesized fixture: $name.jsonl',
        );
      }
    });

    test(
      'each pending backend dir carries a .placeholder and no captured fixtures',
      () {
        for (final dir in pendingCaptureDirs) {
          expect(
            File('$fixturesDir/$dir/.placeholder').existsSync(),
            isTrue,
            reason: '$dir/ is missing its .placeholder',
          );
          final captures = Directory('$fixturesDir/$dir')
              .listSync()
              .whereType<File>()
              .where((f) => f.path.endsWith('.jsonl'))
              .toList();
          expect(
            captures,
            isEmpty,
            reason:
                '$dir/ must hold no captured fixtures until Epic 5: $captures',
          );
        }
      },
    );

    test('agno/ graduated (Story 5.3) — real text_only_run capture, no '
        'placeholder', () {
      expect(
        File('$fixturesDir/agno/text_only_run.jsonl').existsSync(),
        isTrue,
        reason: 'agno/ must hold the captured text_only_run.jsonl',
      );
      expect(
        File('$fixturesDir/agno/.placeholder').existsSync(),
        isFalse,
        reason: 'agno/ .placeholder must be removed once a capture lands',
      );
      // The capture is real (live agno), not synthesized.
      final session =
          (jsonDecode(linesOf('$fixturesDir/agno/text_only_run.jsonl').first)
                  as Map<String, dynamic>)['_session']
              as Map<String, dynamic>;
      expect(session['synthesized'], isFalse);
      expect(session['adapter'], startsWith('koel_agno@'));
      expect(session['backendVersion'], startsWith('agno=='));
    });
  });

  group('synthesized fixture format (AC2)', () {
    test('no fixture has a blank or whitespace-only line', () {
      for (final fixture in synthesizedFixtures()) {
        final raw = File(fixture.path).readAsLinesSync();
        expect(
          raw.where((l) => l.trim().isEmpty),
          isEmpty,
          reason: 'blank line in ${fixture.path}',
        );
      }
    });

    test(
      'first line is a _session header with exactly the required fields',
      () {
        for (final fixture in synthesizedFixtures()) {
          final lines = linesOf(fixture.path);
          expect(
            lines.length,
            greaterThan(1),
            reason: '${fixture.path} must hold a header + at least one event',
          );
          final decodedHeader = jsonDecode(lines.first);
          expect(
            decodedHeader,
            isA<Map<String, dynamic>>(),
            reason: 'header of ${fixture.path} is not a JSON object',
          );
          final header = decodedHeader as Map<String, dynamic>;
          expect(
            header.keys,
            equals(['_session']),
            reason:
                'header of ${fixture.path} must hold exactly one _session key',
          );
          final session = header['_session'];
          expect(
            session,
            isA<Map<String, dynamic>>(),
            reason: '${fixture.path} _session must be an object',
          );
          expect(
            (session as Map<String, dynamic>).keys.toSet(),
            equals(requiredSessionFields),
            reason:
                '${fixture.path} _session must carry exactly: '
                '$requiredSessionFields',
          );
          expect(
            session['synthesized'],
            isTrue,
            reason: '${fixture.path} must mark synthesized: true',
          );
        }
      },
    );

    test('every event line is a well-formed {type, timestamp, payload}', () {
      for (final fixture in synthesizedFixtures()) {
        for (final line in linesOf(fixture.path).skip(1)) {
          final decoded = jsonDecode(line);
          expect(
            decoded,
            isA<Map<String, dynamic>>(),
            reason: 'event line is not a JSON object in ${fixture.path}: $line',
          );
          final event = decoded as Map<String, dynamic>;
          expect(event['type'], isA<String>(), reason: line);
          expect(event['timestamp'], isA<String>(), reason: line);
          expect(
            () => DateTime.parse(event['timestamp'] as String),
            returnsNormally,
            reason: 'unparseable timestamp in ${fixture.path}: $line',
          );
          final payload = event['payload'];
          expect(payload, isA<Map<String, dynamic>>(), reason: line);
          expect(
            (payload as Map<String, dynamic>)['type'],
            equals(event['type']),
            reason:
                'payload.type must mirror line type in ${fixture.path}: $line',
          );
        }
      }
    });
  });

  group('event-type coverage (AC1)', () {
    test('synthesized fixtures cover every registered wire type', () {
      final covered = <String>{};
      for (final fixture in synthesizedFixtures()) {
        for (final line in linesOf(fixture.path).skip(1)) {
          covered.add(
            (jsonDecode(line) as Map<String, dynamic>)['type'] as String,
          );
        }
      }
      expect(
        covered,
        equals(registeredWireTypes),
        reason:
            'synthesized fixtures must cover exactly the registered wire '
            'types; missing: ${registeredWireTypes.difference(covered)}, '
            'unexpected: ${covered.difference(registeredWireTypes)}',
      );
    });
  });

  group('self-consistency (Story 3.3/3.5 replay)', () {
    test('run-bracket events agree with the _session header ids', () {
      for (final fixture in synthesizedFixtures()) {
        final lines = linesOf(fixture.path);
        final session =
            (jsonDecode(lines.first) as Map<String, dynamic>)['_session']
                as Map<String, dynamic>;
        for (final line in lines.skip(1)) {
          final payload =
              (jsonDecode(line) as Map<String, dynamic>)['payload']
                  as Map<String, dynamic>;
          if (payload['type'] == 'RUN_STARTED' ||
              payload['type'] == 'RUN_FINISHED') {
            expect(
              payload['threadId'],
              equals(session['threadId']),
              reason: 'run-bracket threadId drift in ${fixture.path}: $line',
            );
            expect(
              payload['runId'],
              equals(session['runId']),
              reason: 'run-bracket runId drift in ${fixture.path}: $line',
            );
          }
        }
      }
    });

    test('event timestamps increase monotonically per fixture', () {
      for (final fixture in synthesizedFixtures()) {
        DateTime? previous;
        for (final line in linesOf(fixture.path).skip(1)) {
          final timestamp = DateTime.parse(
            (jsonDecode(line) as Map<String, dynamic>)['timestamp'] as String,
          );
          if (previous != null) {
            expect(
              timestamp.isAfter(previous),
              isTrue,
              reason: 'non-monotonic timestamp in ${fixture.path}: $line',
            );
          }
          previous = timestamp;
        }
      }
    });
  });
}
