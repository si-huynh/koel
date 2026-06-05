// Fixture-capture pipeline (AR-14). Repo-level tool — NOT a package `lib/`
// file, so it carries no pubspec of its own and is outside every package's
// coverage scope. Zero-dependency `dart:io`/`dart:convert` (no `package:args`,
// no `package:http`): a repo tool resolves only against the workspace root.
//
// `--backend=agno` (Story 5.3) captures a real run from a live agno deployment
// (`make up-agno` in ../koel_backend) into a single text-run JSONL fixture.
// `--backend=langgraph` (Story 5.6) captures the six scenarios a live LangGraph
// deployment (`make up-langgraph`, port 8003, `POST /agent`) natively emits —
// text, state, tool, error, and the interrupt→resume pair — each into its own
// `<scenario>.jsonl` under koel_test.
//
// `--backend=dojo` (Story 5.9) captures the twelve deterministic AG-UI dojo
// routes (`make up-dojo`, port 8001, SSE over `POST /<route>`), one fixture each,
// EXCLUDING `/predictive_state_updates` (nondeterministic dog names, RESOLVED
// #2). The dojo has no `/status`, so its version is operator-supplied via
// `--backend-version` (default `0.1.18`, RESOLVED #1). Still zero-dep SSE.
//
// `--backend=copilotkit` (Story 5.11) captures the four scenarios the CopilotKit
// **v2** runtime (`make up-copilotkit-v2`, port 8005,
// `POST /api/copilotkit/agent/{agentName}/run`) natively emits over SSE — text,
// tool, state (`STATE_SNAPSHOT` + `STATE_DELTA`), and error (a wire `RUN_ERROR`),
// keyed by the last user-message content (`copilotkit_v2/agent.mjs scenarioFor`).
// v2 (≥1.52) dropped GraphQL for native AG-UI/SSE — the SAME wire agno/langgraph
// emit — so this branch is plain zero-dep `dart:io` SSE via `_postSseRun`, exactly
// like agno/langgraph/dojo; the lossy multipart-GraphQL bridge (and its
// `koel_runtime`/`package:http` capture path) is removed. NOTE the deliberate
// name asymmetry: the koel-side fixture lane/flag is `--backend=copilotkit` (one
// CopilotKit adapter remains after the GraphQL removal), while the sibling
// koel_backend reference dir stays `copilotkit_v2/` (the SCP names it); the flag
// names the adapter, the operator points `--base-url` at the v2 backend (:8005).
//
// Invoke via `dart run tool/capture_fixtures.dart --backend=<name>
// [--base-url=…] [--token=…] [--backend-version=…] [--agent-name=…]` or
// `melos run capture-fixtures -- --backend=<name>`.
//
// Honest scope (Story 5.3, per ../koel_backend/backends/agno/CONTRACT.md): agno
// + the shared mock-LLM emits ONLY the text-run event chain (RUN_STARTED →
// TEXT_MESSAGE_* → RUN_FINISHED). Tool-call / state-delta / reasoning / native
// agent-error / cancellation are NOT natively emittable, so they are NOT
// captured for agno as `synthesized: false`; full AG-UI type conformance is
// proven instead by ConformanceRunner driving AgnoAgent over the all_event_types
// corpus. LangGraph's scripted graph drives far more (`state.scenario`), so its
// capture is richer (Story 5.6).
//
// Determinism: each backend normalizes only the id fields its wire leaves
// nondeterministic, to a stable first-seen token, so re-capture is byte-stable.
// agno's lone variable is `messageId` (UUID4, SPIKE-MOCK). LangGraph's scripted
// graph fixes `messageId` (`msg-scripted-*`) and `toolCallId` (`tool-scripted-1`)
// in code; its lone variable is the server-minted `runId` (UUID7) that
// `ag-ui-langgraph` stamps onto `RUN_FINISHED` — so the langgraph path
// additionally normalizes `runId` (and `toolCallId`, forward-safe against a
// future non-scripted build). CONTRACT.md's normalize set is
// `[timestamp, runId, threadId, messageId, toolCallId]`; `threadId` is the
// caller-fixed input and `timestamp` is synthetic in the envelope, leaving the
// id fields above as the only wire-side work.
import 'dart:convert';
import 'dart:io';

/// The four AG-UI backends Epic 5 captures, mapped to the story that wires each.
/// `agno` (5.3), `langgraph` (5.6), `dojo` (5.9), and — this story — `copilotkit`
/// v2 (5.11) are all live native-SSE captures.
const Map<String, String> _backends = {
  'agno': '5.3',
  'langgraph': '5.6',
  'dojo': '5.9',
  'copilotkit': '5.11',
};

