# Careem Match backend (API v2.1)

FastAPI + Bedrock agent + Careem MCP client. Contract: `../docs/v2-plan.md` section 4.

## Run
```bash
# 1. the Careem sandbox MCP (separate terminal)
cd ../sandbox/server && npm start          # http://127.0.0.1:8787/mcp

# 2. the backend
cd backend
.venv\Scripts\activate
DEMO=1 uvicorn main:app --host 0.0.0.0 --port 8000      # PowerShell: $env:DEMO=1; uvicorn main:app --host 0.0.0.0 --port 8000
```
Settings come from `../.env` (never committed): `AWS_*` keys (expire hourly, refresh with `..\refresh_env.ps1`),
`MCP_URL`, `DEMO=1`, `PUBLIC_APP_URL` (used for join links; use your LAN IP or a tunnel so other devices can open them).
Optional: `FALLBACK=1` (no MCP calls, cached data), `AGENT_MODE=planner` (no Bedrock), `CONSENSUS_THRESHOLD`,
`DISPUTE_MIN_SWIPES`, `WHEEL_DURATION_MS`.

## Try it
```bash
python scripts/demo_room.py --scenario consensus     # everybody agrees
python scripts/demo_room.py --scenario wheel         # dispute settled by the wheel
python scripts/demo_room.py --scenario split --order # dispute split into groups, then the host sends everyone to the restaurants
pytest                                               # 86 tests, offline
```

## Safety
- Swiping chooses the restaurant only. After the match everyone is sent to it in Careem (deep link) to start a normal group order; this backend never orders, never uses a cart, never pays.
- The agent only has read-only tools; its choice is re-validated in code; the planner is the fallback.
- Credentials are re-read from `.env` on every Bedrock call and never logged.

## Refresh cached data
```bash
python catalog.py --refresh     # restaurants + menus -> fallback_catalog.json
python history.py --refresh     # the host's past orders -> fallback_history.json
```
