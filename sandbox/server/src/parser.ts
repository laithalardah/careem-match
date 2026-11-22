/**
 * Parses tool .md files according to spec/FORMAT.md and spec/BUILD.md
 */

import { readFileSync } from "fs";

export interface Scenario {
  name: string;
  match: Record<string, unknown> | null; // null = default scenario
  responseTemplate: string;
  isError: boolean;
}

export interface ToolDefinition {
  name: string;
  definition: Record<string, unknown>; // verbatim json tool block
  scenarios: Scenario[];
  filePath: string;
}

function parseFrontmatter(text: string): Record<string, string> {
  const fmMatch = text.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n/);
  if (!fmMatch) throw new Error("Missing frontmatter");
  const result: Record<string, string> = {};
  for (const line of fmMatch[1].split(/\r?\n/)) {
    const m = line.match(/^(\w+)\s*:\s*(.*)$/);
    if (!m) continue;
    // strip trailing comments and surrounding quotes
    let val = m[2].replace(/\s*#.*$/, "").trim();
    val = val.replace(/^["']|["']$/g, "");
    result[m[1]] = val;
  }
  return result;
}

function extractSections(
  text: string
): Array<{ title: string; body: string }> {
  // Strip frontmatter
  const stripped = text.replace(/^---\r?\n[\s\S]*?\r?\n---\r?\n/, "");

  const sections: Array<{ title: string; body: string }> = [];
  const lines = stripped.split(/\r?\n/);

  let currentTitle = "";
  let currentLines: string[] = [];
  let inFence = false;

  for (const line of lines) {
    if (line.startsWith("```")) {
      inFence = !inFence;
    }
    if (!inFence && line.startsWith("## ")) {
      if (currentTitle) {
        sections.push({ title: currentTitle, body: currentLines.join("\n") });
      }
      currentTitle = line.slice(3).trim();
      currentLines = [];
    } else {
      currentLines.push(line);
    }
  }
  if (currentTitle) {
    sections.push({ title: currentTitle, body: currentLines.join("\n") });
  }
  return sections;
}

function extractFencedBlock(
  body: string,
  infoString: string
): string | null {
  // Match ```<infoString>  ...content... ```
  const pattern = new RegExp(
    "^```" +
      infoString.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") +
      "[ \\t]*\\r?\\n([\\s\\S]*?)^```[ \\t]*$",
    "m"
  );
  const m = pattern.exec(body);
  return m ? m[1] : null;
}

// Spec (BUILD.md §2): ^```json[ \t]+(match|response|error)[ \t]*\n(.*?)^```[ \t]*$  (multi-line, dotall)
function extractAllFencedBlocks(
  body: string
): Array<{ info: string; content: string }> {
  const results: Array<{ info: string; content: string }> = [];
  const pattern = /^```json[ \t]+(match|response|error)[ \t]*\r?\n([\s\S]*?)^```[ \t]*$/gm;
  let m: RegExpExecArray | null;
  while ((m = pattern.exec(body)) !== null) {
    results.push({ info: `json ${m[1]}`, content: m[2] });
  }
  return results;
}

export function parseToolFile(filePath: string): ToolDefinition {
  const text = readFileSync(filePath, "utf8");

  const fm = parseFrontmatter(text);
  if (!fm["tool"]) throw new Error(`${filePath}: missing 'tool' in frontmatter`);
  const toolName = fm["tool"];

  const sections = extractSections(text);

  let definition: Record<string, unknown> | null = null;
  const scenarios: Scenario[] = [];

  for (const sec of sections) {
    if (sec.title === "Definition") {
      const block = extractFencedBlock(sec.body, "json tool");
      if (!block) throw new Error(`${filePath}: Definition section has no json tool block`);
      try {
        definition = JSON.parse(block);
      } catch (e) {
        throw new Error(`${filePath}: invalid JSON in Definition: ${e}`);
      }
      if ((definition as Record<string, unknown>)["name"] !== toolName) {
        throw new Error(
          `${filePath}: definition name '${(definition as Record<string, unknown>)["name"]}' != frontmatter tool '${toolName}'`
        );
      }
    } else if (sec.title.startsWith("Scenario: ")) {
      const scenarioName = sec.title.slice("Scenario: ".length).trim();
      const blocks = extractAllFencedBlocks(sec.body);

      let matchObj: Record<string, unknown> | null = null;
      let responseTemplate: string | null = null;
      let isError = false;
      let responseBlocks = 0;

      for (const block of blocks) {
        if (block.info === "json match") {
          try {
            matchObj = JSON.parse(block.content);
          } catch (e) {
            throw new Error(`${filePath}: Scenario '${scenarioName}' has invalid match JSON: ${e}`);
          }
        } else if (block.info === "json response") {
          responseTemplate = block.content.trim();
          responseBlocks++;
        } else if (block.info === "json error") {
          responseTemplate = block.content.trim();
          isError = true;
          responseBlocks++;
        }
      }

      if (responseBlocks !== 1 || !responseTemplate) {
        throw new Error(
          `${filePath}: Scenario '${scenarioName}' must have exactly one response/error block (has ${responseBlocks})`
        );
      }

      scenarios.push({
        name: scenarioName,
        match: matchObj,
        responseTemplate,
        isError,
      });
    }
  }

  if (!definition) throw new Error(`${filePath}: no Definition section`);
  if (scenarios.length === 0) throw new Error(`${filePath}: no scenarios`);

  const hasDefault = scenarios.some((s) => s.match === null);
  if (!hasDefault) throw new Error(`${filePath}: no default scenario (one without a match block)`);

  return { name: toolName, definition, scenarios, filePath };
}