/// koel's version stamped into a fixture's `_session.koelVersion` (mirrors the
/// synthesized fixtures' `0.0.1`).
const String _koelVersion = '0.0.1';

/// The koel_agno adapter version stamped into `_session.adapter`. Tracks
/// koel_agno's pubspec `version` (the epic's literal `0.1.0` is pre-1.0 drift —
/// the real package version wins).
const String _koelAgnoVersion = '0.0.1';

/// The koel_langgraph adapter version stamped into `_session.adapter`. Tracks
/// koel_langgraph's pubspec `version`.
const String _koelLangGraphVersion = '0.0.1';

/// The koel_runtime adapter version stamped into a dojo/copilotkit fixture's
/// `_session.adapter`. Tracks koel_runtime's pubspec `version`.
const String _koelRuntimeVersion = '0.0.1';

/// The dojo backend version stamped into `_session.backendVersion` when no
/// `--backend-version` flag is passed. The dojo exposes NO version HTTP endpoint
/// (RESOLVED #1 — its version lives only in the Docker `LABEL`), so the stamp is
/// operator-supplied; this default is the pinned python SDK version
/// (`ag-ui-protocol==0.1.18`, SPIKE-DOJO-COVERAGE).
const String _dojoDefaultVersion = '0.1.18';

/// The CopilotKit v2 runtime version stamped into a copilotkit fixture's
/// `_session.backendVersion` when the live `x-copilotkit-runtime-version`
/// response header is absent (the v2 runtime may not send it). The pinned
/// reference backend is `@copilotkit/runtime@1.59.4` (SPIKE-CK-V2,
/// `copilotkit_v2/package.json`); overridable via `--backend-version`.
const String _copilotkitDefaultVersion = '1.59.4';

/// The canonical text-run `RunAgentInput` POSTed to capture agno's
/// `text_only_run` (the exact shape from CONTRACT.md's probe — camelCase, parsed
/// directly by agno's `ag_ui.core.types.RunAgentInput`).
const Map<String, dynamic> _textRunInput = {
  'threadId': 't',
  'runId': 'r',
  'state': <String, dynamic>{},
  'messages': [
    {'id': 'm-1', 'role': 'user', 'content': 'hello'},
  ],
  'tools': <dynamic>[],
  'context': <dynamic>[],
  'forwardedProps': <String, dynamic>{},
};

/// One captured LangGraph scenario: the `state.scenario` the scripted graph
/// branches on, the fixture file it lands in, the `threadId` it runs under, and
/// — for the resume half of the interrupt pair — the value POSTed in
/// `forwardedProps.command.resume`.
///
/// The interrupt pair shares one `threadId` and MUST run in order: `paused`
/// first (drives the graph to `interrupt()` and checkpoints), then `resume`
/// (re-enters the same checkpoint with the resume value). Order is the list
/// order below.
typedef _LangGraphScenario = ({
  String file,
  String scenario,
  String threadId,
  bool resume,
  Object? resumeValue,
});

/// The six scenarios the LangGraph backend natively emits (CONTRACT.md
/// §Event-type coverage), each captured as its own `synthesized: false` fixture.
/// File names reuse the synthesized core-scenario vocabulary where they overlap
/// (`text_only_run`, `state_delta_basic`, `tool_call_basic`, `error_path`); the
/// interrupt pair has no synthesized analogue.
///
/// Each scenario runs under its **own** `threadId`: the scripted graph's
/// `add_messages` reducer accumulates state per thread in the shared
/// `MemorySaver`, so a reused thread would let one scenario's run bleed into the
/// next's `STATE_SNAPSHOT`/`MESSAGES_SNAPSHOT`. Distinct threads keep each fixture
/// a clean single-run capture. The interrupt pair deliberately shares one thread
/// — `paused` checkpoints at `interrupt()` and `resume` re-enters that same
/// checkpoint (SPIKE-LG-RESUME), which is the whole point of the pair.
const List<_LangGraphScenario> _langGraphScenarios = [
  (
    file: 'text_only_run',
    scenario: 'text',
    threadId: 't-text',
    resume: false,
    resumeValue: null,
  ),
  (
    file: 'state_delta_basic',
    scenario: 'state',
    threadId: 't-state',
    resume: false,
    resumeValue: null,
  ),
  (
    file: 'tool_call_basic',
    scenario: 'tool',
    threadId: 't-tool',
    resume: false,
    resumeValue: null,
  ),
  (
    file: 'error_path',
    scenario: 'error',
    threadId: 't-error',
    resume: false,
    resumeValue: null,
  ),
  // The interrupt pair: `paused` checkpoints at `interrupt()`, then `resume`
  // re-enters the SAME thread with the human answer (SPIKE-LG-RESUME). A bare
  // string resume value matches the live contract (`CustomEvent.value` is `any`).
  (
    file: 'interrupt_paused',
    scenario: 'interrupt',
    threadId: 't-interrupt',
    resume: false,
    resumeValue: null,
  ),
  (
    file: 'interrupt_resume',
    scenario: 'interrupt',
    threadId: 't-interrupt',
    resume: true,
    resumeValue: 'approved-by-human',
  ),
];

