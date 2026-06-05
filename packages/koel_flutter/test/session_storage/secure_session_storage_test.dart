import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
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

void main() {
  // `setMockInitialValues` registers an in-memory mock platform; a real
  // `FlutterSecureStorage()` then routes to it — deterministic, no platform
  // channel, no `flutter drive` (D8). The binding is required for that mock.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  SecureSessionStorage storage() => SecureSessionStorage();

  group('SecureSessionStorage — SessionStorage contract (AC2)', () {
    test('save then load returns a structurally equal state', () async {
      final s = ChatState(messages: [_user('hi')]);
      final store = storage();
      await store.save('t1', s);
      expect(await store.load('t1'), equals(s));
    });

    test(
      'multi-thread: three distinct threadIds each round-trip exactly',
      () async {
        final store = storage();
        final a = ChatState(messages: [_user('alpha')]);
        final b = ChatState(messages: [_user('bravo')]);
        final c = ChatState(messages: [_user('charlie')]);
        await store.save('a', a);
        await store.save('b', b);
        await store.save('c', c);
        expect(await store.load('a'), equals(a));
        expect(await store.load('b'), equals(b));
        expect(await store.load('c'), equals(c));
      },
    );

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

    test(
      'save then delete then load returns null (delete clears load)',
      () async {
        final store = storage();
        await store.save('t1', ChatState(messages: [_user('hi')]));
        await store.delete('t1');
        expect(await store.load('t1'), isNull);
      },
    );

    test('overwriting a thread leaves listThreads with no duplicate', () async {
      final store = storage();
      await store.save('t1', ChatState(messages: [_user('first')]));
      await store.save('t1', ChatState(messages: [_user('second')]));
      expect(await store.listThreads(), ['t1']);
    });
  });

  group('SecureSessionStorage — partial in-progress message (AC3)', () {
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

  group(
    'SecureSessionStorage — namespace isolation in a shared store (AC4)',
    () {
      test(
        'listThreads returns only koel threadIds (prefix stripped); a foreign '
        'key is excluded',
        () async {
          FlutterSecureStorage.setMockInitialValues({
            'app_auth_token': 'secret',
          });
          final store = storage();
          await store.save('t1', ChatState(messages: [_user('hi')]));

          expect((await store.listThreads()).toSet(), {'t1'});
        },
      );

      test('the on-disk key is namespaced under the reserved prefix (D3 wire '
          'layout)', () async {
        final store = storage();
        await store.save('t1', const ChatState());
        final all = await const FlutterSecureStorage().readAll();
        expect(all.keys, contains('koel_session.t1'));
      });

      test(
        'delete removes only the thread, leaving a foreign secret readable',
        () async {
          FlutterSecureStorage.setMockInitialValues({
            'app_auth_token': 'secret',
          });
          final store = storage();
          await store.save('t1', ChatState(messages: [_user('hi')]));

          await store.delete('t1');

          // Read the foreign key back through a raw store to prove koel touched
          // only its own prefixed key (never deleteAll).
          expect(await store.load('t1'), isNull);
          final foreign = await const FlutterSecureStorage().read(
            key: 'app_auth_token',
          );
          expect(foreign, 'secret');
        },
      );
    },
  );

  group('SecureSessionStorage — threadId boundaries (prefix injectivity)', () {
    test('an empty threadId round-trips and enumerates as itself', () async {
      final store = storage();
      final s = ChatState(messages: [_user('hi')]);
      await store.save('', s);
      expect(await store.load(''), equals(s));
      expect((await store.listThreads()).toSet(), {''});
    });

    test('a threadId that itself starts with the reserved prefix round-trips '
        'losslessly (strip is the exact inverse of the prefix concat)', () async {
      // The highest-value injectivity guard: `_key` is a positional concat and
      // `listThreads` strips a fixed-length prefix, so a nested-prefix id must
      // survive intact. A future rewrite to `split('.')` would break this.
      final store = storage();
      final nested = ChatState(messages: [_user('hi')]);
      await store.save('koel_session.x', nested);
      await store.save('y', ChatState(messages: [_user('other')]));
      expect(await store.load('koel_session.x'), equals(nested));
      expect((await store.listThreads()).toSet(), {'koel_session.x', 'y'});
    });
  });

  group('SecureSessionStorage — cross-adapter wire-compat (D1)', () {
    test('save emits the canonical jsonEncode(state.toJson()) wire string '
        '(loadable by any adapter on the same v1.0.0 codec)', () async {
      final store = storage();
      final s = ChatState(
        messages: [_user('hi')],
        pendingMessage: _assistant('half'),
        phase: RunPhase.running,
      );
      await store.save('t1', s);
      final raw = (await const FlutterSecureStorage()
          .readAll())['koel_session.t1'];
      expect(raw, jsonEncode(s.toJson()));
    });

    test('load decodes a value written in the canonical wire shape '
        '(a state another adapter persisted)', () async {
      final s = ChatState(
        messages: [_user('hi')],
        pendingMessage: _assistant('half'),
        phase: RunPhase.running,
      );
      // Seed the store exactly as a sibling adapter (e.g. HiveSessionStorage)
      // would: the prefixed key carrying `jsonEncode(state.toJson())`.
      FlutterSecureStorage.setMockInitialValues({
        'koel_session.t1': jsonEncode(s.toJson()),
      });
      expect(await storage().load('t1'), equals(s));
    });
  });
}
