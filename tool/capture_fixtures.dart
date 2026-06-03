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
// `<scenario>.jsonl` under koel_test. The remaining two backends are still
// scaffolded — wired in Story 5.9 (dojo + copilotkit). Invoke via
// `dart run tool/capture_fixtures.dart --backend=<name> [--base-url=…] [--token=…]`
// or `melos run capture-fixtures -- --backend=<name>`.
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
/// `agno` is live (Story 5.3), `langgraph` is live (Story 5.6); the rest stay
/// scaffolded until Story 5.9.
const Map<String, String> _backends = {
  'agno': '5.3',
  'langgraph': '5.6',
  // TODO(Epic 5): Story 5.9 — capture AG-UI Dojo real-run fixtures.
  'dojo': '5.9',
  // TODO(Epic 5): Story 5.9 — capture CopilotKit Next.js runtime fixtures.
  'copilotkit_runtime': '5.9',
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
    default:
      // The remaining backends are scaffolded; their capture lands in Story 5.9.
      stdout.writeln('wired in Epic 5 Story $story');
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
  String routeLabel,
) async {
  final request = await client.postUrl(endpoint);
  request.headers.contentType = ContentType.json;
  request.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');
  extraHeaders.forEach(request.headers.set);
  request.write(jsonEncode(body));
  final response = await request.close();
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
