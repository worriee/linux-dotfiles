// caveman — local OpenCode v2 plugin.
//
// Port of opencode-caveman@0.1.4, whose V1 `server()` export is rejected by the
// OpenCode 2.x loader (PluginModule.LoadError). V2 has no `config` hook: the
// domains that own skills and commands own them now, so both are registered
// through their transforms instead of by copying files into the config dir.

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const DATA_DIR = path.join(__dirname, "..", "caveman");
const SKILL_FILE = path.join(DATA_DIR, "SKILL.md");

function readFrontmatter(file: string) {
  const raw = fs.readFileSync(file, "utf8");
  const match = /^---\r?\n([\s\S]*?)\r?\n---\r?\n?/.exec(raw);
  if (!match) return { data: {} as Record<string, string>, body: raw.trim() };
  const lines = match[1].split(/\r?\n/);
  const data: Record<string, string> = {};
  for (let i = 0; i < lines.length; i++) {
    const kv = /^([A-Za-z0-9_-]+):\s*(.*)$/.exec(lines[i]);
    if (!kv) continue;
    const rawValue = kv[2].trim();
    // Folded/literal block scalar: the value is the indented lines that follow.
    if (rawValue === ">" || rawValue === ">-" || rawValue === "|" || rawValue === "|-") {
      const parts: string[] = [];
      while (i + 1 < lines.length && /^\s+\S/.test(lines[i + 1])) {
        parts.push(lines[++i].trim());
      }
      data[kv[1]] = parts.join(" ").trim();
      continue;
    }
    data[kv[1]] = rawValue.replace(/^["']|["']$/g, "");
  }
  return { data, body: raw.slice(match[0].length).trim() };
}

function readSkill() {
  const { data, body } = readFrontmatter(SKILL_FILE);
  return {
    id: "caveman",
    name: data.name ?? "caveman",
    description: data.description ?? "",
    path: SKILL_FILE,
    content: body,
  };
}

function readCommands() {
  const dir = path.join(DATA_DIR, "commands");
  try {
    return fs
      .readdirSync(dir)
      .filter((file) => file.endsWith(".md"))
      .map((file) => {
        const { data, body } = readFrontmatter(path.join(dir, file));
        return {
          name: path.basename(file, ".md"),
          description: data.description ?? "",
          template: body,
        };
      });
  } catch {
    return [];
  }
}

export default {
  id: "caveman",

  async setup(ctx) {
    const commands = readCommands();
    const skill = readSkill();

    await ctx.skill.transform((editor) => {
      editor.add(skill);
    });

    await ctx.command.transform((editor) => {
      for (const command of commands) {
        editor.add({
          name: command.name,
          description: command.description,
          execute: async ({ sessionID, prompt, delivery }) => {
            await ctx.session.prompt({
              ...prompt,
              sessionID,
              text: command.template.replaceAll("$ARGUMENTS", prompt.text || ""),
              delivery,
            });
          },
        });
      }
    });

    // Re-injected every turn. V2 hands over owned system parts, so push one
    // instead of rewriting the tail of another. The V1 build injected once into
    // the first user message, which let the ruleset drift after a few turns.
    await ctx.session.hook("context", (event) => {
      event.system.push({ type: "text", text: skill.content });
    });
  },
};