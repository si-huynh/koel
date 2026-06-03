import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:http/http.dart';
import 'package:http/testing.dart';

/// Reads the raw wire `payload` of each event line in a bundled koel_test
/// fixture under [subdir] (skipping the `_session` header) — the bytes a real
/// backend endpoint emits. Resolved via `package:` URI so it reads from
/// koel_langgraph's test root unchanged.
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
/// the transport seam a `LangGraphAgent`/`HttpAgent` parses, with no live
/// backend (CI conformance is offline).
MockClient sseClient(String body) => MockClient(
  (_) async =>
      Response(body, 200, headers: const {'content-type': 'text/event-stream'}),
);
