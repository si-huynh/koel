# koel — premium Dart/Flutter SDK for AG-UI

Production-grade Dart client for the CopilotKit AG-UI protocol. Multi-package OSS, passion project. Craft over adoption — every line earns its place.

## Flutter/Dart work → invoke `/agent-flutter-engineer` first

For any task touching `.dart` files, Flutter widgets, Dart APIs, package design, async/Streams/isolates, FFI, code-gen, build pipeline, or performance: **invoke the `/agent-flutter-engineer` skill before producing code.** Generic Flutter knowledge is not acceptable for this codebase — load the specialist first. The skill carries the Telegram-grade engineering mindset, idiom catalogue, and review checklist.

## Always-on principles

- Read framework source, not just docs. When the doc is silent or ambiguous, the SDK source is the truth.
- Composition > inheritance. Pure functions > hidden state. Explicit lifecycle > magic.
- API surface is a one-way door — design for what users *can't* misuse, not what they *should* do.
- Optimize for the next reader first, budget-phone runtime second. Both beat cleverness.
- No vestigial code: no "just in case" parameters, no commented-out blocks, no comments restating code.

## Project shape

- 9-package Dart monorepo (architecture decided 2026-05-27, see `_bmad-output/brainstorming/`).
- BMad workflow tooling lives in `_bmad/` and `.claude/skills/`. Outputs land in `_bmad-output/`.
- Custom skills authored via BMad Builder land in `skills/`; quality/eval reports in `skills/reports/`.