Future<void> main(List<String> args) async {
  final backend = _option(args, '--backend');
  final story = backend == null ? null : _backends[backend];
  if (story == null) {
    stderr.writeln(
      backend == null
          ? 'capture_fixtures: missing --backend=<name>.'
          : 'capture_fixtures: unknown backend "$backend".',
    );
    stderr.writeln('Available backends: ${_backends.keys.join(', ')}');
    stderr.writeln(
      'Usage: dart run tool/capture_fixtures.dart --backend=<name> '
      '[--base-url=<url>] [--token=<token>]',
    );
    exit(2);
  }

  switch (backend) {
    case 'agno':
      await _captureAgno(
        baseUrl: _option(args, '--base-url') ?? 'http://localhost:8002',
        token: _option(args, '--token'),
      );
    case 'langgraph':
      await _captureLangGraph(
        baseUrl: _option(args, '--base-url') ?? 'http://localhost:8003',
        // `--token` keeps invocation parity with agno; the value maps to the
        // `x-api-key` header (langgraph's SPIKE-LG-AUTH convention, not Bearer).
        apiKey: _option(args, '--token') ?? _option(args, '--api-key'),
      );
    case 'dojo':
      await _captureDojo(
        baseUrl: _option(args, '--base-url') ?? 'http://localhost:8001',
        // dojo has no `/status`; the version is operator-supplied (RESOLVED #1).
        backendVersion: _option(args, '--backend-version'),
      );
    case 'copilotkit':
      await _captureCopilotkit(
        baseUrl:
            _option(args, '--base-url') ??
            'http://localhost:8005/api/copilotkit',
        agentName: _option(args, '--agent-name') ?? 'koel_scripted',
        backendVersion: _option(args, '--backend-version'),
      );
    default:
      // Unreachable: `backend` was validated against `_backends` above.
      throw StateError('unhandled backend "$backend" (story $story)');
  }
}

/// Captures `text_only_run` from a live agno deployment into
/// `packages/koel_test/lib/src/fixtures/agno/text_only_run.jsonl`.
Future<void> _captureAgno({required String baseUrl, String? token}) async {
  final base = Uri.parse(baseUrl);
  final client = HttpClient();
  // Set on any failure, then reported + `exit(1)` *after* the try/finally so the
  // `finally` actually runs — `dart:io exit()` terminates the VM without
  // unwinding, so closing the client inside a catch-then-exit would leak it.
  String? failure;
  try {
    final backendVersion = await _statusVersion(client, base);
    final payloads = _normalizeIds(
      await _postSseRun(
        client,
        _endpoint(base, 'agno-chat'),
        _textRunInput,
        // agno auth is `Authorization: Bearer …`, default-OFF (open deployment).
        token != null && token.trim().isNotEmpty
            ? {HttpHeaders.authorizationHeader: 'Bearer $token'}
            : const {},
        'POST /agno-chat',
      ),
      // agno's lone nondeterministic field is `messageId` (UUID4).
      const {'messageId': 'msg'},
    );
    final fixture = _renderFixture(
      adapter: 'koel_agno@$_koelAgnoVersion',
      backendVersion: backendVersion,
      threadId: _textRunInput['threadId'] as String,
      runId: _textRunInput['runId'] as String,
      payloads: payloads,
    );
    final out = File(
      'packages/koel_test/lib/src/fixtures/agno/text_only_run.jsonl',
    );
    await out.writeAsString(fixture);
    stdout.writeln(
      'captured ${payloads.length} events → ${out.path} ($backendVersion)',
    );
  } on SocketException catch (error) {
    failure =
        'cannot reach agno at $baseUrl — run `make up-agno` in '
        '../koel_backend first. ($error)';
  } on _CaptureFailure catch (e) {
    failure = e.message;
  } catch (error) {
    // Anything else — a non-object `/status` body, a scheme-less `--base-url`
    // (`Uri.parse` yields no host → `getUrl` throws), an unexpected SSE frame —
    // surfaces as an actionable line, never a raw stack trace.
    failure =
        'unexpected failure capturing from $baseUrl — check --base-url and '
        'that agno is healthy. ($error)';
  } finally {
    client.close(force: true);
  }
  if (failure != null) {
    stderr.writeln('capture_fixtures: $failure');
    exit(1);
  }
}

