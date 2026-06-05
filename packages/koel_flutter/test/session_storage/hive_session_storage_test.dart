import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:koel_core/koel_core.dart';
import 'package:koel_flutter/koel_flutter.dart';

/// A committed user turn.
Message _user(String content) => Message(
  id: 'u1',
  role: MessageRole.user,
  content: content,
  timestamp: DateTime.utc(2026, 1, 2, 3, 4, 5),
);

/// An assistant turn (committed or pending depending on placement).
Message _assistant(String content) => Message(
  id: 'a1',
  role: MessageRole.assistant,
  content: content,
  timestamp: DateTime.utc(2026, 1, 2, 3, 4, 6),
);

/// The v1.0.0 persisted JSON shape — captured once from `jsonEncode(state
/// .toJson())` of the [_goldenState] below. This is the persistence wire
/// contract: a future field change that breaks `ChatState.fromJson` of this
/// string is a deliberate, reviewed schema decision, not an accident (AC6, D8).
const _goldenV1 =
    '{"messages":[{"id":"u1","role":"user","content":"What is the weather?",'
    '"timestamp":"2026-01-02T03:04:05.000Z","toolCallId":null,"name":null}],'
    '"pendingMessage":{"id":"a1","role":"assistant","content":"The weather is",'
    '"timestamp":"2026-01-02T03:04:06.000Z","toolCallId":null,"name":null},'
    '"pendingToolCalls":[{"id":"t1","name":"getWeather",'
    '"arguments":"{\\"city\\":\\"Ha","parentMessageId":null}],'
    '"state":{"counter":1},"reasoningEcho":{"e1":"AQID"},"phase":"running"}';

/// The [ChatState] [_goldenV1] must decode to.
ChatState _goldenState() => ChatState(
  messages: [
    Message(
      id: 'u1',
      role: MessageRole.user,
      content: 'What is the weather?',
      timestamp: DateTime.utc(2026, 1, 2, 3, 4, 5),
    ),
  ],
  pendingMessage: Message(
    id: 'a1',
    role: MessageRole.assistant,
    content: 'The weather is',
    timestamp: DateTime.utc(2026, 1, 2, 3, 4, 6),
  ),
  pendingToolCalls: const [
    ToolCall(id: 't1', name: 'getWeather', arguments: '{"city":"Ha'),
  ],
  state: const {'counter': 1},
  reasoningEcho: {
    'e1': Uint8List.fromList([1, 2, 3]),
  },
  phase: RunPhase.running,
);

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('koel_hive_test_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.deleteFromDisk(); // closes + deletes every open box
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  HiveSessionStorage storage() => HiveSessionStorage(boxName: 'sessions');

  group('HiveSessionStorage — SessionStorage contract (AC3, AC4)', () {
    test('save then load returns a structurally equal state', () async {
      final s = ChatState(messages: [_user('hi')]);
      final store = storage();
      await store.save('t1', s);
      expect(await store.load('t1'), equals(s));
    });

    test('save is last-write-wins per thread', () async {
      final store = storage();
      await store.save('t1', ChatState(messages: [_user('first')]));
      await store.save('t1', ChatState(messages: [_user('second')]));
      final loaded = await store.load('t1');
      expect(loaded!.messages.single.content, 'second');
    });

    test('load of an unknown thread returns null and never throws', () async {
      expect(await storage().load('absent'), isNull);
    });

    test(
      'delete of an absent thread completes normally (idempotent)',
      () async {
        await expectLater(storage().delete('absent'), completes);
      },
    );

    test('listThreads returns the remaining ids after saves + a delete '
        '(unordered)', () async {
      final store = storage();
      await store.save('a', const ChatState());
      await store.save('b', const ChatState());
      await store.save('c', const ChatState());
      await store.delete('b');
      expect((await store.listThreads()).toSet(), {'a', 'c'});
    });

    test('the returned listThreads snapshot is the caller\'s — mutating it '
        'does not affect the store', () async {
      final store = storage();
      await store.save('a', const ChatState());
      final snapshot = await store.listThreads();
      snapshot.add('mutated');
      expect((await store.listThreads()).toSet(), {'a'});
    });

    test('a second storage instance over the same box reuses the open box '
        '(cached/isBoxOpen path)', () async {
      final first = storage();
      await first.save('t1', ChatState(messages: [_user('shared')]));
      // first opened the box; second must reuse it via the isBoxOpen guard
      // rather than throwing on a re-open.
      final second = storage();
      final loaded = await second.load('t1');
      expect(loaded!.messages.single.content, 'shared');
    });
  });

  group('HiveSessionStorage — partial in-progress message (AC5)', () {
    test('a mid-stream state round-trips: pendingMessage, phase, and committed '
        'messages all survive', () async {
      final midStream = ChatState(
        messages: [_user('What is the weather?')],
        pendingMessage: _assistant('half-written'),
        pendingToolCalls: const [ToolCall(id: 't1', name: 'getWeather')],
        phase: RunPhase.running,
      );
      final store = storage();
      await store.save('t1', midStream);

      final reloaded = (await store.load('t1'))!;
      expect(reloaded.pendingMessage!.content, 'half-written');
      expect(reloaded.phase, RunPhase.running);
      expect(reloaded.messages, equals(midStream.messages));
      expect(reloaded, equals(midStream));
    });
  });

  group('HiveSessionStorage — v1.0.0 schema stability (AC6)', () {
    test('the checked-in golden JSON decodes without error and equals the '
        'expected state', () {
      final decoded = ChatState.fromJson(
        jsonDecode(_goldenV1) as Map<String, dynamic>,
      );
      expect(decoded, equals(_goldenState()));
    });

    test('the golden state re-encodes to the exact checked-in wire shape', () {
      // Encode-side pin (the inverse of the decode test above): `fromJson`
      // tolerates a missing key with a default, so a *newly added* field would
      // slip past the decode assertion. Asserting the encode is byte-identical
      // catches additive schema drift — this is the v1.0.0 wire contract (D8).
      expect(jsonEncode(_goldenState().toJson()), equals(_goldenV1));
    });
  });
}
