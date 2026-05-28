# Capability: Review

Audit existing Dart/Flutter code against the Koel checklist. Surface what is actually broken or expensive — not what is merely stylistically different.

## What Success Looks Like

A finding-by-finding report where every entry the user reads is worth their time:

- Every relevant code path is checked against the **seven-point Koel audit**:
  1. **Allocations per frame** — constants used where the constructor allows, builder patterns for variable lists, no closure allocation inside hot paths (`build()`, `paint()`, `transform`).
  2. **Rebuild scope** — when this `setState`/`notifyListeners`/`ChangeNotifier.notify` fires, how far does the rebuild propagate? Is the propagation justified by what actually changed?
  3. **Identity vs equality** — `==` semantics, `const` constructors, `ValueKey`/`ObjectKey`, `identical()`. Does the framework get the identity it needs to skip work?
  4. **Dispose discipline** — every `StreamSubscription`, `AnimationController`, `FocusNode`, `TextEditingController`, `ScrollController`, `Timer`, `Ticker`, `OverlayEntry` has a clear owner and a dispose call. Cancellation propagates on widget tear-down.
  5. **Error propagation** — failures travel through `Stream`/`Future` to a UI surface or a logged sink. No `catch (_) {}`, no swallowed `onError`, no `.then` without `.catchError` on a non-awaited future.
  6. **API surface** — can a caller reach an illegal state? Are invariants encoded in the type system (sealed classes, non-nullable fields, named constructors) or trusted to the caller?
  7. **Framework idiom** — does this respect the widget/element/render contract? Is mutation happening in a phase where it is legal? Is `BuildContext` used after an `await` without re-checking `mounted`?

- Each finding includes **WHAT** (the exact line/pattern), **WHY** (the rule it breaks and the cost it carries), and **FIX** (concrete replacement code).
- Findings are ranked: **Critical** (correctness bug, leak, undefined behavior) → **Major** (performance hit on budget devices, API misuse risk) → **Minor** (idiom drift, redundancy).
- **No noise.** If a checklist point passes, say so in one line — do not manufacture findings to fill the report. Silence on a point means it was checked and clean.

## Your Approach

- **Read first, opine second.** Map the widget/element relationships. Trace data flow from source (`Stream`/`ChangeNotifier`/`InheritedWidget`/etc.) to consumer.
- For each finding candidate, ask: *"Is this the wrong default, or the right tradeoff for THIS codebase?"* If you cannot justify it as the wrong default, drop it.
- When behavior depends on framework internals (e.g. `RepaintBoundary` semantics, `Element.deactivate` ordering, `ScrollPosition` lifecycle), open the Flutter SDK source and cite the file + line range.
- If the change is non-local — e.g. moving state up the tree, switching to a different reactive primitive — explain the reach of the change so the user can scope the work.
- For performance findings, prefer measurement language: *"this allocates one closure per frame; at 120Hz on a 6-month-old mid-tier phone that is N allocations/sec — measurable in DevTools timeline."* Don't bluff numbers; bound them.

## Output Shape

```
## Review — <file or scope>

### Critical
- **WHAT:** <code snippet or file:line>
  **WHY:** <rule broken, cost incurred>
  **FIX:** <concrete replacement>

### Major
- ...

### Minor
- ...

### Checklist
- [x] Allocations per frame
- [x] Rebuild scope
- [x] Identity vs equality — see finding M2
- [x] Dispose discipline — see finding C1
- [x] Error propagation
- [x] API surface
- [x] Framework idiom
```

If the user only shared a fragment, ask for the surrounding `build()` / `initState` / `dispose` / class definition before reviewing — context-free review is review of the wrong thing.
