import 'dart:convert';
import 'dart:io';

import 'package:koel_core/src/error/koel_error.dart';
import 'package:koel_core/src/json_patch/json_patch.dart';
import 'package:koel_core/src/json_patch/json_patch_op.dart';
import 'package:test/test.dart';

/// Runs the canonical `json-patch/json-patch-tests` RFC 6902 conformance corpus
/// (see `rfc6902_fixtures/PROVENANCE.md`) against [JsonPatch.apply].
///
/// Each fixture is one of:
/// - `expected` — applying `patch` to `doc` must deep-equal `expected`;
/// - `error` — parsing or applying `patch` must throw a [ProtocolError];
/// - `disabled: true` — skipped (implementation-specific behavior upstream
///   leaves open).
void main() {
  for (final file in const ['tests.json', 'spec_tests.json']) {
    group('RFC 6902 conformance: $file', () {
      final entries =
          jsonDecode(
                File(
                  'test/json_patch/rfc6902_fixtures/$file',
                ).readAsStringSync(),
              )
              as List<dynamic>;

      for (var i = 0; i < entries.length; i++) {
        final entry = entries[i] as Map<String, dynamic>;
        final label = (entry['comment'] as String?) ?? 'entry #$i';

        if (entry['disabled'] == true) {
          continue;
        }

        test(label, () {
          final doc = entry['doc'];
          final rawPatch = entry['patch'] as List<dynamic>;

          // Parsing is part of the operation: an "error" fixture may be
          // malformed at the op level (unknown op, missing member), which
          // JsonPatchOp.fromJson rejects before apply ever runs.
          List<JsonPatchOp> parse() => [
            for (final raw in rawPatch)
              JsonPatchOp.fromJson(raw as Map<String, dynamic>),
          ];

          if (entry.containsKey('error')) {
            expect(
              () => JsonPatch.apply(doc, parse()),
              throwsA(isA<ProtocolError>()),
            );
          } else {
            final result = JsonPatch.apply(doc, parse());
            // Suite convention: an entry with neither 'expected' nor 'error' is
            // a no-op — the document must be returned structurally unchanged.
            expect(
              result,
              equals(entry.containsKey('expected') ? entry['expected'] : doc),
            );
          }
        });
      }
    });
  }
}
