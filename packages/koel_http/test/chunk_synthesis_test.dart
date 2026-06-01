@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:koel_core/koel_core.dart';
import 'package:koel_http/koel_http.dart';
import 'package:test/test.dart';

/// A minimal run payload — these tests assert on synthesis, not body shape.
RunAgentInput _input() => const RunAgentInput(threadId: 't', runId: 'r');

/// Frames event wire payloads as a `text/event-stream` body (`data: <json>\n\n`)
/// — the bytes a real SSE endpoint would emit.
String _sseBody(List<Map<String, dynamic>> payloads) =>
    payloads.map((p) => 'data: ${jsonEncode(p)}\n\n').join();

/// Binds an ephemeral loopback `HttpServer` that replays [body] as an SSE
/// response, draining each request first. Registers its own teardown.
Future<HttpServer> _sseServer(String body) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  addTearDown(() => server.close(force: true));
  server.listen((request) async {
    await request.drain<void>();
    request.response.headers.contentType = ContentType('text', 'event-stream');
    request.response.write(body);
    await request.response.close();
  });
  return server;
}

Uri _serverUri(HttpServer server) =>
    Uri.parse('http://${server.address.host}:${server.port}');

/// Asserts every synthesized `*StartEvent` id has a matching trailing
/// `*EndEvent`, every `ARGS`/`CONTENT` falls inside an open envelope, and no
/// envelope is left open (AC3). This is the matched-pair invariant the
/// downstream `verifyStage` enforces — checked here directly so the transport
/// test never imports the internal stage.
void _expectWellFormedPairs(List<AgUiEvent> events) {
  final openTool = <String>[];
  final openText = <String>[];
  final openReasoning = <String>[];
  for (final event in events) {
    switch (event) {
      case ToolCallStartEvent(:final toolCallId):
        expect(
          openTool,
          isNot(contains(toolCallId)),
          reason: 'duplicate START for tool $toolCallId',
        );
        openTool.add(toolCallId);
      case ToolCallArgsEvent(:final toolCallId):
        expect(
          openTool,
          contains(toolCallId),
          reason: 'ARGS outside an open envelope for tool $toolCallId',
        );
      case ToolCallEndEvent(:final toolCallId):
        expect(
          openTool.remove(toolCallId),
          isTrue,
          reason: 'END without a matching START for tool $toolCallId',
        );
      case TextMessageStartEvent(:final messageId):
        expect(
          openText,
          isNot(contains(messageId)),
          reason: 'duplicate START for message $messageId',
        );
        openText.add(messageId);
      case TextMessageContentEvent(:final messageId):
        expect(
          openText,
          contains(messageId),
          reason: 'CONTENT outside an open envelope for message $messageId',
        );
      case TextMessageEndEvent(:final messageId):
        expect(
          openText.remove(messageId),
          isTrue,
          reason: 'END without a matching START for message $messageId',
        );
      case ReasoningMessageStartEvent(:final messageId):
        expect(
          openReasoning,
          isNot(contains(messageId)),
          reason: 'duplicate START for reasoning $messageId',
        );
        openReasoning.add(messageId);
      case ReasoningMessageContentEvent(:final messageId):
        expect(
          openReasoning,
          contains(messageId),
          reason: 'CONTENT outside an open envelope for reasoning $messageId',
        );
      case ReasoningMessageEndEvent(:final messageId):
        expect(
          openReasoning.remove(messageId),
          isTrue,
          reason: 'END without a matching START for reasoning $messageId',
        );
      default:
        break;
    }
  }
  expect(openTool, isEmpty, reason: 'unclosed tool-call envelope(s)');
  expect(openText, isEmpty, reason: 'unclosed text-message envelope(s)');
  expect(openReasoning, isEmpty, reason: 'unclosed reasoning envelope(s)');
}

