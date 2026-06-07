# Pattern: cancel-correct stream teardown

> House pattern for koel transports/adapters. Recurs across koel_http
> (4.3/4.4/4.6/4.9) and applies to every `async*` event stream a consumer can
> `cancel()` mid-run. Documented per Epic-4 retrospective Action Item #3.

## The problem

koel agents expose runs as `Stream<AgUiEvent>` produced by `async*` + `await for`
(e.g. `SseParser.parse`). When a consumer
`cancel()`s the subscription, Dart's cancel signal only reaches an `async*` body
*at its next suspension point* — so relying on it to propagate a connection
teardown **strands** the cancel and blows the sub-50 ms abort budget (NFR-8). Two
things must happen the instant the consumer cancels, neither of which the bare
`async*` gives you:

1. **Force/observe teardown now** — fire the explicit abort handle (or the
   side-effect: a disconnect hook, a FINE drop log), not whenever the generator
   next wakes.
2. **Never let a misbehaving client hang `cancel()`** — a client that ignores
   abort must not be able to block the consumer's `cancel()` future.

## The pattern

Wrap the inner stream in a `StreamController` whose `onCancel` does the teardown
**fire-and-forget**, and race it against the budget with a one-shot watchdog
`Timer`. Canonical implementation:
[`abortOnCancel`](https://github.com/si-huynh/koel/blob/main/packages/koel_http/lib/src/connection/cancellation.dart).

```dart
final controller = StreamController<AgUiEvent>(sync: true);
StreamSubscription<AgUiEvent>? sub;
controller
  ..onListen = () => sub = inner.listen(
        controller.add, onError: controller.addError, onDone: controller.close)
  ..onPause = () => sub?.pause()
  ..onResume = () => sub?.resume()
  ..onCancel = () {
    final upstream = sub;
    sub = null;                       // drop the ref: no event escapes post-cancel
    _watchBudget(Future.wait<void>([  // fire-and-forget — do NOT await on this path
      Future<void>.sync(teardown),    // abort handle / disconnect side-effect
      if (upstream != null) upstream.cancel(),
    ]));
    // return nothing → consumer's cancel() completes immediately
  };
return controller.stream;
```

The three load-bearing parts:

- **Second controller wrapping the guard.** Tearing `sub` to `null` on `onCancel`
  means even a client that keeps producing has nowhere to deliver — the **silent
  drop** guarantee. This is the "second `StreamController` *inside* the guard"
  idiom: the side effect you want to observe (`onDisconnect(null)`, a FINE drop
  log) lives in *this* controller's `onCancel`, not the inner stream's.
- **Fire-and-forget teardown.** `onCancel` returns without awaiting the abort, so
  a non-honoring client cannot stall `cancel()`. Failure of the teardown is
  irrelevant — a cancelled run is not a failed one.
- **Watchdog Timer, always cancelled on settle.** A `Timer(budget, …)` emits one
  `Level.WARNING` (process-once) if the teardown doesn't settle in time; the
  teardown's `.then`/`onError` **always** cancels the timer, so an honoring client
  leaves **no pending timer** (critical — a leaked timer fails tests and lingers
  the isolate).

## When to reach for it

Any koel layer that must act on consumer-cancel of an `async*` stream:

- **Transport abort** — force the socket down (`io_transport`/`web_transport`
  abort handle).
- **Connection lifecycle / logging** — observe the cancel to fire `onDisconnect`
  or a drop log without altering the event sequence.
- **Owned-resource teardown without a budget** — a simpler shape suffices: do the
  cleanup in a `finally` on the `async*` body (a cancelled `async*` runs its
  `finally`), as `CopilotRuntimeAgent` closes its owned `http.Client`. Use the
  full controller+watchdog pattern only when you need the **sub-budget force** or
  the **can't-hang** guarantee.
- **Epic 6 `KoelChatController`** — `cancel()`/`dispose()` tearing down the run
  subscription: own the subscription, cancel it on `dispose`, and never `await` a
  teardown that a stalled transport could hang.

## Anti-patterns

- Awaiting `abort()` / `subscription.cancel()` on the cancel-return path — a
  misbehaving client hangs the consumer.
- A watchdog `Timer` not cancelled on settle — leaks a pending timer (test
  failures, lingering isolate).
- `catch (_) {}` swallowing a teardown error instead of letting it settle the
  watchdog — see [no silent failures](https://github.com/si-huynh/koel/blob/main/CLAUDE.md).
