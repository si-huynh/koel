import 'package:koel_core/src/error/koel_error.dart';
import 'package:koel_core/src/error/koel_error_code.dart';
import 'package:koel_core/src/json_patch/json_pointer.dart';
import 'package:test/test.dart';

void main() {
  group('parseJsonPointer', () {
    test('empty pointer references the whole document', () {
      expect(parseJsonPointer(''), isEmpty);
    });

    test('single token', () {
      expect(parseJsonPointer('/foo'), ['foo']);
    });

    test('array element token', () {
      expect(parseJsonPointer('/foo/0'), ['foo', '0']);
    });

    test('end-of-array token survives as "-"', () {
      expect(parseJsonPointer('/foo/-'), ['foo', endOfArrayToken]);
    });

    test('empty-string member token (pointer "/")', () {
      expect(parseJsonPointer('/'), ['']);
    });

    test('unescape ~1 to / and ~0 to ~ (order matters)', () {
      expect(parseJsonPointer('/a~1b'), ['a/b']);
      expect(parseJsonPointer('/m~0n'), ['m~n']);
      // ~01 must unescape to ~1 (decode ~1 first would give /), so order is
      // ~1 then ~0: '~01' -> after ~1: '~01' has no '~1' literal except the
      // trailing '1'? RFC example: '/~01' -> key '~1'.
      expect(parseJsonPointer('/~01'), ['~1']);
    });

    test('non-empty pointer not starting with "/" is malformed', () {
      expect(
        () => parseJsonPointer('foo'),
        throwsA(
          isA<ProtocolError>().having(
            (e) => e.code,
            'code',
            KoelErrorCode.protocolMalformed,
          ),
        ),
      );
    });
  });

  group('parseArrayIndex', () {
    test('valid non-negative decimals', () {
      expect(parseArrayIndex('0'), 0);
      expect(parseArrayIndex('12'), 12);
    });

    test('rejects leading zero', () {
      expect(parseArrayIndex('01'), isNull);
    });

    test('rejects negative, fractional, non-numeric, empty, and "-"', () {
      expect(parseArrayIndex('-1'), isNull);
      expect(parseArrayIndex('1.0'), isNull);
      expect(parseArrayIndex('a'), isNull);
      expect(parseArrayIndex(''), isNull);
      expect(parseArrayIndex(endOfArrayToken), isNull);
    });

    test('rejects an all-digit token that overflows int (no raw throw)', () {
      expect(parseArrayIndex('99999999999999999999'), isNull);
    });
  });

  group('resolvePointer', () {
    test('whole document for empty token list', () {
      final doc = {'a': 1};
      expect(resolvePointer(doc, const []), same(doc));
    });

    test('object member', () {
      expect(resolvePointer({'a': 42}, const ['a']), 42);
    });

    test('nested object + array element', () {
      final doc = {
        'a': {
          'b': [10, 20, 30],
        },
      };
      expect(resolvePointer(doc, const ['a', 'b', '2']), 30);
    });

    test('resolves to a genuine null value (distinct from missing)', () {
      expect(resolvePointer({'a': null}, const ['a']), isNull);
    });

    test('missing object key signals not-found', () {
      expect(resolvePointer({'a': 1}, const ['b']), same(missing));
    });

    test('reference into a missing parent signals not-found, no crash', () {
      expect(resolvePointer({'a': 1}, const ['x', 'y']), same(missing));
    });

    test('array index out of range signals not-found', () {
      expect(
        resolvePointer(
          {
            'a': [1, 2],
          },
          const ['a', '5'],
        ),
        same(missing),
      );
    });

    test('non-index token into an array signals not-found', () {
      expect(
        resolvePointer(
          {
            'a': [1, 2],
          },
          const ['a', 'x'],
        ),
        same(missing),
      );
    });

    test('walking into a scalar signals not-found', () {
      expect(resolvePointer({'a': 1}, const ['a', 'b']), same(missing));
    });
  });
}
