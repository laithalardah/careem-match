/**
 * Local Careem MCP sandbox server. Implements spec/BUILD.md with @modelcontextprotocol/sdk.
 * Streamable HTTP with stateful sessions (one Server+transport per client session), as production.
 */

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  ListResourcesRequestSchema,
  ReadResourceRequestSchema,
  McpError,
  ErrorCode,
  isInitializeRequest,
} from "@modelcontextprotocol/sdk/types.js";
import { createServer, IncomingMessage, ServerResponse } from "http";
import { join, dirname } from "path";
import { fileURLToPath } from "url";
import { randomUUID } from "crypto";
import Ajv2020 from "ajv/dist/2020.js";
import addFormats from "ajv-formats";

import { loadAllTools } from "./loader.js";
import { parseToolFile } from "./parser.js";
import { matchScenario } from "./matcher.js";
import { renderTemplate } from "./renderer.js";
import { readOverrides } from "./overrides.js";

// ── Paths (sandbox/server/src -> sandbox/) ────────────────────────────────────
const __dirname = dirname(fileURLToPath(import.meta.url));
const SANDBOX_DIR = join(__dirname, "../..");
const SPEC_DIR = process.env.SPEC_DIR ?? join(SANDBOX_DIR, "spec");
const TOOLS_DIR = join(SPEC_DIR, "tools");
const OVERRIDES_PATH = process.env.OVERRIDES_PATH ?? join(SANDBOX_DIR, ".run", "overrides.json");

const PORT = parseInt(process.env.PORT ?? "8787");
const HOST = process.env.HOST ?? "127.0.0.1";
const SERVICE_NAME = "careem-mcp-service";
const SERVICE_VERSION = "v1.0.0";

// ── Widget resource (exactly as spec/MCP_SERVER.md "Resources") ───────────────
const WIDGET_RESOURCE = {
  uri: "ui://careem-mcp-app",
  name: "ui://careem-mcp-app",
  description: "Careem Widget",
  mimeType: "text/html;profile=mcp-app",
  _meta: {
    ui: {
      resourceUri: "ui://careem-mcp-app",
      csp: {
        connectDomains: ["https://careem-mcp-app.pages.dev"],
        resourceDomains: [
          "https://careem-mcp-app.pages.dev",
          "https://careem.s3.eu-west-1.amazonaws.com",
          "https://d1a3f4spazzrp4.cloudfront.net",
          "https://careem-catalog-media.media.careem.com",
          "https://partner-mot-prod.media.careem.com",
        ],
        frameDomains: [],
        baseUriDomains: [],
      },
    },
    prefersBorder: false,
    domain: "https://careem-mcp-app.pages.dev",
    annotations: { ttlMs: 60000, destructiveHint: false, openWorldHint: false, readOnlyHint: true },
  },
};

