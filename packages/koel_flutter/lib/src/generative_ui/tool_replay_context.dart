import 'package:flutter/widgets.dart';

/// Publishes whether the surrounding tool handlers are running under DevTools
/// time-travel replay, so a handler can skip its real-world side effects (F-F7).
///
/// During replay (Epic 8), the DevTools wrapper mounts
/// `ToolReplayContext(isReplaying: true, child: appSubtree)` so a replay-aware
/// handler short-circuits:
///
/// ```dart
/// if (ToolReplayContext.of(context).isReplaying) return; // no live side effect
/// ```
///
/// **[of] is total — it never throws.** This is the deliberate opposite of
/// `KoelClientScope.of` (which throws on a missing ancestor, because a missing
/// client is a programming error). Here, *no* `ToolReplayContext` is mounted in
/// normal live operation — the replay wrapper exists only in Epic-8 replay mode
/// — yet handlers consult the flag on every call. So a missing ancestor is the
/// expected *live* answer, not an error: [of] returns a const default with
/// `isReplaying == false`.
///
/// The flag is read **imperatively** inside handler callbacks, not reactively in
/// `build`, so [of] reads via `getInheritedWidgetOfExactType` and registers **no**
/// dependency. A consumer who genuinely wants to rebuild on a replay toggle can
/// call `dependOnInheritedWidgetOfExactType<ToolReplayContext>()` directly —
/// [updateShouldNotify] gives that the correct value semantics.
class ToolReplayContext extends InheritedWidget {
  /// Publishes [isReplaying] to [child]'s subtree.
  const ToolReplayContext({
    required this.isReplaying,
    required super.child,
    super.key,
  });

  /// The live-mode default returned by [of] when no ancestor is mounted: a
  /// detached value holder (`isReplaying: false`, never inserted in the tree —
  /// its child is irrelevant), read only for [isReplaying].
  const ToolReplayContext._liveDefault()
    : isReplaying = false,
      super(child: const SizedBox.shrink());

  /// Whether tool handlers in this subtree are running under replay. When
  /// `true`, a replay-aware handler should skip live side effects.
  final bool isReplaying;

  static const ToolReplayContext _live = ToolReplayContext._liveDefault();

  /// The nearest enclosing [ToolReplayContext], or the live default
  /// (`isReplaying: false`) when none is mounted. **Never throws and never
  /// returns `null`** — a missing ancestor is live mode, the common case.
  ///
  /// Reads without subscribing (`getInheritedWidgetOfExactType`): the flag is
  /// consulted imperatively in handler callbacks, where depending on an
  /// inherited widget outside `build` would be a footgun.
  static ToolReplayContext of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ToolReplayContext>() ?? _live;

  /// Notifies dependents only when the [isReplaying] flag actually flips — so a
  /// consumer who *does* depend on this scope rebuilds on a live↔replay toggle
  /// and nothing else.
  @override
  bool updateShouldNotify(ToolReplayContext old) =>
      isReplaying != old.isReplaying;
}
