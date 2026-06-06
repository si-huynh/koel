import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koel_widgets/koel_widgets.dart';

/// A `ThemeExtension<KoelTheme>` that is **not** a [KoelTheme] — the only kind
/// of "foreign" extension that survives the `covariant ThemeExtension<KoelTheme>`
/// downcast and reaches `KoelTheme.lerp`'s `is! KoelTheme` guard. (A truly
/// unrelated `ThemeExtension<X>` is a compile-time error to pass.)
@immutable
class _NotKoelTheme extends ThemeExtension<KoelTheme> {
  const _NotKoelTheme();

  @override
  KoelTheme copyWith() => KoelTheme.light();

  @override
  KoelTheme lerp(covariant ThemeExtension<KoelTheme>? other, double t) =>
      KoelTheme.light();
}

void main() {
  // A controlled pair with simple slots so midpoint blends are exact:
  // messageBubbleUser 0xFF000000 → 0xFF808080 ⇒ 0xFF404040 at t==0.5,
  // bubblePadding all(0) → all(10) ⇒ all(5) at t==0.5.
  const a = KoelTheme(
    colors: KoelColors(
      messageBubbleUser: Color(0xFF000000),
      messageBubbleAssistant: Color(0xFF101010),
      onMessageBubbleUser: Color(0xFF202020),
      onMessageBubbleAssistant: Color(0xFF303030),
      inputBackground: Color(0xFF404040),
      codeBlockBackground: Color(0xFF505050),
      followUpPillBackground: Color(0xFF606060),
      onFollowUpPill: Color(0xFF707070),
    ),
    textStyles: KoelTextStyles(
      bodyText: TextStyle(fontSize: 10),
      codeText: TextStyle(fontSize: 12),
    ),
    spacing: KoelSpacing(
      bubblePadding: EdgeInsets.zero,
      inputPadding: EdgeInsets.all(4),
    ),
  );
  const b = KoelTheme(
    colors: KoelColors(
      messageBubbleUser: Color(0xFF808080),
      messageBubbleAssistant: Color(0xFF909090),
      onMessageBubbleUser: Color(0xFFA0A0A0),
      onMessageBubbleAssistant: Color(0xFFB0B0B0),
      inputBackground: Color(0xFFC0C0C0),
      codeBlockBackground: Color(0xFFD0D0D0),
      followUpPillBackground: Color(0xFFE0E0E0),
      onFollowUpPill: Color(0xFFF0F0F0),
    ),
    textStyles: KoelTextStyles(
      bodyText: TextStyle(fontSize: 20),
      codeText: TextStyle(fontSize: 24),
    ),
    spacing: KoelSpacing(
      bubblePadding: EdgeInsets.all(10),
      inputPadding: EdgeInsets.all(8),
    ),
  );

  group('AC2 — copyWith replaces named fields, preserves the rest', () {
    test('top-level: one group swapped, two preserved', () {
      final swapped = a.copyWith(colors: b.colors);
      expect(swapped.colors, b.colors);
      expect(swapped.textStyles, a.textStyles);
      expect(swapped.spacing, a.spacing);
    });

    test('top-level: no args returns an equal theme', () {
      expect(a.copyWith(), a);
    });

    test('nested KoelColors: one slot swapped, others preserved', () {
      final swapped = a.colors.copyWith(
        messageBubbleUser: const Color(0xFFABCDEF),
      );
      expect(swapped.messageBubbleUser, const Color(0xFFABCDEF));
      expect(swapped.messageBubbleAssistant, a.colors.messageBubbleAssistant);
      expect(swapped.onFollowUpPill, a.colors.onFollowUpPill);
    });

    test('nested KoelSpacing: one token swapped, other preserved', () {
      final swapped = a.spacing.copyWith(
        bubblePadding: const EdgeInsets.all(99),
      );
      expect(swapped.bubblePadding, const EdgeInsets.all(99));
      expect(swapped.inputPadding, a.spacing.inputPadding);
    });

    test('nested KoelTextStyles: one style swapped, other preserved', () {
      final swapped = a.textStyles.copyWith(
        bodyText: const TextStyle(fontSize: 99),
      );
      expect(swapped.bodyText, const TextStyle(fontSize: 99));
      expect(swapped.codeText, a.textStyles.codeText);
    });
  });

  group('AC3 — lerp interpolates and guards null/foreign other', () {
    test('t == 0 equals a', () {
      expect(a.lerp(b, 0), a);
    });

    test('t == 1 equals b', () {
      expect(a.lerp(b, 1), b);
    });

    test('t == 0.5 blends every slot to its exact midpoint', () {
      final mid = a.lerp(b, 0.5);
      // All 8 colour slots: each channel pair midpoints to an exact byte.
      expect(mid.colors.messageBubbleUser, const Color(0xFF404040));
      expect(mid.colors.messageBubbleAssistant, const Color(0xFF505050));
      expect(mid.colors.onMessageBubbleUser, const Color(0xFF606060));
      expect(mid.colors.onMessageBubbleAssistant, const Color(0xFF707070));
      expect(mid.colors.inputBackground, const Color(0xFF808080));
      expect(mid.colors.codeBlockBackground, const Color(0xFF909090));
      expect(mid.colors.followUpPillBackground, const Color(0xFFA0A0A0));
      expect(mid.colors.onFollowUpPill, const Color(0xFFB0B0B0));
      // Both spacing tokens.
      expect(mid.spacing.bubblePadding, const EdgeInsets.all(5));
      expect(mid.spacing.inputPadding, const EdgeInsets.all(6));
      // Both text styles (fontSize 10→20 ⇒ 15, 12→24 ⇒ 18).
      expect(mid.textStyles.bodyText.fontSize, 15);
      expect(mid.textStyles.codeText.fontSize, 18);
    });

    test('null other returns this unchanged (identity)', () {
      expect(identical(a.lerp(null, 0.5), a), isTrue);
    });

    test('foreign ThemeExtension returns this unchanged (identity)', () {
      expect(identical(a.lerp(const _NotKoelTheme(), 0.5), a), isTrue);
    });
  });

  group('AC4 — light()/dark() factories differ per palette', () {
    test('every colour slot differs between light and dark', () {
      final light = KoelTheme.light().colors;
      final dark = KoelTheme.dark().colors;
      expect(light.messageBubbleUser, isNot(dark.messageBubbleUser));
      expect(light.messageBubbleAssistant, isNot(dark.messageBubbleAssistant));
      expect(light.onMessageBubbleUser, isNot(dark.onMessageBubbleUser));
      expect(
        light.onMessageBubbleAssistant,
        isNot(dark.onMessageBubbleAssistant),
      );
      expect(light.inputBackground, isNot(dark.inputBackground));
      expect(light.codeBlockBackground, isNot(dark.codeBlockBackground));
      expect(light.followUpPillBackground, isNot(dark.followUpPillBackground));
      expect(light.onFollowUpPill, isNot(dark.onFollowUpPill));
    });

    test('factories are not equal to each other', () {
      expect(KoelTheme.light(), isNot(KoelTheme.dark()));
    });
  });

  group('AC5 — value equality + hashCode', () {
    test(
      'two independently-built identical themes are == with equal hashCode',
      () {
        expect(KoelTheme.light(), KoelTheme.light());
        expect(KoelTheme.light().hashCode, KoelTheme.light().hashCode);
      },
    );

    test('a one-slot colour difference is !=', () {
      final tweaked = KoelTheme.light().copyWith(
        colors: KoelTheme.light().colors.copyWith(
          inputBackground: const Color(0xFF123456),
        ),
      );
      expect(tweaked, isNot(KoelTheme.light()));
    });

    test('nested types implement value equality', () {
      expect(a.colors, a.colors.copyWith());
      expect(a.textStyles, a.textStyles.copyWith());
      expect(a.spacing, a.spacing.copyWith());
      expect(a.colors.hashCode, a.colors.copyWith().hashCode);
    });
  });
}
