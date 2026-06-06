import 'package:koel_core/src/context/context.dart';
import 'package:test/test.dart';

void main() {
  group('Context', () {
    test('const construction with required description/value', () {
      const c = Context(description: 'page', value: 'home');
      expect(c.description, 'page');
      expect(c.value, 'home');
      expect(
        identical(
          const Context(description: 'a', value: 'b'),
          const Context(description: 'a', value: 'b'),
        ),
        isTrue,
      );
    });

    test('value equality and copyWith', () {
      const a = Context(description: 'page', value: 'home');
      const b = Context(description: 'page', value: 'home');
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(a.copyWith(value: 'about'))));
    });

    test('fromJson(toJson()) round-trips structurally equal', () {
      const c = Context(description: 'page', value: 'home');
      expect(Context.fromJson(c.toJson()), equals(c));
      expect(c.toJson(), {'description': 'page', 'value': 'home'});
    });
  });
}
