import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:koel_core/koel_core.dart';

import 'fixture_envelope.dart';

/// The typed `_session` header that opens every fixture `.jsonl` — the
/// provenance of a captured or synthesized run.
///
/// A plain `final class` (no `freezed`/codegen — a six-field header value needs
/// none, and `koel_test` carries no codegen dep). Produced only by
/// [FixtureLoader] while reading a fixture; it is parsed for validation and
/// excluded from the returned event list (the loaders return events only).
final class FixtureSession {
  /// Constructs a fixture header from its six provenance fields. Built only by
  /// [FixtureSession.fromJson] while [FixtureLoader] reads a fixture.
  const FixtureSession({
    required this.koelVersion,
    required this.adapter,
    required this.captured,
    required this.threadId,
    required this.runId,
    required this.synthesized,
    this.backendVersion,
  });

  /// Builds a [FixtureSession] from the **inner** `_session` object (the value
  /// under the single top-level `_session` key).
  ///
  /// A missing or wrong-typed required field is a corrupt fixture — an authoring
  /// error — so it throws [ArgumentError] rather than degrading silently.
  factory FixtureSession.fromJson(Map<String, dynamic> session) {
    T require<T>(String key) {
      final value = session[key];
      if (value is! T) {
        throw ArgumentError.value(
          session,
          '_session',
          'malformed fixture header: missing or wrong-typed "$key"',
        );
      }
      return value;
    }

    return FixtureSession(
      koelVersion: require<String>('koelVersion'),
      adapter: require<String>('adapter'),
      captured: DateTime.parse(require<String>('captured')),
      threadId: require<String>('threadId'),
      runId: require<String>('runId'),
      synthesized: require<bool>('synthesized'),
      // Optional: only live captures stamp it (a synthesized fixture has no
      // backend). Absent → null; present-but-wrong-typed is a corrupt header,
      // so it routes through `require` for the same ArgumentError as the rest.
      backendVersion: session['backendVersion'] == null
          ? null
          : require<String>('backendVersion'),
    );
  }

  /// The `koel` version that captured/synthesized this fixture.
  final String koelVersion;

  /// The backend adapter the run came from (`synthesized`, `agno`, …).
  final String adapter;

  /// When the fixture was captured (parsed from the ISO-8601 header string).
  final DateTime captured;

  /// The thread id the run executed under.
  final String threadId;

  /// The run id of this single run.
  final String runId;

  /// Whether the fixture is hand-synthesized (`true`) or captured from a live
  /// backend (`false`).
  final bool synthesized;

  /// The backend's own version string for a live capture (e.g. `agno==2.6.10`),
  /// or `null` for a synthesized fixture (which has no backend). Distinct from
  /// [adapter], which carries the koel adapter's version (e.g. `koel_agno@…`).
  final String? backendVersion;
}

/// Reads koel's bundled JSONL fixtures and decodes each into typed
/// [AgUiEvent]s — the zero-setup load half of `koel_test` (the replay half is
/// `MockAgent`).
///
/// A namespace of statics (`abstract final` forbids both construction and
/// subclassing). Each loader resolves its fixture through the **`package:`
/// asset URI**, so it reads correctly from any consuming package's test CWD —
/// not just `koel_test`'s own. The `_session` header is parsed into a
/// [FixtureSession] and dropped; the returned list is events only, decoded from
/// each line's `payload` via [AgUiEvent.fromWire].
abstract final class FixtureLoader {
  /// Loads a synthesized fixture (`lib/src/fixtures/synthesized/<name>.jsonl`).
  static Future<List<AgUiEvent>> loadSynthesized(String name) =>
      _load('synthesized', name);

  /// Loads a captured AG-UI Dojo fixture
  /// (`lib/src/fixtures/dojo/<eventType>.jsonl`), keyed per event type.
  static Future<List<AgUiEvent>> loadDojo(String eventType) =>
      _load('dojo', eventType);

  /// Loads a captured Agno fixture
  /// (`lib/src/fixtures/agno/<scenario>.jsonl`), keyed per scenario.
  static Future<List<AgUiEvent>> loadAgno(String scenario) =>
      _load('agno', scenario);

  /// Loads a captured LangGraph fixture
  /// (`lib/src/fixtures/langgraph/<scenario>.jsonl`), keyed per scenario.
  static Future<List<AgUiEvent>> loadLangGraph(String scenario) =>
      _load('langgraph', scenario);

