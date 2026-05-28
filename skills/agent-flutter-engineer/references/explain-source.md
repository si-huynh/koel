# Capability: Explain Framework Internals

Answer "how does this actually work" questions about Flutter and Dart by reading the SDK source — not by paraphrasing the public docs.

## What Success Looks Like

The user finishes the explanation knowing:

- **What** the public API exposes — surface contract, parameters, return shape.
- **How** the framework implements it — the call chain from public entry point down to the layer that answers the user's actual question.
- **What it costs** — allocations, frame-time impact, GC pressure, layout/paint phase work.
- **What constrains it** — preconditions, assertions, phase legality (build vs layout vs paint), thread/isolate rules, lifecycle dependencies.
- **What it implies for usage** — concrete patterns this mechanism enables or forbids (e.g. "this is why `RepaintBoundary` only helps when the subtree actually repaints independently of its parent").

Citations are **concrete and verifiable**:

- File path inside the Flutter SDK or `dart-sdk` repo, with line range — e.g. `packages/flutter/lib/src/widgets/framework.dart:4823-4856`.
- The relevant code snippet quoted inline, lightly trimmed (no full method dumps unless every line matters).
- Flutter version pinned via `flutter --version` when the source has changed across releases. Note the version explicitly.

## Your Approach

- **Pin the version first.** Run or ask for `flutter --version`. Source paths and behavior shift across releases (e.g. `RenderObject.layout` reentrancy rules, `Element.deactivate` ordering, `Sliver*` protocols).
- **Locate the source.** Common roots:
  - Flutter framework: `flutter/packages/flutter/lib/src/{widgets,rendering,animation,painting,foundation,scheduler,gestures,material,cupertino}/`
  - Dart core: `dart-sdk/sdk/lib/{core,async,collection,isolate,ffi}/`
  - Engine bindings (rarely): `flutter/packages/flutter/lib/src/services/`
- **Walk the call chain.** Start at the public entry point the user asked about. Step into each call until the layer that answers the user's actual question. Stop one layer past that — don't waterfall into unrelated mechanism.
- **Show the code that matters.** Quote the method bodies that carry the answer. Skip getters, debug methods, and trivial forwarders that don't change behavior.
- **Make the cost model explicit.** "This walks the element tree once per dirty mark, O(depth) per `markNeedsBuild`." "This allocates a `_DependencyMutationRecord` per `dependOnInheritedWidgetOfExactType` call." Numbers beat adjectives.
- **Connect mechanism to pattern.** End with the usage implication: *"Therefore, `const` constructors matter here because element identity survives rebuild — the framework short-circuits at `Element.update` line N."*

## Output Shape

```
## <Public API or Concept> — Flutter <version>

### Public Surface
<one paragraph: signature, contract, common use>

### Mechanism
<code citations + walk-through, deepest first or top-down depending on which is clearer>

### Cost Model
<allocations, phase, complexity>

### Constraints
<phase legality, thread rules, lifecycle preconditions>

### Implications for Usage
<what this means in practice — patterns to prefer, patterns to refuse>
```

## What to Refuse

- Explaining from the public docs without opening the source. The user already has access to the docs — they came here for the source.
- Speculating about behavior. If you cannot find the source for a claim, say so and stop. Wrong mechanism explanations are worse than no answer.
- Quoting hundreds of lines because the method is long. Trim to the lines that carry the answer; cite the surrounding range so the user can read more.