/// Captures every scenario the LangGraph backend natively emits (the six in
/// [_langGraphScenarios]) into `packages/koel_test/lib/src/fixtures/langgraph/`.
///
/// The interrupt pair is order-dependent and stateful: `interrupt_paused` writes
/// a `MemorySaver` checkpoint that `interrupt_resume` then consumes. Re-running
/// against a warm backend re-captures the four stateless scenarios byte-stably,
/// but the interrupt pair needs a fresh checkpoint (restart the container) — the
/// documented single-process `MemorySaver` constraint, not a koel bug.
Future<void> _captureLangGraph({
  required String baseUrl,
  String? apiKey,
}) async {
  final base = Uri.parse(baseUrl);
  final client = HttpClient();
  String? failure;
  try {
    final backendVersion = await _statusVersion(client, base);
    final endpoint = _endpoint(base, 'agent');
    // x-api-key (trimmed; SPIKE-LG-AUTH), default-OFF for an open deployment.
    final headers = apiKey != null && apiKey.trim().isNotEmpty
        ? {'x-api-key': apiKey.trim()}
        : const <String, String>{};
    var captured = 0;
    for (final scenario in _langGraphScenarios) {
      final payloads = _normalizeIds(
        await _postSseRun(
          client,
          endpoint,
          _langGraphInput(scenario),
          headers,
          'POST /agent (${scenario.scenario}${scenario.resume ? ' resume' : ''})',
        ),
        // The scripted graph fixes messageId/toolCallId; `runId` (UUID7 on
        // RUN_FINISHED) is the lone live variable. messageId/toolCallId stay in
        // the set for forward-safety against a non-scripted build.
        const {'messageId': 'msg', 'toolCallId': 'tool', 'runId': 'run'},
      );
      final out = File(
        'packages/koel_test/lib/src/fixtures/langgraph/${scenario.file}.jsonl',
      );
      await out.writeAsString(
        _renderFixture(
          adapter: 'koel_langgraph@$_koelLangGraphVersion',
          backendVersion: backendVersion,
          threadId: scenario.threadId,
          runId: 'r',
          payloads: payloads,
        ),
      );
      stdout.writeln(
        'captured ${payloads.length} events → ${out.path} '
        '(${scenario.scenario}${scenario.resume ? ' resume' : ''})',
      );
      captured++;
    }
    stdout.writeln('captured $captured langgraph fixtures ($backendVersion)');
  } on SocketException catch (error) {
    failure =
        'cannot reach langgraph at $baseUrl — run `make up-langgraph` in '
        '../koel_backend first. ($error)';
  } on _CaptureFailure catch (e) {
    failure = e.message;
  } catch (error) {
    failure =
        'unexpected failure capturing from $baseUrl — check --base-url and '
        'that langgraph is healthy. ($error)';
  } finally {
    client.close(force: true);
  }
  if (failure != null) {
    stderr.writeln('capture_fixtures: $failure');
    exit(1);
  }
}

/// The `RunAgentInput` body for a LangGraph [scenario]: the scripted graph reads
/// `state.scenario` to branch, and the resume half carries
/// `forwardedProps.command.resume` (SPIKE-LG-RESUME).
Map<String, dynamic> _langGraphInput(_LangGraphScenario scenario) =>
    <String, dynamic>{
      'threadId': scenario.threadId,
      'runId': 'r',
      'state': {'scenario': scenario.scenario},
      'messages': [
        {'id': 'm-1', 'role': 'user', 'content': 'hello'},
      ],
      'tools': <dynamic>[],
      'context': <dynamic>[],
      'forwardedProps': scenario.resume
          ? {
              'command': {'resume': scenario.resumeValue},
            }
          : <String, dynamic>{},
    };

/// One captured dojo scenario: the fixture [file] it lands in, the [route]
/// POSTed to, and the last-user-message [content] that selects the route's
/// branch (`/agentic_chat` keys text/tool/backend-tool off it; the other routes
/// ignore it and emit their scripted sequence).
typedef _DojoScenario = ({String file, String route, String content});

