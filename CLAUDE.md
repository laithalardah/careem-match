# Careem Match (Careem Builders '26 hackathon)

"Tinder for food": two players swipe on real Careem Food dishes; an AI agent finds ONE restaurant
that satisfies both, builds the basket, prices it via the Careem MCP, and presents it. It must be a
real tool-using agent that re-plans when a call fails (dish unavailable, restaurant closed, options
required, no overlap between swipes). Demo 18:00, 3 minutes. Keep changes small and runnable;
commit after each working step.

## Stack
- `/backend`: Python 3.12 + FastAPI. Owns the Bedrock agent and ALL Careem MCP calls. No secrets in the app.
- `/app`: Flutter (UI only), REST to backend, must run on Flutter Web (Chrome).
- Agent: Bedrock Converse API with tool use, model `global.anthropic.claude-sonnet-5-5`, region `us-east-1`
  (only allowed region). Loop capped at 8 iterations (team budget $300).
- MCP client: official Python `mcp` SDK, Streamable HTTP.
- Storage: in-memory dict. Cached fallback data in `fallback.json`, used when `FALLBACK=1`.

## Secrets
- `.env` in repo root; never commit or hardcode secrets.
- AWS credentials are temporary and expire hourly: re-read `.env` every time a Bedrock client is created. Never cache credentials at startup.

## Careem MCP
- Dev target: local sandbox `http://127.0.0.1:8787/mcp` (no auth, test data). Read from env `MCP_URL` (default = sandbox).
- Production (later, do NOT build login unless asked): `https://mcp.careemapis.com/mcp`, OAuth PKCE public client.
- Sandbox test restaurant: Morning Syrniki Cafe, ID 30104. Use real tool names from the server, not guesses.
- The sandbox is Careem's; do not edit it. Force failure scenarios via `.run/overrides.json`.

## Safety rules (also in the agent system prompt)
- Never auto-confirm a mutating tool; ask the user first. Never blindly retry a mutating tool. Retrying lookups is fine.
- Cart tools are OK for sandbox testing; NEVER call checkout or any order-placing tool unless explicitly told.
- Errors are readable messages: explain them and decide whether a retry makes sense.
- Location: Amman, Jordan. Currency: JOD.

## API v2.1 (group rooms)
Single source of truth: **docs/v2-plan.md section 4** (the old two-player API is gone). Rooms have a host and guests;
stages: lobby -> settings -> swiping -> dispute (only if no consensus) -> matching -> result -> ordered.
- Backend lives in `backend/` (FastAPI). Run: `DEMO=1 uvicorn main:app --host 0.0.0.0 --port 8000`. Tests: `pytest`.
  Live demo: `python scripts/demo_room.py --scenario consensus|wheel|split [--order]`.
- Order step: the host's tap is the only approval. Only `cart_add_items` may mutate (allow-list in `order.py`), it is never
  retried automatically, and checkout / order-placing tools are NEVER called.
- Credentials are re-read from `.env` on every Bedrock call (`bedrock_client.py`); refresh them with `refresh_env.ps1`.