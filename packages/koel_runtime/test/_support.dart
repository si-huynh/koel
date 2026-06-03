import 'dart:convert';

/// Test-local fixture support for `MultipartGraphQLStreamParser`.
///
/// These builders are the **independent oracle** for the forward parser: they
/// hand-author the CopilotKit `multipart/mixed` wire from the `SPIKE-CK-FRAMING`
/// raw capture, so the parser is tested against a fixture it did not produce.
/// (The production reverse path, `eventsToGraphQLParts`, is exercised separately
/// by the symmetry round-trip — code is never tested with itself.)
///
/// The AC2 fixture is **test-local** by design: `koel_test`'s captured
/// `copilotkit_runtime/` fixtures + invariant graduation are Story 5.9's job.

const _isoTs = '2026-06-02T00:00:00.000Z';

/// The document root every GraphQL Incremental Delivery `path` is anchored at.
List<dynamic> msgPath(int index) => [
  'generateCopilotResponse',
  'messages',
  index,
];

/// The initial seed part: an empty `messages[]` document, `hasNext:true`. Mirrors
/// the raw capture's part 1 (note `runId:null`).
Map<String, dynamic> initialPart({String threadId = 't-spike-1'}) => {
  'data': {
    'generateCopilotResponse': {
      'threadId': threadId,
      'runId': null,
      'extensions': null,
      'messages': <dynamic>[],
    },
  },
  'hasNext': true,
};

/// An `{incremental:[…], hasNext}` part carrying the ordered patch [entries].
Map<String, dynamic> incrementalPart(
  List<Map<String, dynamic>> entries, {
  bool hasNext = false,
}) => {'incremental': entries, 'hasNext': hasNext};

/// `@stream` append of a new `TextMessageOutput` at `messages[index]`.
Map<String, dynamic> textStart(
  int index,
  String id, {
  String role = 'assistant',
}) => {
  'items': [
    {
      '__typename': 'TextMessageOutput',
      'id': id,
      'createdAt': _isoTs,
      'role': role,
      'parentMessageId': null,
      'content': <dynamic>[],
    },
  ],
  'path': msgPath(index),
};

/// `@stream` append of one `content` delta to `messages[index]`.
Map<String, dynamic> contentDelta(int index, int slot, String delta) => {
  'items': [delta],
  'path': [...msgPath(index), 'content', slot],
};

/// `@stream` append of a new `ActionExecutionMessageOutput` at `messages[index]`.
Map<String, dynamic> actionStart(
  int index,
  String id,
  String name, {
  String? parentMessageId,
}) => {
  'items': [
    {
      '__typename': 'ActionExecutionMessageOutput',
      'id': id,
      'createdAt': _isoTs,
      'name': name,
      'parentMessageId': parentMessageId,
      'arguments': <dynamic>[],
    },
  ],
  'path': msgPath(index),
};

/// `@stream` append of one `arguments` delta to `messages[index]`.
Map<String, dynamic> argsDelta(int index, int slot, String delta) => {
  'items': [delta],
  'path': [...msgPath(index), 'arguments', slot],
};

/// `@stream` append of an `AgentStateMessageOutput` (`state` is a JSON string).
Map<String, dynamic> stateOutput(
  int index,
  String id,
  Map<String, dynamic> state,
) => {
  'items': [
    {
      '__typename': 'AgentStateMessageOutput',
      'id': id,
      'createdAt': _isoTs,
      'threadId': 't-spike-1',
      'state': jsonEncode(state),
      'running': true,
      'agentName': 'koel_scripted',
      'nodeName': '',
      'runId': 'run-$index',
      'active': false,
      'role': 'assistant',
    },
  ],
  'path': msgPath(index),
};

/// A terminal `@defer` `{status:{code:"Success"}}` at `messages[index]` — the
/// message-completion marker. Placed after a message's deltas (see the
/// conversion layer's reverse-path note).
Map<String, dynamic> messageSuccess(int index) => {
  'data': {
    'status': {'code': 'Success'},
  },
  'path': msgPath(index),
};

/// The response-level `@defer` `status` at the document root — envelope-only, it
/// maps to no AG-UI event.
Map<String, dynamic> responseSuccess() => {
  'data': {
    'status': {'code': 'Success'},
  },
  'path': ['generateCopilotResponse'],
};

/// Frames arbitrary part [bodies] into the `multipart/mixed; boundary="-"` wire:
/// leading `\r\n` preamble, each part a `Content-Type`/`Content-Length`/blank-
/// line header block + one body line, all CRLF, closed by the `-----` terminator.
/// `Content-Length` is computed faithfully though the parser ignores it.
String rawMultipart(List<String> bodies) {
  final buffer = StringBuffer('\r\n');
  for (final body in bodies) {
    buffer
      ..write('---\r\n')
      ..write('Content-Type: application/json; charset=utf-8\r\n')
      ..write('Content-Length: ${utf8.encode(body).length}\r\n')
      ..write('\r\n')
      ..write(body)
      ..write('\r\n');
  }
  return (buffer..write('-----\r\n')).toString();
}

/// JSON-encodes each GraphQL [parts] map into the multipart wire string.
String multipartString(List<Map<String, dynamic>> parts) =>
    rawMultipart([for (final part in parts) jsonEncode(part)]);

/// The multipart wire bytes for [parts].
List<int> multipartBytes(List<Map<String, dynamic>> parts) =>
    utf8.encode(multipartString(parts));

/// Streams [bytes] split into chunks at the sorted [cuts] offsets (empty = one
/// chunk), so a test can place the split exactly inside a delimiter or a
/// multi-byte UTF-8 sequence.
Stream<List<int>> streamBytes(List<int> bytes, {List<int> cuts = const []}) {
  final points = [0, ...cuts, bytes.length];
  return Stream.fromIterable([
    for (var k = 0; k < points.length - 1; k++)
      bytes.sublist(points[k], points[k + 1]),
  ]);
}