/// The twelve deterministic dojo routes captured (SPIKE-DOJO-COVERAGE) — the 7
/// upstream + 5 `handlers_ext/` gap-fill routes, EXCLUDING
/// `/predictive_state_updates` (RESOLVED #2 — its `random.choice(dog_names)`
/// content is nondeterministic beyond the documented id fields, so a golden
/// fixture would false-pass capture-twice-diff). Their union covers the non-chunk
/// AG-UI wire types except `CUSTOM`, which ONLY `/predictive_state_updates`
/// emits; `CUSTOM` is carried by the synthesized corpus + the langgraph capture,
/// so excluding the route loses no overall type (RESOLVED #2). The 3 `*_CHUNK`
/// variants the dojo never emits stay the synthesized corpus's job.
const List<_DojoScenario> _dojoScenarios = [
  (file: 'agentic_chat', route: 'agentic_chat', content: 'hello'),
  (file: 'agentic_chat_tool', route: 'agentic_chat', content: 'tool'),
  (
    file: 'backend_tool_rendering',
    route: 'backend_tool_rendering',
    content: 'hello',
  ),
  (file: 'human_in_the_loop', route: 'human_in_the_loop', content: 'hello'),
  (
    file: 'agentic_generative_ui',
    route: 'agentic_generative_ui',
    content: 'hello',
  ),
  (file: 'shared_state', route: 'shared_state', content: 'hello'),
  (
    file: 'tool_based_generative_ui',
    route: 'tool_based_generative_ui',
    content: 'hello',
  ),
  (file: 'reasoning', route: 'reasoning', content: 'hello'),
  (file: 'activity', route: 'activity', content: 'hello'),
  (file: 'tool_call_result', route: 'tool_call_result', content: 'hello'),
  (file: 'error', route: 'error', content: 'hello'),
  (file: 'cancellation', route: 'cancellation', content: 'hello'),
];

/// Captures every deterministic dojo route ([_dojoScenarios]) into
/// `packages/koel_test/lib/src/fixtures/dojo/`. Zero-dep `dart:io`/`dart:convert`
/// (an SSE `data:` frame already IS a canonical AG-UI event), exactly like the
/// agno/langgraph branches — NOT the copilotkit branch's koel_runtime path.
///
/// The dojo exposes no `/status`, so [backendVersion] is operator-supplied
/// (RESOLVED #1), defaulting to [_dojoDefaultVersion]. The backend is open by
/// design (NFR-2) → no auth header.
Future<void> _captureDojo({
  required String baseUrl,
  String? backendVersion,
}) async {
  final base = Uri.parse(baseUrl);
  final version = (backendVersion == null || backendVersion.trim().isEmpty)
      ? _dojoDefaultVersion
      : backendVersion.trim();
  final client = HttpClient();
  String? failure;
  try {
    var captured = 0;
    for (final scenario in _dojoScenarios) {
      final payloads = _normalizeUuids(
        await _postSseRun(
          client,
          _endpoint(base, scenario.route),
          _dojoInput(scenario.content),
          const {}, // dojo is open by design (no auth header)
          'POST /${scenario.route}',
        ),
      );
      final out = File(
        'packages/koel_test/lib/src/fixtures/dojo/${scenario.file}.jsonl',
      );
      await out.writeAsString(
        _renderFixture(
          adapter: 'koel_runtime@$_koelRuntimeVersion',
          backendVersion: 'dojo==$version',
          threadId: 't',
          runId: 'r',
          payloads: payloads,
        ),
      );
      stdout.writeln(
        'captured ${payloads.length} events → ${out.path} (${scenario.route})',
      );
      captured++;
    }
    stdout.writeln('captured $captured dojo fixtures (dojo==$version)');
  } on SocketException catch (error) {
    failure =
        'cannot reach dojo at $baseUrl — run `make up-dojo` in '
        '../koel_backend first. ($error)';
  } on _CaptureFailure catch (e) {
    failure = e.message;
  } catch (error) {
    failure =
        'unexpected failure capturing from $baseUrl — check --base-url and '
        'that dojo is healthy. ($error)';
  } finally {
    client.close(force: true);
  }
  if (failure != null) {
    stderr.writeln('capture_fixtures: $failure');
    exit(1);
  }
}

/// The `RunAgentInput` body for a dojo route: a minimal single-user-message run
/// whose [content] selects the `/agentic_chat` branch (ignored by the other
/// routes). camelCase wire shape, parsed by the dojo's `RunAgentInput`.
Map<String, dynamic> _dojoInput(String content) => <String, dynamic>{
  'threadId': 't',
  'runId': 'r',
  'state': <String, dynamic>{},
  'messages': [
    {'id': 'm-1', 'role': 'user', 'content': content},
  ],
  'tools': <dynamic>[],
  'context': <dynamic>[],
  'forwardedProps': <String, dynamic>{},
};