void main() {
  group('HttpAgent chunk synthesis', () {
    test(
      'AC1 — TOOL_CALL_CHUNK runs synthesize START/ARGS/END (default on)',
      () async {
        // First chunk opens the envelope (name + parent, no delta → START only);
        // each later chunk carries one args delta; the non-chunk RUN_FINISHED
        // closes the envelope (synthesized END) then flows through.
        final body = _sseBody([
          const ToolCallChunkEvent(
            toolCallId: 'c',
            toolCallName: 'search',
            parentMessageId: 'p',
          ).toJson(),
          const ToolCallChunkEvent(toolCallId: 'c', delta: '{').toJson(),
          const ToolCallChunkEvent(toolCallId: 'c', delta: '}').toJson(),
          const RunFinishedEvent(threadId: 't', runId: 'r').toJson(),
        ]);
        final server = await _sseServer(body);
        // Default ctor → synthesizeChunks: true.
        final agent = HttpAgent(url: _serverUri(server));

        final events = await agent.run(_input()).toList();

        expect(events, const [
          ToolCallStartEvent(
            toolCallId: 'c',
            toolCallName: 'search',
            parentMessageId: 'p',
          ),
          ToolCallArgsEvent(toolCallId: 'c', delta: '{'),
          ToolCallArgsEvent(toolCallId: 'c', delta: '}'),
          ToolCallEndEvent(toolCallId: 'c'),
          RunFinishedEvent(threadId: 't', runId: 'r'),
        ]);
        // No raw chunk survives the transport.
        expect(events.whereType<ToolCallChunkEvent>(), isEmpty);
      },
    );

    test(
      'AC1 — TEXT_MESSAGE_CHUNK runs synthesize START/CONTENT/END (default on)',
      () async {
        // First chunk carries a delta → START then CONTENT (synthesis never
        // drops wire data); the trailing RUN_FINISHED closes the message.
        final body = _sseBody([
          const TextMessageChunkEvent(
            messageId: 'm',
            role: 'assistant',
            delta: 'Hel',
          ).toJson(),
          const TextMessageChunkEvent(messageId: 'm', delta: 'lo').toJson(),
          const RunFinishedEvent(threadId: 't', runId: 'r').toJson(),
        ]);
        final server = await _sseServer(body);
        final agent = HttpAgent(url: _serverUri(server));

        final events = await agent.run(_input()).toList();

        expect(events, const [
          TextMessageStartEvent(messageId: 'm', role: 'assistant'),
          TextMessageContentEvent(messageId: 'm', delta: 'Hel'),
          TextMessageContentEvent(messageId: 'm', delta: 'lo'),
          TextMessageEndEvent(messageId: 'm'),
          RunFinishedEvent(threadId: 't', runId: 'r'),
        ]);
        expect(events.whereType<TextMessageChunkEvent>(), isEmpty);
      },
    );

    test(
      'AC2 — synthesizeChunks: false passes raw chunk events through unchanged',
      () async {
        const raw = <AgUiEvent>[
          ToolCallChunkEvent(
            toolCallId: 'c',
            toolCallName: 'search',
            parentMessageId: 'p',
          ),
          ToolCallChunkEvent(toolCallId: 'c', delta: '{'),
          TextMessageChunkEvent(messageId: 'm', role: 'assistant', delta: 'Hi'),
          RunFinishedEvent(threadId: 't', runId: 'r'),
        ];
        final body = _sseBody([
          const ToolCallChunkEvent(
            toolCallId: 'c',
            toolCallName: 'search',
            parentMessageId: 'p',
          ).toJson(),
          const ToolCallChunkEvent(toolCallId: 'c', delta: '{').toJson(),
          const TextMessageChunkEvent(
            messageId: 'm',
            role: 'assistant',
            delta: 'Hi',
          ).toJson(),
          const RunFinishedEvent(threadId: 't', runId: 'r').toJson(),
        ]);
        final server = await _sseServer(body);
        // Subscribe the raw agent directly — AC2 governs the transport stream
        // only, never a pipeline (a KoelClient consumer is normalized regardless).
        final agent = HttpAgent(
          url: _serverUri(server),
          synthesizeChunks: false,
        );

        final events = await agent.run(_input()).toList();

        expect(events, raw);
      },
    );

    test('AC3 — synthesized transport output is well-formed START/END '
        'pairs', () async {
      // Two interleaved-by-id envelopes (a tool call and a message) plus the
      // free reasoning-chunk superset, all closed by stream completion (no
      // trailing non-chunk: the onDone flush must emit every END).
      final body = _sseBody([
        const ToolCallChunkEvent(toolCallId: 'c', toolCallName: 'fn').toJson(),
        const ToolCallChunkEvent(toolCallId: 'c', delta: 'a').toJson(),
        const TextMessageChunkEvent(messageId: 'm', delta: 'x').toJson(),
        const ReasoningMessageChunkEvent(messageId: 'r', delta: 'why').toJson(),
      ]);
      final server = await _sseServer(body);
      final agent = HttpAgent(url: _serverUri(server));

      final events = await agent.run(_input()).toList();

      _expectWellFormedPairs(events);
      // Reasoning chunks are normalized too (trap #9 superset) — prove it.
      expect(events.whereType<ReasoningMessageStartEvent>(), hasLength(1));
      expect(events.whereType<ReasoningMessageEndEvent>(), hasLength(1));
      expect(events.whereType<ReasoningMessageChunkEvent>(), isEmpty);
    });

    test('idempotency — re-feeding synthesized transport output through '
        "koel_core's chunksStage is identity (trap #2)", () async {
      final body = _sseBody([
        const ToolCallChunkEvent(
          toolCallId: 'c',
          toolCallName: 'search',
        ).toJson(),
        const ToolCallChunkEvent(toolCallId: 'c', delta: '{}').toJson(),
        const TextMessageChunkEvent(messageId: 'm', delta: 'hi').toJson(),
        const RunFinishedEvent(threadId: 't', runId: 'r').toJson(),
      ]);
      final server = await _sseServer(body);
      final agent = HttpAgent(url: _serverUri(server));

      final synthesized = await agent.run(_input()).toList();
      // The long-form output, fed through the pipeline's stage-1 synthesizer,
      // hits the `default:` pass-through for every event: no second synthesis,
      // no doubled END. This is the linchpin that lets transport synthesis and
      // the pipeline's unconditional chunksStage coexist.
      final reSynthesized = await Stream.fromIterable(
        synthesized,
      ).transform(chunksStage).toList();

      expect(reSynthesized, synthesized);
    });
  });
}