  /// Loads a captured CopilotKit **v2** fixture
  /// (`lib/src/fixtures/copilotkit/<scenario>.jsonl`), keyed per scenario. The
  /// fixture is the AG-UI event sequence `CopilotRuntimeAgent` produces against
  /// the live **native-SSE** wire (Story 5.11 capture) — the same full-matrix
  /// surface agno/langgraph emit, no GraphQL bridge.
  static Future<List<AgUiEvent>> loadCopilotkit(String scenario) =>
      _load('copilotkit', scenario);

  /// The shared load+decode pipeline behind every public loader.
  ///
  /// Resolves the bundled asset, reads its lines, validates+discards the
  /// `_session` header, and decodes each event line's `payload`. A missing
  /// fixture throws an enumerated [ArgumentError] ([_unknownFixture]); a
  /// genuinely corrupt line surfaces its `FormatException` rather than being
  /// swallowed.
  static Future<List<AgUiEvent>> _load(String subdir, String name) async {
    // package: URI → real file: URI via package_config.json, independent of the
    // caller's CWD. NOT a CWD-relative File('lib/...'): that only resolves under
    // koel_test's own test root and breaks the moment a downstream package (e.g.
    // koel_http) loads a fixture from its own root (the D8 "zero setup" promise).
    final uri = Uri.parse('package:koel_test/src/fixtures/$subdir/$name.jsonl');
    final resolved = await Isolate.resolvePackageUri(uri);
    final file = resolved == null ? null : File.fromUri(resolved);

    if (file == null || !await file.exists()) {
      throw await _unknownFixture(subdir, name, resolved);
    }

    // A newline-terminated file can yield a trailing '' from readAsLines; 3.2
    // guarantees no interior blanks, so filtering trailing whitespace is safe.
    final lines = (await file.readAsLines())
        .where((line) => line.trim().isNotEmpty)
        .toList();

    // A present-but-empty fixture (a `touch`'d file, a truncated/failed
    // capture) would otherwise blow up on `lines.first` with an opaque
    // `StateError`; surface a fixture-naming `FormatException` instead.
    if (lines.isEmpty) {
      throw FormatException('fixture "$name" is empty — no `_session` header');
    }

    // Line 0 is the `_session` header: validate its shape (single `_session`
    // key whose value is an object), parse it (which throws on a malformed
    // header), then discard it.
    final headerLine = jsonDecode(lines.first) as Map<String, dynamic>;
    if (headerLine.length != 1 || !headerLine.containsKey('_session')) {
      throw FormatException(
        'fixture "$name" does not open with a `_session` header line',
        lines.first,
      );
    }
    final session = headerLine['_session'];
    if (session is! Map<String, dynamic>) {
      throw FormatException(
        'fixture "$name" has a malformed `_session` header value',
        lines.first,
      );
    }
    FixtureSession.fromJson(session);

    // Lines 1..N: decode each line's `payload` (the full wire object), never the
    // whole {type, timestamp, payload} envelope — the envelope's timestamp is
    // not part of the event. A corrupt line (Epic-5 partial/truncated capture)
    // throws a fixture-naming `FormatException` via `decodeFixtureEvent`, not an
    // opaque `TypeError` (the 3.3/3.5 deferral cluster).
    final events = <AgUiEvent>[];
    for (var i = 1; i < lines.length; i++) {
      events.add(
        AgUiEvent.fromWire(
          decodeFixtureEvent('fixture "$name"', i, lines[i]).payload,
        ),
      );
    }
    return events;
  }

  /// Builds the [ArgumentError] for an unknown fixture name, enumerating the
  /// `.jsonl` fixtures that *do* exist in [subdir] (discovered from disk, not a
  /// hardcoded catalog, so the message never rots). `.placeholder` files are
  /// never surfaced as available fixtures.
  static Future<ArgumentError> _unknownFixture(
    String subdir,
    String name,
    Uri? resolved,
  ) async {
    final available = <String>[];
    if (resolved != null) {
      final dir = File.fromUri(resolved).parent;
      if (await dir.exists()) {
        await for (final entity in dir.list()) {
          final base = entity.uri.pathSegments.last;
          if (entity is File && base.endsWith('.jsonl')) {
            available.add(base.substring(0, base.length - '.jsonl'.length));
          }
        }
      }
    }
    available.sort();
    return ArgumentError.value(
      name,
      'name',
      'Unknown $subdir fixture. Available: '
          '${available.isEmpty ? '(none)' : available.join(', ')}',
    );
  }
}
