import 'dart:typed_data';

import 'package:koel_core/src/message/message.dart';
import 'package:koel_core/src/session/in_memory_session_storage.dart';
import 'package:koel_core/src/state/chat_state.dart';
import 'package:test/test.dart';

void main() {
  final ts = DateTime.utc(2026, 5, 30, 12);

  ChatState stateWith(String tag) => ChatState(
    messages: [
      Message(
        id: 'm-$tag',
        role: MessageRole.user,
        content: tag,
        timestamp: ts,
      ),
    ],
    state: {'k': tag},
    reasoningEcho: {
      'e-$tag': Uint8List.fromList([1, 2, 3]),
    },
    phase: RunPhase.running,
  );

  late InMemorySessionStorage storage;
  setUp(() => storage = InMemorySessionStorage());

  test('save then load round-trips a structurally-equal ChatState', () async {
    final saved = stateWith('a');
    await storage.save('t1', saved);
    expect(await storage.load('t1'), equals(saved));
  });

  test('load of an unknown threadId returns null (no throw)', () async {
    expect(await storage.load('missing'), isNull);
  });

  test('save overwrites the prior value for the same threadId', () async {
    await storage.save('t1', stateWith('first'));
    final second = stateWith('second');
    await storage.save('t1', second);
    expect(await storage.load('t1'), equals(second));
  });

  test('delete removes the thread; subsequent load is null', () async {
    await storage.save('t1', stateWith('a'));
    await storage.delete('t1');
    expect(await storage.load('t1'), isNull);
  });

  test('delete of an absent thread is a no-op (completes, no throw)', () async {
    await expectLater(storage.delete('missing'), completes);
  });

  test('listThreads returns all saved ids; empty when none', () async {
    expect(await storage.listThreads(), isEmpty);
    await storage.save('t1', stateWith('a'));
    await storage.save('t2', stateWith('b'));
    expect(await storage.listThreads(), unorderedEquals(['t1', 't2']));
  });

  test('listThreads returns a snapshot decoupled from the store', () async {
    await storage.save('t1', stateWith('a'));
    final threads = await storage.listThreads();
    threads.add('mutated'); // caller mutation must not touch the store
    await storage.save('t2', stateWith('b')); // later save must not touch it
    expect(await storage.listThreads(), unorderedEquals(['t1', 't2']));
    expect(threads, unorderedEquals(['t1', 'mutated']));
  });

  test(
    'no copy/serialization: load returns the identical saved instance',
    () async {
      final saved = stateWith('a');
      await storage.save('t1', saved);
      final a = await storage.load('t1');
      final b = await storage.load('t1');
      expect(identical(a, saved), isTrue);
      expect(identical(a, b), isTrue);
    },
  );

  test('same instance under two keys: deleting one leaves the other', () async {
    final shared = stateWith('shared');
    await storage.save('t1', shared);
    await storage.save('t2', shared);
    await storage.delete('t1');
    expect(await storage.load('t1'), isNull);
    expect(identical(await storage.load('t2'), shared), isTrue);
  });
}
