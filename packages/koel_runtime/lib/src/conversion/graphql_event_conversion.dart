/// The GraphQL Incremental-Delivery ↔ AG-UI conversion layer for the CopilotKit
/// runtime bridge — the wire-meaning half of `MultipartGraphQLStreamParser`
/// (the framing half is the parser; this is what each framed part *means*).
///
/// **Why this is stateful, unlike `koel_http`'s SSE path.** An SSE `data:`
/// payload already *is* a canonical AG-UI event, so framing → `jsonDecode` →
/// `AgUiEvent.fromWire` is the whole job. CopilotKit is not: every multipart
/// part is a GraphQL Incremental Delivery patch (`{incremental:[{items|data,
/// path}], hasNext}`) against one evolving `generateCopilotResponse` document.
/// A patch like `{"items":["Hello"],"path":[…,"messages",0,"content",0]}` only
/// *means* `TEXT_MESSAGE_CONTENT(messageId:"msg-text-1", delta:"Hello")` because
/// an earlier part established that `messages[0]` is a `TextMessageOutput` with
/// `id:"msg-text-1"`. So the forward converter tracks per-`messages[i]` identity
/// as parts arrive — see [GraphQLIncrementalConverter].
///
/// Mapping follows the CopilotKit wire contract `## Event-type coverage` table
/// (spike `SPIKE-CK-FRAMING`, pinned `@copilotkit/runtime@1.8.14`) verbatim. Only
/// the four GraphQL message-output shapes the runtime emits are representable:
/// `TextMessageOutput`, `ActionExecutionMessageOutput`, `ResultMessageOutput`,
/// `AgentStateMessageOutput`. Run-lifecycle, step, reasoning, activity, raw, and
/// custom events have no GraphQL representation and are out of scope here (the
/// runtime even swallows `RUN_ERROR`); the agent (Story 5.8) owns the
/// `RUN_STARTED`/`RUN_FINISHED` envelope, not this layer.
library;

import 'dart:convert';

import 'package:koel_core/koel_core.dart';

// --- The four `__typename`s the runtime frames AG-UI messages into. ---------
const _kText = 'TextMessageOutput';
const _kAction = 'ActionExecutionMessageOutput';
const _kResult = 'ResultMessageOutput';
const _kState = 'AgentStateMessageOutput';

/// The document root every `path` is anchored at.
const _root = 'generateCopilotResponse';

/// What a recorded `messages[i]` element is, so a later `content`/`arguments`
/// `@stream` patch (or terminal `@defer` status) maps to the right event.
enum _Kind { text, tool, state, result, unknown }

/// The identity of one `messages[i]` element, established when it is first
/// appended and consulted by every subsequent patch addressed at that index.
class _Message {
  _Message(this.kind, this.id);

  final _Kind kind;

  /// `messageId` for text, `toolCallId` for a tool call — the id every delta and
  /// the terminal status reuse. Empty for state/result/unknown (no streamed id
  /// follows, so no id is reused).
  final String id;
}

/// Where in the document a patch is addressed: the `messages[index]` element and
/// the optional sub-field (`content` / `arguments`) being streamed into.
typedef _Loc = ({int index, String? field});

/// Forward path: a **stateful** reconstruction of AG-UI events from the ordered
/// GraphQL Incremental Delivery parts of one response stream.
///
/// One instance per `parse` stream — its [_messages] map is the per-stream
/// reconstruction state. [ingest] takes one decoded part (the initial seed or an
/// `incremental` batch) and returns the AG-UI events that part produces, in wire
/// order; a single part can yield zero, one, or many events.
final class GraphQLIncrementalConverter {
  final Map<int, _Message> _messages = {};

  /// Interprets one decoded multipart part. The initial part
  /// (`{data:{generateCopilotResponse:{…,messages:[]}}, hasNext:true}`) carries
  /// no `incremental` array and yields nothing — it only opens the document.
  List<AgUiEvent> ingest(Map<String, dynamic> part) {
    final incremental = part['incremental'];
    if (incremental is! List) return const [];
    final events = <AgUiEvent>[];
    for (final entry in incremental) {
      if (entry is Map<String, dynamic>) _entry(entry, events);
    }
    return events;
  }

  void _entry(Map<String, dynamic> entry, List<AgUiEvent> out) {
    final path = entry['path'];
    if (path is! List) return;
    final loc = _locate(path);
    // A top-level path (e.g. the response-level `status`) has no `messages`
    // segment and maps to no event — it's envelope-only.
    if (loc == null) return;
    if (entry.containsKey('items')) {
      final items = entry['items'];
      if (items is! List) return;
      if (loc.field == null) {
        // `@stream` append of new `messages[]` elements (message-output objects).
        for (final item in items) {
          if (item is Map<String, dynamic>) _open(loc.index, item, out);
        }
      } else {
        // `@stream` append of `content`/`arguments` deltas (JSON strings).
        for (final item in items) {
          if (item is String) _delta(loc.index, loc.field!, item, out);
        }
      }
    } else if (entry.containsKey('data')) {
      // `@defer` object-merge — the terminal `status` marks message completion.
      _defer(loc, entry['data'], out);
    }
  }

