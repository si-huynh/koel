part of 'ag_ui_event.dart';

/// `RUN_STARTED` — the agent has begun a run on a thread. The first lifecycle
/// event of every run; brackets the stream with [RunFinishedEvent] (or
/// [RunErrorEvent]).
///
/// [parentRunId] links a nested/forked run to its parent; `null` for a
/// top-level run. The spec's optional `input` echo is deliberately not modeled
/// in v1 — it re-sends data the client already holds and no consumer needs it.
@freezed
abstract class RunStartedEvent extends AgUiEvent with _$RunStartedEvent {
  const RunStartedEvent._() : super();

  /// Constructs a `RUN_STARTED` for [runId] on [threadId], optionally nested
  /// under [parentRunId].
  const factory RunStartedEvent({
    required String threadId,
    required String runId,
    String? parentRunId,
  }) = _RunStartedEvent;

  /// Decodes a `RUN_STARTED` wire payload. Throws
  /// [ProtocolError]`(protocolMalformed)` when `threadId`/`runId` is absent.
  static RunStartedEvent fromJson(Map<String, dynamic> json) => RunStartedEvent(
    threadId: _requireString(json, 'threadId'),
    runId: _requireString(json, 'runId'),
    parentRunId: _optionalString(json, 'parentRunId'),
  );

  /// Serializes to the `RUN_STARTED` wire shape, omitting an absent
  /// [parentRunId].
  Map<String, dynamic> toJson() => {
    'type': 'RUN_STARTED',
    'threadId': threadId,
    'runId': runId,
    if (parentRunId != null) 'parentRunId': parentRunId,
  };
}

/// `RUN_FINISHED` — the agent completed a run successfully. Closes the
/// lifecycle opened by [RunStartedEvent].
///
/// [result] is an arbitrary backend-defined payload (`result?: any` on the
/// wire); `Object?`, compared deeply via freezed's `DeepCollectionEquality`.
/// Absent when the run returns nothing.
@freezed
abstract class RunFinishedEvent extends AgUiEvent with _$RunFinishedEvent {
  const RunFinishedEvent._() : super();

  /// Constructs a `RUN_FINISHED` for [runId] on [threadId], carrying the
  /// optional backend [result].
  const factory RunFinishedEvent({
    required String threadId,
    required String runId,
    Object? result,
  }) = _RunFinishedEvent;

  /// Decodes a `RUN_FINISHED` wire payload. Throws
  /// [ProtocolError]`(protocolMalformed)` when `threadId`/`runId` is absent.
  static RunFinishedEvent fromJson(Map<String, dynamic> json) =>
      RunFinishedEvent(
        threadId: _requireString(json, 'threadId'),
        runId: _requireString(json, 'runId'),
        result: json['result'],
      );

  /// Serializes to the `RUN_FINISHED` wire shape, omitting an absent [result].
  Map<String, dynamic> toJson() => {
    'type': 'RUN_FINISHED',
    'threadId': threadId,
    'runId': runId,
    if (result != null) 'result': result,
  };
}

/// `RUN_ERROR` — the agent terminated a run with a failure. Carries the typed
/// [KoelError] consumed via the Story-2.3 union (no new error type).
///
/// Adapters **emit** this event rather than throwing a [KoelError]; the
/// deserializer canonicalizes the wire `{message, code?}` to an [AgentError] —
/// the "least-wrong home" for an unclassifiable failure per `koel_error.dart`.
/// The wire `code` is mapped to a [KoelErrorCode] by name (else
/// [KoelErrorCode.unknown]) while the original wire string is preserved verbatim
/// in [AgentError.agentCode], so the round-trip is lossless. Backend-specific
/// reclassification to `Transport`/`Business`/`Protocol` errors is the
/// `ErrorClassifier`'s job in Epic 5, **not** the deserializer's.
@freezed
abstract class RunErrorEvent extends AgUiEvent with _$RunErrorEvent {
  const RunErrorEvent._() : super();

  /// Constructs a `RUN_ERROR` carrying the typed [error].
  const factory RunErrorEvent({required KoelError error}) = _RunErrorEvent;

  /// Decodes a `RUN_ERROR` wire payload into an [AgentError]. Throws
  /// [ProtocolError]`(protocolMalformed)` when `message` is absent.
  static RunErrorEvent fromJson(Map<String, dynamic> json) => RunErrorEvent(
    error: AgentError(
      message: _requireString(json, 'message'),
      code: _koelErrorCodeFromWire(json['code']),
      agentCode: _optionalString(json, 'code'),
    ),
  );

  /// Serializes to the `RUN_ERROR` wire shape, preferring the verbatim wire
  /// code and omitting a bare `unknown` so it round-trips to an absent `code`.
  Map<String, dynamic> toJson() {
    final error = this.error;
    // Prefer the verbatim wire code (`agentCode`); fall back to the classified
    // enum name, but omit a bare `unknown` — it carries no wire signal and must
    // round-trip to an absent `code` (the no-`code` AC4 shape). This keeps a
    // hand-built `AgentError(code: …, agentCode: null)` from silently dropping
    // its classified code on serialization.
    final code = error is AgentError
        ? (error.agentCode ??
              (error.code == KoelErrorCode.unknown ? null : error.code.name))
        : error.code.name;
    return {'type': 'RUN_ERROR', 'message': error.message, 'code': ?code};
  }
}
