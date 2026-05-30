import 'package:koel_core/src/error/koel_error.dart';
import 'package:koel_core/src/error/koel_error_code.dart';
import 'package:koel_core/src/json_patch/json_patch_op.dart';
import 'package:koel_core/src/state/state_conflict.dart';
import 'package:test/test.dart';

void main() {
  group('StateConflict value semantics', () {
    test('equal fields compare == with deep patch-list equality', () {
      final a = StateConflict(
        incomingPatches: const [ReplaceOp(path: '/a', value: 1)],
        localState: const {'a': 0},
        snapshotState: const {'a': 0},
      );
      final b = StateConflict(
        incomingPatches: const [ReplaceOp(path: '/a', value: 1)],
        localState: const {'a': 0},
        snapshotState: const {'a': 0},
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('copyWith diffs a single field', () {
      const conflict = StateConflict(
        incomingPatches: [],
        localState: {'a': 1},
        snapshotState: {'a': 1},
      );
      expect(conflict.copyWith(localState: {'a': 2}).localState, {'a': 2});
      expect(conflict.copyWith(localState: {'a': 2}).snapshotState, {'a': 1});
    });
  });

  group('LastWriterWinsResolver', () {
    const resolver = LastWriterWinsResolver();

    test(
      'applies incoming patches verbatim onto localState, ignoring snapshot',
      () {
        // /a exists in both; only localState carries /b. Applying to localState
        // keeps /b; applying to snapshotState would drop it — so /b in the output
        // proves localState (not snapshotState) is the base.
        const conflict = StateConflict(
          incomingPatches: [ReplaceOp(path: '/a', value: 'incomingA')],
          localState: {'a': 'localA', 'b': 'localB'},
          snapshotState: {'a': 'snapA'},
        );
        final resolved = resolver.resolve(conflict);
        expect(resolved, {'a': 'incomingA', 'b': 'localB'});
        expect(resolved.containsValue('snapA'), isFalse);
      },
    );

    test('is non-mutating — localState is unchanged after resolve', () {
      final local = {
        'a': 'localA',
        'nested': {'x': 1},
      };
      final before = {
        'a': 'localA',
        'nested': {'x': 1},
      };
      final conflict = StateConflict(
        incomingPatches: const [ReplaceOp(path: '/a', value: 'incomingA')],
        localState: local,
        snapshotState: const {},
      );
      resolver.resolve(conflict);
      expect(local, equals(before));
    });

    test('throws ProtocolError when a patch is inapplicable to localState', () {
      const conflict = StateConflict(
        incomingPatches: [RemoveOp(path: '/nonexistent')],
        localState: {'a': 1},
        snapshotState: {'a': 1},
      );
      expect(
        () => resolver.resolve(conflict),
        throwsA(
          isA<ProtocolError>().having(
            (e) => e.code,
            'code',
            KoelErrorCode.protocolMalformed,
          ),
        ),
      );
    });

    test(
      'root-replacing op → non-object root throws ProtocolError, not CastError',
      () {
        // ReplaceOp(path: '') makes JsonPatch.apply return a List; the resolver
        // must type-guard and throw ProtocolError rather than let a CastError
        // escape (the 2.12 reducer regression class).
        const conflict = StateConflict(
          incomingPatches: [
            ReplaceOp(path: '', value: [1, 2, 3]),
          ],
          localState: {'a': 1},
          snapshotState: {'a': 1},
        );
        expect(
          () => resolver.resolve(conflict),
          throwsA(
            isA<ProtocolError>().having(
              (e) => e.code,
              'code',
              KoelErrorCode.protocolMalformed,
            ),
          ),
        );
      },
    );

    test(
      'AddOp(path: "") non-object root throws ProtocolError, not CastError',
      () {
        // AddOp(path: '') routes through the same JsonPatch.apply root-replace
        // (_add returns `value` when tokens are empty) and the same `is! Map`
        // guard as ReplaceOp — prove both root-replacing ops are guarded.
        const conflict = StateConflict(
          incomingPatches: [AddOp(path: '', value: 42)],
          localState: {'a': 1},
          snapshotState: {'a': 1},
        );
        expect(
          () => resolver.resolve(conflict),
          throwsA(
            isA<ProtocolError>().having(
              (e) => e.code,
              'code',
              KoelErrorCode.protocolMalformed,
            ),
          ),
        );
      },
    );

    test('empty incomingPatches resolves to a localState-equal map', () {
      const conflict = StateConflict(
        incomingPatches: [],
        localState: {'a': 1, 'b': 2},
        snapshotState: {'a': 9},
      );
      expect(resolver.resolve(conflict), {'a': 1, 'b': 2});
    });
  });
}
