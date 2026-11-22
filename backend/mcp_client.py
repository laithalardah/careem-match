"""Careem MCP client (Streamable HTTP). Lookups only by default; mutating tools are flagged."""
import asyncio
import json
import os
import re
import sys

from dotenv import load_dotenv
from mcp import ClientSession
from mcp.client.streamable_http import streamable_http_client

MCP_URL_DEFAULT = "http://127.0.0.1:8787/mcp"

# Fallback name heuristic, used only when the server gives no readOnlyHint annotation.
_MUTATING_RE = re.compile(r"(add|remove|update|delete|clear|checkout|place|create|cancel|set|apply|confirm|pay|submit|reorder|reschedule|save)")


def mcp_url() -> str:
    load_dotenv()
    return os.getenv("MCP_URL", MCP_URL_DEFAULT)


def is_mutating(tool) -> bool:
    # Conservative: mutating if the server says so OR the name looks like a write.
    ann = getattr(tool, "annotations", None)
    hint = getattr(ann, "read_only_hint", None) if ann is not None else None
    return hint is False or bool(_MUTATING_RE.search(tool.name))


async def list_tools(session: ClientSession) -> list[dict]:
    res = await session.list_tools()
    return [
        {
            "name": t.name,
            "description": t.description,
            "input_schema": t.input_schema,
            "mutating": is_mutating(t),
        }
        for t in res.tools
    ]


async def call_tool(session: ClientSession, name: str, args: dict, allow_mutating: bool = False):
    """Call a tool. Mutating tools are refused unless allow_mutating is set explicitly."""
    tools = {t["name"]: t for t in await list_tools(session)}
    if name not in tools:
        raise ValueError(f"unknown tool: {name}")
    if tools[name]["mutating"] and not allow_mutating:
        raise PermissionError(f"{name} is mutating; refusing without explicit approval")
    return await session.call_tool(name, args)


class Careem:
    """async with Careem() as c: await c.list_tools(); await c.call(...)"""

    async def __aenter__(self):
        self._cm = streamable_http_client(mcp_url())
        read, write = await self._cm.__aenter__()
        self._session = ClientSession(read, write)
        await self._session.__aenter__()
        await self._session.initialize()
        return self

    async def __aexit__(self, *exc):
        await self._session.__aexit__(*exc)
        await self._cm.__aexit__(*exc)

    async def list_tools(self):
        return await list_tools(self._session)

    async def call(self, name, args, allow_mutating=False):
        # List the tools once per connection (the mutating guard needs them), not on every call.
        if not hasattr(self, "_tools"):
            self._tools = {t["name"]: t for t in await list_tools(self._session)}
        if name not in self._tools:
            raise ValueError(f"unknown tool: {name}")
        if self._tools[name]["mutating"] and not allow_mutating:
            raise PermissionError(f"{name} is mutating; refusing without explicit approval")
        return await self._session.call_tool(name, args)


async def _main():
    async with Careem() as c:
        tools = await c.list_tools()
        print(f"# {len(tools)} tools at {mcp_url()}\n")
        for t in tools:
            flag = "MUTATING" if t["mutating"] else "read-only"
            print(f"## {t['name']}  [{flag}]")
            print((t["description"] or "").strip()[:300])
            print("input_schema:", json.dumps(t["input_schema"]))
            print()
        if "--menu" in sys.argv:  # read-only lookup, same connection
            args = {"restaurant_id": 30104, "latitude": 31.9539, "longitude": 35.9106}
            r = await c.call("food_get_restaurant_menu", args)
            print("=== food_get_restaurant_menu", args, "isError =", r.is_error)
            print(json.dumps(r.structured_content, indent=2, ensure_ascii=False)
                  if r.structured_content else r.content)


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    asyncio.run(_main())
