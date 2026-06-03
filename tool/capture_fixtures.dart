// Fixture-capture pipeline (AR-14). Repo-level tool — NOT a package `lib/`
// file, so it carries no pubspec of its own and is outside every package's
// coverage scope. Zero-dependency `dart:io`/`dart:convert` (no `package:args`,
// no `package:http`): a repo tool resolves only against the workspace root.
//
// `--backend=agno` (Story 5.3) captures a real run from a live agno deployment
// (`make up-agno` in ../koel_backend) into a JSONL fixture under koel_test.
// The other three backends are still scaffolded — wired in their stories
// (langgraph 5.6, dojo + copilotkit 5.9). Invoke via
// `dart run tool/capture_fixtures.dart --backend=agno [--base-url=…] [--token=…]`
// or `melos run capture-fixtures -- --backend=agno`.
//
// Honest scope (Story 5.3, per ../koel_backend/backends/agno/CONTRACT.md): agno
// + the shared mock-LLM emits ONLY the text-run event chain (RUN_STARTED →
// TEXT_MESSAGE_* → RUN_FINISHED). Tool-call / state-delta / reasoning / native
// agent-error / cancellation are NOT natively emittable, so they are NOT
// captured here as `synthesized: false`; full AG-UI type conformance is proven
// instead by ConformanceRunner driving AgnoAgent over the all_event_types
// corpus (koel_agno/test/conformance_test.dart). The one nondeterministic field
// — `messageId` (UUID4, per CONTRACT SPIKE-MOCK) — is normalized to a stable
// token so the captured event lines are byte-stable golden artifacts.
import 'dart:convert';
import 'dart:io';

/// The four AG-UI backends Epic 5 captures, mapped to the story that wires each.
/// `agno` is live (Story 5.3); the rest stay scaffolded until their stories.
const Map<String, String> _backends = {
  'agno': '5.3',
  // TODO(Epic 5): Story 5.6 — capture langgraph real-run fixtures.
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

/// The canonical text-run `RunAgentInput` POSTed to capture `text_only_run`
/// (the exact shape from CONTRACT.md's probe — camelCase, parsed directly by
/// agno's `ag_ui.core.types.RunAgentInput`).
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

  if (backend == 'agno') {
    await _captureAgno(
      baseUrl: _option(args, '--base-url') ?? 'http://localhost:8002',
      token: _option(args, '--token'),
    );
    return;
  }

  // The remaining backends are scaffolded; their capture lands in their story.
  stdout.writeln('wired in Epic 5 Story $story');
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
    final backendVersion = await _agnoVersion(client, base);
    final payloads = _normalizeMessageIds(
      await _captureTextRun(client, base, token),
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

/// Reads `GET <base>/status` for the backend version stamp (e.g. `agno==2.6.10`).
/// The status route is always open (no auth), per CONTRACT.md §6.5.
Future<String> _agnoVersion(HttpClient client, Uri base) async {
  final request = await client.getUrl(_endpoint(base, 'status'));
  final response = await request.close();
  final body = await response.transform(utf8.decoder).join();
  if (response.statusCode != 200) {
    throw _CaptureFailure('GET /status returned HTTP ${response.statusCode}');
  }
  final json = jsonDecode(body) as Map<String, dynamic>;
  return '${json['framework'] ?? 'agno'}==${json['version'] ?? 'unknown'}';
}

/// POSTs the text-run input to `<base>/agno-chat` and parses the SSE response
/// into the ordered wire payloads (one per `data:` frame).
Future<List<Map<String, dynamic>>> _captureTextRun(
  HttpClient client,
  Uri base,
  String? token,
) async {
  final request = await client.postUrl(_endpoint(base, 'agno-chat'));
  request.headers.contentType = ContentType.json;
  request.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');
  if (token != null && token.trim().isNotEmpty) {
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
  }
  request.write(jsonEncode(_textRunInput));
  final response = await request.close();
  if (response.statusCode != 200) {
    final body = await response.transform(utf8.decoder).join();
    throw _CaptureFailure(
      'POST /agno-chat returned HTTP ${response.statusCode} (expected 200): '
      '${body.trim()}',
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
    throw _CaptureFailure('agno streamed no SSE events — nothing to capture');
  }
  return payloads;
}

/// Remaps every `messageId` (the sole nondeterministic field) to a stable
/// first-seen token (`msg-0`, `msg-1`, …) so re-capture is byte-identical.
List<Map<String, dynamic>> _normalizeMessageIds(
  List<Map<String, dynamic>> payloads,
) {
  final remap = <String, String>{};
  String stable(String original) =>
      remap.putIfAbsent(original, () => 'msg-${remap.length}');
  return [
    for (final payload in payloads)
      if (payload['messageId'] is String)
        {...payload, 'messageId': stable(payload['messageId'] as String)}
      else
        payload,
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

/// Appends [segment] to [base]'s path, trailing-slash-safe — mirrors
/// `AgnoAgent`'s endpoint derivation so the capture hits the same route koel
/// POSTs to.
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
