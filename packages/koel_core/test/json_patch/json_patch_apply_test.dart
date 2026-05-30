import 'package:koel_core/src/error/koel_error.dart';
import 'package:koel_core/src/error/koel_error_code.dart';
import 'package:koel_core/src/json_patch/json_patch.dart';
import 'package:koel_core/src/json_patch/json_patch_op.dart';
import 'package:test/test.dart';

/// Matches a thrown [ProtocolError] whose code is `protocolMalformed`.
final throwsMalformed = throwsA(
  isA<ProtocolError>().having(
    (e) => e.code,
    'code',
    KoelErrorCode.protocolMalformed,
  ),
);

void main() {
  group('add', () {
    test('adds a new object member', () {
      expect(JsonPatch.apply({'a': 1}, const [AddOp(path: '/b', value: 2)]), {
        'a': 1,
        'b': 2,
      });
    });

    test('replaces an existing object member', () {
      expect(JsonPatch.apply({'a': 1}, const [AddOp(path: '/a', value: 9)]), {
        'a': 9,
      });
    });

    test('inserts into an array, shifting later elements', () {
      expect(
        JsonPatch.apply(
          {
            'a': [1, 2, 3],
          },
          const [AddOp(path: '/a/1', value: 99)],
        ),
        {
          'a': [1, 99, 2, 3],
        },
      );
    });

    test('appends with the "-" end-of-array token', () {
      expect(
        JsonPatch.apply(
          {
            'a': [1, 2],
          },
          const [AddOp(path: '/a/-', value: 3)],
        ),
        {
          'a': [1, 2, 3],
        },
      );
    });

    test('add at index == length appends', () {
      expect(
        JsonPatch.apply(
          {
            'a': [1, 2],
          },
          const [AddOp(path: '/a/2', value: 3)],
        ),
        {
          'a': [1, 2, 3],
        },
      );
    });

    test('add at root "" replaces the whole document', () {
      expect(
        JsonPatch.apply(
          {'a': 1},
          const [
            AddOp(path: '', value: {'z': 9}),
          ],
        ),
        {'z': 9},
      );
    });

    test('array index out of range throws', () {
      expect(
        () => JsonPatch.apply(
          {
            'a': [1],
          },
          const [AddOp(path: '/a/5', value: 9)],
        ),
        throwsMalformed,
      );
    });

    test('non-integer array index throws', () {
      expect(
        () => JsonPatch.apply(
          {
            'a': [1],
          },
          const [AddOp(path: '/a/x', value: 9)],
        ),
        throwsMalformed,
      );
    });

    test('missing parent throws', () {
      expect(
        () => JsonPatch.apply({}, const [AddOp(path: '/a/b', value: 9)]),
        throwsMalformed,
      );
    });
  });

  group('remove', () {
    test('removes an object member', () {
      expect(JsonPatch.apply({'a': 1, 'b': 2}, const [RemoveOp(path: '/b')]), {
        'a': 1,
      });
    });

    test('removes an array element, shifting later elements', () {
      expect(
        JsonPatch.apply(
          {
            'a': [1, 2, 3],
          },
          const [RemoveOp(path: '/a/1')],
        ),
        {
          'a': [1, 3],
        },
      );
    });

    test('removing a non-existent path throws', () {
      expect(
        () => JsonPatch.apply({'a': 1}, const [RemoveOp(path: '/b')]),
        throwsMalformed,
      );
    });

    test('removing the whole document throws', () {
      expect(
        () => JsonPatch.apply({'a': 1}, const [RemoveOp(path: '')]),
        throwsMalformed,
      );
    });
  });

  group('replace', () {
    test('replaces an existing object member', () {
      expect(
        JsonPatch.apply({'a': 1}, const [ReplaceOp(path: '/a', value: 5)]),
        {'a': 5},
      );
    });

    test('replacing a non-existent path throws', () {
      expect(
        () =>
            JsonPatch.apply({'a': 1}, const [ReplaceOp(path: '/b', value: 5)]),
        throwsMalformed,
      );
    });

    test('replace at root "" replaces the whole document', () {
      expect(
        JsonPatch.apply({'a': 1}, const [ReplaceOp(path: '', value: 'x')]),
        'x',
      );
    });
  });

  group('move', () {
    test('moves a value between object members', () {
      expect(
        JsonPatch.apply(
          {'a': 1, 'b': 2},
          const [MoveOp(from: '/a', path: '/c')],
        ),
        {'b': 2, 'c': 1},
      );
    });

    test('"from" does not exist throws', () {
      expect(
        () => JsonPatch.apply({'a': 1}, const [MoveOp(from: '/x', path: '/c')]),
        throwsMalformed,
      );
    });

    test('moving a location into its own child throws', () {
      expect(
        () => JsonPatch.apply(
          {
            'a': {'b': 1},
          },
          const [MoveOp(from: '/a', path: '/a/b')],
        ),
        throwsMalformed,
      );
    });
  });

  group('copy', () {
    test('copies a value, leaving the source intact', () {
      expect(
        JsonPatch.apply({'a': 1}, const [CopyOp(from: '/a', path: '/b')]),
        {'a': 1, 'b': 1},
      );
    });

    test('the copied value is independent of the source', () {
      final result =
          JsonPatch.apply(
                {
                  'a': {'n': 1},
                },
                const [
                  CopyOp(from: '/a', path: '/b'),
                  AddOp(path: '/a/n', value: 99),
                ],
              )
              as Map<String, dynamic>;
      expect(result['b'], {'n': 1});
      expect(result['a'], {'n': 99});
    });

    test('"from" does not exist throws', () {
      expect(
        () => JsonPatch.apply({'a': 1}, const [CopyOp(from: '/x', path: '/b')]),
        throwsMalformed,
      );
    });
  });

  group('test', () {
    test('passes when the value matches (scalar)', () {
      expect(JsonPatch.apply({'a': 1}, const [TestOp(path: '/a', value: 1)]), {
        'a': 1,
      });
    });

    test('passes for deep object/array equality', () {
      expect(
        JsonPatch.apply(
          {
            'a': {
              'list': [1, 2],
            },
          },
          const [
            TestOp(
              path: '/a',
              value: {
                'list': [1, 2],
              },
            ),
          ],
        ),
        isNotNull,
      );
    });

    test('passes for a genuine null value', () {
      expect(
        JsonPatch.apply({'a': null}, const [TestOp(path: '/a', value: null)]),
        {'a': null},
      );
    });

    test('fails on value mismatch', () {
      expect(
        () => JsonPatch.apply({'a': 1}, const [TestOp(path: '/a', value: 2)]),
        throwsMalformed,
      );
    });

    test('fails when the path does not exist', () {
      expect(
        () => JsonPatch.apply({'a': 1}, const [TestOp(path: '/b', value: 1)]),
        throwsMalformed,
      );
    });
  });

  group('non-mutation + atomicity', () {
    test('a successful patch does not mutate the caller input', () {
      final input = {
        'a': [1, 2],
        'b': 3,
      };
      final result = JsonPatch.apply(input, const [
        AddOp(path: '/a/-', value: 9),
        ReplaceOp(path: '/b', value: 4),
      ]);
      // Input untouched.
      expect(input, {
        'a': [1, 2],
        'b': 3,
      });
      // Result carries the change.
      expect(result, {
        'a': [1, 2, 9],
        'b': 4,
      });
    });

    test('the returned tree is a distinct object graph from the input', () {
      final input = {
        'a': [1],
      };
      final result =
          JsonPatch.apply(input, const [AddOp(path: '/b', value: 2)])
              as Map<String, dynamic>;
      expect(identical(result['a'], input['a']), isFalse);
    });

    test('a failing op leaves the caller input structurally unchanged', () {
      final input = {'a': 1, 'b': 2};
      expect(
        () => JsonPatch.apply(input, const [
          ReplaceOp(path: '/a', value: 10), // ok
          RemoveOp(path: '/missing'), // fails — whole patch aborts
          AddOp(path: '/c', value: 3), // never reached
        ]),
        throwsMalformed,
      );
      expect(input, {'a': 1, 'b': 2});
    });
  });

  group('empty patch + malformed pointer', () {
    test('an empty patch returns a structural copy of the document', () {
      final input = {'a': 1};
      final result = JsonPatch.apply(input, const []);
      expect(result, {'a': 1});
      expect(identical(result, input), isFalse);
    });

    test('a syntactically invalid pointer throws', () {
      expect(
        () => JsonPatch.apply(
          {'a': 1},
          const [AddOp(path: 'no-slash', value: 1)],
        ),
        throwsMalformed,
      );
    });

    test(
      'an array index that overflows int throws (not a raw FormatException)',
      () {
        expect(
          () => JsonPatch.apply(
            {
              'a': [1],
            },
            const [AddOp(path: '/a/99999999999999999999', value: 9)],
          ),
          throwsMalformed,
        );
      },
    );

    test(
      'a document with a non-String map key throws (not a raw TypeError)',
      () {
        expect(
          () => JsonPatch.apply(<dynamic, dynamic>{1: 'x'}, const []),
          throwsMalformed,
        );
      },
    );
  });
}
