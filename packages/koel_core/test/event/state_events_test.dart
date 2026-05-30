import 'package:koel_core/src/error/koel_error.dart';
import 'package:koel_core/src/error/koel_error_code.dart';
import 'package:koel_core/src/event/ag_ui_event.dart';
import 'package:koel_core/src/event/event_deserializer.dart';
import 'package:koel_core/src/json_patch/json_patch_op.dart';
import 'package:koel_core/src/message/message.dart';
import 'package:test/test.dart';

/// Matches a [ProtocolError] carrying `KoelErrorCode.protocolMalformed`.
final _malformed = throwsA(
  isA<ProtocolError>().having(
    (e) => e.code,
    'code',
    KoelErrorCode.protocolMalformed,
  ),
);

void main() {
  group('StateSnapshotEvent', () {
    test('const construction + type membership', () {
      const event = StateSnapshotEvent(state: {'count': 1});
      expect(event.state, {'count': 1});
      expect(event, isA<AgUiEvent>());
      expect(event, isA<StateSnapshotEvent>());
    });

    test('deep structural equality over nested state', () {
      final a = StateSnapshotEvent(
        state: {
          'user': {
            'name': 'ada',
            'roles': ['admin'],
          },
        },
      );
      final b = StateSnapshotEvent(
        state: {
          'user': {
            'name': 'ada',
            'roles': ['admin'],
          },
        },
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('copyWith replaces state', () {
      const event = StateSnapshotEvent(state: {'count': 1});
      expect(event.copyWith(state: {'count': 2}).state, {'count': 2});
    });

    test('fromJson reads wire key `snapshot`; toJson writes it back', () {
      final event = StateSnapshotEvent.fromJson({
        'type': 'STATE_SNAPSHOT',
        'snapshot': {'count': 1},
      });
      expect(event.state, {'count': 1});
      expect(event.toJson(), {
        'type': 'STATE_SNAPSHOT',
        'snapshot': {'count': 1},
      });
    });

    test('round-trips a nested-object snapshot', () {
      const event = StateSnapshotEvent(
        state: {
          'a': 1,
          'b': {
            'c': [1, 2, 3],
          },
        },
      );
      expect(StateSnapshotEvent.fromJson(event.toJson()), equals(event));
      expect(deserializeAgUiEvent(event.toJson()), equals(event));
    });

    test('missing snapshot throws ProtocolError(protocolMalformed)', () {
      expect(
        () => StateSnapshotEvent.fromJson({'type': 'STATE_SNAPSHOT'}),
        _malformed,
      );
    });

    test('non-object snapshot throws ProtocolError(protocolMalformed)', () {
      expect(
        () => StateSnapshotEvent.fromJson({
          'type': 'STATE_SNAPSHOT',
          'snapshot': 42,
        }),
        _malformed,
      );
    });
  });

  group('StateDeltaEvent', () {
    test('const construction + type membership', () {
      const event = StateDeltaEvent(patches: [AddOp(path: '/a', value: 1)]);
      expect(event.patches, hasLength(1));
      expect(event, isA<AgUiEvent>());
    });

    test('copyWith replaces patches', () {
      const event = StateDeltaEvent(patches: [AddOp(path: '/a', value: 1)]);
      final updated = event.copyWith(patches: [const RemoveOp(path: '/b')]);
      expect(updated.patches, [const RemoveOp(path: '/b')]);
    });

    test('decodes wire key `delta` into JsonPatchOp list', () {
      final event = StateDeltaEvent.fromJson({
        'type': 'STATE_DELTA',
        'delta': [
          {'op': 'add', 'path': '/a', 'value': 1},
          {'op': 'remove', 'path': '/b'},
        ],
      });
      expect(event.patches, [
        const AddOp(path: '/a', value: 1),
        const RemoveOp(path: '/b'),
      ]);
    });

    test('multi-op patch list round-trips through JsonPatchOp codec', () {
      const event = StateDeltaEvent(
        patches: [
          AddOp(path: '/a', value: 1),
          RemoveOp(path: '/b'),
          ReplaceOp(path: '/c', value: 'x'),
        ],
      );
      expect(StateDeltaEvent.fromJson(event.toJson()), equals(event));
      expect(deserializeAgUiEvent(event.toJson()), equals(event));
      expect(event.toJson(), {
        'type': 'STATE_DELTA',
        'delta': [
          {'op': 'add', 'path': '/a', 'value': 1},
          {'op': 'remove', 'path': '/b'},
          {'op': 'replace', 'path': '/c', 'value': 'x'},
        ],
      });
    });

    test('empty delta decodes to empty patches without throwing (decode is '
        'lenient; verify is Story 2.11)', () {
      final event = StateDeltaEvent.fromJson({
        'type': 'STATE_DELTA',
        'delta': <dynamic>[],
      });
      expect(event.patches, isEmpty);
      expect(deserializeAgUiEvent(event.toJson()), equals(event));
    });

    test('missing delta throws ProtocolError(protocolMalformed)', () {
      expect(
        () => StateDeltaEvent.fromJson({'type': 'STATE_DELTA'}),
        _malformed,
      );
    });

    test('non-array delta throws ProtocolError(protocolMalformed)', () {
      expect(
        () => StateDeltaEvent.fromJson({'type': 'STATE_DELTA', 'delta': 42}),
        _malformed,
      );
    });

    test(
      'non-object delta element throws ProtocolError(protocolMalformed)',
      () {
        expect(
          () => StateDeltaEvent.fromJson({
            'type': 'STATE_DELTA',
            'delta': ['not-an-object'],
          }),
          _malformed,
        );
      },
    );

    test('malformed op inside delta throws ProtocolError (delegated)', () {
      expect(
        () => StateDeltaEvent.fromJson({
          'type': 'STATE_DELTA',
          'delta': [
            {'op': 'frobnicate', 'path': '/a'},
          ],
        }),
        _malformed,
      );
    });
  });

  group('MessagesSnapshotEvent', () {
    final userMessage = Message(
      id: 'm1',
      role: MessageRole.user,
      content: 'hello',
      timestamp: DateTime.utc(2026, 5, 30, 12),
    );
    final toolMessage = Message(
      id: 'm2',
      role: MessageRole.tool,
      content: '{"result":42}',
      timestamp: DateTime.utc(2026, 5, 30, 12, 0, 1),
      toolCallId: 'tc1',
      name: 'search',
    );

    test('const-ish construction + type membership', () {
      final event = MessagesSnapshotEvent(messages: [userMessage]);
      expect(event.messages, hasLength(1));
      expect(event, isA<AgUiEvent>());
    });

    test('copyWith replaces messages', () {
      final event = MessagesSnapshotEvent(messages: [userMessage]);
      final updated = event.copyWith(messages: [userMessage, toolMessage]);
      expect(updated.messages, [userMessage, toolMessage]);
    });

    test('decodes wire `messages` array via Message.fromJson', () {
      final event = MessagesSnapshotEvent.fromJson({
        'type': 'MESSAGES_SNAPSHOT',
        'messages': [userMessage.toJson(), toolMessage.toJson()],
      });
      expect(event.messages, [userMessage, toolMessage]);
    });

    test('round-trips a mixed-field message list losslessly', () {
      final event = MessagesSnapshotEvent(messages: [userMessage, toolMessage]);
      expect(MessagesSnapshotEvent.fromJson(event.toJson()), equals(event));
      expect(deserializeAgUiEvent(event.toJson()), equals(event));
    });

    test('empty messages list round-trips', () {
      const event = MessagesSnapshotEvent(messages: []);
      expect(event.toJson(), {
        'type': 'MESSAGES_SNAPSHOT',
        'messages': <dynamic>[],
      });
      expect(deserializeAgUiEvent(event.toJson()), equals(event));
    });

    test('missing messages throws ProtocolError(protocolMalformed)', () {
      expect(
        () => MessagesSnapshotEvent.fromJson({'type': 'MESSAGES_SNAPSHOT'}),
        _malformed,
      );
    });

    test('non-array messages throws ProtocolError(protocolMalformed)', () {
      expect(
        () => MessagesSnapshotEvent.fromJson({
          'type': 'MESSAGES_SNAPSHOT',
          'messages': 'nope',
        }),
        _malformed,
      );
    });

    test('non-object messages element throws ProtocolError', () {
      expect(
        () => MessagesSnapshotEvent.fromJson({
          'type': 'MESSAGES_SNAPSHOT',
          'messages': ['not-an-object'],
        }),
        _malformed,
      );
    });

    test('message missing required id normalizes to ProtocolError (no raw '
        'TypeError leaks past _decodeObjectList)', () {
      expect(
        () => MessagesSnapshotEvent.fromJson({
          'type': 'MESSAGES_SNAPSHOT',
          'messages': [
            {
              'role': 'user',
              'content': 'hi',
              'timestamp': '2026-05-30T12:00:00Z',
            },
          ],
        }),
        _malformed,
      );
    });

    test('message with unparseable timestamp normalizes to ProtocolError (no '
        'raw FormatException leaks)', () {
      expect(
        () => MessagesSnapshotEvent.fromJson({
          'type': 'MESSAGES_SNAPSHOT',
          'messages': [
            {
              'id': 'm1',
              'role': 'user',
              'content': 'hi',
              'timestamp': 'notadate',
            },
          ],
        }),
        _malformed,
      );
    });

    test('message with unknown role normalizes to ProtocolError (no raw '
        'ArgumentError leaks)', () {
      expect(
        () => MessagesSnapshotEvent.fromJson({
          'type': 'MESSAGES_SNAPSHOT',
          'messages': [
            {
              'id': 'm1',
              'role': 'developer',
              'content': 'hi',
              'timestamp': '2026-05-30T12:00:00Z',
            },
          ],
        }),
        _malformed,
      );
    });
  });
}
