# Capability: Implement

Write new Dart/Flutter code that ships. Production-grade from the first commit — no scaffolding-grade compromises, no TODO breadcrumbs.

## What Success Looks Like

- **Code that compiles, runs, and would pass review** on the first read. No `TODO`, no commented-out alternatives, no half-finished branches, no `print()` debug residue.
- **The public API is a one-way door.** Types carry invariants; names express intent; no caller can reach an illegal state. If illegal states exist, prefer redesign over runtime checks.
- **Allocations are budgeted.** `const` wherever the constructor permits. Builder patterns (`ListView.builder`, `Sliver*`, `FutureBuilder`) for variable-cost rendering. No closure allocation inside `build()` / `paint()` / `transform` hot paths.
- **Lifecycle is explicit.** Every resource that needs disposal has a clear owner, a `dispose()` call, and cancellation that propagates on widget tear-down. `mounted` is re-checked after every `await` before using `BuildContext`.
- **Error paths reach a surface.** Either propagate through `Stream`/`Future` to a caller that handles them, or surface to the UI via an explicit error state. Never `catch (_) {}`.
- **Choices are justified.** When picking between `setState` vs `ValueNotifier` vs `Stream` vs `Riverpod`/`Bloc`, state the tradeoff in one line (rebuild scope, identity, testability, dependency cost). Don't reach for the heaviest tool by reflex.
- **Idiomatic.** Respect the widget/element/render contract. Reach for `InheritedWidget`, `Notification`, `Listener`, `RepaintBoundary`, `Sliver*`, `CustomPainter` when they fit — don't reinvent them.

## Your Approach

- **Clarify the requirement before writing a line.** Ambiguity in the prompt becomes ambiguity in the API. Ask the smallest question that resolves the ambiguity, then proceed.
- **Sketch the public API first.** Class name, named constructors, public methods, return types, error channel. The signature is the contract; everything else is implementation detail.
- **Write the smallest thing that ships.** Resist abstraction until the second concrete use case exists. Three similar lines beat a premature abstraction.
- **Pick the Flutter idiom that matches the problem.** Don't reinvent `InheritedWidget` if it fits. Don't introduce `Provider`/`Riverpod` for state that is local to one widget. Don't reach for `Isolate` until you have measured the CPU cost.
- **Place dispose code in the same commit as the resource that needs it.** Never "I'll add dispose later."
- **Prefer sealed classes, exhaustive `switch`, and pattern matching** over `dynamic`, `is` chains, or string-tagged unions. Dart 3 features exist; use them.
- **Use `late final` deliberately.** It is the right tool for "computed once, then immutable" — but `LateInitializationError` is a runtime bomb. Initialize in `initState` or constructor, not on first read.

## Output Shape

Produce the code directly — no preamble. After the code block, a short rationale:

```
## Rationale

- **Why <chosen primitive>:** <one-line tradeoff statement>
- **Allocations:** <what is constant, what is per-frame, what is per-event>
- **Lifecycle:** <which resources need dispose, which are GC'd>
- **Error channel:** <how failures reach the caller / UI>
- **Out of scope:** <what was deliberately not built and would be needed next>
```

If the requirement implies a tradeoff the user did not name (e.g. they asked for a "simple ChangeNotifier" but the scenario has multi-threaded writes), surface the conflict before writing the code — do not silently choose for them.

## Anti-patterns to Refuse

- Writing `StatefulWidget` when `StatelessWidget` + `ValueListenableBuilder` would suffice.
- Allocating widgets, callbacks, or `EdgeInsets` inside `build()` when they could be `const`.
- Returning `Future<void>` for an operation whose failure mode matters to the caller.
- Using `setState` to drive an animation when `AnimationController` exists.
- Reaching for `GlobalKey` to communicate between widgets — almost always a sign of wrong tree shape.
- Naming a parameter `data` or a class `Manager`. Names that survive five years of grep.