  /// Records `messages[index]`'s identity from its `__typename` and emits the
  /// opening event for the recognized shapes.
  void _open(int index, Map<String, dynamic> item, List<AgUiEvent> out) {
    switch (item['__typename']) {
      case _kText:
        final id = _str(item, 'id');
        if (id == null) {
          _messages[index] = _Message(_Kind.unknown, '');
          return;
        }
        _messages[index] = _Message(_Kind.text, id);
        out.add(
          TextMessageStartEvent(
            messageId: id,
            role: _str(item, 'role') ?? 'assistant',
          ),
        );
      case _kAction:
        final id = _str(item, 'id');
        final name = _str(item, 'name');
        if (id == null || name == null) {
          _messages[index] = _Message(_Kind.unknown, '');
          return;
        }
        _messages[index] = _Message(_Kind.tool, id);
        out.add(
          ToolCallStartEvent(
            toolCallId: id,
            toolCallName: name,
            parentMessageId: _str(item, 'parentMessageId'),
          ),
        );
      case _kResult:
        // No streamed deltas follow a result; emit it whole. `actionExecutionId`
        // links it back to the originating call (`__typename`-faithful mapping).
        // Skip-to-`unknown` when a required field is absent — consistent with the
        // text/action arms and with `ToolCallResultEvent`'s required fields — so a
        // malformed result is dropped, never emitted as a structurally-invalid
        // event with an empty `toolCallId` that links to no call.
        final messageId = _str(item, 'id');
        final toolCallId = _str(item, 'actionExecutionId');
        final content = _str(item, 'result');
        if (messageId == null || toolCallId == null || content == null) {
          _messages[index] = _Message(_Kind.unknown, '');
          return;
        }
        _messages[index] = _Message(_Kind.result, '');
        out.add(
          ToolCallResultEvent(
            messageId: messageId,
            toolCallId: toolCallId,
            content: content,
          ),
        );
      case _kState:
        _messages[index] = _Message(_Kind.state, '');
        out.add(StateSnapshotEvent(state: _decodeState(item['state'])));
      default:
        // Forward-compatible: an unmodelled message output is skipped rather
        // than throwing, mirroring how `AgUiEvent.fromWire` tolerates an
        // unknown `type` (→ `UnknownAgUiEvent`). Recorded so its deltas skip too.
        _messages[index] = _Message(_Kind.unknown, '');
    }
  }

  /// One `content`/`arguments` `@stream` delta against an already-opened message.
  void _delta(int index, String field, String delta, List<AgUiEvent> out) {
    final message = _messages[index];
    if (message == null) return; // delta to an element we never opened — skip
    switch (message.kind) {
      case _Kind.text:
        if (field == 'content') {
          out.add(TextMessageContentEvent(messageId: message.id, delta: delta));
        }
      case _Kind.tool:
        if (field == 'arguments') {
          out.add(ToolCallArgsEvent(toolCallId: message.id, delta: delta));
        }
      default:
        break; // state/result/unknown carry no streamed deltas
    }
  }

  /// A terminal `@defer` `{status:{code:"Success"}}` at a message path closes
  /// that message. Non-`Success` codes (`Pending`/`Failed`) are not a clean
  /// close and emit nothing (the runtime swallows error completions anyway).
  void _defer(_Loc loc, Object? data, List<AgUiEvent> out) {
    if (loc.field != null || !_isSuccess(data)) return;
    final message = _messages[loc.index];
    if (message == null) return;
    switch (message.kind) {
      case _Kind.text:
        out.add(TextMessageEndEvent(messageId: message.id));
      case _Kind.tool:
        out.add(ToolCallEndEvent(toolCallId: message.id));
      default:
        break; // a state snapshot has no end; unknown/result close nothing
    }
  }
}

/// Resolves a patch `path` to the `messages[index]` element and optional
/// streamed sub-field it addresses. Returns `null` for a top-level path (no
/// `"messages"` segment — e.g. the response-level `status` `@defer`).
_Loc? _locate(List<dynamic> path) {
  final m = path.indexOf('messages');
  if (m == -1 || m + 1 >= path.length) return null;
  final index = path[m + 1];
  if (index is! int) return null;
  final field = (m + 2 < path.length && path[m + 2] is String)
      ? path[m + 2] as String
      : null;
  return (index: index, field: field);
}

bool _isSuccess(Object? data) =>
    data is Map &&
    data['status'] is Map &&
    (data['status'] as Map)['code'] == 'Success';

String? _str(Map<String, dynamic> map, String key) =>
    map[key] is String ? map[key] as String : null;

