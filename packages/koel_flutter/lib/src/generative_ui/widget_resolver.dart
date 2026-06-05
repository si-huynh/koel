import 'package:flutter/widgets.dart';
import 'package:koel_core/koel_core.dart';

/// Maps a tool-call name to the Flutter [Widget] that renders its generative UI,
/// with a graceful fallback for names no builder claims (F-E2).
///
/// Generative UI rides the `TOOL_CALL_*` convention: when an agent invokes a
/// frontend-rendered tool, a [ToolCallStartEvent] arrives carrying the
/// [ToolCallStartEvent.toolCallName] that selects which widget to show. A host
/// (Epic 7 / consumer territory) calls [resolve] as those events stream; this
/// class is the pure name → builder lookup, not the streaming host.
///
/// Resolution is **total** over any name — [resolve] always selects a builder
/// and never returns `null`. (The name-resolution itself never throws; a
/// supplied builder that throws during its own execution propagates normally.)
/// The order is:
///
/// 1. the builder registered for `toolCall.toolCallName`, else
/// 2. the [onUnknown] fallback builder, if supplied, else
/// 3. a built-in [UnknownGenerativeUI] placeholder that names the unhandled tool.
///
/// ```dart
/// final resolver = WidgetResolver(
///   {'chart': (context, toolCall) => ChartCard(id: toolCall.toolCallId)},
///   onUnknown: (context, toolCall) => const SizedBox.shrink(),
/// );
/// final widget = resolver.resolve(context, startEvent);
/// ```
///
/// The builder is typed over [ToolCallStartEvent] — the only `TOOL_CALL_*` event
/// carrying `toolCallName` (the resolution key) alongside `toolCallId` /
/// `parentMessageId`, which pass through to the builder for richer rendering.
class WidgetResolver {
  /// Builds a resolver over [_registry] (tool name → widget builder), falling
  /// back to [onUnknown] — and then [UnknownGenerativeUI] — for unregistered
  /// names. The registry is positional and private: callers read through
  /// [resolve], never the map.
  WidgetResolver(this._registry, {this.onUnknown});

  final Map<String, Widget Function(BuildContext, ToolCallStartEvent)>
  _registry;

  /// Builds the widget for a tool name that has no registered builder. When
  /// `null`, [resolve] falls through to [UnknownGenerativeUI].
  final Widget Function(BuildContext, ToolCallStartEvent)? onUnknown;

  /// The widget for [toolCall], selected by [ToolCallStartEvent.toolCallName].
  ///
  /// Returns the registered builder's widget, else [onUnknown]'s, else a
  /// built-in [UnknownGenerativeUI]. Total over any name — the lookup is
  /// `_registry[toolCall.toolCallName]`, so an absent or unregistered name falls
  /// through rather than failing.
  Widget resolve(BuildContext context, ToolCallStartEvent toolCall) =>
      (_registry[toolCall.toolCallName] ?? onUnknown ?? _defaultUnknown)(
        context,
        toolCall,
      );

  static Widget _defaultUnknown(
    BuildContext context,
    ToolCallStartEvent toolCall,
  ) => UnknownGenerativeUI(toolCallName: toolCall.toolCallName);
}

/// The built-in placeholder [WidgetResolver] renders when a tool call has no
/// registered builder and no [WidgetResolver.onUnknown] fallback (F-E2).
///
/// Deliberately minimal and theme-free — it builds over `package:flutter/widgets.dart`
/// only (no Material/Cupertino), so it renders under any host app. It surfaces
/// the unhandled [toolCallName] to make the gap debuggable; the richer themed
/// generative-UI primitives live in `koel_widgets` (Epic 7). Consumers who want
/// a different fallback pass [WidgetResolver.onUnknown] instead.
class UnknownGenerativeUI extends StatelessWidget {
  /// Creates a placeholder naming the unhandled [toolCallName].
  const UnknownGenerativeUI({required this.toolCallName, super.key});

  /// The tool-call name that no builder claimed — surfaced in the placeholder.
  final String toolCallName;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(8),
    child: Text('Unhandled generative UI: $toolCallName'),
  );
}
