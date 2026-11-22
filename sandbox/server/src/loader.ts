/**
 * Loads all tool files from the spec/tools directory at startup.
 * Re-reads individual files on each call (spec says re-read on every call).
 */

import { readdirSync, statSync } from "fs";
import { join } from "path";
import { parseToolFile, type ToolDefinition } from "./parser.js";

export function loadAllTools(toolsDir: string): Map<string, ToolDefinition> {
  const tools = new Map<string, ToolDefinition>();
  const errors: string[] = [];

  function walk(dir: string) {
    for (const entry of readdirSync(dir)) {
      if (entry === "README.md") continue;
      const full = join(dir, entry);
      const stat = statSync(full);
      if (stat.isDirectory()) {
        walk(full);
      } else if (entry.endsWith(".md")) {
        try {
          const tool = parseToolFile(full);
          if (tools.has(tool.name)) {
            errors.push(`Duplicate tool name: ${tool.name} in ${full}`);
          } else {
            tools.set(tool.name, tool);
          }
        } catch (e) {
          errors.push(String(e));
        }
      }
    }
  }

  walk(toolsDir);

  if (errors.length > 0) {
    throw new Error("Tool loading errors:\n" + errors.join("\n"));
  }

  return tools;
}
