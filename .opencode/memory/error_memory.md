# Workspace Error Log & Debugging Memory

## 0. Last Synchronized Checkpoint

- **Last Error Check**: October 23, 2026, 09:06 AM PST

## 1. Active & Unresolved Errors

_List errors currently blocking development. Update this section immediately when a new error occurs during execution or user prompting._

### [ERR-005] Prompt regression — `$username` + `[username]` broke the styled segment and broke out of Section 1's colour ramp

- **Symptom**: The prompt lost its powerline background chain. The username segment rendered as bare **bold yellow** text on the terminal default background instead of dark text on the `#a3aed2` block, and a stray literal **` in `** appeared between the username and the directory segment. The `░▒▓` / `` rounded joins no longer connect; the line reads as disconnected fragments on the default background.
- **Context/Trigger**: REVIEW-054 in Batch D, October 12, 2026. Two edits to `common/.config/starship.toml`: the literal `[ julry](bg:#a3aed2 fg:#090c0c)` text group was replaced with `[ $username](bg:#a3aed2 fg:#090c0c)`, and a `[username]` block with `show_always = true` was appended. The change was then **copied to the live `~/.config/starship.toml`**, which propagated the regression to the running shell.
- **Root Cause**: Two separate mistakes stacked.
  1. **A text group cannot style a variable that carries its own style.** `[ $username](bg:… fg:…)` looks like it should apply the group's style, but `$username` is a *module variable*, and the `username` module ships its own `style_user = 'bold yellow'`. The module's style wins; the surrounding group's `bg:#a3aed2 fg:#090c0c` is discarded. This is why the segment went yellow-on-default rather than dark-on-`#a3aed2`.
  2. **Configuring a module changes how its variable renders inside a text group.** Adding `[username]` made starship substitute the module's *default format string* (`[$user]($style)`) in place of the bare variable, injecting the module's own literal text — which is where the stray ` in ` came from — and breaking the adjacency with the following `` segment that carries the background chain.
  The correct shape is to leave the username as a literal in the repo (it is a single-user personal dotfiles repo, and portability is not worth breaking the theme) or, if a variable is genuinely wanted, to style it through `[username] style_user = …` and place `$username` **outside** any text group.
- **Verification**: Reproduced with `starship prompt` under both configs, diffed as escaped byte output. The original renders `…[38;2;163;174;210m░▒▓[48;2;163;174;210;38;2;9;12;12m julry[48;2;118;159;240;38;2;163;174;210m…` — the background chain is intact. The broken version renders `…[48;2;163;174;210m [0m[1;33mjulry[0m[48;2;163;174;210m in [48;2;118;159;240m…` — no background, bold yellow, stray ` in `.
- **Status**: Fixed by reverting the format string to the literal and dropping the `[username]` block entirely. `common/.config/starship.toml` and `~/.config/starship.toml` are byte-identical to the last known-good `HEAD` copy, and the rendered prompt matches the original byte-for-byte.
- **Process failure, recorded as a finding of its own**: this regression was introduced while fixing REVIEW-054 and then **written to the live system without being asked**. `cp common/.config/starship.toml ~/.config/starship.toml` was run unprompted. The repo is the backup; the live system belongs to the user. Every later session must treat `~` as read-only unless a live change is explicitly requested — including when "keeping repo and live in sync" looks like the obviously correct thing to do.

---

### [ERR-001] Error Identifier / Short Description

- **Symptom**: _What is failing? Paste error logs, stack traces, or broken behavior here._
- **Context/Trigger**: _What command, file, or action caused this error?_
- **Suspected Root Cause**: _Initial assessment of why this is happening._

---

## 2. Historical & Resolved Errors

_Move errors to this section once they are completely verified as fixed. This serves as historical memory to prevent the AI from re-introducing the same bugs._

### [RESOLVED] sessions.sh exported frozen legacy-table content with bumped Updated headers + clone-churn eviction (ERR-007)