/// One captured copilotkit v2 scenario: the fixture [file] it lands in and the
/// last-user-message [content] the scripted v2 agent keys its scenario off
/// (`text`|`tool`|`state`|`error` — `copilotkit_v2/agent.mjs scenarioFor`).
typedef _CopilotkitScenario = ({String file, String content});

/// The four scenarios the CopilotKit **v2** backend natively emits over SSE
/// (`copilotkit_v2/agent.mjs`), each captured as its own `synthesized: false`
/// fixture. File names mirror langgraph's overlapping vocabulary. Unlike the
/// removed GraphQL set (3 scenarios, no `error` — the bridge swallowed
/// `RUN_ERROR`), v2 delivers `error_path` (a wire `RUN_ERROR`) and a
/// `state_delta_basic` carrying `STATE_SNAPSHOT` **+ `STATE_DELTA`** — the two
/// headline proofs that v2 is full-fidelity, not 7/28 (SCP-2026-06-05).
const List<_CopilotkitScenario> _copilotkitScenarios = [
  (file: 'text_only_run', content: 'text'),
  (file: 'tool_call_basic', content: 'tool'),
  (file: 'state_delta_basic', content: 'state'),
  (file: 'error_path', content: 'error'),
];

/// Captures every CopilotKit v2 scenario ([_copilotkitScenarios]) into
/// `packages/koel_test/lib/src/fixtures/copilotkit/` over **native SSE** — the
/// same zero-dep `dart:io` `_postSseRun` path agno/langgraph/dojo use, NOT the
/// removed GraphQL `koel_runtime`/`package:http` bridge.
///
/// v2 (≥1.52) is a transparent AG-UI passthrough: each `data:` frame already IS
/// a canonical AG-UI event (`SPIKE-CK-V2`), so the capture POSTs a complete
/// `RunAgentInput` to `{base}/agent/{agentName}/run` and writes the frames
/// verbatim. The scripted v2 agent fixes every message/tool id and reuses the
/// input's `threadId`/`runId`, so the wire is byte-deterministic with **no**
/// id normalization (unlike agno's UUID4 `messageId` or the dojo's minted ids).
///
/// [backendVersion] (operator `--backend-version`) wins when set; otherwise the
/// live `x-copilotkit-runtime-version` response header is read if the runtime
/// sends one; otherwise [_copilotkitDefaultVersion] (the pinned `1.59.4`).
Future<void> _captureCopilotkit({
  required String baseUrl,
  required String agentName,
  String? backendVersion,
}) async {
  // [baseUrl] already includes the runtime base path (default
  // `…/api/copilotkit`); the run route appends `agent/{agentName}/run`, the same
  // join `CopilotRuntimeAgent` POSTs to.
  final base = Uri.parse(baseUrl);
  final endpoint = base.replace(
    pathSegments: [
      ...base.pathSegments.where((s) => s.isNotEmpty),
      'agent',
      agentName,
      'run',
    ],
  );
  // Operator override wins; else the live header (set below); else the default.
  final operatorVersion = backendVersion?.trim();
  final hasOverride = operatorVersion != null && operatorVersion.isNotEmpty;
  var version = hasOverride ? operatorVersion : _copilotkitDefaultVersion;
  final client = HttpClient();
  String? failure;
  try {
    var captured = 0;
    for (final scenario in _copilotkitScenarios) {
      final payloads = await _postSseRun(
        client,
        endpoint,
        _copilotkitInput(scenario.content),
        const {}, // the v2 runtime is open by design (no auth header)
        'POST /agent/$agentName/run (${scenario.content})',
        onResponseHeaders: hasOverride
            ? null
            : (headers) {
                final live = headers.value('x-copilotkit-runtime-version');
                if (live != null && live.trim().isNotEmpty) {
                  version = live.trim();
                }
              },
      );
      final out = File(
        'packages/koel_test/lib/src/fixtures/copilotkit/${scenario.file}.jsonl',
      );
      await out.writeAsString(
        _renderFixture(
          adapter: 'koel_runtime@$_koelRuntimeVersion',
          backendVersion: 'copilotkit==$version',
          threadId: 't',
          runId: 'r',
          payloads: payloads,
        ),
      );
      stdout.writeln(
        'captured ${payloads.length} events → ${out.path} (${scenario.content})',
      );
      captured++;
    }
    stdout.writeln(
      'captured $captured copilotkit fixtures (copilotkit==$version)',
    );
  } on SocketException catch (error) {
    failure =
        'cannot reach copilotkit v2 at $baseUrl — run `make up-copilotkit-v2` '
        'in ../koel_backend first. ($error)';
  } on _CaptureFailure catch (e) {
    failure = e.message;
  } catch (error) {
    failure =
        'unexpected failure capturing from $baseUrl — check --base-url and '
        'that copilotkit_v2 is healthy. ($error)';
  } finally {
    client.close(force: true);
  }
  if (failure != null) {
    stderr.writeln('capture_fixtures: $failure');
    exit(1);
  }
}

