import 'package:flutter/services.dart'
    show LogicalKeyboardKey, TextInputAction, TextInputType;
import 'package:flutter/widgets.dart';

import '../theme/theme_resolve.dart';

/// An auto-growing chat composer with an optional trailing attachment slot,
/// reading its fill, padding, and text geometry from the ambient `KoelTheme`
/// (F-E3).
///
/// The field starts one line tall and grows with content up to [maxLines]
/// (default 5), then scrolls. With a hardware keyboard, **Enter** submits (the
/// trimmed, non-empty text is delivered to [onSubmit] and the field clears) and
/// **Shift+Enter** inserts a newline. A non-null [attachmentSlot] renders in the
/// trailing position; [placeholder] shows while the field is empty.
///
/// It is built on the design-neutral `EditableText`, not Material `TextField`,
/// so it renders under a bare `CupertinoApp` too — which ships no
/// `MaterialLocalizations` and no `Material` ancestor that `TextField` requires.
/// When no `KoelTheme` is attached it falls back to a brightness-appropriate
/// default (see [resolveKoelTheme]).
class ChatInput extends StatefulWidget {
  /// Creates a chat input that reports submissions through [onSubmit].
  const ChatInput({
    required this.onSubmit,
    this.attachmentSlot,
    this.placeholder,
    this.maxLines = 5,
    super.key,
  }) : assert(maxLines >= 1, 'maxLines must be >= 1 (the field starts at 1)');

  /// Called with the trimmed, non-empty content when the user submits. A
  /// blank/whitespace-only field does not fire this.
  final void Function(String content) onSubmit;

  /// An optional widget rendered in the trailing position (e.g. an attach
  /// button); omitted when null.
  final Widget? attachmentSlot;

  /// Hint text shown while the field is empty; no hint when null.
  final String? placeholder;

  /// The line count the field grows to before it scrolls internally.
  final int maxLines;

  @override
  State<ChatInput> createState() => _ChatInputState();
}

/// Intent fired by the Enter shortcut to submit the current text.
class _SubmitTextIntent extends Intent {
  const _SubmitTextIntent();
}

class _ChatInputState extends State<ChatInput> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  /// Drives the placeholder's visibility. A [ValueNotifier] (not `setState`)
  /// so only the placeholder subtree rebuilds, and only when emptiness flips —
  /// the setter suppresses notifications when the bool is unchanged.
  late final ValueNotifier<bool> _isEmpty;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _isEmpty = ValueNotifier<bool>(true);
    _controller.addListener(_syncEmpty);
  }

  void _syncEmpty() => _isEmpty.value = _controller.text.isEmpty;

  void _submit() {
    final content = _controller.text.trim();
    if (content.isEmpty) return;
    widget.onSubmit(content);
    _controller.clear();
  }

  @override
  void dispose() {
    _controller.removeListener(_syncEmpty);
    _controller.dispose();
    _focusNode.dispose();
    _isEmpty.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final koel = resolveKoelTheme(context);
    final colors = koel.colors;
    // No `onInputBackground` slot by design — derive a readable foreground from
    // the fill's luminance (the 7.2 code-block precedent), so text stays legible
    // even when a consumer mismatches KoelTheme against the ambient brightness.
    final dark = colors.inputBackground.computeLuminance() < 0.5;
    final foreground = dark ? const Color(0xFFECECEC) : const Color(0xFF1B1B1B);
    final hint = foreground.withValues(alpha: 0.5);
    final bodyText = koel.textStyles.bodyText;

    final editable = EditableText(
      controller: _controller,
      focusNode: _focusNode,
      style: bodyText.copyWith(color: foreground),
      cursorColor: foreground,
      backgroundCursorColor: hint,
      minLines: 1,
      maxLines: widget.maxLines,
      keyboardType: TextInputType.multiline,
      // Soft-keyboard return inserts a newline; hardware Enter is intercepted by
      // the Shortcuts override below.
      textInputAction: TextInputAction.newline,
    );

    final placeholder = widget.placeholder;
    final field = Stack(
      children: [
        editable,
        if (placeholder != null)
          Positioned.fill(
            // The hint must not absorb taps meant to focus the field.
            child: IgnorePointer(
              child: ValueListenableBuilder<bool>(
                valueListenable: _isEmpty,
                builder: (context, isEmpty, _) => isEmpty
                    ? Align(
                        alignment: AlignmentDirectional.topStart,
                        child: Text(
                          placeholder,
                          style: bodyText.copyWith(color: hint),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
      ],
    );

    // A wrapping Shortcuts overrides the root DefaultTextEditingShortcuts'
    // plain-Enter handling (which sends Enter to the IME). `SingleActivator`
    // matches only with no modifiers, so Shift+Enter falls through to the
    // default and inserts a newline. Source: editable_text.dart:716-742.
    final composed = Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): _SubmitTextIntent(),
        SingleActivator(LogicalKeyboardKey.numpadEnter): _SubmitTextIntent(),
      },
      child: Actions(
        actions: {
          _SubmitTextIntent: CallbackAction<_SubmitTextIntent>(
            onInvoke: (_) {
              _submit();
              return null;
            },
          ),
        },
        child: field,
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.inputBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: koel.spacing.inputPadding,
        child: Row(
          // Keep the attachment pinned to the last line as the field grows.
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: composed),
            ?widget.attachmentSlot,
          ],
        ),
      ),
    );
  }
}
