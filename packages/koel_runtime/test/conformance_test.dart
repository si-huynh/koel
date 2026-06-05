@TestOn('vm')
@Tags(['conformance'])
library;

import 'package:koel_core/koel_core.dart';
import 'package:koel_runtime/koel_runtime.dart';
import 'package:koel_test/koel_test.dart';
import 'package:test/test.dart';

import '_support.dart';

/// The v2 run route base every replay drives `CopilotRuntimeAgent` against; the
/// `sseClient` ignores it and replays the committed fixture, so the host is inert.
final _endpoint = Uri.parse('http://host:8005/api/copilotkit');

void main() {
  group('CopilotRuntimeAgent conformance (FR-G4) — full matrix, no 7/28', () {
    // One entry per AG-UI type in all_event_types.jsonl (RUN_STARTED … CUSTOM).
    const typeCount = 28;

    // The 3 `*_CHUNK` convenience shapes are NOT reproduced verbatim by ANY
    // HTTP adapter: koel_http's default-on `synthesizeChunks` (Story 4.8)
    // normalizes them into their START/CONTENT/END triplets *at the transport*,
    // so the Epic-5 backends always see long form. `CopilotRuntimeAgent` (like
    // `AgnoAgent`) does not expose `synthesizeChunks`, so 25/28 is its fixed
    // contract — the SAME full canonical surface agno/langgraph prove, versus the
    // legacy GraphQL bridge's lossy 7/28 (the headline of SCP-2026-06-05). The
    // 25 reproduced types include exactly the ones the GraphQL bridge dropped:
    // STATE_DELTA, RUN_ERROR, STEP_STARTED/FINISHED, CUSTOM, MESSAGES_SNAPSHOT,
    // REASONING_*.
    const synthesizedChunkTypes = {
      'TEXT_MESSAGE_CHUNK',
      'TOOL_CALL_CHUNK',
      'REASONING_MESSAGE_CHUNK',
    };

    test('ConformanceRunner reproduces the 25 canonical AG-UI types verbatim '
        'through the inherited HttpAgent SSE parse; the 3 *_CHUNK shapes are '
        'transport-synthesized into long form (AC3)', () async {
      // The synthesized corpus replayed as SSE — the full-matrix proof needs no
      // live backend: CopilotRuntimeAgent is a transparent HttpAgent passthrough.
      // RUN_ERROR rides the wire verbatim (the agent's "terminal RunErrorEvent"
      // classifies only transport/parser *throws*, not a parsed event), so every
      // non-chunk type reaches the runner. (Real captured v2 fixtures + the
      // conformance.yml lane swap are Story 5.11.)
      final client = sseClient(
        sseBody(await fixturePayloads('synthesized', 'all_event_types')),
      );

      final report = await const ConformanceRunner().runAgainst(
        CopilotRuntimeAgent(
          endpoint: Uri.parse('http://host:8005/api/copilotkit'),
          agentName: 'koel_scripted',
          client: client,
        ),
      );

      // The 25 canonical types reproduce verbatim — zero failures among them.
      expect(
        report.passed,
        hasLength(typeCount - synthesizedChunkTypes.length),
      );
      expect(
        report.passed.toSet().intersection(synthesizedChunkTypes),
        isEmpty,
      );
      // The ONLY unmatched types are exactly the 3 synthesized chunk shapes —
      // proves they were normalized, not silently dropped, and no 26th regressed.
      expect(
        report.failed.map((f) => f.eventType).toSet(),
        synthesizedChunkTypes,
      );
      expect(report.agentName, contains('CopilotRuntimeAgent'));
    });

    test(
      'CopilotRuntimeAgent replays the REAL captured v2 text_only_run fixture '
      'verbatim (AC3 + FR-G1) — proves the inherited parse on real v2-SSE wire',
      () async {
        // The fixture is a committed live capture (`make up-copilotkit-v2` →
        // `dart run tool/capture_fixtures.dart --backend=copilotkit`); replaying
        // it through CopilotRuntimeAgent's inherited SSE parse must reproduce the
        // loader's typed events exactly. `fixtures_test.dart` hard-asserts the
        // fixture's presence, so this depends on it unconditionally (no skip).
        final client = sseClient(
          sseBody(await fixturePayloads('copilotkit', 'text_only_run')),
        );

        final events = await CopilotRuntimeAgent(
          endpoint: _endpoint,
          agentName: 'koel_scripted',
          client: client,
        ).run(const RunAgentInput(threadId: 't', runId: 'r')).toList();

        expect(events, await FixtureLoader.loadCopilotkit('text_only_run'));
      },
    );

    test(
      'CopilotRuntimeAgent replays the v2 state_delta_basic fixture verbatim — '
      'a STATE_DELTA rides the wire (headline proof: GraphQL collapsed it away)',
      () async {
        final client = sseClient(
          sseBody(await fixturePayloads('copilotkit', 'state_delta_basic')),
        );

        final events = await CopilotRuntimeAgent(
          endpoint: _endpoint,
          agentName: 'koel_scripted',
          client: client,
        ).run(const RunAgentInput(threadId: 't', runId: 'r')).toList();

        expect(events, await FixtureLoader.loadCopilotkit('state_delta_basic'));
        // The headline: v2 delivers STATE_DELTA on the wire — the lossy GraphQL
        // bridge collapsed it into the preceding STATE_SNAPSHOT (7/28).
        expect(events.whereType<StateDeltaEvent>(), isNotEmpty);
      },
    );

    test(
      'CopilotRuntimeAgent replays the v2 error_path fixture verbatim — a '
      'RUN_ERROR rides the wire (headline proof: GraphQL swallowed it)',
      () async {
        final client = sseClient(
          sseBody(await fixturePayloads('copilotkit', 'error_path')),
        );

        final events = await CopilotRuntimeAgent(
          endpoint: _endpoint,
          agentName: 'koel_scripted',
          client: client,
        ).run(const RunAgentInput(threadId: 't', runId: 'r')).toList();

        expect(events, await FixtureLoader.loadCopilotkit('error_path'));
        // The headline: v2 delivers RUN_ERROR as a parsed wire event — NOT a
        // swallowed-then-Success ending (the GraphQL bridge's 7/28 loss). This is
        // a parsed RunErrorEvent on the stream, not the adapter's terminal-throw
        // classification (no transport/parser error occurred).
        expect(events.whereType<RunErrorEvent>(), isNotEmpty);
      },
    );
  });
}
