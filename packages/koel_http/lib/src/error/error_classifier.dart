import 'package:koel_core/koel_core.dart';

import 'error_classifier_stub.dart'
    if (dart.library.io) 'io_error_classifier.dart';

/// The koel_http transport [ErrorClassifier], resolved per platform at compile
/// time — the seam `HttpAgent.run` builds its `InterceptorChain` over.
///
/// Native ([io_error_classifier.dart]) refines [DefaultErrorClassifier] with
/// real `dart:io` `is` checks, so `package:http`'s `IOClient`-wrapped
/// `SocketException` classifies as `transportRefused` rather than slipping to
/// `unknown` (AC4 — the base matches by `runtimeType` name and cannot see
/// through the wrapper). Every other platform falls back to the web-safe base:
/// there are no `dart:io` socket shapes to refine, and the web transport throws
/// before any socket error can arise.
///
/// Never throws — unlike the transport seam's `createTransport()`, this resolves
/// to a real classifier on every platform, so `run` can call it synchronously
/// while assembling the chain. This file imports no platform library; the
/// `dart:io` coupling lives only behind the conditional import.
ErrorClassifier transportErrorClassifier() => createErrorClassifier();
