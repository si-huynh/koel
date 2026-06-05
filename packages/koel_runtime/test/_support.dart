import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:http/http.dart';
import 'package:http/testing.dart';

// ─── SSE helpers (v2 native AG-UI) ───────────────────────────────────────────
// Copied from koel_agno/test/_support.dart — the v2 agent (`extends HttpAgent`)
// parses a `text/event-stream` response, so its tests replay SSE, not multipart.

/// Reads the raw wire `payload` of each event line in a bundled koel_test
/// fixture under [subdir] (skipping the `_session` header) — the bytes a real
/// backend endpoint emits. Resolved via `package:` URI so it reads from
/// koel_test's fixtures unchanged.
Future<List<Map<String, dynamic>>> fixturePayloads(
  String subdir,
  String name,
) async {
  final uri = Uri.parse('package:koel_test/src/fixtures/$subdir/$name.jsonl');
  final resolved = await Isolate.resolvePackageUri(uri);
  final lines = (await File.fromUri(
    resolved!,
  ).readAsLines()).where((line) => line.trim().isNotEmpty).toList();
  return [
    for (final line in lines.skip(1))
      (jsonDecode(line) as Map<String, dynamic>)['payload']
          as Map<String, dynamic>,
  ];
}

/// Frames wire payloads as a `text/event-stream` body (`data: <json>\n\n`).
String sseBody(List<Map<String, dynamic>> payloads) =>
    payloads.map((p) => 'data: ${jsonEncode(p)}\n\n').join();

/// A [MockClient] that replays [body] as a 200 `text/event-stream` response —
/// the transport seam a `CopilotRuntimeAgent`/`HttpAgent` parses, no live backend.
MockClient sseClient(String body) => MockClient(
  (_) async =>
      Response(body, 200, headers: const {'content-type': 'text/event-stream'}),
);
