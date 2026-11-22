/**
 * Reads .run/overrides.json on every call.
 * A missing or invalid file means "no overrides".
 */

import { readFileSync, existsSync } from "fs";

export function readOverrides(overridesPath: string): Record<string, string> {
  if (!existsSync(overridesPath)) return {};
  try {
    const text = readFileSync(overridesPath, "utf8");
    const obj = JSON.parse(text);
    if (typeof obj === "object" && obj !== null && !Array.isArray(obj)) {
      const out: Record<string, string> = {};
      for (const [k, v] of Object.entries(obj)) if (typeof v === "string") out[k] = v;
      return out;
    }
    return {};
  } catch {
    return {};
  }
}
