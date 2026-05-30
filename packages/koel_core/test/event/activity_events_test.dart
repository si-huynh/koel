import 'package:koel_core/src/error/koel_error.dart';
import 'package:koel_core/src/error/koel_error_code.dart';
import 'package:koel_core/src/event/ag_ui_event.dart';
import 'package:koel_core/src/event/event_deserializer.dart';
import 'package:koel_core/src/json_patch/json_patch_op.dart';
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
  group('ActivitySnapshotEvent', () {
    test('const construction + type membership', () {
      const event = ActivitySnapshotEvent(
        messageId: 'm1',
        activityType: 'checklist',
        content: {'items': 3},
      );
      expect(event.messageId, 'm1');
      expect(event.activityType, 'checklist');
      expect(event.content, {'items': 3});
      expect(event.replace, isNull);
      expect(event, isA<AgUiEvent>());
      expect(event, isA<ActivitySnapshotEvent>());
    });

    test('deep structural equality over nested content', () {
      final a = ActivitySnapshotEvent(
        messageId: 'm1',
        activityType: 'checklist',
        content: {
          'items': [
            {'label': 'a', 'done': true},
          ],
        },
      );
      final b = ActivitySnapshotEvent(
        messageId: 'm1',
        activityType: 'checklist',
        content: {
          'items': [
            {'label': 'a', 'done': true},
          ],
        },
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('differs on any field', () {
      const base = ActivitySnapshotEvent(
        messageId: 'm1',
        activityType: 'checklist',
        content: {'items': 3},
      );
      expect(base, isNot(equals(base.copyWith(messageId: 'm2'))));
      expect(base, isNot(equals(base.copyWith(activityType: 'progress'))));
      expect(base, isNot(equals(base.copyWith(content: {'items': 4}))));
      expect(base, isNot(equals(base.copyWith(replace: true))));
    });

    test('copyWith replaces fields', () {
      const event = ActivitySnapshotEvent(
        messageId: 'm1',
        activityType: 'checklist',
        content: {'items': 3},
      );
      expect(event.copyWith(replace: false).replace, isFalse);
    });

    test('fromJson reads required members + absent replace → null', () {
      final event = ActivitySnapshotEvent.fromJson({
        'type': 'ACTIVITY_SNAPSHOT',
        'messageId': 'm1',
        'activityType': 'checklist',
        'content': {'items': 3},
      });
      expect(event.messageId, 'm1');
      expect(event.activityType, 'checklist');
      expect(event.content, {'items': 3});
      expect(event.replace, isNull);
      expect(event.toJson(), {
        'type': 'ACTIVITY_SNAPSHOT',
        'messageId': 'm1',
        'activityType': 'checklist',
        'content': {'items': 3},
      });
    });

    test('replace present (true) round-trips', () {
      const event = ActivitySnapshotEvent(
        messageId: 'm1',
        activityType: 'checklist',
        content: {'items': 3},
        replace: true,
      );
      expect(event.toJson()['replace'], isTrue);
      expect(ActivitySnapshotEvent.fromJson(event.toJson()), equals(event));
      expect(deserializeAgUiEvent(event.toJson()), equals(event));
    });

    test('replace present (false) round-trips', () {
      const event = ActivitySnapshotEvent(
        messageId: 'm1',
        activityType: 'progress',
        content: {'pct': 50},
        replace: false,
      );
      expect(event.toJson()['replace'], isFalse);
      expect(ActivitySnapshotEvent.fromJson(event.toJson()), equals(event));
    });

    test('absent replace round-trips (omitted on toJson, decodes to null)', () {
      const event = ActivitySnapshotEvent(
        messageId: 'm1',
        activityType: 'checklist',
        content: {'items': 3},
      );
      expect(event.toJson().containsKey('replace'), isFalse);
      expect(deserializeAgUiEvent(event.toJson()), equals(event));
    });

    test('round-trips nested-object content via freezed deep equality', () {
      const event = ActivitySnapshotEvent(
        messageId: 'm1',
        activityType: 'checklist',
        content: {
          'a': 1,
          'b': {
            'c': [1, 2, 3],
          },
        },
      );
      expect(ActivitySnapshotEvent.fromJson(event.toJson()), equals(event));
      expect(deserializeAgUiEvent(event.toJson()), equals(event));
    });

    test('missing messageId throws ProtocolError(protocolMalformed)', () {
      expect(
        () => ActivitySnapshotEvent.fromJson({
          'type': 'ACTIVITY_SNAPSHOT',
          'activityType': 'checklist',
          'content': {'items': 3},
        }),
        _malformed,
      );
    });

    test('missing activityType throws ProtocolError(protocolMalformed)', () {
      expect(
        () => ActivitySnapshotEvent.fromJson({
          'type': 'ACTIVITY_SNAPSHOT',
          'messageId': 'm1',
          'content': {'items': 3},
        }),
        _malformed,
      );
    });

    test('non-String messageId throws ProtocolError(protocolMalformed)', () {
      expect(
        () => ActivitySnapshotEvent.fromJson({
          'type': 'ACTIVITY_SNAPSHOT',
          'messageId': 7,
          'activityType': 'checklist',
          'content': {'items': 3},
        }),
        _malformed,
      );
    });

    test('missing content throws ProtocolError(protocolMalformed)', () {
      expect(
        () => ActivitySnapshotEvent.fromJson({
          'type': 'ACTIVITY_SNAPSHOT',
          'messageId': 'm1',
          'activityType': 'checklist',
        }),
        _malformed,
      );
    });

    test('non-object content throws ProtocolError(protocolMalformed)', () {
      expect(
        () => ActivitySnapshotEvent.fromJson({
          'type': 'ACTIVITY_SNAPSHOT',
          'messageId': 'm1',
          'activityType': 'checklist',
          'content': 42,
        }),
        _malformed,
      );
    });

    test('non-bool replace throws ProtocolError(protocolMalformed)', () {
      expect(
        () => ActivitySnapshotEvent.fromJson({
          'type': 'ACTIVITY_SNAPSHOT',
          'messageId': 'm1',
          'activityType': 'checklist',
          'content': {'items': 3},
          'replace': 'yes',
        }),
        _malformed,
      );
    });
  });

  group('ActivityDeltaEvent', () {
    test('const construction + type membership', () {
      const event = ActivityDeltaEvent(
        messageId: 'm1',
        activityType: 'checklist',
        patches: [AddOp(path: '/items/0/done', value: true)],
      );
      expect(event.messageId, 'm1');
      expect(event.patches, hasLength(1));
      expect(event, isA<AgUiEvent>());
    });

    test('copyWith replaces patches', () {
      const event = ActivityDeltaEvent(
        messageId: 'm1',
        activityType: 'checklist',
        patches: [AddOp(path: '/a', value: 1)],
      );
      final updated = event.copyWith(patches: [const RemoveOp(path: '/b')]);
      expect(updated.patches, [const RemoveOp(path: '/b')]);
    });

    test('decodes wire key `patch` into JsonPatchOp list', () {
      final event = ActivityDeltaEvent.fromJson({
        'type': 'ACTIVITY_DELTA',
        'messageId': 'm1',
        'activityType': 'checklist',
        'patch': [
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
      const event = ActivityDeltaEvent(
        messageId: 'm1',
        activityType: 'checklist',
        patches: [
          AddOp(path: '/a', value: 1),
          RemoveOp(path: '/b'),
          ReplaceOp(path: '/c', value: 'x'),
        ],
      );
      expect(ActivityDeltaEvent.fromJson(event.toJson()), equals(event));
      expect(deserializeAgUiEvent(event.toJson()), equals(event));
      expect(event.toJson(), {
        'type': 'ACTIVITY_DELTA',
        'messageId': 'm1',
        'activityType': 'checklist',
        'patch': [
          {'op': 'add', 'path': '/a', 'value': 1},
          {'op': 'remove', 'path': '/b'},
          {'op': 'replace', 'path': '/c', 'value': 'x'},
        ],
      });
    });

    test('empty patch decodes to empty patches without throwing (decode is '
        'lenient; verify is Story 2.11)', () {
      final event = ActivityDeltaEvent.fromJson({
        'type': 'ACTIVITY_DELTA',
        'messageId': 'm1',
        'activityType': 'checklist',
        'patch': <dynamic>[],
      });
      expect(event.patches, isEmpty);
      expect(deserializeAgUiEvent(event.toJson()), equals(event));
    });

    test('missing messageId throws ProtocolError(protocolMalformed)', () {
      expect(
        () => ActivityDeltaEvent.fromJson({
          'type': 'ACTIVITY_DELTA',
          'activityType': 'checklist',
          'patch': <dynamic>[],
        }),
        _malformed,
      );
    });

    test('missing patch throws ProtocolError(protocolMalformed)', () {
      expect(
        () => ActivityDeltaEvent.fromJson({
          'type': 'ACTIVITY_DELTA',
          'messageId': 'm1',
          'activityType': 'checklist',
        }),
        _malformed,
      );
    });

    test('non-array patch throws ProtocolError(protocolMalformed)', () {
      expect(
        () => ActivityDeltaEvent.fromJson({
          'type': 'ACTIVITY_DELTA',
          'messageId': 'm1',
          'activityType': 'checklist',
          'patch': 42,
        }),
        _malformed,
      );
    });

    test(
      'non-object patch element throws ProtocolError(protocolMalformed)',
      () {
        expect(
          () => ActivityDeltaEvent.fromJson({
            'type': 'ACTIVITY_DELTA',
            'messageId': 'm1',
            'activityType': 'checklist',
            'patch': ['not-an-object'],
          }),
          _malformed,
        );
      },
    );

    test('malformed op inside patch throws ProtocolError (delegated)', () {
      expect(
        () => ActivityDeltaEvent.fromJson({
          'type': 'ACTIVITY_DELTA',
          'messageId': 'm1',
          'activityType': 'checklist',
          'patch': [
            {'op': 'frobnicate', 'path': '/a'},
          ],
        }),
        _malformed,
      );
    });
  });
}
