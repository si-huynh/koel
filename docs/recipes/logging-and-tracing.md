---
id: logging-and-tracing
title: Logging & tracing
---

# Logging & tracing

Two interceptors give you observability without touching the transport:
`LoggingInterceptor` for structured logs, and `EventTraceInterceptor` for a
machine-readable trace of every event (the feed koel_devtools consumes).

```dart
import 'dart:async';
import 'package:koel/koel.dart' show HttpAgent, KoelClient;
import 'package:koel_http/koel_http.dart'
    show EventTraceInterceptor, LoggingInterceptor, TraceEntry;
import 'package:logging/logging.dart' show Level, Logger;

void main() {
  // package:logging is the sink LoggingInterceptor writes to.
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((r) => print('${r.level.name}: ${r.message}'));

  final traces = StreamController<TraceEntry>();
  traces.stream.listen((entry) => print('trace: $entry'));

  final client = KoelClient(
    agent: HttpAgent(url: Uri.parse('https://your-backend.example/agui')),
    interceptors: [
      LoggingInterceptor(level: Level.INFO),
      EventTraceInterceptor(sink: traces.sink),
    ],
  );
  // ... use client; close traces when done.
}
```

## Logging

`LoggingInterceptor` emits structured request/response records through
`package:logging` at the `level` you choose, so it routes through your app's
existing logging setup rather than `print`.

## Tracing

`EventTraceInterceptor` writes a `TraceEntry` to the `Sink` you supply for each
event — wire it to a `StreamController` (above), a ring buffer, or directly to
the koel_devtools observer. It is the structured trail behind time-travel replay
and post-hoc inspection.

For redaction before anything reaches a log, add
[PII redaction](./pii-redaction-sentry.md) ahead of the logger in the chain.
