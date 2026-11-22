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

## API (exact, Flutter builds against it)
- `POST /session/start {location}` -> `{session_id, dishes:[{id,name,image_url,cuisine}]}`
- `POST /session/{id}/swipe {player:1|2, dish_id, liked}` -> `{ok:true}`
- `POST /session/{id}/run {}` -> `{ok:true}` (agent runs async)
- `GET /session/{id}/result` -> `{status:"ready"|"running"|"failed"|"no_match", restaurant:{id,name,image_url,cuisine,rating}, basket:[{player,dish_name,price,image_url}], total_price, currency, reasoning, agent_trace:[{iteration,tool,input,output_summary}]}`
- `GET /health` -> `{status:"ok"}`
