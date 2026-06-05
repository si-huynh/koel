import 'package:flutter/widgets.dart';
import 'package:koel_core/koel_core.dart';

/// Publishes a [KoelClient] to its widget subtree so descendants resolve it via
/// [KoelClientScope.of] — no service-locator, no `get_it` (FR-D5).
///
/// Wrap the app (or any subtree) once:
///
/// ```dart
/// KoelClientScope(
///   client: client,
///   child: MaterialApp(home: ChatPage()),
/// )
/// ```
///
/// then any descendant reads the client with `KoelClientScope.of(context)`.
///
/// **The scope publishes the client; it does not own it.** The client is
/// injected, so whoever constructed it disposes it ([KoelClient.dispose]) —
/// [InheritedWidget] is immutable and has no teardown hook of its own.
class KoelClientScope extends InheritedWidget {
  /// Publishes [client] to [child]'s subtree. Kept `const` to match A.6 and
  /// because it costs nothing — a runtime-built [client] is never a const
  /// expression, so real call sites are never const anyway.
  const KoelClientScope({
    required this.client,
    required super.child,
    super.key,
  });

  /// The client published to descendants. Reached via [of].
  final KoelClient client;

  /// The [KoelClient] published by the nearest enclosing [KoelClientScope].
  ///
  /// Registers the calling element as a dependent
  /// (`dependOnInheritedWidgetOfExactType`), so the caller rebuilds when the
  /// scope is given a **different** client (see [updateShouldNotify]). For an
  /// `initState`-time read that must not create a dependency, capture the result
  /// in `didChangeDependencies` instead.
  ///
  /// Throws a [FlutterError] with remediation if no [KoelClientScope] ancestor
  /// is found — a missing scope is a programming error, not a null case.
  static KoelClient of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<KoelClientScope>();
    if (scope == null) {
      throw FlutterError.fromParts([
        ErrorSummary(
          'KoelClientScope.of() called with a context that has no '
          'KoelClientScope ancestor.',
        ),
        ErrorHint(
          'Wrap your app (or the subtree that needs the client) in a '
          'KoelClientScope, e.g.\n'
          '  KoelClientScope(client: client, child: MaterialApp(...))',
        ),
        context.describeElement('The context used was'),
      ]);
    }
    return scope.client;
  }

  /// Notifies dependents only when a **different** client instance is published.
  ///
  /// [KoelClient] has no `==` override, so this is an identity comparison: a new
  /// client instance rebuilds every dependent exactly once; re-publishing the
  /// same instance rebuilds nothing.
  @override
  bool updateShouldNotify(KoelClientScope old) => client != old.client;
}
