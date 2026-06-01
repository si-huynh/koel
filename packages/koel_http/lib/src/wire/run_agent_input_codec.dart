import 'dart:convert';

import 'package:koel_core/koel_core.dart';

/// Encodes a [RunAgentInput] into the AG-UI request body map — the wire codec
/// `koel_core` deliberately deferred to "the transport that posts this payload"
/// ([RunAgentInput] ships freezed-**without**-json on purpose).
///
/// Hand-written (not codegen): [Message] and [ToolDefinition] already carry
/// `json_serializable`-generated `toJson()`, so the seven AG-UI-normative body
/// fields are pure composition. The one bespoke field is [RunAgentInput.reasoningEcho]
/// (`Map<String, Uint8List>?`) — a **koel extension**, not one of the normative
/// fields — whose blobs are base64-encoded and whose key is **omitted entirely**
/// when null or empty (a backend that does not recognize it simply never sees it).
///
/// Keys are camelCase, matching the AG-UI wire shape verbatim:
/// `{threadId, runId, state, messages, tools, context, forwardedProps}`. There is
/// deliberately **no** decode (`fromJson`): the client only ever *posts* a
/// [RunAgentInput]; events come back through `SseParser`, never a decoded input.
Map<String, dynamic> encodeRunAgentInput(RunAgentInput input) {
  final json = <String, dynamic>{
    'threadId': input.threadId,
    'runId': input.runId,
    'state': input.state,
    'messages': [for (final message in input.messages) message.toJson()],
    'tools': [for (final tool in input.tools) tool.toJson()],
    'context': input.context,
    // koel-reserved transport keys (e.g. `AuthInterceptor.transportHeadersKey`,
    // carrying resolved auth headers) are stripped by `HttpAgent`'s transport
    // *before* this codec runs, so they never reach the wire. The codec itself
    // is auth-agnostic and special-cases none of them.
    'forwardedProps': input.forwardedProps,
  };

  // base64-encode the opaque reasoning blobs; omit the key when there is nothing
  // to echo so the normative body stays clean for backends that ignore it.
  final reasoningEcho = input.reasoningEcho;
  if (reasoningEcho != null && reasoningEcho.isNotEmpty) {
    json['reasoningEcho'] = <String, String>{
      for (final entry in reasoningEcho.entries)
        entry.key: base64Encode(entry.value),
    };
  }

  return json;
}
