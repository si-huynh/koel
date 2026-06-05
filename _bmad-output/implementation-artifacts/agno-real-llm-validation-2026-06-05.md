# Evidence — AI-5.6 agno real-LLM validation (local Ollama)

- **Date:** 2026-06-05
- **Action item:** AI-5.6 (Epic-5 retro 2026-06-05) — witness agno's real tool-call/state mapping flow through koel's `AgnoAgent`, using a local LLM instead of the text-only mock. **Exploratory — NOT a deterministic conformance fixture.**
- **Machine:** Mac Studio, Apple **M1 Max**, 32GB unified, 10-core (8P+2E).
- **Status:** ✅ PASS — local LLM drives agno to emit `TOOL_CALL_*` over the real wire.

## Setup (reproducible)

| Piece | Value |
|---|---|
| Runtime | **Ollama 0.20.0** (already installed, `/opt/homebrew/bin/ollama`) — OpenAI-compatible `…/v1`, native tool calling |
| Model | **`qwen2.5:7b`** (Q4, 4.7GB) — strong tool calling, Apache-2.0; ~40-60 tok/s on M1 Max |
| Endpoint | `http://localhost:11434/v1` (host) · `http://host.docker.internal:11434/v1` (from a container) |
| agno env override | `MOCK_LLM_BASE_URL=<ollama>/v1`, `AGNO_MODEL_ID=qwen2.5:7b`, `AGNO_ENABLE_TOOLS=1` |

### Three real constraints found in the harness (why "swap MOCK_LLM_BASE_URL" alone is insufficient)

1. **`shared/mock-llm/app.py` never returns `tool_calls`** — fixed content + `finish_reason=stop` only. This is why agno had only `text_only_run`.
2. **The agno `Agent` registered no tools** — agno only advertises `tools` to the model when the Agent has them. Wired via the new `AGNO_ENABLE_TOOLS=1` flag (a sample `get_weather` tool).
3. **agno runs in Docker** — `localhost` can't reach a host Ollama; use `host.docker.internal` (Docker Desktop for Mac). Also: Docker Desktop's own VM consumes RAM, so size the model ≤~14GB when the container runs alongside host Ollama (7B is comfortable).

## Backend change (`../koel_backend/backends/agno/app.py`)

Made the model id + tool registration env-driven, **backward-compatible**: all three knobs default to the deterministic mock path, so docker/conformance behaviour is byte-identical unless explicitly overridden. `AGNO_MODEL_ID` (default `mock`), `AGNO_ENABLE_TOOLS` (default off → no tools advertised → text-only mock unchanged).

## Result — event sequence over the live `/agno-chat` wire

Driven via `qwen2.5:7b` + `get_weather` tool, "What is the weather in Hanoi? Use the get_weather tool.":

```
RUN_STARTED
TEXT_MESSAGE_START → TEXT_MESSAGE_END        # empty assistant turn before the tool call (real model quirk)
TOOL_CALL_START → TOOL_CALL_ARGS → TOOL_CALL_END
TOOL_CALL_RESULT
TEXT_MESSAGE_START → TEXT_MESSAGE_CONTENT ×N → TEXT_MESSAGE_END   # streamed final answer
RUN_FINISHED
```

Distinct AG-UI types over the wire: `RUN_STARTED, RUN_FINISHED, TEXT_MESSAGE_START/CONTENT/END, TOOL_CALL_START/ARGS/END, TOOL_CALL_RESULT`.

## Findings

1. **agno's real tool-call mapping works end-to-end through `AgnoAgent`'s wire** — `TOOL_CALL_START/ARGS/END/RESULT` appear, the diversity the text-only mock cannot produce. The adapter handles real backend output, not just the synthesized corpus. This is the publish-confidence evidence Si asked for.
2. **Real-model quirk surfaced:** an **empty `TEXT_MESSAGE_START → TEXT_MESSAGE_END` frame before the tool call** (qwen2.5 opens an empty assistant text turn). Worth a defensive check that koel's `AgnoAgent` + content parser tolerate a zero-content text message — an edge the scripted/mock backends never emit.
3. **`TOOL_CALL_RESULT` is emitted by real agno** — a type beyond copilotkit's 7-representable set; confirms the agno passthrough surface is genuinely richer than the GraphQL bridge.

## Reproduce

```bash
ollama serve &                       # or brew service
ollama pull qwen2.5:7b
python3 -m venv /tmp/agno-venv && /tmp/agno-venv/bin/pip install -r backends/agno/requirements.txt
cd backends/agno
MOCK_LLM_BASE_URL=http://localhost:11434/v1 AGNO_MODEL_ID=qwen2.5:7b AGNO_ENABLE_TOOLS=1 \
  /tmp/agno-venv/bin/uvicorn app:app --host 127.0.0.1 --port 8002
# then POST a RunAgentInput to /agno-chat (see this file's history)
```

## Follow-ups (not blocking)

- Pull a richer capture (multi-tool, state scenario) through the koel capture tool's agno branch and store the **exploratory** JSONL separately from `fixtures/` (label `synthesized:false, exploratory:true`), so it never enters the deterministic conformance corpus.
- Add the zero-content `TEXT_MESSAGE` tolerance check to the `AgnoAgent` / Epic-6 content-parser test set (finding #2).