const WIDGET_HTML = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<meta name="color-scheme" content="light dark">
<title>Careem MCP App</title>
<link rel="stylesheet" href="https://careem-mcp-app.pages.dev/assets/index.css">
</head>
<body>
<div id="root"></div>
<script type="module" src="https://careem-mcp-app.pages.dev/assets/index.js"></script>
</body>
</html>`;

// ── Load tools at startup, fail fast on bad files/templates ───────────────────
const tools = loadAllTools(TOOLS_DIR);
for (const t of tools.values()) {
  for (const s of t.scenarios) {
    try {
      JSON.parse(renderTemplate(s.responseTemplate, {}));
    } catch (e) {
      throw new Error(`${t.filePath}: scenario '${s.name}' renders invalid JSON: ${e}`);
    }
  }
}
console.error(`[careem-mcp] Loaded ${tools.size} tools from ${TOOLS_DIR}`);

// ── Input validation: JSON Schema draft 2020-12, compiled once per tool ───────
const ajv = new Ajv2020({ strict: false, allErrors: true });
addFormats(ajv as unknown as Parameters<typeof addFormats>[0]);
const validators = new Map<string, ReturnType<typeof ajv.compile>>();
for (const t of tools.values()) {
  const schema = t.definition["inputSchema"];
  if (schema) validators.set(t.name, ajv.compile(schema as object));
}

type ToolResult = {
  content: Array<{ type: "text"; text: string }>;
  structuredContent?: Record<string, unknown>;
  isError?: boolean;
};

const internalError = (): ToolResult => ({
  content: [{ type: "text", text: "internal server error" }],
  isError: true,
});

function handleToolCall(toolName: string, rawArgs: Record<string, unknown>): ToolResult {
  const toolDef = tools.get(toolName);
  if (!toolDef) {
    throw new McpError(ErrorCode.InvalidParams, `unknown tool "${toolName}"`);
  }

  // Apply inputSchema defaults, then validate
  const args: Record<string, unknown> = { ...rawArgs };
  const props = (toolDef.definition["inputSchema"] as { properties?: Record<string, { default?: unknown }> } | undefined)
    ?.properties;
  for (const [k, v] of Object.entries(props ?? {})) {
    if (args[k] === undefined && v.default !== undefined) args[k] = v.default;
  }
  const validate = validators.get(toolName);
  if (validate && !validate(args)) {
    return {
      content: [{ type: "text", text: `validating "arguments": ${ajv.errorsText(validate.errors)}` }],
      isError: true,
    };
  }

  // Re-read the tool file on every call so edits apply without a restart
  let current;
  try {
    current = parseToolFile(toolDef.filePath);
  } catch (e) {
    console.error(`[careem-mcp] parse error in ${toolDef.filePath}:`, e);
    return {
      content: [{ type: "text", text: `internal server error: ${e}` }],
      isError: true,
    };
  }

  // Scenario selection: forced (overrides.json) > first matching > first default
  const forcedName = readOverrides(OVERRIDES_PATH)[toolName];
  let selected = forcedName
    ? current.scenarios.find((s) => s.name.toLowerCase() === forcedName.toLowerCase())
    : undefined;
  const forced = selected !== undefined;
  if (!selected) selected = current.scenarios.find((s) => s.match !== null && matchScenario(s.match, args));
  if (!selected) selected = current.scenarios.find((s) => s.match === null);
  if (!selected) {
    console.error(`[careem-mcp] no scenario for ${toolName}`);
    return internalError();
  }

  console.error(`[careem-mcp] ${toolName} -> ${selected.name}${forced ? " (forced)" : ""} ${JSON.stringify(args)}`);

  let value: Record<string, unknown>;
  try {
    value = JSON.parse(renderTemplate(selected.responseTemplate, args));
  } catch (e) {
    console.error(`[careem-mcp] render error in ${toolName}/${selected.name}:`, e);
    return internalError();
  }

  return {
    content: [{ type: "text", text: JSON.stringify(value) }],
    structuredContent: value,
    isError: selected.isError,
  };
}

// ── One MCP Server per client session ─────────────────────────────────────────
function buildServer(): Server {
  const server = new Server(
    { name: SERVICE_NAME, version: SERVICE_VERSION },
    {
      capabilities: {
        tools: { listChanged: true },
        resources: { listChanged: true },
        logging: {},
      },
    }
  );

  server.setRequestHandler(ListToolsRequestSchema, async () => ({
    tools: Array.from(tools.values())
      .map((t) => t.definition as never)
      .sort((a, b) => String(a["name"]).localeCompare(String(b["name"]))),
  }));

  server.setRequestHandler(ListResourcesRequestSchema, async () => ({ resources: [WIDGET_RESOURCE] }));

  server.setRequestHandler(ReadResourceRequestSchema, async (request) => {
    if (request.params.uri !== WIDGET_RESOURCE.uri) {
      throw new McpError(ErrorCode.InvalidParams, `Unknown resource: ${request.params.uri}`);
    }
    return {
      contents: [
        { uri: WIDGET_RESOURCE.uri, mimeType: WIDGET_RESOURCE.mimeType, _meta: WIDGET_RESOURCE._meta, text: WIDGET_HTML },
      ],
    };
  });

  server.setRequestHandler(CallToolRequestSchema, async (request) =>
    handleToolCall(request.params.name, (request.params.arguments ?? {}) as Record<string, unknown>)
  );

  return server;
}

// ── HTTP ──────────────────────────────────────────────────────────────────────
const transports = new Map<string, StreamableHTTPServerTransport>();

function readBody(req: IncomingMessage): Promise<string> {
  return new Promise((resolve, reject) => {
    const chunks: Buffer[] = [];
    req.on("data", (c: Buffer) => chunks.push(c));
    req.on("end", () => resolve(Buffer.concat(chunks).toString("utf8")));
    req.on("error", reject);
  });
}

function jsonRpcError(res: ServerResponse, status: number, code: number, message: string) {
  res.writeHead(status, { "Content-Type": "application/json" });
  res.end(JSON.stringify({ jsonrpc: "2.0", error: { code, message }, id: null }));
}

async function handleMCP(req: IncomingMessage, res: ServerResponse) {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "*");
  res.setHeader("Access-Control-Allow-Headers", "*");
  res.setHeader("Access-Control-Expose-Headers", "Mcp-Session-Id");
  if (req.method === "OPTIONS") {
    res.writeHead(200);
    res.end();
    return;
  }

  let body: unknown;
  if (req.method === "POST") {
    try {
      body = JSON.parse(await readBody(req));
    } catch {
      return jsonRpcError(res, 400, -32700, "Parse error");
    }
  }

  const sid = req.headers["mcp-session-id"] as string | undefined;
  let transport = sid ? transports.get(sid) : undefined;

  if (!transport) {
    if (sid) return jsonRpcError(res, 404, -32001, "Session not found");
    if (!(req.method === "POST" && isInitializeRequest(body))) {
      return jsonRpcError(res, 400, -32000, "Bad Request: no valid session ID provided");
    }
    const t: StreamableHTTPServerTransport = new StreamableHTTPServerTransport({
      sessionIdGenerator: () => randomUUID(),
      onsessioninitialized: (id) => {
        transports.set(id, t);
      },
    });
    t.onclose = () => {
      if (t.sessionId) transports.delete(t.sessionId);
    };
    await buildServer().connect(t);
    transport = t;
  }

  await transport.handleRequest(req, res, body);
}

const httpServer = createServer(async (req: IncomingMessage, res: ServerResponse) => {
  const url = req.url ?? "/";
  try {
    if (url === "/health" || url === "/health/") {
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ status: "ok", tools: tools.size }));
    } else if (url === "/mcp" || url.startsWith("/mcp?") || url.startsWith("/mcp/")) {
      await handleMCP(req, res);
    } else if (url === "/") {
      res.writeHead(200, { "Content-Type": "text/html" });
      res.end(`<link rel="icon" href="https://www.careem.com/favicon.ico"><h1>${SERVICE_NAME} ${SERVICE_VERSION}</h1>`);
    } else {
      res.writeHead(404);
      res.end("Not found");
    }
  } catch (e) {
    console.error("[careem-mcp] request error:", e);
    if (!res.headersSent) jsonRpcError(res, 500, -32603, "Internal error");
  }
});

httpServer.listen(PORT, HOST, () => {
  console.error(`[careem-mcp] ${SERVICE_NAME} ${SERVICE_VERSION} listening on http://${HOST}:${PORT}/mcp`);
  console.error(`[careem-mcp] Tools: ${tools.size} | Health: http://${HOST}:${PORT}/health`);
});