/// The `RunAgentInput` body for a copilotkit v2 scenario: one user message whose
/// [content] (`text`|`tool`|`state`|`error`) the v2 agent's `scenarioFor` reads
/// to branch. The complete input (`tools`/`context`/`forwardedProps` all present)
/// is required — the runtime's `parseRunRequest` 500s on a partial body. The
/// fixed thread/run ids (`t`/`r`) are reused verbatim onto the wire's
/// `RUN_STARTED`/`RUN_FINISHED`, so they stay deterministic. camelCase wire shape.
Map<String, dynamic> _copilotkitInput(String content) => <String, dynamic>{
  'threadId': 't',
  'runId': 'r',
  'state': <String, dynamic>{},
  'messages': [
    {'id': 'm-1', 'role': 'user', 'content': content},
  ],
  'tools': <dynamic>[],
  'context': <dynamic>[],
  'forwardedProps': <String, dynamic>{},
};

/// Reads `GET <base>/status` for the backend version stamp (e.g. `agno==2.6.10`
/// or `langgraph==0.0.37`). The status route is always open (no auth) on every
/// Epic-5 backend, per each CONTRACT.md §6.5.
Future<String> _statusVersion(HttpClient client, Uri base) async {
  final request = await client.getUrl(_endpoint(base, 'status'));
  final response = await request.close();
  final body = await response.transform(utf8.decoder).join();
  if (response.statusCode != 200) {
    throw _CaptureFailure('GET /status returned HTTP ${response.statusCode}');
  }
  final json = jsonDecode(body) as Map<String, dynamic>;
  return '${json['framework'] ?? 'unknown'}==${json['version'] ?? 'unknown'}';
}

/// POSTs [body] as JSON to [endpoint] and parses the SSE response into the
/// ordered wire payloads (one per `data:` frame). [extraHeaders] carries the
/// per-backend auth header (agno's Bearer, langgraph's `x-api-key`) — empty for
/// an open deployment. [routeLabel] names the route in any failure message.
Future<List<Map<String, dynamic>>> _postSseRun(
  HttpClient client,
  Uri endpoint,
  Map<String, dynamic> body,
  Map<String, String> extraHeaders,
  String routeLabel, {
  void Function(HttpHeaders headers)? onResponseHeaders,
}) async {
  final request = await client.postUrl(endpoint);
  request.headers.contentType = ContentType.json;
  request.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');
  extraHeaders.forEach(request.headers.set);
  request.write(jsonEncode(body));
  final response = await request.close();
  // The copilotkit v2 lane reads `x-copilotkit-runtime-version` off the live
  // response to stamp `_session.backendVersion`; agno/langgraph/dojo pass null.
  onResponseHeaders?.call(response.headers);
  if (response.statusCode != 200) {
    final errorBody = await response.transform(utf8.decoder).join();
    throw _CaptureFailure(
      '$routeLabel returned HTTP ${response.statusCode} (expected 200): '
      '${errorBody.trim()}',
    );
  }

  final payloads = <Map<String, dynamic>>[];
  final lines = response
      .transform(utf8.decoder)
      .transform(const LineSplitter());
  await for (final line in lines) {
    if (!line.startsWith('data:')) continue;
    final json = line.substring('data:'.length).trim();
    if (json.isEmpty) continue;
    payloads.add(jsonDecode(json) as Map<String, dynamic>);
  }
  if (payloads.isEmpty) {
    throw _CaptureFailure(
      '$routeLabel streamed no SSE events — nothing to '
      'capture',
    );
  }
  return payloads;
}

