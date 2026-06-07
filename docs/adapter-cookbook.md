---
id: adapter-cookbook
title: Adapter Cookbook
---

# Adapter Cookbook

This is the guide to writing your own backend bridge. koel ships three —
[`koel_agno`](./recipes/connect-agno.md),
[`koel_langgraph`](./recipes/connect-langgraph.md), and
[`koel_runtime`](./recipes/connect-copilotkit-runtime.md) (CopilotKit) — and they
are the worked examples this cookbook draws on.

## The SPI

Everything koel consumes is an `AbstractAgent`:

```dart
abstract class AbstractAgent {
  Stream<AgUiEvent> run(RunAgentInput input);
}
```

One method. If your backend already speaks native AG-UI over SSE — and most
modern ones do — you almost never implement this directly. You **extend
`HttpAgent`**, which gives you the entire transport stack (SSE parse, timeouts,
cancellation, retry/auth interceptors, chunk synthesis) for free, and override
only the two seams that differ per backend.

## Extend `HttpAgent`, override two seams

```dart
import 'package:koel_core/koel_core.dart';
import 'package:koel_http/koel_http.dart';

class MyAgent extends HttpAgent {
  MyAgent({required Uri baseURL, this.token})
      : super(url: baseURL.resolve('agui'));

  final String? token;

  // Seam 1 — encodeBody: shape the POST body your backend expects. Start from
  // super.encodeBody(input) (canonical AG-UI: threadId/runId/state/messages/
  // tools/context/forwardedProps) and add/rename only what your backend needs.
  @override
  Map<String, dynamic> encodeBody(RunAgentInput input) => {
        ...super.encodeBody(input),
        'my_backend_flag': true,
      };

  // Seam 2 — errorClassifier: map your backend's HTTP/business failures to typed
  // KoelError codes, so a 401/403/429 reaches the consumer as a typed error
  // rather than a raw status.
  @override
  ErrorClassifier errorClassifier() => const MyErrorClassifier();
}
```

That is the whole shape of `AgnoAgent` and `CopilotRuntimeAgent`: a constructor
that resolves the run URL, an `encodeBody` that normalizes the body, an
`errorClassifier`. The response path — parsing the `text/event-stream` into typed
`AgUiEvent`s — is unreshaped `HttpAgent` behavior, so you write none of it.

### When the wire is not plain SSE

If your backend speaks something other than canonical AG-UI/SSE, you implement
`AbstractAgent.run` directly and emit typed events yourself. Apply the
[cancel-correct teardown pattern](./patterns/stream-cancellation.md) so a
consumer `cancel()` tears the connection down within the abort budget and can
never hang.

## Auth as an interceptor, not a special case

Add auth as an `AuthInterceptor` (or your own `Interceptor`), prepended outermost
so a caller-supplied inner auth wins the merge. A blank/absent token should be a
no-op — the right default for an open local deployment. See
[Interceptors](./concepts/interceptors.md).

## Prove it with the conformance runner

The contract that makes a bridge a koel bridge is the **conformance runner**. It
drives your agent against the synthesized corpus (one event of every AG-UI type)
and reports which canonical types your bridge reproduces verbatim.

```dart
@TestOn('vm')
@Tags(['conformance'])
library;

import 'package:koel_test/koel_test.dart';
import 'package:test/test.dart';

void main() {
  test('MyAgent conformance', () async {
    final agent = MyAgent(baseURL: Uri.parse('http://localhost/agui'));
    final report = await const ConformanceRunner().runAgainst(agent);
    // Assert the report reproduces the canonical types your backend emits.
    expect(report.passed, isNotEmpty);
  });
}
```

### The 25/28 contract

An HTTP bridge reproduces **25 of the 28** AG-UI types verbatim. The three
`*_CHUNK` convenience shapes are normalized into their `START`/`CONTENT`/`END`
triplets at the transport by koel_http's default-on `synthesizeChunks` — so the
runner sees long form, not chunks. This is the fixed contract every native-AG-UI
adapter shares (a real backend never emits chunk shapes anyway), not a
limitation of your bridge. See [Events](./concepts/events.md).

## Capturing fixtures

For deterministic conformance without a live backend, capture real responses
once into JSONL fixtures and replay them through a `MockClient`. The repo's
`melos run capture-fixtures` pipeline (and the agno/langgraph/runtime test
suites) are the reference; the conformance lane then runs fully offline in CI.

## Checklist

- [ ] Extend `HttpAgent` (native SSE) or implement `AbstractAgent.run`.
- [ ] Override `encodeBody` from `super.encodeBody(input)`.
- [ ] Override `errorClassifier` mapping your failures to typed `KoelError`s.
- [ ] Auth via an interceptor; blank token is a no-op.
- [ ] A `@Tags(['conformance'])` test driving `ConformanceRunner.runAgainst`.
- [ ] Cancellation honored within budget (the teardown pattern).
