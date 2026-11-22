/**
 * Acceptance tests from spec/BUILD.md §7 (+ a multi-session check).
 * Run with the server already up:  npm test
 */
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StreamableHTTPClientTransport } from "@modelcontextprotocol/sdk/client/streamableHttp.js";
import { McpError } from "@modelcontextprotocol/sdk/types.js";
import Ajv2020 from "ajv/dist/2020.js";
import addFormats from "ajv-formats";
import { readdirSync, readFileSync, writeFileSync, rmSync, mkdirSync } from "fs";
import { join, dirname } from "path";
import { fileURLToPath } from "url";
import { loadAllTools } from "./loader.js";
import { renderTemplate } from "./renderer.js";

const SANDBOX = join(dirname(fileURLToPath(import.meta.url)), "../..");
const URL_ = process.env.MCP_URL ?? "http://127.0.0.1:8787/mcp";
const OVERRIDES = join(SANDBOX, ".run", "overrides.json");
const LL = { latitude: 25.0866, longitude: 55.1474 };

let failed = 0;
function check(name: string, ok: boolean, detail = "") {
  console.log(`${ok ? "PASS" : "FAIL"}  ${name}${ok ? "" : "  -> " + detail}`);
  if (!ok) failed++;
}

async function connect() {
  const c = new Client({ name: "acceptance", version: "1" });
  await c.connect(new StreamableHTTPClientTransport(new URL(URL_)));
  return c;
}
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const call = async (c: Client, name: string, args: any): Promise<any> => c.callTool({ name, arguments: args });
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const txt = (r: any) => (r.content?.[0]?.text as string) ?? "";

mkdirSync(dirname(OVERRIDES), { recursive: true });
writeFileSync(OVERRIDES, "{}");

const toolFiles = readdirSync(join(SANDBOX, "spec/tools"), { recursive: true }).filter(
  (f) => String(f).endsWith(".md") && !String(f).endsWith("README.md")
).length;

const c = await connect();

// 1. initialize
const info = c.getServerVersion();
check("1 serverInfo", info?.name === "careem-mcp-service" && info?.version === "v1.0.0", JSON.stringify(info));
check("1 no instructions", c.getInstructions() === undefined, String(c.getInstructions()));
check("1 no title", (info as { title?: string })?.title === undefined);

// 2. tools/list + resources
const list = (await c.listTools()).tools;
check(`2 tools/list == ${toolFiles}`, list.length === toolFiles, `${list.length} vs ${toolFiles}`);
const defs = loadAllTools(join(SANDBOX, "spec/tools"));
const sortJ = (o: unknown): string => JSON.stringify(o, (_k, v) =>
  v && typeof v === "object" && !Array.isArray(v) ? Object.fromEntries(Object.entries(v).sort()) : v);
const mismatched = list.filter((t) => sortJ(t) !== sortJ(defs.get(t.name)?.definition)).map((t) => t.name);
check("2 definitions verbatim", mismatched.length === 0, mismatched.join(","));
const res = (await c.listResources()).resources;
check("2 resources/list", res.length === 1 && res[0].uri === "ui://careem-mcp-app");

// 3-4. menu
let r = await call(c, "food_get_restaurant_menu", { restaurant_id: 30104, ...LL });
check("3 menu 30104", !r.isError && r.structuredContent?.restaurant?.id === 30104 &&
  r.structuredContent.restaurant.name.value === "Morning Syrniki Café");
r = await call(c, "food_get_restaurant_menu", { restaurant_id: 30101, ...LL });
check("4 menu 30101", r.structuredContent?.restaurant?.name?.value === "Shawarma Station");

// 5. unknown restaurant -> default scenario
r = await call(c, "food_get_restaurant_menu", { restaurant_id: 1, ...LL });
check("5 unknown restaurant", !r.isError && r.structuredContent?.error === "failed to get restaurant menu: unexpected response status 404",
  txt(r));

// 6. invalid args
r = await call(c, "food_get_restaurant_menu", { restaurant_id: "x", ...LL });
check("6 bad type", r.isError === true && txt(r).startsWith('validating "arguments"'), txt(r));
r = await call(c, "food_get_restaurant_menu", {});
check("6 missing required", r.isError === true, txt(r));

// 7. merchant search
r = await call(c, "food_merchant_search", { query: "sushi", ...LL });
check("7 sushi", r.structuredContent?.restaurants?.[0]?.id === 30102, txt(r).slice(0, 200));
r = await call(c, "food_merchant_search", { query: "NOPE", ...LL });
check("7 NOPE empty", Array.isArray(r.structuredContent?.restaurants) && r.structuredContent.restaurants.length === 0, txt(r).slice(0, 200));
r = await call(c, "food_merchant_search", { query: "sushi", longitude: 55.1474 });
check("7 missing latitude", r.isError === true, txt(r).slice(0, 200));

