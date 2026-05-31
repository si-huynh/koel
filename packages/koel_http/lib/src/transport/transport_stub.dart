import 'transport.dart';

/// Default-platform [Transport] fallback — selected when neither
/// `dart.library.io` nor `dart.library.js_interop` is available. No
/// koel-supported platform resolves here; it exists only to satisfy the
/// conditional-import contract (a default branch is mandatory).
Transport createTransport() =>
    throw UnsupportedError('No koel_http transport for this platform');
