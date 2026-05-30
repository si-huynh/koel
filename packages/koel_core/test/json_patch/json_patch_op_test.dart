import 'package:koel_core/src/error/koel_error.dart';
import 'package:koel_core/src/error/koel_error_code.dart';
import 'package:koel_core/src/json_patch/json_patch_op.dart';
import 'package:test/test.dart';

void main() {
  group('construction + type membership', () {
    test('AddOp carries path + value and is a JsonPatchOp', () {
      const op = AddOp(path: '/a', value: 1);
      expect(op.path, '/a');
      expect(op.value, 1);
      expect(op, isA<JsonPatchOp>());
    });

    test('RemoveOp carries path only', () {
      const op = RemoveOp(path: '/a');
      expect(op.path, '/a');
      expect(op, isA<JsonPatchOp>());
    });

    test('ReplaceOp carries path + value', () {
      const op = ReplaceOp(path: '/a', value: 'x');
      expect(op.path, '/a');
      expect(op.value, 'x');
      expect(op, isA<JsonPatchOp>());
    });

    test('MoveOp carries from + path', () {
      const op = MoveOp(from: '/a', path: '/b');
      expect(op.from, '/a');
      expect(op.path, '/b');
      expect(op, isA<JsonPatchOp>());
    });

    test('CopyOp carries from + path', () {
      const op = CopyOp(from: '/a', path: '/b');
      expect(op.from, '/a');
      expect(op.path, '/b');
      expect(op, isA<JsonPatchOp>());
    });

    test('TestOp carries path + value', () {
      const op = TestOp(path: '/a', value: true);
      expect(op.path, '/a');
      expect(op.value, true);
      expect(op, isA<JsonPatchOp>());
    });
  });

  group('structural equality', () {
    test('equal-field instances are == with equal hashCode', () {
      const a = AddOp(path: '/a', value: 1);
      const b = AddOp(path: '/a', value: 1);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('differing on any field breaks equality', () {
      const base = MoveOp(from: '/a', path: '/b');
      expect(base, isNot(equals(const MoveOp(from: '/a', path: '/c'))));
      expect(base, isNot(equals(const MoveOp(from: '/z', path: '/b'))));
    });

    test('deep equality over distinct but content-equal nested value', () {
      AddOp build() => const AddOp(
        path: '/a',
        value: {
          'list': [1, 2, 3],
          'nested': {'flag': true},
        },
      );
      final a = build();
      final b = AddOp(
        path: '/a',
        value: {
          'list': [1, 2, 3],
          'nested': {'flag': true},
        },
      );
      expect(identical(a.value, b.value), isFalse);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('a null value differs from a missing-equivalent zero value', () {
      const nullValued = AddOp(path: '/a', value: null);
      const zeroValued = AddOp(path: '/a', value: 0);
      expect(nullValued, isNot(equals(zeroValued)));
    });
  });

  group('copyWith', () {
    test('updates one field, leaves others identical', () {
      const op = AddOp(path: '/a', value: 1);
      final updated = op.copyWith(value: 2);
      expect(updated.value, 2);
      expect(updated.path, op.path);
    });
  });

  group('fromJson dispatch + toJson round-trip', () {
    test('add round-trips through fromJson/toJson', () {
      final json = {'op': 'add', 'path': '/a', 'value': 1};
      final op = JsonPatchOp.fromJson(json);
      expect(op, const AddOp(path: '/a', value: 1));
      expect(op.toJson(), json);
    });

    test('remove round-trips (no value member)', () {
      final json = {'op': 'remove', 'path': '/a'};
      final op = JsonPatchOp.fromJson(json);
      expect(op, const RemoveOp(path: '/a'));
      expect(op.toJson(), json);
    });

    test('replace round-trips', () {
      final json = {'op': 'replace', 'path': '/a', 'value': 'x'};
      final op = JsonPatchOp.fromJson(json);
      expect(op, const ReplaceOp(path: '/a', value: 'x'));
      expect(op.toJson(), json);
    });

    test('move round-trips with from member', () {
      final json = {'op': 'move', 'from': '/a', 'path': '/b'};
      final op = JsonPatchOp.fromJson(json);
      expect(op, const MoveOp(from: '/a', path: '/b'));
      expect(op.toJson(), json);
    });

    test('copy round-trips with from member', () {
      final json = {'op': 'copy', 'from': '/a', 'path': '/b'};
      final op = JsonPatchOp.fromJson(json);
      expect(op, const CopyOp(from: '/a', path: '/b'));
      expect(op.toJson(), json);
    });

    test('test round-trips', () {
      final json = {'op': 'test', 'path': '/a', 'value': true};
      final op = JsonPatchOp.fromJson(json);
      expect(op, const TestOp(path: '/a', value: true));
      expect(op.toJson(), json);
    });

    test('add with explicit null value preserves the null', () {
      final json = {'op': 'add', 'path': '/a', 'value': null};
      final op = JsonPatchOp.fromJson(json);
      expect(op, const AddOp(path: '/a', value: null));
      expect(op.toJson(), json);
    });

    test('nested value round-trips deeply equal', () {
      final json = {
        'op': 'add',
        'path': '/a',
        'value': {
          'list': [1, 2, 3],
        },
      };
      final op = JsonPatchOp.fromJson(json);
      expect(op.toJson(), json);
    });
  });

  group('fromJson negative cases throw ProtocolError(protocolMalformed)', () {
    void expectMalformed(Map<String, dynamic> json) {
      expect(
        () => JsonPatchOp.fromJson(json),
        throwsA(
          isA<ProtocolError>().having(
            (e) => e.code,
            'code',
            KoelErrorCode.protocolMalformed,
          ),
        ),
      );
    }

    test('unknown op', () {
      expectMalformed({'op': 'frobnicate', 'path': '/a'});
    });

    test('non-string op', () {
      expectMalformed({'op': 42, 'path': '/a'});
    });

    test('missing op', () {
      expectMalformed({'path': '/a'});
    });

    test('add missing path', () {
      expectMalformed({'op': 'add', 'value': 1});
    });

    test('add missing value member', () {
      expectMalformed({'op': 'add', 'path': '/a'});
    });

    test('replace missing value member', () {
      expectMalformed({'op': 'replace', 'path': '/a'});
    });

    test('test missing value member', () {
      expectMalformed({'op': 'test', 'path': '/a'});
    });

    test('move missing from', () {
      expectMalformed({'op': 'move', 'path': '/b'});
    });

    test('copy missing from', () {
      expectMalformed({'op': 'copy', 'path': '/b'});
    });
  });
}
