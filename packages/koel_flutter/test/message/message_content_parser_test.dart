import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:koel_flutter/koel_flutter.dart';

void main() {
  const parser = MessageContentParser();

  group('AC2 — prose + fenced blocks alternate, language-preserving', () {
    test('prose interleaved with 3 differently-languaged blocks', () {
      const content =
          'Here is dart:\n'
          '```dart\n'
          'void main() {}\n'
          '```\n'
          'then python:\n'
          '```python\n'
          'print("hi")\n'
          '```\n'
          'and finally json:\n'
          '```json\n'
          '{"a": 1}\n'
          '```\n'
          'done.';

      final segments = parser.parse(content);

      expect(segments, [
        const TextSegment('Here is dart:'),
        const CodeBlockSegment(language: 'dart', code: 'void main() {}'),
        const TextSegment('then python:'),
        const CodeBlockSegment(language: 'python', code: 'print("hi")'),
        const TextSegment('and finally json:'),
        const CodeBlockSegment(language: 'json', code: '{"a": 1}'),
        const TextSegment('done.'),
      ]);
    });

    test('inline backticks stay inside their TextSegment', () {
      const content = 'Call `foo()` and ``bar`` to start.';

      final segments = parser.parse(content);

      expect(segments, const [
        TextSegment('Call `foo()` and ``bar`` to start.'),
      ]);
    });

    test(
      'a backtick run mid-line (not line-leading) does not open a fence',
      () {
        const content = 'see ```not a fence``` inline';

        final segments = parser.parse(content);

        expect(segments, const [TextSegment('see ```not a fence``` inline')]);
      },
    );

    test('single fenced block round-trips body verbatim', () {
      const content = '```dart\nfoo\nbar\n```';

      final segments = parser.parse(content);

      expect(segments, const [
        CodeBlockSegment(language: 'dart', code: 'foo\nbar'),
      ]);
    });

    test('plain prose with no fences → one TextSegment', () {
      const content = 'just prose\nover two lines';

      final segments = parser.parse(content);

      expect(segments, const [TextSegment('just prose\nover two lines')]);
    });
  });

  group('AC3 — every edge case is well-formed and the parser is total', () {
    test('empty string → []', () {
      expect(parser.parse(''), isEmpty);
    });

    test('whitespace-only → single TextSegment', () {
      final segments = parser.parse('   ');
      expect(segments, const [TextSegment('   ')]);
    });

    test('code block at start → list begins with CodeBlockSegment', () {
      const content = '```\ncode\n```\nafter';

      final segments = parser.parse(content);

      expect(segments, const [
        CodeBlockSegment(language: '', code: 'code'),
        TextSegment('after'),
      ]);
    });

    test('code block at end → list ends with CodeBlockSegment', () {
      const content = 'before\n```\ncode\n```';

      final segments = parser.parse(content);

      expect(segments, const [
        TextSegment('before'),
        CodeBlockSegment(language: '', code: 'code'),
      ]);
    });

    test('two adjacent fences → no empty TextSegment between them', () {
      const content = '```\na\n```\n```\nb\n```';

      final segments = parser.parse(content);

      expect(segments, const [
        CodeBlockSegment(language: '', code: 'a'),
        CodeBlockSegment(language: '', code: 'b'),
      ]);
    });

    test('unclosed fence → one CodeBlockSegment running to EOF', () {
      const content = 'intro\n```dart\nnever closed\nmore';

      final segments = parser.parse(content);

      expect(segments, const [
        TextSegment('intro'),
        CodeBlockSegment(language: 'dart', code: 'never closed\nmore'),
      ]);
    });

    test('open then immediate close → empty-body CodeBlockSegment', () {
      const content = '```dart\n```';

      final segments = parser.parse(content);

      expect(segments, const [CodeBlockSegment(language: 'dart', code: '')]);
    });

    test('fence with no language → language is empty', () {
      const content = '```\nx\n```';

      final segments = parser.parse(content);

      expect(segments, const [CodeBlockSegment(language: '', code: 'x')]);
    });

    test('multi-word info string is kept verbatim (trimmed, not split)', () {
      const content = '```dart title=example\nx\n```';

      final segments = parser.parse(content);

      expect(segments, const [
        CodeBlockSegment(language: 'dart title=example', code: 'x'),
      ]);
    });

    test('a longer closing run still closes a 3-backtick block', () {
      const content = '```\nx\n`````';

      final segments = parser.parse(content);

      expect(segments, const [CodeBlockSegment(language: '', code: 'x')]);
    });

    test('a shorter run inside the block is body, not a close', () {
      const content = '````\n```\nx\n````';

      final segments = parser.parse(content);

      expect(segments, const [CodeBlockSegment(language: '', code: '```\nx')]);
    });
  });

  group('AC3 — CRLF / lone-CR line endings normalize and still alternate', () {
    test('CRLF document: fence closes and prose splits out', () {
      const content = '```dart\r\nfoo\r\n```\r\nafter';

      final segments = parser.parse(content);

      expect(segments, const [
        CodeBlockSegment(language: 'dart', code: 'foo'),
        TextSegment('after'),
      ]);
    });

    test('CRLF multi-line body normalizes to LF-joined code', () {
      const content = '```dart\r\nfoo\r\nbar\r\n```';

      final segments = parser.parse(content);

      expect(segments, const [
        CodeBlockSegment(language: 'dart', code: 'foo\nbar'),
      ]);
    });

    test('lone CR is treated as a line break (CommonMark)', () {
      const content = 'a\rb';

      final segments = parser.parse(content);

      expect(segments, const [TextSegment('a\nb')]);
    });
  });

  group('AC3 — property: 500 seeded markdown-ish strings stay invariant', () {
    test('parse never throws and upholds the structural invariants', () {
      final rng = Random(0xC0DE);

      for (var i = 0; i < 500; i++) {
        final input = _randomMarkdownish(rng);

        late final List<MessageSegment> segments;
        expect(
          () => segments = parser.parse(input),
          returnsNormally,
          reason: 'parse threw on:\n$input',
        );

        for (final segment in segments) {
          if (segment is TextSegment) {
            expect(
              segment.text,
              isNotEmpty,
              reason: 'empty TextSegment from:\n$input',
            );
          }
        }

        for (var j = 1; j < segments.length; j++) {
          final bothText =
              segments[j - 1] is TextSegment && segments[j] is TextSegment;
          expect(
            bothText,
            isFalse,
            reason: 'adjacent TextSegments at $j from:\n$input',
          );
        }
      }
    });
  });
}

/// Builds a markdown-ish string: random short prose tokens, line breaks (LF,
/// CRLF, and lone CR — to exercise line-ending normalization), backtick runs of
/// length 1–5, and optional language tags. Deterministic given [rng].
String _randomMarkdownish(Random rng) {
  const tokens = ['lorem', 'ipsum', 'foo()', 'a b', '   ', 'dart', 'x=1', ''];
  const breaks = ['\n', '\r\n', '\r'];
  const langs = ['', 'dart', 'py', 'json title=x'];

  final buffer = StringBuffer();
  final pieces = rng.nextInt(12);
  for (var i = 0; i < pieces; i++) {
    switch (rng.nextInt(4)) {
      case 0:
        buffer.write(tokens[rng.nextInt(tokens.length)]);
      case 1:
        buffer.write(breaks[rng.nextInt(breaks.length)]);
      case 2:
        buffer.write('`' * (1 + rng.nextInt(5)));
      default:
        buffer
          ..write('`' * (1 + rng.nextInt(5)))
          ..write(langs[rng.nextInt(langs.length)]);
    }
  }
  return buffer.toString();
}