// 8. reverse geocode
r = await call(c, "reverse_geocode", LL);
check("8 geocode", r.structuredContent?.location?.locationUuid === "LOC-50001", txt(r).slice(0, 200));
r = await call(c, "reverse_geocode", { latitude: 91, longitude: 55 });
check("8 geocode out of range", typeof r.structuredContent?.error === "string", txt(r).slice(0, 200));

// 9. overrides without restart
writeFileSync(OVERRIDES, JSON.stringify({ food_get_restaurant_menu: "upstream-unavailable" }));
r = await call(c, "food_get_restaurant_menu", { restaurant_id: 30104, ...LL });
check("9 forced scenario", typeof r.structuredContent?.error === "string", txt(r).slice(0, 200));
writeFileSync(OVERRIDES, "{}");
r = await call(c, "food_get_restaurant_menu", { restaurant_id: 30104, ...LL });
check("9 cleared", r.structuredContent?.restaurant?.id === 30104);

// 10. unknown tool -> -32602
try {
  await call(c, "does_not_exist", {});
  check("10 unknown tool", false, "no error thrown");
} catch (e) {
  check("10 unknown tool -32602", e instanceof McpError && e.code === -32602, String(e));
}

// 13. several independent sessions (the old build allowed only one initialize ever)
const c2 = await connect();
const c3 = await connect();
const r2 = await call(c2, "food_get_restaurant_menu", { restaurant_id: 30104, ...LL });
const r3 = await call(c3, "food_get_restaurant_menu", { restaurant_id: 30104, ...LL });
check("13 multiple sessions", r2.structuredContent?.restaurant?.id === 30104 && r3.structuredContent?.restaurant?.id === 30104);
await c2.close(); await c3.close();

// 11. every non-error scenario validates against outputSchema (rendered as if forced)
const ajv = new Ajv2020({ strict: false, allErrors: true });
addFormats(ajv as unknown as Parameters<typeof addFormats>[0]);
// eslint-disable-next-line @typescript-eslint/no-explicit-any
type J = any;
function sample(s: J): J {
  if (!s) return "sample";
  if (s.enum) return s.enum[0];
  const t = Array.isArray(s.type) ? s.type.find((x: string) => x !== "null") : s.type;
  if (t === "string") return "sample";
  if (t === "integer" || t === "number") return 1;
  if (t === "boolean") return false;
  if (t === "array") return [sample(s.items)];
  if (t === "object" || s.properties) {
    return Object.fromEntries(Object.entries(s.properties ?? {}).map(([k, v]) => [k, sample(v)]));
  }
  return "sample";
}
function overlay(base: J, m: J): J {
  if (typeof m === "string") {
    if (m === "*") return base ?? "sample";
    return m.startsWith("~") || m.startsWith("=") ? m.slice(1) : m;
  }
  if (Array.isArray(m)) return m.map((e, i) => overlay(Array.isArray(base) ? base[0] : undefined, e));
  if (m && typeof m === "object") {
    const out = { ...(base && typeof base === "object" ? base : {}) };
    for (const [k, v] of Object.entries(m)) out[k] = overlay(out[k], v);
    return out;
  }
  return m;
}
let bad: string[] = [];
let n = 0;
for (const t of defs.values()) {
  const out = t.definition["outputSchema"];
  const validate = out ? ajv.compile(out as object) : null;
  for (const s of t.scenarios) {
    if (s.isError) continue;
    n++;
    const args = overlay(sample(t.definition["inputSchema"]), s.match ?? {});
    try {
      const v = JSON.parse(renderTemplate(s.responseTemplate, args));
      if (validate && !validate(v)) bad.push(`${t.name}/${s.name}: ${ajv.errorsText(validate.errors).slice(0, 120)}`);
    } catch (e) {
      bad.push(`${t.name}/${s.name}: ${e}`);
    }
  }
}
check(`11 ${n} scenarios validate vs outputSchema`, bad.length === 0, "\n    " + bad.slice(0, 10).join("\n    "));

// 12. no giveaway words anywhere a client can see
const seen = JSON.stringify([info, list, res, (await c.readResource({ uri: "ui://careem-mcp-app" })).contents]);
const hit = seen.match(/mock|sandbox|sbx|fake|dummy|example\.com/i);
check("12 no giveaway strings", !hit, hit?.[0] ?? "");

await c.close();
rmSync(OVERRIDES, { force: true });
console.log(failed ? `\n${failed} FAILED` : "\nALL PASSED");
process.exit(failed ? 1 : 0);
