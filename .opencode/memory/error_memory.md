# Workspace Error Log & Debugging Memory

## 0. Last Synchronized Checkpoint

- **Last Error Check**: October 11, 2026, 05:15 PM PST

## 1. Active & Unresolved Errors

_List errors currently blocking development. Update this section immediately when a new error occurs during execution or user prompting._

### [ERR-001] Error Identifier / Short Description

- **Symptom**: _What is failing? Paste error logs, stack traces, or broken behavior here._
- **Context/Trigger**: _What command, file, or action caused this error?_
- **Suspected Root Cause**: _Initial assessment of why this is happening._

---

## 2. Historical & Resolved Errors

_Move errors to this section once they are completely verified as fixed. This serves as historical memory to prevent the AI from re-introducing the same bugs._

### [RESOLVED] caveman rebuilt as a local OpenCode v2 plugin (ERR-002)

- **The Issue**: `opencode-caveman@0.1.4` exports the V1 shape `{ id, server }`, which the OpenCode 2.0.26 loader rejects outright, so caveman vanished from `/plugins` and had never once injected its ruleset on this machine. Upstream is abandoned — the GitHub repo `DxVapor/opencode-caveman` still carries the same V1 export, last touched 2026-04-17 with docs only, so installing from GitHub would fail identically.
- **The Resolution**: Ported to a local v2 plugin at `~/.config/opencode/plugins/caveman.ts`, beside the working `rtk.ts` and using `@dietrichgebert/ponytail` as the API reference (same `id` + `async setup(ctx)` export, same `ctx.skill.transform` / `ctx.command.transform` / `ctx.session.hook('context')` / `ctx.session.prompt` calls). Two V1 constructs were deleted rather than ported: `installFilesToConfigDir()` (V2 has no `config` hook, so skills and commands register through their own transforms) and the `caveman-compress` tool (redundant once injection is automatic). Data files copied byte-for-byte to `~/.config/opencode/caveman/` (SKILL.md + 3 commands). Injection also improved — V1 shoved rules into the first *user message* exactly once, V2 pushes to the system prompt every turn. A follow-up bug was caught live: the first `readFrontmatter` was line-based and could not fold YAML block scalars, so `description: >` registered the skill with the literal description `>`; replaced with a block-scalar-aware parser. Verified October 11, 2026, 05:31 PM PST — the harness reloaded the skill list mid-session with the full description text, with no restart.
- **Prevention Strategy**: For an abandoned V1 plugin, do not reinstall from source hoping for newer code — check the repo's last commit date against the published version first. When copying a plugin's rules into a local v2 port, reuse the already-working v2 plugin on the machine as the API reference rather than the migration guide alone; the guide understates which V1 constructs simply vanish. The `-c` subagent caught the folded-scalar bug that a type checker passed, because a static check cannot see a wrong value that is still the right type.

---

### [RESOLVED] Repo configs shipped dead plugins and an invalid compaction block (ERR-003)

- **The Issue**: Both repo copies of `opencode.jsonc` declared `opencode-caveman` (V1, dead — see ERR-002) and the xfce copy additionally declared `opencode-ponytail`, a package that does not exist on npm at all. Because `gnome/setup.sh:151` and `xfce/setup.sh:136` bulk-copy `$REPO/.config/.` over `$HOME_DIR/.config/`, any restore silently reinstated the dead entries. Both repo copies — and the live config — also carried a `compaction` block using four keys that the OpenCode 2.x schema rejects under `additionalProperties: false`.
- **The Resolution**: Purged the dead specs from both repo copies; replaced xfce's nonexistent `opencode-ponytail` with the real `@dietrichgebert/ponytail` rather than leaving the array empty. Rewrote the invalid compaction block to schema-valid `auto` + `tail_turns`, preserving the original intent (auto-compact, keep 10 recent turns) and deliberately NOT setting `prune`, since the old `strategy: summarize` asked for summarization rather than pruning. Applied the same compaction fix to the live config, which had been carrying the broken block the whole time. October 11, 2026, 05:45 PM PST. Verified: `grep` for both dead specs returns 0 across both repo files, and live now matches the repo `gnome/` copy exactly apart from one trailing comma.
- **Prevention Strategy**: `cp` overwrites but never deletes, so a bulk-copy installer silently resurrects whatever stale file the repo still carries — audit repo and live config trees together, never one alone. Also: when removing a plugin spec, replace it with its working equivalent instead of deleting the array entry, or the restore quietly loses a plugin that still works.

---

### [RESOLVED] rtk.ts V1 plugin rejected by OpenCode 2.0.26 loader (ERR-004)

- **The Issue**: `~/.config/opencode/plugins/rtk.ts` used the V1 plugin form. OpenCode 2.0.26 rejected it with `PluginModule.LoadError: ... SchemaError(Missing key at ["default"])` — the module had no valid default export. Log showed 4 consecutive load failures at 08:28:59–08:29:00 UTC.
- **The Resolution**: User migrated the file to the V2 default-object form via Gemini on October 11, 2026, 05:15 PM PST. Verified all four required changes are present in the current file: (1) `export default { id: "rtk", async setup(ctx) {...} }` replaces the old `export const RtkOpencodePlugin: Plugin`; (2) Bun shell `$` removed in favour of `import { spawn } from "node:child_process"`; (3) hook re-registered as `ctx.tool.hook("execute.before", async (event) => ...)` with `event.input` reassigned directly; (4) subprocess resolves on `close` regardless of exit code, so the deliberate exit-status-3 of `rtk rewrite` does not throw. Log confirms clean load with no WARN from 08:35:34 UTC onward.
- **Prevention Strategy**: Before upgrading the OpenCode CLI, audit every plugin's default export for `setup` or `effect`. A V1 `server:`/`Plugin` export will fail validation on load, not at call time, so the plugin vanishes from `/plugins` with only a WARN in the log. Check `~/.local/share/opencode/log/opencode.log` for `failed to load plugin` after any upgrade — `/plugins` silently omits dead entries.

---

### [RESOLVED] Error Identifier / Short Description

- **The Issue**: _Brief summary of what went wrong._
- **The Resolution**: _How it was fixed (e.g., code changes, configuration adjustments, dependency updates)._
- **Prevention Strategy**: _What architectural rule or guideline should be followed to avoid a regression?_

---

## 3. Persistent Debugging Rules

- **Lookback Before Guessing**: Before attempting to fix any code, cross-reference this file to see if a similar failure has happened before.
- **Immediate Documentation**: Every time a debugger action fails or reveals a new error, log it under section 1 before writing any fixes.
- **Clean Transitions**: When an error is resolved, update its status, document the solution, and shift it to section 2.

---

## 4. ARCHIVE STATUS

- **Archive File**: `.opencode/archives/error_archive.md`
- **Threshold**: 10 active entries per section
- **Total Archived**: 0
- **Last Archive Check**: `Not yet performed`

| Entries Archived | Archived At (PST) |
| ---------------- | ----------------- |
| 0                | —                 |

<!-- c: worrie -->
