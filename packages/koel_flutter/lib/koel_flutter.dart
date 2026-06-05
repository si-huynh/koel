/// Flutter glue for koel — controller, scope, session storage, generative UI.
///
/// This barrel is the **public 1.x contract** of `koel_flutter`. It surfaces the
/// Flutter-facing bindings layered over `koel_core`'s framework-free kernel and
/// deliberately re-exports nothing from `koel_core` itself — `ChatSession`,
/// `ChatState`, and the event/error types reach consumers through `koel_core`
/// (or the `koel` meta-package), never duplicated here.
library;

// ---- Controller: the LCD ChangeNotifier binding (F-D4) --------------------
export 'src/controller/koel_chat_controller.dart';

// ---- Scope: InheritedWidget client publication (F-D5) ---------------------
export 'src/scope/koel_client_scope.dart';

// ---- Session storage: Hive + secure encrypted-at-rest persistence (F-D1) --
export 'src/session_storage/hive_session_storage.dart' show HiveSessionStorage;
export 'src/session_storage/secure_session_storage.dart'
    show SecureSessionStorage;

// ---- Message content: assistant-string → segments (F-E1) ------------------
export 'src/message/message_content_parser.dart';
export 'src/message/message_segment.dart'
    show MessageSegment, TextSegment, CodeBlockSegment;

// ---- Generative UI: tool-call → Widget + replay-safety (F-E2/F-F7) --------
export 'src/generative_ui/widget_resolver.dart'
    show WidgetResolver, UnknownGenerativeUI;
export 'src/generative_ui/tool_replay_context.dart' show ToolReplayContext;
