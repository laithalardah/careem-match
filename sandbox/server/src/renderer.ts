/**
 * Template renderer per spec/BUILD.md §3 "Placeholders"
 * Handles {{args.x.y}}, {{now}}, {{now+2h@20m|date}}, {{uuid}}, {{rand:0-9}}, {{unix}}, etc.
 */

import { randomUUID } from "crypto";

const DUBAI_TZ = "Asia/Dubai";

// Parse duration string like "15m", "2h", "1h30m", "30s", "500ms"
function parseDuration(s: string): number {
  let ms = 0;
  const re = /(\d+)(ms|s|m|h)/g;
  let m: RegExpExecArray | null;
  while ((m = re.exec(s)) !== null) {
    const n = parseInt(m[1]);
    switch (m[2]) {
      case "ms": ms += n; break;
      case "s":  ms += n * 1000; break;
      case "m":  ms += n * 60000; break;
      case "h":  ms += n * 3600000; break;
    }
  }
  return ms;
}

function getWalkValue(args: Record<string, unknown>, path: string): unknown {
  const parts = path.split(".");
  let cur: unknown = args;
  for (const p of parts) {
    if (cur === null || cur === undefined) return null;
    if (Array.isArray(cur)) {
      const idx = parseInt(p);
      cur = isNaN(idx) ? undefined : (cur as unknown[])[idx];
    } else if (typeof cur === "object") {
      cur = (cur as Record<string, unknown>)[p];
    } else {
      return null;
    }
  }
  return cur ?? null;
}

function formatDubaiDate(d: Date, fmt: string): string {
  if (fmt === "date") {
    return d.toLocaleDateString("en-CA", { timeZone: DUBAI_TZ }); // YYYY-MM-DD
  }
  if (fmt === "weekday") {
    return d.toLocaleDateString("en-US", { weekday: "long", timeZone: DUBAI_TZ });
  }
  if (fmt === "hhmm") {
    return d.toLocaleTimeString("en-GB", {
      hour: "2-digit",
      minute: "2-digit",
      hourCycle: "h23",
      timeZone: DUBAI_TZ,
    });
  }
  if (fmt === "daylabel") {
    // "Fri, 9th Oct"
    const weekday = d.toLocaleDateString("en-US", { weekday: "short", timeZone: DUBAI_TZ });
    const day = parseInt(d.toLocaleDateString("en-CA", { day: "numeric", timeZone: DUBAI_TZ }));
    const month = d.toLocaleDateString("en-US", { month: "short", timeZone: DUBAI_TZ });
    const suffix =
      day === 1 || day === 21 || day === 31
        ? "st"
        : day === 2 || day === 22
        ? "nd"
        : day === 3 || day === 23
        ? "rd"
        : "th";
    return `${weekday}, ${day}${suffix} ${month}`;
  }
  return d.toISOString().replace(/\.\d{3}Z$/, "Z");
}

function evalExpr(expr: string, args: Record<string, unknown>): unknown {
  expr = expr.trim();

  // args.x.y.0
  if (expr.startsWith("args.")) {
    return getWalkValue(args, expr.slice(5));
  }

  // uuid
  if (expr === "uuid") return randomUUID();

  // rand:MIN-MAX
  const randM = expr.match(/^rand:(\d+)-(\d+)$/);
  if (randM) {
    const lo = parseInt(randM[1]);
    const hi = parseInt(randM[2]);
    return Math.floor(Math.random() * (hi - lo + 1)) + lo;
  }

  // unix / unixms with optional offset, e.g. unix+30m, unixms-1h30m
  const unixM = expr.match(/^(unixms?)(?:([+-])((?:\d+(?:ms|s|m|h))+))?$/);
  if (unixM) {
    const isMs = unixM[1] === "unixms";
    const offset = unixM[3] ? (unixM[2] === "-" ? -1 : 1) * parseDuration(unixM[3]) : 0;
    const ts = Date.now() + offset;
    return isMs ? ts : Math.floor(ts / 1000);
  }

  // now / now+Xh@Ym|format
  if (expr.startsWith("now") || expr === "now") {
    const nowExpr = expr;
    // Parse: now([+-]duration)?(@roundDur)?(|format)?
    const m = nowExpr.match(
      /^now([+-]\d+(?:ms|s|m|h)+(?:\d+(?:ms|s|m|h)+)*)?(?:@(\d+(?:ms|s|m|h)+))?(?:\|(.+))?$/
    );
    if (!m) throw new Error(`Unknown expression: ${expr}`);

    const now = Date.now();
    let ms = now;

    if (m[1]) {
      const sign = m[1][0] === "+" ? 1 : -1;
      ms += sign * parseDuration(m[1].slice(1));
    }

    if (m[2]) {
      const roundMs = parseDuration(m[2]);
      if (roundMs > 0) ms = Math.floor(ms / roundMs) * roundMs;
    }

    const d = new Date(ms);
    const fmt = m[3];

    if (fmt) {
      return formatDubaiDate(d, fmt);
    }

    // RFC 3339, whole seconds
    return d.toISOString().replace(/\.\d{3}Z$/, "Z");
  }

  throw new Error(`Unknown placeholder expression: ${expr}`);
}

function isInsideString(template: string, placeholderStart: number): boolean {
  // Count unescaped quotes before this position
  let inStr = false;
  let i = 0;
  while (i < placeholderStart) {
    if (template[i] === "\\" && inStr) {
      i += 2;
      continue;
    }
    if (template[i] === '"') inStr = !inStr;
    i++;
  }
  return inStr;
}

function jsonStringEscape(s: string): string {
  return s
    .replace(/\\/g, "\\\\")
    .replace(/"/g, '\\"')
    .replace(/\n/g, "\\n")
    .replace(/\r/g, "\\r")
    .replace(/\t/g, "\\t")
    .replace(/[\x00-\x1f]/g, (c) => "\\u" + c.charCodeAt(0).toString(16).padStart(4, "0"));
}

export function renderTemplate(
  template: string,
  args: Record<string, unknown>
): string {
  // Replace {{expr}} placeholders
  return template.replace(/\{\{\s*([^}]+?)\s*\}\}/g, (full, expr, offset) => {
    const value = evalExpr(expr, args);
    const inside = isInsideString(template, offset);

    if (inside) {
      // insert as text, json-string-escaped
      if (typeof value === "string") return jsonStringEscape(value);
      if (value === null) return "null";
      return jsonStringEscape(JSON.stringify(value));
    } else {
      // insert as bare JSON value
      if (value === null) return "null";
      return JSON.stringify(value);
    }
  });
}
