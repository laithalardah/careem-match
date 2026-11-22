"""Runtime settings. Read from the environment at call time so tests can change them."""
import os
from pathlib import Path

from dotenv import load_dotenv

load_dotenv(Path(__file__).resolve().parent.parent / ".env")


def flag(name: str, default: str = "0") -> bool:
    return os.getenv(name, default) == "1"


def number(name: str, default: float) -> float:
    try:
        return float(os.getenv(name, default))
    except ValueError:
        return float(default)


def fallback_mode() -> bool:
    """FALLBACK=1: serve everything from cached files, no MCP calls."""
    return flag("FALLBACK")


def demo_enabled() -> bool:
    """DEMO=1: allow demo friends (bots)."""
    return flag("DEMO")


def sandbox_mcp() -> bool:
    """True when MCP_URL points at the local sandbox (it answers with fixed test data, not our items)."""
    from urllib.parse import urlparse

    host = urlparse(os.getenv("MCP_URL", "http://127.0.0.1:8787/mcp")).hostname or ""
    return host in ("127.0.0.1", "localhost", "::1")


def public_app_url() -> str:
    return os.getenv("PUBLIC_APP_URL", "http://localhost:8080").rstrip("/")


def agent_mode() -> str:
    """'bedrock' (default) or 'planner' (deterministic only, no LLM)."""
    return os.getenv("AGENT_MODE", "bedrock")


def consensus_threshold() -> float:
    return number("CONSENSUS_THRESHOLD", 0.6)


def dispute_min_swipes() -> int:
    return int(number("DISPUTE_MIN_SWIPES", 5))


def wheel_duration_ms() -> int:
    return int(number("WHEEL_DURATION_MS", 5000))


def wheel_reveal_pause_ms() -> int:
    return int(number("WHEEL_REVEAL_PAUSE_MS", 2000))


def bot_delay_range() -> tuple[float, float]:
    return number("BOT_MIN_DELAY", 1.5), number("BOT_MAX_DELAY", 4.0)