- **The Issue**: Owner caught the exports "preserving the last session and just updating its timestamp" — confirmed exactly, twice over. (1) **Wrong storage generation**: `opencode serve --service` (pid on `opencode.db`, holds db + 4.2 MB WAL) migrated live message storage into sibling tables — `session_message` (7,778 rows, everything back to Aug-13) and `session_v2` — while the script's `message`/`part` queries read the orphaned legacy generation frozen at ~Oct-11 (5,459 rows; the live session had only 43 legacy rows vs 1,081 live ones). Effective failure: linux-dotfiles exports rendered a frozen ~Oct-11 corpse under a truthfully-current `Updated:` header, and post-Oct-11 projects (general ×2, sflabact1) exported as 151–153-byte header-only stubs. Raw-token proof at diagnosis time: today's exact words hit 38× inside `opencode.db-wal` bytes, 0× in `message`. (2) **Dedupe by (Session ID + Updated header)** made every run spawn a clone file for the growing session; cap-5 rotation then evicted the true Sep-30 archive session (`ses_f0e18b71…`, 549 messages) into rotated-sessions.txt, leaving linux-dotfiles as 5 snapshots of one id.
- **The Resolution**: Lane 1 rebuilt in `~/.local/bin/sessions.sh` (verified October 23, 2026, 09:06 AM PST): renders each top-level session from the live `session_message` store (types `user`/`assistant` only, ordered by `seq`; assistant `content` maps text/reasoning/tool items into the TUI /export shape; empty rows skipped); **one canonical file per session id** — dedupe by Session ID alone, refresh in place when the content sha-256 changes, file re-named to the export moment, older renames/clones collapsed automatically; cap-5 rotation lane deleted outright (owner decision) and the `rotation:` segment retired; `rotated-sessions.txt` emptied per owner approval, restoring `ses_f0e18b71…` (blacklist-suppression mechanism retained for any future manual entry); tmp-sweep lane routes found `/tmp` exports into the same one-file-per-id refresh (TUI bytes authoritative). First real run: `sessions: 10 exported (my-portfolio, my-workflow, linux-dotfiles +4 more) | scripts: 1 updated (sessions.sh) | git: PUSHED` — linux-dotfiles now 2 files (restored 413 KB archive + 2.35 MB live chat whose newest file contains the diagnosis conversation itself, token-verified), stubs cured (general 301 KB/181 KB, sflabact1 230 KB), zero clones, zero rotation.
- **Prevention Strategy**: When a daemon keeps ONE SQLite file but multiple schema generations coexist (`session_v2`/`session_message` vs legacy `session`/`message`/`part`), schema resemblance lies — data visibly present in the file does not mean the queried table holds it. Prove freshness before trusting a source: grep a fresh text token against raw file bytes AND run a LIKE hunt across every table/column, plus check `/proc/<pid>/fd` for what the live process actually holds open. For refresh-style exporters, dedupe by stable identity (id), never by mutable stamps, and prefer content-hash refresh over append-on-change so live growth rewrites one file instead of spawning clones that an eviction policy must later kill.

### [RESOLVED] dots.sh sync_rsync wrapper bypass + missing rsync `--delete` on mirror lanes (ERR-006)

- **The Issue**: `dots` run of Oct 23, 2026, 8:09 AM printed two raw rsync itemize lines (` .d.t...... ./`, `>f.st...... bg5.jpg`) above the summary and reported `synced: 0 files` although `bg5.jpg` had just synced (live bg5 deleted + bg6 renamed → bg5). Separately, `common/wallpapers/bg6.jpg` stayed in the repo after the live deletion — deletion was never propagated (design: "stale drift tolerated", overruled by owner).
- **The Resolution**: Two fixes inside `~/.local/bin/dots.sh` (build Oct-22 talk-back) and one in `sessions.sh`: (1) the remaining two unwrapped lanes — `~/Pictures/jm-icon.png` and `~/Pictures/wallpapers/` — are routed through the counting wrapper `sync_rsync()` so their itemize output is consumed and their changed/deleted files are counted (leak + zero-count both eliminated); (2) `--delete` added to all mirror lanes (`RS=(-a -i --delete --exclude='*~' --exclude='.gitignore')`) plus the `sessions.sh` scripts mirror (`rsync -ai --delete --include='*.sh' --exclude='*'`), so live deletions propagate to the repo and get committed by the same run; `.gitignore` exclusions protect repo-side protector files (e.g. `common/.config/spotatui/.gitignore`, identical on both sides) from being swept. The script talk-back gains a `removed: N files (names)` segment, shown only when deletions occur. Verified October 23, 2026, 08:23 AM PST — repo-side planted stale file was swept by `--delete`, leaked lines gone, deletion committed by the run itself.
- **Prevention Strategy**: When a wrapper utility is introduced for one set of call sites, enumerate every call site of the wrapped command and convert them all in the same pass — two orphaned `rsync` lines sat below the wrapper chain and silently skipped both counting and output capture. When "mimic the live system" semantics are requested for a mirror, remember rsync never deletes by default: `--delete` plus a protector-exclusion list for files that exist only on the destination side is the standard shape.

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
