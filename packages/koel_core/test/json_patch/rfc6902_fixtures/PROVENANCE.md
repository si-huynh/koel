# RFC 6902 conformance fixtures — provenance

Vendored verbatim, not modified. These drive `../rfc6902_conformance_test.dart`.

| Field | Value |
|-------|-------|
| Source repo | <https://github.com/json-patch/json-patch-tests> |
| Files | `tests.json`, `spec_tests.json` |
| Pinned commit | `2a928f9044aad35c74e2788d498bcf2c6b91adea` |
| Retrieved | 2026-05-30 |
| Upstream license | Apache License 2.0 — "Copyright 2014 The Authors" (per the repo `README.md`) |

`tests.json` is the community edge-case corpus; `spec_tests.json` mirrors the
examples in RFC 6902 Appendix A. Apache-2.0 is permissive and compatible with
this package's license; retain this record for the Epic 9 publish-readiness /
brand-license audit.

## Entry schema

```jsonc
{
  "comment": "human label",          // optional
  "doc":      { ... },               // input document
  "patch":    [ { "op": ... }, ... ],// the JSON Patch to apply
  "expected": { ... },               // success: the document after apply
  "error":    "reason",              // OR failure: apply (or parse) must throw
  "disabled": true                   // optional: skip (impl-specific behavior)
}
```

The harness skips `disabled` entries, asserts `expected` entries deep-equal the
`JsonPatch.apply` result, and asserts `error` entries throw `ProtocolError`
(from either `JsonPatchOp.fromJson` or `JsonPatch.apply`).