/// Remaps each nondeterministic id field to a stable first-seen token so
/// re-capture is byte-identical. [fieldPrefixes] maps a top-level payload key to
/// its token prefix — e.g. `messageId` → `msg-0`, `msg-1`. Each field gets an
/// independent namespace; a value is rewritten only where the key is present and
/// holds a String. agno needs only `messageId`; langgraph adds `runId` and
/// `toolCallId` (see the file header).
List<Map<String, dynamic>> _normalizeIds(
  List<Map<String, dynamic>> payloads,
  Map<String, String> fieldPrefixes,
) {
  final remaps = {
    for (final field in fieldPrefixes.keys) field: <String, String>{},
  };
  String stable(String field, String original) {
    final remap = remaps[field]!;
    return remap.putIfAbsent(
      original,
      () => '${fieldPrefixes[field]}-${remap.length}',
    );
  }

  return [
    for (final payload in payloads)
      {
        for (final entry in payload.entries)
          entry.key:
              fieldPrefixes.containsKey(entry.key) && entry.value is String
              ? stable(entry.key, entry.value as String)
              : entry.value,
      },
  ];
}

/// Matches a v4-style UUID — the shape every dojo route mints for its
/// server-side ids (`messageId`, `toolCallId`, `runId`, and the nested
/// MESSAGES_SNAPSHOT `messages[].id`/`toolCalls[].id`).
final RegExp _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
  r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

/// Deep-normalizes every UUID-shaped string value in [payloads] to a stable
/// first-seen token (`id-0`, `id-1`, …) under ONE shared namespace, so a
/// cross-reference (a tool message's `toolCallId` reusing its `toolCalls[].id`)
/// maps to the same token and stays linked. Recurses through maps and lists;
/// non-UUID strings (the caller-fixed `t`/`r`, scripted literals like
/// `reason-1`) pass through untouched.
///
/// Unlike the top-level-key [_normalizeIds] (agno/langgraph, whose wire leaves
/// ids only at the payload root), the dojo's MESSAGES_SNAPSHOT nests minted ids
/// inside `messages[]`, so the dojo needs value-shaped normalization. After this
/// the only residual per-capture variance is the synthetic envelope timestamp
/// ([_renderFixture] stamps the real instant), which is informational —
/// `FixtureLoader` decodes the payload only — so the captured event payloads are
/// byte-identical across re-capture.
List<Map<String, dynamic>> _normalizeUuids(
  List<Map<String, dynamic>> payloads,
) {
  final remap = <String, String>{};
  String token(String uuid) =>
      remap.putIfAbsent(uuid, () => 'id-${remap.length}');

  Object? walk(Object? node) {
    if (node is String) {
      return _uuidPattern.hasMatch(node) ? token(node) : node;
    }
    if (node is Map) {
      return <String, dynamic>{
        for (final entry in node.entries)
          entry.key as String: walk(entry.value),
      };
    }
    if (node is List) return [for (final element in node) walk(element)];
    return node;
  }

  return [
    for (final payload in payloads) walk(payload)! as Map<String, dynamic>,
  ];
}

/// Renders the `_session` header + one `{type, timestamp, payload}` line per
/// event, matching the synthesized fixtures' envelope. Timestamps are synthetic
/// and monotonic (informational — `FixtureLoader` decodes the payload only);
/// `_session.captured` records the real capture instant.
String _renderFixture({
  required String adapter,
  required String backendVersion,
  required String threadId,
  required String runId,
  required List<Map<String, dynamic>> payloads,
}) {
  final captured = DateTime.now().toUtc();
  final buffer = StringBuffer()
    ..writeln(
      jsonEncode({
        '_session': {
          'koelVersion': _koelVersion,
          'adapter': adapter,
          'captured': captured.toIso8601String(),
          'threadId': threadId,
          'runId': runId,
          'synthesized': false,
          'backendVersion': backendVersion,
        },
      }),
    );
  for (var i = 0; i < payloads.length; i++) {
    buffer.writeln(
      jsonEncode({
        'type': payloads[i]['type'],
        'timestamp': captured
            .add(Duration(milliseconds: i + 1))
            .toIso8601String(),
        'payload': payloads[i],
      }),
    );
  }
  return buffer.toString();
}

/// Appends [segment] to [base]'s path, trailing-slash-safe — mirrors each
/// agent's endpoint derivation so the capture hits the same route koel POSTs to.
Uri _endpoint(Uri base, String segment) => base.replace(
  pathSegments: [...base.pathSegments.where((s) => s.isNotEmpty), segment],
);

/// Extracts `<name>=<value>` (or `<name> <value>`) from [args], or `null`.
String? _option(List<String> args, String name) {
  final prefix = '$name=';
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg.startsWith(prefix)) return arg.substring(prefix.length);
    if (arg == name && i + 1 < args.length) return args[i + 1];
  }
  return null;
}

/// A capture-time failure with an operator-facing [message] (unreachable backend
/// is handled separately via [SocketException]).
class _CaptureFailure implements Exception {
  _CaptureFailure(this.message);

  final String message;
}
