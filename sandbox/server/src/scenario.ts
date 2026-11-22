/**
 * Scenario CLI (BUILD.md §6).
 *   npm run scenario -- list [tool]       list scenarios (of a tool, or tools that have more than one)
 *   npm run scenario -- set <tool> <name> force a scenario
 *   npm run scenario -- clear <tool>      remove one override
 *   npm run scenario -- reset             remove all overrides
 *   npm run scenario -- show              print current overrides
 */
import { readFileSync, writeFileSync, mkdirSync, existsSync } from "fs";
import { join, dirname } from "path";
import { fileURLToPath } from "url";
import { loadAllTools } from "./loader.js";

const SANDBOX = join(dirname(fileURLToPath(import.meta.url)), "../..");
const FILE = process.env.OVERRIDES_PATH ?? join(SANDBOX, ".run", "overrides.json");
const tools = loadAllTools(join(process.env.SPEC_DIR ?? join(SANDBOX, "spec"), "tools"));

const read = (): Record<string, string> => {
  try { return existsSync(FILE) ? JSON.parse(readFileSync(FILE, "utf8")) : {}; } catch { return {}; }
};
const write = (o: Record<string, string>) => {
  mkdirSync(dirname(FILE), { recursive: true });
  writeFileSync(FILE, JSON.stringify(o, null, 2));
};
const [cmd, tool, name] = process.argv.slice(2);

function need(t?: string) {
  const d = t ? tools.get(t) : undefined;
  if (!d) { console.error(`unknown tool: ${t}`); process.exit(1); }
  return d;
}

if (cmd === "list") {
  const show = (n: string) => {
    const d = tools.get(n)!;
    console.log(`${n}: ${d.scenarios.map((s) => s.name + (s.match === null ? "*" : "")).join(", ")}   (* = default)`);
  };
  if (tool) { need(tool); show(tool); }
  else for (const n of [...tools.keys()].sort()) if (tools.get(n)!.scenarios.length > 1) show(n);
} else if (cmd === "set") {
  const d = need(tool);
  const s = d.scenarios.find((x) => x.name.toLowerCase() === (name ?? "").toLowerCase());
  if (!s) { console.error(`no scenario '${name}' for ${tool}. Have: ${d.scenarios.map((x) => x.name).join(", ")}`); process.exit(1); }
  write({ ...read(), [tool]: s.name });
  console.log(`forced ${tool} -> ${s.name}`);
} else if (cmd === "clear") {
  need(tool);
  const o = read(); delete o[tool]; write(o);
  console.log(`cleared ${tool}`);
} else if (cmd === "reset") {
  write({});
  console.log("all overrides cleared");
} else if (cmd === "show") {
  console.log(JSON.stringify(read(), null, 2));
} else {
  console.error("usage: list [tool] | set <tool> <scenario> | clear <tool> | reset | show");
  process.exit(1);
}