/// `AgentStateMessageOutput.state` is itself a JSON string. A malformed inner
/// payload is the same wire-sanity boundary `jsonDecode` crosses elsewhere, so
/// it surfaces as `ProtocolError(protocolMalformed)`; a non-object decodes to an
/// empty state.
Map<String, dynamic> _decodeState(Object? state) {
  if (state is! String) return const {};
  final Object? decoded;
  try {
    decoded = jsonDecode(state);
  } on FormatException catch (e) {
    throw ProtocolError(
      message: 'Malformed AgentStateMessageOutput.state JSON',
      code: KoelErrorCode.protocolMalformed,
      cause: e,
    );
  }
  return decoded is Map<String, dynamic> ? decoded : const {};
}

// --- Reverse path -----------------------------------------------------------

const _ts = '2026-06-02T00:00:00.000Z';
const _success = {
  'status': {'code': 'Success'},
};

List<dynamic> _msgPath(int index) => [_root, 'messages', index];

/// Reverse path: the representable AG-UI event subset → the GraphQL Incremental
/// Delivery part sequence the runtime would emit (initial seed part +
/// one `{incremental:[…], hasNext:false}` part). Used to author the test-local
/// multipart fixture and to prove `reverse → bytes → parse` round-trip symmetry.
///
/// Faithful to the raw-capture shape: terminal `@defer` `status:Success` patches
/// are placed **after** a message's `content`/`arguments` deltas so the forward
/// path reconstructs the canonical `START → …deltas → END` order. (The live wire
/// resolves `@defer` `status` mid-`@stream`; reordering that capture artefact is
/// Story 5.9's job — recorded in `deferred-work.md`.)
///
/// Throws [ArgumentError] on any event outside the representable subset
/// (`TEXT_MESSAGE_*`, `TOOL_CALL_START/ARGS/END`, `STATE_SNAPSHOT`) — a fixture
/// author's mistake, surfaced fail-fast rather than silently dropped.
List<Map<String, dynamic>> eventsToGraphQLParts(
  List<AgUiEvent> events, {
  String threadId = 't-spike-1',
}) {
  final entries = <Map<String, dynamic>>[];
  final indexOf = <String, int>{}; // messageId/toolCallId → messages[] index
  final deltaCount = <int, int>{}; // index → next content/arguments slot j
  var next = 0;

  for (final event in events) {
    switch (event) {
      case TextMessageStartEvent(:final messageId, :final role):
        final i = next++;
        indexOf[messageId] = i;
        deltaCount[i] = 0;
        entries.add({
          'items': [
            {
              '__typename': _kText,
              'id': messageId,
              'createdAt': _ts,
              'role': role,
              'parentMessageId': null,
              'content': <dynamic>[],
            },
          ],
          'path': _msgPath(i),
        });
      case TextMessageContentEvent(:final messageId, :final delta):
        final i = indexOf[messageId]!;
        entries.add({
          'items': [delta],
          'path': [..._msgPath(i), 'content', deltaCount[i]!],
        });
        deltaCount[i] = deltaCount[i]! + 1;
      case TextMessageEndEvent(:final messageId):
        entries.add({'data': _success, 'path': _msgPath(indexOf[messageId]!)});
      case ToolCallStartEvent(
        :final toolCallId,
        :final toolCallName,
        :final parentMessageId,
      ):
        final i = next++;
        indexOf[toolCallId] = i;
        deltaCount[i] = 0;
        entries.add({
          'items': [
            {
              '__typename': _kAction,
              'id': toolCallId,
              'createdAt': _ts,
              'name': toolCallName,
              'parentMessageId': parentMessageId,
              'arguments': <dynamic>[],
            },
          ],
          'path': _msgPath(i),
        });
      case ToolCallArgsEvent(:final toolCallId, :final delta):
        final i = indexOf[toolCallId]!;
        entries.add({
          'items': [delta],
          'path': [..._msgPath(i), 'arguments', deltaCount[i]!],
        });
        deltaCount[i] = deltaCount[i]! + 1;
      case ToolCallEndEvent(:final toolCallId):
        entries.add({'data': _success, 'path': _msgPath(indexOf[toolCallId]!)});
      case StateSnapshotEvent(:final state):
        final i = next++;
        entries.add({
          'items': [
            {
              '__typename': _kState,
              'id': 'ck-state-$i',
              'createdAt': _ts,
              'threadId': threadId,
              'state': jsonEncode(state),
              'running': true,
              'agentName': 'koel_scripted',
              'nodeName': '',
              'runId': 'run-$i',
              'active': false,
              'role': 'assistant',
            },
          ],
          'path': _msgPath(i),
        });
      default:
        throw ArgumentError.value(
          event,
          'event',
          'has no CopilotKit GraphQL representation; the reverse path covers only '
              'TEXT_MESSAGE_*, TOOL_CALL_START/ARGS/END, STATE_SNAPSHOT',
        );
    }
  }

  return [
    {
      'data': {
        'generateCopilotResponse': {
          'threadId': threadId,
          'runId': null,
          'extensions': null,
          'messages': <dynamic>[],
        },
      },
      'hasNext': true,
    },
    {'incremental': entries, 'hasNext': false},
  ];
}
