---
baseline_commit: 01c57a4
---

# Story 6.4: `SecureSessionStorage` via `flutter_secure_storage`

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Flutter developer,
I want `SecureSessionStorage implements SessionStorage` backed by `flutter_secure_storage` for encrypted-at-rest conversation persistence,
so that consumers needing PII protection get a drop-in storage with the **same API as `HiveSessionStorage`** per FR-D1.

## Context & scope (read first)

This is the **second** `SessionStorage` adapter in `koel_flutter` and the **encrypted-at-rest sibling** of [`HiveSessionStorage`](../../packages/koel_flutter/lib/src/session_storage/hive_session_storage.dart) (Story 6.3, just shipped — read it first). It is **single-package** (`koel_flutter` only) and reuses, unchanged, the `koel_core` JSON codec that 6.3 added to `ChatState`/`ToolCall`. **No `koel_core` change here.** The whole job is: a four-method adapter over `flutter_secure_storage`, the dependency, tests, the barrel line, and the per-platform caveat docs.

The deliberately small surface (`SecureSessionStorage({FlutterSecureStorage? storage})` — [addendum A.6:413-415](../planning-artifacts/prds/prd-koel-2026-05-27/addendum.md#L413)) hides one genuinely tricky design problem the epic's BDD only gestures at: **`flutter_secure_storage` is a flat, single-namespace key→value store the consumer may share with their own secrets** (they inject the instance). Enumerating "koel's thread ids" out of a store that may also hold the app's auth tokens — without a Hive-style per-box keyspace — is the entire design weight of this story. It is resolved by **D3 (namespaced key prefix)** below. Read **Dev Notes → Design decisions (D1–D8, locked)** before writing any code.

The epic's three BDD blocks ([epic-6:78-99](../planning-artifacts/epics/epic-6-flutter-glue-persistence-koelflutter.md#L78)) expand into the ACs below. Where the epic says "the index entry" (AC2) the faithful implementation is a key prefix, not a literal index key — see **D3**; this is a recorded design decision, not a deviation.

## Acceptance Criteria

1. **`SecureSessionStorage` class shape matches Addendum A.6 (AC source: [epic-6:84-89](../planning-artifacts/epics/epic-6-flutter-glue-persistence-koelflutter.md#L84)).** `packages/koel_flutter/lib/src/session_storage/secure_session_storage.dart` exposes `class SecureSessionStorage implements SessionStorage` with the constructor `SecureSessionStorage({FlutterSecureStorage? storage})` per A.6 ([addendum.md A.6:413-415](../planning-artifacts/prds/prd-koel-2026-05-27/addendum.md#L413)). When `storage` is omitted it defaults to `const FlutterSecureStorage()` (platform defaults — D5; the default constructor is `const` in flutter_secure_storage 10.x). **Nothing else public** beyond the constructor + `SessionStorage`'s four members — no `open` factory, no extra config knobs (A.6-exact surface discipline, parity with 6.1/6.2/6.3).

2. **The four methods honor the `SessionStorage` contract exactly across multiple threadIds (AC source: [session_storage.dart:18-35](../../packages/koel_core/lib/src/session/session_storage.dart#L18), [epic-6:91-95](../planning-artifacts/epics/epic-6-flutter-glue-persistence-koelflutter.md#L91)).** Mirroring `HiveSessionStorage`/`InMemorySessionStorage`: `save` is last-write-wins per `threadId`; `load` of an unknown `threadId` returns `null` and **never throws on absence**; `delete` is **idempotent** (deleting an absent thread completes normally); `listThreads()` returns a **fresh snapshot** the caller owns, with **no ordering guarantee**. A save→load round-trip across **at least three distinct threadIds** returns each persisted state exactly; a test exercises each contract clause (multi-thread round-trip, overwrite, load-missing→null, delete-absent→no-throw, listThreads-after-delete-as-set, snapshot ownership).

3. **Serialization is identical to `HiveSessionStorage`; partial in-progress messages survive (AC source: [epic-6:67](../planning-artifacts/epics/epic-6-flutter-glue-persistence-koelflutter.md#L67), [epic-6:91-93](../planning-artifacts/epics/epic-6-flutter-glue-persistence-koelflutter.md#L91)).** Each state is stored as `jsonEncode(state.toJson())` and decoded via `ChatState.fromJson(jsonDecode(value))` — the **exact same `koel_core` v1.0.0 wire-shape** 6.3 pinned (D1 — no new codec, no per-adapter serialization). A mid-stream `ChatState` (`phase == RunPhase.running`, `pendingMessage` populated, possibly non-empty `pendingToolCalls`) round-trips with its `pendingMessage` content, `phase`, and committed `messages` intact — the "incomplete" marker is the structural `pendingMessage != null` (D6 — no `isComplete` field), as in 6.3 AC5. A test asserts the reloaded `pendingMessage.content`, `phase`, and `messages`.

4. **Keys are koel-namespaced; `listThreads`/`delete` never touch the consumer's other secrets (AC source: [epic-6:91-95](../planning-artifacts/epics/epic-6-flutter-glue-persistence-koelflutter.md#L91); resolves the epic's "index entry" — D3).** Every persisted key is `'$_keyPrefix$threadId'` for a reserved private prefix (D3). `listThreads()` is `readAll()` filtered to keys carrying the prefix, **with the prefix stripped**, so it returns the raw threadIds and **only koel's** — never a foreign key co-resident in an injected/app-shared store. `delete(threadId)` removes the single prefixed key and nothing else; `deleteAll()` is **never** called (D4 — it would wipe the consumer's whole secure store). A test seeds the mock store with a non-koel key (e.g. `'app_auth_token'`), then: a save→listThreads returns **only** the koel threadId(s) (prefix stripped, foreign key absent); `delete(threadId)` removes the thread but leaves the foreign key readable.

5. **Per-platform caveats are documented in the package README per NFR-11 (AC source: [epic-6:97-99](../planning-artifacts/epics/epic-6-flutter-glue-persistence-koelflutter.md#L97), [architecture.md:1183](../planning-artifacts/architecture.md#L1183)).** `packages/koel_flutter/README.md` gains a "Secure persistence" subsection under the existing "Session persistence" heading with a per-platform caveat table covering at minimum: **iOS/macOS** Keychain (Keychain Sharing entitlement; accessibility / cold-start-before-first-unlock; survives app uninstall on older iOS), **Android** KeyStore (min API 23; disable auto-backup; data cleared on factory reset / "clear app data"), **web** (WebCrypto over `localStorage` — **not** hardware-backed; HTTPS/localhost only), **Windows** (DPAPI; needs VC++ build tools), **Linux** (`libsecret` + an active keyring such as GNOME Keyring/KDE Wallet). Note that platform setup (entitlements, keyring, build deps) is the **consumer's** responsibility (parity with 6.3's "consumer bootstraps Hive" — D5/D7 there, D5 here).

6. **Barrel, dartdoc, gates, and scope boundaries.** `lib/koel_flutter.dart` exports `secure_session_storage.dart` under a banner mirroring the existing session-storage banner — export **only** `SecureSessionStorage` (never re-export `SessionStorage`/`ChatState`/`FlutterSecureStorage`). Every public symbol carries contract-form dartdoc (NFR-16). Tests use `FlutterSecureStorage.setMockInitialValues({...})` with `TestWidgetsFlutterBinding.ensureInitialized()` (D8 — deterministic in-memory, no real platform). `melos run analyze` (11 pkgs clean), `melos run test` (full sweep SUCCESS), `melos run format:check` (0 changed) all green; AI-5.9 pins (`analyzer 12.1.0` / `freezed 3.2.6-dev.1`) held. Write to the ≥90% bar; **live six-platform verification is Story 6.7 and the coverage gate is Story 6.8 — neither is wired here** (parity with how 6.3 deferred its coverage gate).

## Tasks / Subtasks

- [x] **Task 1 — `koel_flutter`: add `flutter_secure_storage` dependency (AC: 1, 6)**
  - [x] Add to `packages/koel_flutter/pubspec.yaml` `dependencies:` → `flutter_secure_storage: ^10.3.1` (canonical, maintained by `steenbakker.dev`, 160/160 pub points — D2). It is a **regular dependency** (not dev): `FlutterSecureStorage` appears in `SecureSessionStorage`'s public A.6 constructor signature, exactly the reasoning that put `koel_core`/`hive_ce` in `dependencies`. Add a house-style comment (encrypted-at-rest sibling of `hive_ce`; in A.6 public signature; consumer owns platform entitlements/keyring/build-deps — parity with the existing `hive_ce` comment block, [pubspec.yaml:20-26](../../packages/koel_flutter/pubspec.yaml#L20)).
  - [x] `melos bootstrap` / `dart pub get`. **AI-5.9 watch:** confirm `pubspec.lock` did **not** bump the pinned `analyzer 12.1.0` / `freezed 3.2.6-dev.1` — the lock diff should add only the `flutter_secure_storage` subtree. ✅ Verified: analyzer/freezed lines untouched by the diff; lock added only the `flutter_secure_storage*` subtree + its transitives (ffi/jni/path_provider/etc.).

- [x] **Task 2 — `koel_flutter`: implement `SecureSessionStorage` (AC: 1, 2, 3, 4)**
  - [x] Create `lib/src/session_storage/secure_session_storage.dart`. Imports: `dart:convert` (`jsonEncode`/`jsonDecode`), `package:flutter_secure_storage/flutter_secure_storage.dart` (`FlutterSecureStorage`), `package:koel_core/koel_core.dart` (`SessionStorage`, `ChatState` — barrel-exported; never import `src/`).
  - [x] `class SecureSessionStorage implements SessionStorage` with `SecureSessionStorage({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();` and `final FlutterSecureStorage _storage;` (D5 — injected collaborator, const default; the constructor itself is non-const because of the `??`).
  - [x] **Reserved key prefix (D3):** `static const _keyPrefix = 'koel_session.';` and a private `String _key(String threadId) => '$_keyPrefix$threadId';`. Document the prefix is koel-reserved within the (possibly app-shared) secure store.
  - [x] `save`: `await _storage.write(key: _key(threadId), value: jsonEncode(state.toJson()));` — last-write-wins (`write` overwrites).
  - [x] `load`: `final raw = await _storage.read(key: _key(threadId)); if (raw == null) return null; return ChatState.fromJson(jsonDecode(raw) as Map<String, dynamic>);` — missing key → `null`, never throws on absence (AC2). **Faithful-parity with Hive (D7):** do **not** add catch-and-drop decode-hardening here — that is a cross-adapter decision left deferred (see Dev Notes → Carry-ins).
  - [x] `delete`: `await _storage.delete(key: _key(threadId));` — `delete` of an absent key is a no-op (idempotent, AC2). **Never `deleteAll()` (D4).**
  - [x] `listThreads`: read the whole store, keep only koel's keys, strip the prefix (fresh list, caller owns it, no ordering, foreign keys excluded — AC4).
  - [x] Contract-form dartdoc on the class, the constructor, and each method (restate the `SessionStorage` guarantee each upholds). `SecureSessionStorage` is on the 1.x public contract.

- [x] **Task 3 — `koel_flutter`: tests (AC: 2, 3, 4)**
  - [x] Create `test/session_storage/secure_session_storage_test.dart`. **Deterministic mock (D8):** `TestWidgetsFlutterBinding.ensureInitialized();` at the top of `main`, then `FlutterSecureStorage.setMockInitialValues({});` in `setUp`. A real `SecureSessionStorage()` (default `const FlutterSecureStorage()`) routes to that mock — no platform, no `flutter drive`.
  - [x] Build `ChatState` fixtures directly via the `_user`/`_assistant` helper idiom mirrored from `hive_session_storage_test.dart`.
  - [x] AC2 contract suite: save→load equal; multi-thread (3 distinct threadIds each round-trip exactly); last-write-wins; `load('absent')`→`null`; `delete('absent')`→completes; listThreads-after-delete as a set; snapshot ownership.
  - [x] AC3 partial-message suite: mid-stream `ChatState(phase: running, pendingMessage, pendingToolCalls)` round-trips with `pendingMessage.content`/`phase`/`messages` intact + full `equals`.
  - [x] **AC4 namespace-isolation suite:** seeded `{'app_auth_token': 'secret'}`; `listThreads()`→exactly `{'t1'}` (prefix stripped, foreign absent); on-disk key is `'koel_session.t1'` (raw `readAll()`); after `delete('t1')` the foreign key is still readable via a raw `FlutterSecureStorage().read` (proves no `deleteAll`).
  - [x] Wrote to the ≥90% bar (every method, both `load` branches, prefix-filter + foreign-excluded paths). Coverage-gate wiring is Story 6.8. **11 tests, all green.**

- [x] **Task 4 — Barrel, README, gates (AC: 5, 6)**
  - [x] `lib/koel_flutter.dart`: added `export 'src/session_storage/secure_session_storage.dart' show SecureSessionStorage;` under the session-storage banner (extended to name both Hive + secure). Export **only** `SecureSessionStorage`.
  - [x] `packages/koel_flutter/README.md`: added a "Secure persistence" subsection under "Session persistence" — drop-in same-API one-liner + `SecureSessionStorage()` snippet + the per-platform caveat table (iOS/macOS Keychain, Android KeyStore, web WebCrypto/localStorage, Windows DPAPI, Linux libsecret) (AC5/N-11). Updated the stale forward-reference parenthetical.
  - [x] Gates from a clean repo-root CWD: `melos run format:check` (0 changed), `melos run analyze` (11 pkgs clean), `melos run test` (full sweep SUCCESS). No flaky `koel_http`/`koel_test` interference observed.

### Review Findings (code review 2026-06-05)

3-layer adversarial review (Blind Hunter / Edge Case Hunter / Acceptance Auditor). **Adapter is correctness-clean** — the `koel_session.` prefix scheme is provably injective and `substring`-strip is its exact inverse (nested-prefix/dot/unicode ids all round-trip); all 6 ACs SATISFIED, all 8 design decisions CONFORM, gates independently re-verified green. Findings are test-coverage and doc-hardening for asserted guarantees, plus pre-existing carry-outs.

- [x] [Review][Patch] Cross-adapter wire-compat claim is untested — the headline parity promise ("a state saved by one adapter loads in the other", class dartdoc + README) has no test; true by construction today (byte-identical `jsonEncode(state.toJson())`/`ChatState.fromJson`) but rots silently if either adapter's serialization drifts [test/session_storage/secure_session_storage_test.dart] — **fixed:** added a "cross-adapter wire-compat (D1)" group (save emits canonical `jsonEncode(state.toJson())`; load decodes a canonically-seeded value).
- [x] [Review][Patch] No explicit `save→delete→load==null` contract test — the delete-clears-load guarantee is only asserted incidentally inside the AC4 namespace-isolation test; add a first-class case to the AC2 group so it isn't hostage to the AC4 test [test/session_storage/secure_session_storage_test.dart] — **fixed:** added to the AC2 group.
- [x] [Review][Patch] Overwrite-then-`listThreads` no-duplicate is untested — `last-write-wins` proves the value is replaced but not that `listThreads` returns `['t1']` with no dup; one-liner guards a future `listThreads` rewrite [test/session_storage/secure_session_storage_test.dart] — **fixed:** added to the AC2 group.
- [x] [Review][Patch] Boundary round-trips untested — empty threadId (`save('')` → key exactly `koel_session.`, enumerates as `''`) and nested-prefix threadId (`'koel_session.x'`); the nested-prefix case is the highest-value injectivity-regression guard (catches a future maintainer rewriting the strip as `split('.')`) [test/session_storage/secure_session_storage_test.dart] — **fixed:** added a "threadId boundaries (prefix injectivity)" group with both cases.
- [x] [Review][Patch] Reserved-prefix consumer constraint is asserted but not stated — "reserved `koel_session.` prefix" is claimed, but nothing tells the consumer *"do not write your own keys under it"*; a co-resident foreign key literally named `koel_session.*` would (by design) be enumerated/deletable as a koel thread. One dartdoc/README sentence [secure_session_storage.dart:44-46 / README.md] — **fixed:** `_keyPrefix` dartdoc + README now state the consumer-side reservation.
- [x] [Review][Defer] Codec schema/version marker — `ChatState.toJson` evolution will fail `fromJson` on entries that survive an app upgrade (Keychain entries can outlive uninstall on older iOS); cross-adapter (applies to Hive too), ties into the deferred `load()` decode-hardening seam [cross-adapter] — deferred, cross-adapter decision (D7 family)
- [x] [Review][Defer] Cross-instance options-mismatch device footgun — a state saved under default `const FlutterSecureStorage()` options is only readable under the same option-set (Keychain `accessGroup` / `AndroidOptions` partition keys); invisible in the mock; design per D5 (consumer owns options) [secure_session_storage.dart dartdoc] — deferred, doc-only device hazard
- [x] [Review][Defer] README "Requires Flutter 3.35.0+" is stale vs `pubspec.yaml` `flutter: ">=3.38.0"` [README.md:16] — deferred, pre-existing (outside the 6.4-edited region)

**Dismissed (4, noise/false-positive/by-design):** `load()` throws on corrupt JSON → intentional D7, already documented in the class dartdoc ("decode failures surface … not wrapped in KoelError"); concurrency atomicity → `SessionStorage` makes no atomicity promise, parity with Hive/InMemory single-await; "broken README table / unfinished pubspec comment" → **false positive** (Blind Hunter saw a redacted diff; the actual README table has all 5 platform rows and the pubspec comment is complete); "F-D1 vs FR-D1" → intentional parity with the Hive sibling's tag.

## Dev Notes

### Design decisions (locked — implement as stated)

- **D1 — Reuse the `koel_core` v1.0.0 JSON codec; store `jsonEncode(state.toJson())`. No new serialization.** Story 6.3 added `toJson`/`fromJson` to `ChatState`+`ToolCall` and pinned the JSON wire-shape as the v1.0.0 persistence contract (its AC6 golden, [chat_state.dart:35](../../packages/koel_core/lib/src/state/chat_state.dart#L35) home). `SecureSessionStorage` stores **the same string** Hive stores — `jsonEncode(state.toJson())` — and decodes via `ChatState.fromJson`. **Do not** touch `koel_core`, **do not** invent a secure-only shape: the two adapters must be wire-compatible (a state saved by one is loadable by the other modulo the store) and both ride the single pinned golden. This is straight parity, not a new decision.

- **D2 — `flutter_secure_storage ^10.3.1`, the canonical maintained package.** 160/160 pub points, publisher `steenbakker.dev`, BSD-3, ~2.7M downloads — the de-facto standard, same source-evidence discipline that picked `hive_ce` (6.3 D5) and the lint pivot ([[project_lint_pivot_analysis_server_plugin]]). v10's default constructor is `const`, so the A.6 default is `const FlutterSecureStorage()`. Runtime API only: `write` / `read` / `readAll` / `delete` (all named-param `key:`/`value:`). **Never `deleteAll`** (D4).

- **D3 — Namespaced key prefix, NOT a separate index entry — this resolves the epic's "index entry."** `flutter_secure_storage` is a **flat, single-namespace** key→value store with no Hive-style per-box keyspace, and the consumer **injects** the `FlutterSecureStorage` (A.6) — so it may be the same instance holding their app's auth tokens and other secrets. koel therefore prefixes every key (`'koel_session.$threadId'`) and derives `listThreads()` from `readAll()` filtered to that prefix (stripped). This is the faithful parallel to Hive's "the box's keyspace **is** the index" (6.3 D5/D8) and is **strictly safer than a literal index key**:
  - **Crash-consistent:** one `write` per `save`, one `delete` per `delete` — there is no second index entry to keep in sync, so a crash mid-`save` can never desync content from index (a separate index needs read-modify-write: content-then-index leaves a ghost or an orphan on a crash between them).
  - **Race-free:** concurrent `save`s to different threads touch different keys with no shared mutable index → no lost-update race (a JSON-array index would race on read-modify-write).
  - **Namespace-isolated:** filtering by prefix guarantees `listThreads()` never leaks the consumer's other secrets and `delete` never removes them.
  The epic's phrase "removes both the thread's content and the index entry" ([epic-6:94](../planning-artifacts/epics/epic-6-flutter-glue-persistence-koelflutter.md#L94)) describes the **observable behavior** (after `delete`, `listThreads` no longer returns the thread and `read` returns `null`) — exactly what the single prefixed-key delete delivers. Decided here per [[project_parity_decides_ambiguous_api]] + source evidence; no question bounced upstream.

- **D4 — Never call `deleteAll()`.** The injected store may be app-shared; `deleteAll()` wipes **every** secret in it, not just koel's. `delete` is always a single prefixed-key removal, and there is no "clear all sessions" method on the A.6 surface (and inventing one would be a one-way-door surface expansion with no AC — A.6-exact discipline). Guardrail, asserted indirectly by the AC4 foreign-key-survives test.

- **D5 — Injected collaborator, const default; platform setup is the consumer's.** A.6 pins `SecureSessionStorage({FlutterSecureStorage? storage})`; default to `const FlutterSecureStorage()`. Unlike Hive there is **no open/init step koel performs** — `flutter_secure_storage` needs no `Hive.init`-equivalent from koel's side; what it needs is *platform* setup (iOS/macOS Keychain entitlement, Linux keyring, Windows VC++ deps, Android min-API/backup config), which is the **consumer's** responsibility and is documented (AC5), exactly mirroring 6.3's "consumer bootstraps Hive" (its D7) and 6.1/6.2's "injected collaborator ⇒ caller owns the cross-cutting lifecycle."

- **D6 — Partial in-progress message is structural — no `isComplete` field (parity with 6.3 D4).** koel encodes completion structurally: a committed turn lives in `messages`, the interrupted turn lives in `pendingMessage`. Persisting `pendingMessage != null` *is* the FR-D1 "incomplete" marker. `SecureSessionStorage` inherits this for free through the shared codec (D1) — there is nothing adapter-specific to do beyond round-tripping the state. Do **not** add any `isComplete` flag.

- **D7 — `load` is faithful-parity with Hive; decode-hardening stays deferred.** [deferred-work.md:7](deferred-work.md) lists a `load()` decode-hardening seam (corrupt/legacy/foreign JSON throws out of `load` rather than returning `null`) and names *"the Story 6.4 sibling pass"* as a **candidate** home. **Decision: do not take it in 6.4.** The catch-and-drop-vs-throw call is a **cross-adapter** contract decision — `SessionStorage` surfaces decode/I-O failures and returns `null` only for *absence* ([session_storage.dart:12-15](../../packages/koel_core/lib/src/session/session_storage.dart#L12)), and `Message` deliberately avoids speculative parsing. Hardening `SecureSessionStorage.load` **alone** would silently diverge the two adapters' failure semantics — a worse outcome than the deferred state. `SecureSessionStorage.load` therefore behaves **exactly** like `HiveSessionStorage.load`: absence → `null`, decode/I-O error → surfaces. The deferred item remains, to be taken (if ever) for *both* adapters in one reviewed pass.

- **D8 — Test via `FlutterSecureStorage.setMockInitialValues`, not a hand-rolled fake.** flutter_secure_storage ships `static void setMockInitialValues(Map<String, String>)` (registers an in-memory mock platform); with `TestWidgetsFlutterBinding.ensureInitialized()` a real `FlutterSecureStorage()` routes to it. This exercises koel's real prefix/filter/strip logic against a real `readAll`/`write`/`read`/`delete` surface — deterministically, with no platform channel and no `flutter drive`. Prefer it over subclassing `FlutterSecureStorage` (a concrete plugin class) or implementing the platform interface. **Live six-platform behavior** (AC5's caveats) is verified by Story 6.7's CI matrix; 6.4 proves the *logic* and *documents* the platform caveats.

### `SessionStorage` contract (the interface to satisfy — already in koel_core, do not modify)

`abstract class SessionStorage` ([session_storage.dart:18-35](../../packages/koel_core/lib/src/session/session_storage.dart#L18), barrel-exported):

```dart
abstract class SessionStorage {
  Future<void> save(String threadId, ChatState state);   // last-write-wins per thread
  Future<ChatState?> load(String threadId);              // null on missing, never throws on absence
  Future<void> delete(String threadId);                  // idempotent — absent thread completes normally
  Future<List<String>> listThreads();                    // fresh snapshot, caller owns it, no ordering guarantee
}
```

The reference impls are `InMemorySessionStorage` ([in_memory_session_storage.dart](../../packages/koel_core/lib/src/session/in_memory_session_storage.dart)) and the just-shipped `HiveSessionStorage` ([hive_session_storage.dart](../../packages/koel_flutter/lib/src/session_storage/hive_session_storage.dart)) — match their behavior exactly. I/O failures surface by completing the future with an error; `SessionStorage` does **not** wrap them in `KoelError` (persistence is below the classifier seam). Absence is **not** an error.

### `HiveSessionStorage` — the sibling to mirror (read it)

[hive_session_storage.dart](../../packages/koel_flutter/lib/src/session_storage/hive_session_storage.dart) is the structural template: same `implements SessionStorage`, same `jsonEncode(state.toJson())` / `ChatState.fromJson(jsonDecode(...))` codec, same four-method contract, same dartdoc voice. The **only** real differences in `SecureSessionStorage`:
1. backing store is `flutter_secure_storage` (encrypted-at-rest) instead of a `hive_ce` box;
2. no lazy box-open (D5 — secure storage needs no koel-side init), so no `late final Future<Box>` machinery — methods call `_storage` directly;
3. enumeration is `readAll()` + prefix-filter (D3) instead of `box.keys` (Hive's box gives a clean keyspace for free; the flat secure store does not).

### `ChatState` shape (what is persisted)

Unchanged from 6.3 — the 7-field freezed `ChatState` ([chat_state.dart:18-33](../../packages/koel_core/lib/src/state/chat_state.dart#L18)) with `error` excluded from the codec and `reasoningEcho` base64-encoded. `RunPhase` values: `idle`, `running`, `stepRunning`, `error`, `cancelled`. You persist the JSON; you do not re-derive any of this.

### Project Structure Notes

- New file: `packages/koel_flutter/lib/src/session_storage/secure_session_storage.dart` — lands **beside** `hive_session_storage.dart`, matching the architecture source tree exactly ([architecture.md:900-902](../planning-artifacts/architecture.md#L900) — `secure_session_storage.dart    # flutter_secure_storage backed`).
- New test: `packages/koel_flutter/test/session_storage/secure_session_storage_test.dart` (beside the Hive test).
- Modified: `packages/koel_flutter/lib/koel_flutter.dart` (barrel), `packages/koel_flutter/pubspec.yaml` (`flutter_secure_storage`), `packages/koel_flutter/README.md` (Secure persistence subsection + caveat table), `pubspec.lock` (`flutter_secure_storage` subtree only).
- This is the **fourth** symbol in `koel_flutter` (after `KoelChatController`, `KoelClientScope`, `HiveSessionStorage`) and is **single-package** — no `koel_core` change, no codegen (koel_flutter has no `build_runner`).

### Carry-ins from Story 6.3 / 6.2 / 6.1 / Epic-5 retro

- **AI-5.9 (freezed `3.2.6-dev.1` / analyzer `12.1.0` pin watch)** — Task 1 adds a `koel_flutter` dependency; after `melos bootstrap` confirm `pubspec.lock` did **not** bump those pins. Do not bump.
- **Deferred `load()` decode-hardening** ([deferred-work.md:7](deferred-work.md)) — explicitly **out of 6.4 scope** per D7 (cross-adapter decision; Secure-only hardening would diverge the adapters). Leave the deferred item in place.
- **A.6-exact surface discipline** (6.1 dropped `tools`; 6.2 omitted `maybeOf`; 6.3 added no `open` factory) — same here: `SecureSessionStorage` exposes only the A.6 constructor + the four `SessionStorage` members. No `clearAll`, no config knobs.
- **House pattern — injected collaborator ⇒ caller owns cross-cutting lifecycle** (6.1 D1, 6.2 D1, 6.3 D7, here D5): koel uses the secure store but the consumer owns platform setup (entitlements/keyring/build-deps).
- **Flutter test-harness routing** — `tool/test_package.sh` already routes `koel_flutter` → `flutter test` (landed in 6.1). `setMockInitialValues` needs the `flutter_test` binding, which that routing provides. No harness change.

### References

- [Source: epics/epic-6-flutter-glue-persistence-koelflutter.md#Story-6.4] (lines 78-99) — user story + the three BDD ACs (surface, multi-thread round-trip + delete/listThreads, per-platform caveat docs).
- [Source: prds/prd-koel-2026-05-27/addendum.md#A.6] (lines 413-415) — canonical `SecureSessionStorage({FlutterSecureStorage? storage})`.
- [Source: packages/koel_core/lib/src/session/session_storage.dart] (lines 18-35) — the interface contract (null-on-missing, idempotent delete, snapshot listThreads, below the classifier seam).
- [Source: packages/koel_core/lib/src/session/in_memory_session_storage.dart] — reference behavioral spec.
- [Source: packages/koel_flutter/lib/src/session_storage/hive_session_storage.dart] — the sibling adapter to mirror (codec, contract, dartdoc voice).
- [Source: packages/koel_flutter/test/session_storage/hive_session_storage_test.dart] — test idiom to mirror (`_user`/`_assistant` helpers, contract + partial-message + isolation suites).
- [Source: _bmad-output/implementation-artifacts/6-3-hive-session-storage.md] — sibling story; D5 (hive_ce choice), D7 (consumer bootstraps), D8 (JSON wire-shape contract), A.6-exact discipline.
- [Source: _bmad-output/implementation-artifacts/deferred-work.md] (line 7) — the `load()` decode-hardening seam named for a "6.4 sibling pass"; D7 here decides to leave it deferred.
- [Source: architecture.md#L900-902] — source-tree placement of `secure_session_storage.dart`.
- [Source: architecture.md#L1087] — "Session storage → Hive / flutter_secure_storage / in-memory (consumer-pluggable)".
- [Source: architecture.md#L1183] — N-11 "six platforms … documented per-platform caveats".
- `flutter_secure_storage` 10.3.1 (pub.dev, publisher `steenbakker.dev`, 160/160 pub points) — the maintained canonical secure-storage plugin (basis for D2); `static setMockInitialValues(Map<String,String>)` is the documented unit-test mock (D8); `readAll() → Future<Map<String,String>>`; default constructor is `const`.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8[1m] (Claude Opus 4.8, 1M context)

### Debug Log References

- **AI-5.9 pin verification** — captured `pubspec.lock` git diff after `melos bootstrap`: `analyzer`/`freezed` lines were not touched (`git diff pubspec.lock | grep -E '(analyzer|freezed)'` → empty); resolved versions still `analyzer 12.1.0` / `freezed 3.2.6-dev.1`. Lock added only the `flutter_secure_storage*` subtree + its transitives (ffi, jni, path_provider, objective_c, code_assets, …).
- **API source-verification (framework-first)** — read `package:flutter_secure_storage/flutter_secure_storage.dart` before coding: confirmed `const FlutterSecureStorage({…})` (all-default options, so the A.6 `const` default holds), `write/read/delete/readAll` are named-param, `delete` of an absent key is a documented no-op (idempotent), and `setMockInitialValues(Map<String,String>)` swaps in `TestFlutterSecureStoragePlatform` (a plain in-memory map) — confirming D8's mock is deterministic and that `readAll` reflects koel's writes.
- **format:check** initially flagged the new test file; `dart format` re-wrapped long `test(...)`/`group(...)` headers. Re-ran → 0 changed.

### Completion Notes List

- Implemented `SecureSessionStorage implements SessionStorage` in `koel_flutter` — the encrypted-at-rest sibling of `HiveSessionStorage`, A.6-exact surface (`SecureSessionStorage({FlutterSecureStorage? storage})` + the four `SessionStorage` members; nothing else public).
- **D1** — reuses the koel_core v1.0.0 JSON codec unchanged: stores `jsonEncode(state.toJson())`, decodes via `ChatState.fromJson`. No koel_core change, no secure-only shape — wire-compatible with Hive.
- **D3** — resolved the epic's "index entry" as a reserved key prefix `koel_session.`; `listThreads()` is `readAll()` filtered to the prefix (stripped). Crash-consistent (one write/delete per op, no second index to desync), race-free (no shared mutable index), namespace-isolated (a co-resident foreign key is never enumerated or deleted).
- **D4** — `deleteAll()` is never called; `delete` is a single prefixed-key removal. Asserted indirectly by the AC4 foreign-key-survives test.
- **D5** — injected collaborator, `const FlutterSecureStorage()` default; koel performs no init. Platform setup (Keychain entitlement / KeyStore / DPAPI / libsecret) is the consumer's, documented in README per N-11.
- **D6/D7** — partial in-progress message is the structural `pendingMessage != null` (inherited via the shared codec, no `isComplete`); `load` is faithful-parity with Hive (absence→null, decode/I-O errors surface), the deferred cross-adapter decode-hardening left in place.
- **D8** — tests via `FlutterSecureStorage.setMockInitialValues` + `TestWidgetsFlutterBinding.ensureInitialized()`; 11 tests (contract ×7, partial-message ×1, namespace-isolation ×3), all green. Live six-platform verification is Story 6.7; coverage gate is Story 6.8 — neither wired here.
- **Gates** (clean repo-root CWD): `format:check` 0 changed, `analyze` SUCCESS across 11 pkgs (all "No issues found!"), full `test` sweep SUCCESS. AI-5.9 pins held.

### File List

- `packages/koel_flutter/lib/src/session_storage/secure_session_storage.dart` (new) — the adapter.
- `packages/koel_flutter/test/session_storage/secure_session_storage_test.dart` (new) — 11 tests.
- `packages/koel_flutter/lib/koel_flutter.dart` (modified) — barrel: `show SecureSessionStorage`; banner extended to name both adapters.
- `packages/koel_flutter/pubspec.yaml` (modified) — `flutter_secure_storage: ^10.3.1` + house-style comment.
- `packages/koel_flutter/README.md` (modified) — "Secure persistence" subsection + per-platform caveat table; stale forward-reference updated.
- `pubspec.lock` (modified) — `flutter_secure_storage` subtree only (AI-5.9 pins unchanged).
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified) — 6-4 ready-for-dev → in-progress → review.

## Change Log

- 2026-06-05 — Story 6.4 implemented → **review**. `SecureSessionStorage implements SessionStorage` in `koel_flutter` over `flutter_secure_storage ^10.3.1`: reuses the koel_core v1.0.0 JSON codec unchanged (D1, no core change), reserved `koel_session.` key prefix resolving the epic's "index entry" (D3, crash-consistent/race-free/namespace-isolated), `deleteAll` never called (D4), const-default injected store (D5), structural partial-message marker (D6), `load` faithful-parity with Hive and deferred decode-hardening left in place (D7), deterministic `setMockInitialValues` tests (D8). +11 tests (koel_flutter 29→40); barrel `show SecureSessionStorage`; README "Secure persistence" subsection + per-platform caveat table (N-11). Gates green: format:check 0-changed, analyze 11 pkgs clean, full test sweep SUCCESS; AI-5.9 pins (analyzer 12.1.0 / freezed 3.2.6-dev.1) held.
- 2026-06-05 — Story 6.4 `SecureSessionStorage` created (ready-for-dev). Single-package (`koel_flutter`), encrypted-at-rest sibling of 6.3's `HiveSessionStorage`: same `koel_core` v1.0.0 JSON codec (D1, no core change), `flutter_secure_storage ^10.3.1` (D2, canonical/maintained). Resolved the epic's "index entry" as a **namespaced key prefix** (D3) — crash-consistent + namespace-isolated over a flat, possibly app-shared secure store, strictly safer than a literal index key; `deleteAll` forbidden (D4). Const-default injected store, platform setup is the consumer's (D5); structural partial-message marker (D6, parity); `load` faithful-parity with Hive and the deferred decode-hardening kept cross-adapter/out-of-scope (D7); deterministic tests via `setMockInitialValues` (D8). Live six-platform verification → 6.7; coverage gate → 6.8.
