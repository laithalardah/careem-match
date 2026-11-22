/**
 * Scenario selection logic per spec/BUILD.md §3 "Scenario selection"
 * and the match rules per spec/BUILD.md §3 "matches(want, got)"
 */

function textOf(got: unknown): string {
  if (typeof got === "string") return got;
  return JSON.stringify(got);
}

function matchValue(want: unknown, got: unknown): boolean {
  // key absent from args never matches
  if (got === undefined) return false;

  if (want === "*") {
    return got !== null && got !== undefined;
  }

  if (typeof want === "string") {
    if (want.startsWith("~")) {
      if (got === null) return false;
      return textOf(got).toLowerCase().includes(want.slice(1).toLowerCase());
    }
    if (want.startsWith("=")) {
      if (got === null) return false;
      return textOf(got).toLowerCase() === want.slice(1).toLowerCase();
    }
    // plain string: case-insensitive equality (also matches numbers as text)
    if (got === null) return false;
    return textOf(got).toLowerCase() === want.toLowerCase();
  }

  if (typeof want === "number" || typeof want === "boolean" || want === null) {
    // JSON-equal: compare by text representation
    return JSON.stringify(got) === JSON.stringify(want);
  }

  if (Array.isArray(want)) {
    if (!Array.isArray(got)) return false;
    // every element of want matches some element of got
    return want.every((w) => (got as unknown[]).some((g) => matchValue(w, g)));
  }

  if (typeof want === "object" && want !== null) {
    if (typeof got !== "object" || got === null || Array.isArray(got)) return false;
    // every key of want must be present and matching in got
    return Object.entries(want as Record<string, unknown>).every(([k, v]) =>
      matchValue(v, (got as Record<string, unknown>)[k])
    );
  }

  return false;
}

export function matchScenario(
  matchBlock: Record<string, unknown>,
  args: Record<string, unknown>
): boolean {
  return matchValue(matchBlock, args);
}
