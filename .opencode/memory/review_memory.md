# Code Review Log Memory

## 0. Last Synchronized Checkpoint

- **Last AI Analysis Timestamp**: October 12, 2026, second `-r` pass — 8 new findings (REVIEW-105..112), 37 prior verified still open
- **Prior Pass**: October 11, 2026, 08:35 AM PST — 63 findings, REVIEW-027..089

## 1. Active & Open Review Findings

_Audited October 11, 2026; re-verified and extended October 12, 2026. **No open findings remain.** The last two (REVIEW-106 dkms, REVIEW-111 Acer battery) were closed by owner decision on October 12, 2026: both belong to the out-of-tree kernel-driver path that only applies to the Linux Mint / Ubuntu installation used on old laptops and low-power machines, not to the openSUSE Tumbleweed installation this repo now serves. Tumbleweed ships the in-kernel `mt7921e` driver for the MT7902 card, `dkms` is not installed, and Secure Boot is enabled so unsigned out-of-tree modules cannot load at all. **The code is left exactly as written — the owner has chosen a non-working script on this platform over editing core backups.** Section 2 holds 53 resolved entries and preserves the full narrative of every closed finding.

_All eight reviews REVIEW-019–026 (split-layout audit, September 13, 2026) fixed the same day — migrated to Section 2._

_All six reviews from the September 05, 2026 full-repo audit are resolved — migrated to Section 2._

_Reviews REVIEW-012–018 (TW-readiness audit, September 09, 2026) all fixed the same day — migrated to Section 2._

## 2. Historical & Resolved Reviews

_Move reviews to this section once they are completely verified as resolved. This serves as historical memory to prevent the AI from re-introducing the same issues._

_Seven entries further down were closed by owner decision rather than by a code change: each is a real defect that was reviewed and knowingly kept. They carry the original tracking number so the history stays intact, and the decision plus any compensating control is recorded so a later pass does not mistake them for unexamined bugs._

### [RESOLVED] Batch G — out-of-tree kernel drivers retired from scope for the Tumbleweed platform (REVIEW-106, 111)

Closed October 12, 2026 by owner decision. **No file in the repository was modified in this batch.** `xfce/setup.sh` and the `xfce/drivers/mt7902/` tree are untouched, exactly as written.

- **The decision**: both findings sit in the optional-hardware section of `xfce/setup.sh` — the section that installs out-of-tree kernel modules. That path exists for the **Linux Mint / Ubuntu installation used on old laptops and low-power machines**, whose kernels predate the in-kernel MediaTek driver. It does not apply to the openSUSE Tumbleweed installation this repo now serves. The owner's instruction is explicit: **the script is allowed not to work on this platform rather than the core backups being edited.** So neither line was changed, and neither will be.
- **REVIEW-106 — `dkms status` called unprivileged, so the idempotency guard never matches.** `xfce/setup.sh:449` runs `dkms status | grep -q "^mt7902-wifi/"`. `dkms` lives in `/usr/sbin`, which is not on this machine's user `PATH`, so the guard is always false and the DKMS branch would re-run its `sudo rm -rf /usr/src/mt7902-*` on every execution. **Unreachable on this machine for three independent reasons**: `dkms` is not installed (`rpm -q dkms` → not installed); the MT7902 at `0000:02:00.0` is already bound to the in-kernel `mt7921e` driver, which Tumbleweed ships and which works; and `xfce/setup.sh` aborts at its DE guard because the active session is COSMIC, not XFCE. The defect is real on a Mint machine with an MT7902 card and is left in place for that platform.
- **REVIEW-111 — Acer battery driver clones an unpinned branch into a predictable `/tmp` path.** `xfce/setup.sh:474-478` runs `git clone --depth=1 https://github.com/frederik-h/acer-wmi-battery.git /tmp/acer-wmi-battery`, builds it, and copies the resulting `.ko` into `/lib/modules/$(uname -r)` with `sudo`. Three defects were recorded: the fixed world-writable `/tmp` path is pre-creatable by any local user as a symlink; the branch is unpinned so module contents vary per run; and the cleanup `rm -rf` is on the success path only. **All three apply to the Mint path and are left uncorrected here.** Two further facts make the code inert on this machine regardless: `mokutil --sb-state` reports `SecureBoot enabled` with no shim-signed MOK enrolled, so an unsigned out-of-tree `.ko` is rejected by design — the owner has confirmed Secure Boot must stay enabled and has declined the driver for that reason; and the DE guard stops the script before it reaches this block.
- **Noted and accepted**: because the Secure Boot `modprobe` fails after the `.ko` has already been copied into the live kernel tree, `depmod -a` has already run, and `/etc/modules-load.d/acer-wmi-battery.conf` has already been written, *forcing* this block to execute on a Secure Boot machine would leave a module that cannot load armed at every subsequent boot while the script prints a success. This is recorded here as a known limitation of the Mint path rather than a live risk, since the block cannot be reached from a Tumbleweed COSMIC session. It is the reason a future pass must not "helpfully" add a Secure Boot guard — the owner has decided that path is out of scope, and the block is left byte-for-byte as backed up.

**Prevention Strategy**: A finding belongs in the log only if the owner intends to act on it, and a platform boundary is as much a scoping decision as a personal preference. Both of these were correct observations about code that is genuinely defective — the `/tmp` symlink and the unsigned-module issues are real — but they describe a platform this repo no longer targets. Recording them as open implied pending work that was never going to happen, and re-raising them each pass cost attention without producing improvement. The generalisable form: **verify the finding's premise still applies to the current platform before keeping it open**, which is the same check that killed REVIEW-029, REVIEW-032 and REVIEW-066 in earlier batches, applied here to two findings that are accurate but irrelevant. A third-party driver's install path, a deprecated desktop's config tree, and a personal shell profile are all cases where "it would be better this way" is not automatically "it should be changed" — the owner decides what their own backups are allowed to look like.

---

### [RESOLVED] Batch F — prompt username and the archived sway tree retired from scope (REVIEW-054, 065, 076, 077, 078, 079, 083, 088)

Closed October 12, 2026. Eight findings, none of them worked. No file in the repository was modified in this batch.

- **The archived `sway/` tree is out of scope permanently (REVIEW-065, 077, 078, 079, 083, 088).** Six findings sit in `sway/.config/waybar/config`, `sway/.config/sway/config` and `sway/README.md`. **This is the owner's own install record from a desktop environment they previously used and no longer run** — `sway` is not installed (`rpm -q sway` → not installed), and none of its toolchain (swaylock, swayidle, waybar, wofi, mako, grim, slurp, brightnessctl, playerctl) is present. The findings are accurate descriptions of that archived configuration: waybar exposing five workspaces against sway's ten bindings (065), an `include /etc/sway/config.d/*` glob matching nothing (077), a backlight module pinned to one machine's `amdgpu_bl1` device (078), Bluetooth format strings all reading `" OFF"` regardless of state (079), a README claiming a wallpaper was absent from the repo when it is not (083), and one launcher script bound to two key combinations at a hardcoded path (088). **They are closed as historical record, not fixed.** Do not edit, "repair", or re-raise anything under `sway/`. It is kept deliberately as a backup of a working configuration the owner may want again; the same decision already closed REVIEW-036 and REVIEW-037 in the first pass of this review. `sway/README.md` already carries an ARCHIVED banner naming every absent package, so nothing in the tree reads as live configuration.
- **REVIEW-076 — superseded, not fixed.** This was logged against `gnome/.config/zed/keymap.json` at mode `0755`; it is not a sway finding and was swept into this batch by filename association. It was actually fixed in Batch B as REVIEW-109, which found twelve Markdown and JSON files carrying the executable bit in the git index and corrected all twelve to `0644`. `common/.config/zed/keymap.json` is now `644`, and a repo-wide sweep for non-script files at `0755` returns zero.
- **REVIEW-054 — closed by owner decision, do not retry.** `common/.config/starship.toml` contains a literal `[ julry]` text segment rather than the `$username` variable, so the prompt would show the original owner's name if restored onto a different account. A fix was attempted during Batch D and **broke the prompt theme**: a text group cannot style a module variable, so the `username` module's own `style_user = 'bold yellow'` overrode the segment's `bg:#a3aed2 fg:#090c0c`, and adding a `[username]` block made starship substitute the module's default format — injecting a stray literal ` in ` and severing the background chain between the username and directory segments. The literal was reverted and both the repo and live copies were restored to the last known-good state, verified by diffing the rendered prompt byte-for-byte. Full root cause is in `error_memory.md` as ERR-005. **The owner has reviewed this and chosen to keep the literal.** If portability to another account is ever genuinely wanted, the only correct shape is `[username] style_user = "fg:#090c0c bg:#a3aed2"` with `$username` placed **outside** any text group, and it must be validated with `starship prompt | cat -v | grep -c '48;2;'` — checking that the string `julry` still appears proves nothing, since the broken version printed it too.

**Prevention Strategy**: A finding is open only if someone intends to act on it. These eight were open because a review pass recorded observations without ever confirming that fixing them was wanted, and they survived four batches that way — long enough to be re-raised repeatedly and to accumulate entirely on the owner's attention. Two rules follow, both learned the hard way here. First, **scope is a property of a directory, not of individual findings**: if a tree is an archive, every finding pointing into it closes together, so a sweep that ends with any sway finding still open has not finished the job. Second, **a fix that regresses must not be re-opened as work** — the honest end state for REVIEW-054 is "attempted, reverted, documented, owner keeps the literal," not a live ticket inviting the next reviewer to try the same thing again. Re-opening it was my error; the finding had been closed by the owner and I undid that by carrying it forward.

---

### [RESOLVED] Batch E — personal workflow closed by owner decision; two findings resolved on evidence (REVIEW-062, 066, 067, 068, 069, 070, 080, 082, 089, 112)

Closed October 12, 2026. **No code, config or workflow file was changed in this batch.** Ten findings, in two very different categories: eight describe the owner's deliberate shell workflow, and two are resolved by evidence rather than by preference.

- **Closed by owner decision — the personal shell workflow (REVIEW-062, 067, 068, 069, 070, 080, 082).** These describe choices in `common/.bashrc`, `common/.config/fastfetch/config.jsonc`, `common/.config/kitty/kitty.conf` and `gnome/.config/autostart/lock-screen.desktop`: `fastfetch` on every terminal opened at `$HOME`, `zed` launched detached with output discarded, `zzed`/`repo` argument handling, `zoxide query -i` interactive selection, the `packages` key not padded to the 8-column width used by every sibling row, a comment crediting `picom` for an opacity setting kitty applies itself, and the `sleep 3; loginctl lock-session` autostart. The owner reviewed each and kept them. They are the workflow, not defects in it. **These files are not to be refactored, hardened or "corrected" for cosmetic reasons in any future pass** — a review that keeps re-raising them is producing noise, and `zzed` in particular is a personal tool with a personal shape.
  Each was checked for correctness before closing rather than waved through. The three `.bashrc` findings are real edge cases that happen not to fire in the owner's environment: `$1` before `$#` is harmless because `.bashrc` never runs under `set -u`; `repo ref` returns 0 when `~/repo` is absent, which does not happen here; `zed` is a manual leftover on this machine and is present on the machine where `zzed` is used. They are documented here as known trade-offs, not as open work.
- **REVIEW-066 — premise disproven.** The finding claimed `zoxide query -i "${@:2}"` and `zoxide query -i "$@"` "split on spaces". Both are correctly quoted and `"$@"` provably preserves an embedded space: `f() { printf '[%s]\n' "$@"; }; f "my project"` emits one argument, `[my project]`. The real, different observation is that `zoxide query -i` shells out to fzf and requires a TTY, so it fails with `inappropriate ioctl for device` in any non-interactive context. That does not affect the owner, who runs it from a terminal. Closed as a non-issue rather than "fixed", because changing the quoting would have changed nothing.
- **REVIEW-089 — `/usr/sbin` binaries; already resolved by Batch A plus evidence.** Of the four binaries named, `zramctl` was fixed to `/usr/sbin/zramctl` at all six call sites in Batch A (REVIEW-105). The other two, `sysctl` and `update-alternatives`, were never broken: every call site is `sudo`-prefixed, and sudo resets `PATH` through `secure_path`, which includes `/usr/sbin` — so `sudo sysctl` resolves correctly even though the unprivileged shell cannot find `sysctl`. The documentation side was already correct too: `gnome/setup.md:511` states in bold that `efibootmgr` is at `/usr/sbin/` and is not on a user `PATH`. The finding's own recommendation had been satisfied before it was written. One residual observation is not a defect: `xrandr` appears bare inside the `toggle-screen-dim.sh` heredoc, but that script is written to `$HOME_DIR/.local/bin` and only runs in an XFCE session, and `xrandr` is a genuine X11 client that a user session can always execute.
- **REVIEW-112 — no `.gitignore`.** Closed by owner decision on October 12, 2026: `.opencode/node_modules/` is to be excluded, and the owner handled the exclusion. This is the third and final time this finding has been raised (previously declined alongside REVIEW-039) and it is now closed rather than deferred, so it will not be re-raised.

**Prevention Strategy**: A personal dotfiles repo is a working environment first and a codebase second. Findings that describe how the owner chose to work are not maintenance items, and re-raising them costs the owner attention while producing no improvement — the correct response to "this could break in an edge case" in a single-user shell profile is to write it down once and stop. The generalisable form: distinguish *defects* (the thing does not do what it claims) from *trade-offs* (the thing works, in the environment it is used in, and would need care elsewhere), and only keep the former open. Two of this batch's ten findings also failed verification outright — 066's stated cause was not real, and 089's was fixed before the finding existed — which is the second time in three batches that a finding's premise did not survive a check against the repo. The cheaper habit remains: re-derive the line number, run the command, and confirm the claim before recording it as open.

---

### [RESOLVED] Batch D — documentation and portability drift (REVIEW-043, 053, 054, 056, 059, 061, 063, 064, 084, 085, 086, 087)

Twelve findings closed October 12, 2026. Ten were documentation that would send a reader to a path, a count, or a package that does not exist; two were config files that would not survive a move to another account. Verified against the repo after the edits — no assertion in this entry rests on the log.

- **REVIEW-043 — dead `vscodefiles` paths.** `gnome/setup.md:238,332` and `xfce/setup.md:785` set `REPO=/home/julry/vscodefiles/linux-configs/...`. That entire tree is gone; the repo moved and was renamed. Every command in those blocks failed. The three sites now use `/path/to/linux-dotfiles/<de>`, and the GNOME one derives the path instead of hardcoding it. The same class of example was corrected in `cosmic/setup.md:206`.
- **REVIEW-087 — copying from a tree that does not exist.** `xfce/setup.md` gave three `cp linux-configs/.config/…` blocks — wrong repo name *and* wrong level, since the dotfiles live under `xfce/`, not at the root. Correcting the name alone would still have left a broken path. All three now use `xfce/.config/…`, the surrounding "adjust the path" hedges are replaced with a concrete "run from the repo root, or just `bash xfce/setup.sh`", and the prose that claimed the GTK CSS lived at `.config/gtk-3.0/gtk.css` was corrected to `xfce/.config/gtk-3.0/gtk.css`.
- **REVIEW-084 — docs appending to `.bashrc` that the scripts replace.** Three hand-run blocks told the reader to `echo … >> ~/.bashrc` (`gnome/setup.md`, `xfce/setup.md` ×2). Every `setup.sh` copies `common/.bashrc` wholesale, so following the docs by hand and then running the script produced duplicate `NODE_OPTIONS` and duplicate `eval "$(starship init bash)"` lines. All three blocks now copy `common/.bashrc` and say explicitly not to append.
- **REVIEW-064 — stale kernels presented as live state.** `gnome/setup.md` pinned `7.2.5-1.1` and `7.2.6-1.1` as "verified live", and §13 told the reader to `sudo kernel-install remove 7.2.5-1-default` and to keep `7.2.5` as the fallback. The machine runs `7.2.9-1-default` with `7.2.8-1-default` installed — on a rolling-release distro those numbers were stale within days. The state line now records what is actually installed with a date and tells the reader to re-read `ls /lib/modules/`; the removal command is now `ls /lib/modules/` + `uname -r` + `remove <old-version>` with an explicit "NOT `$(uname -r)`" warning. Tumbleweed moves fast enough that a hardcoded version in a maintenance procedure is a defect, not a detail.
- **REVIEW-054 — prompt hardcoded the username. ATTEMPTED, THEN REVERTED — still open.** `starship.toml` has a literal `[ julry]` text segment rather than the `$username` variable, so a restore onto a different account shows the original owner's name. The Batch D fix replaced it with `[ $username](bg:#a3aed2 fg:#090c0c)` plus a `[username]` block, and that **broke the theme**: a text group cannot style a module variable, so the module's own `style_user = 'bold yellow'` won and the segment lost its `#a3aed2` background; adding the `[username]` block also made starship substitute the module's default format, injecting a stray literal ` in ` and breaking adjacency with the next segment in the background chain. The literal was restored and `common/.config/starship.toml` plus the live `~/.config/starship.toml` are now byte-identical to the last known-good `HEAD` copy, verified by diffing the rendered prompt byte-for-byte. Recorded in `error_memory.md` as ERR-005. **Do not retry this without first proving the styling survives** — the correct shape, if it is ever wanted, is `[username] style_user = "fg:#090c0c bg:#a3aed2"` with `$username` placed outside any text group, checked with `starship prompt | cat -v | grep -c '48;2;'` rather than by confirming the string `julry` still appears.
- **REVIEW-053 — hardcoded `/home/julry` paths.** Seventeen tracked files carried the original machine's path. Re-checked individually rather than by count: the four COSMIC config files are rebased by `cosmic/setup.sh` §6, `common/.bashrc` and `gnome/dconf/dash-to-panel.dconf` were already in their scripts' rebase lists — and `common/.config/fastfetch/config.jsonc` was **not**, in any of the three scripts, so a restore onto another account left the fastfetch logo pointing at a nonexistent `Documents/` file. The fastfetch config is now in all three rebase lists. The remaining occurrences are the literal search-and-replace strings inside the scripts themselves, the rebase verification `grep -l '/home/julry'`, and documentation that *describes* the rebase — all correct. The one un-rebased payload left is `xfce/.config/xfce4/…/xfce4-keyboard-shortcuts.xml`, which carries three live paths (the rofi launcher, the screen-dim script, and a `Pictures -c` argument); that file **is** already in `xfce/setup.sh`'s list.
- **REVIEW-059 — invalid strict JSON.** `opencode.json` and `.opencode/workspace.json` each ended with a `// c: worrie` comment *after* the closing brace, which `json.load` rejects. Both now parse. `workspace_id` and `project_name` were deliberately left as `linux-configs` — that is REVIEW-060, which the owner is handling personally. The two Zed files also fail strict JSON, but they use `//` comments *inside* the object, which Zed's JSONC parser accepts by design; not a defect, and not changed.
- **REVIEW-061 — `AGENTS.md` incomplete path table.** It listed `.opencode/rules/` and `.opencode/memory/` without naming their contents, and omitted `.opencode/archives/` entirely. All three are now enumerated file by file.
- **REVIEW-086 — "Seven optimizations", five delivered.** `gnome/setup.md` §1 has five subsections (1A, 1D–1G; 1B GRUB and 1C ext4-reserve are absent because this is a btrfs/systemd-boot install, which the script states). Header now says Five. `xfce/setup.md` genuinely has seven (1A–1G) and is correct.
- **REVIEW-085 — header contradicted its own list.** `gnome/setup.md` §3 was headed "GNOME Shell Extensions (dash-to-panel only)" and then listed three IDs. Now headed "(3 enabled)".
- **REVIEW-063 — group-writable fastfetch config.** `common/.config/fastfetch/config.jsonc` was `0664` on disk. **This cannot be fixed in the repository:** git tracks only the executable bit, so a clone always checks out `0644` regardless of the working tree's mode. The local file was corrected to `0644` and the finding closed on that basis — the discrepancy was never representable in the index, which is why the original wording ("group-writable while git records 0644") described something no commit could ever fix.
- **REVIEW-056 — `xfce/setup.md` reads as Mint-only.** The document is genuinely written in apt/dpkg throughout (36 `apt` references across nine sections), while `xfce/setup.sh` supports both Ubuntu-family and openSUSE-family. Rewriting 36 command blocks into a dual-dialect document risks getting package names wrong in both branches — the zypper equivalents differ (`zram-tools` vs `zram-generator`, `lightdm-slick-greeter` vs `cosmic-greeter`). The title no longer claims Mint-only, a banner now says the commands are the apt branch and points Tumbleweed users at `setup.sh`, and §0 states the substitution explicitly. This documents the asymmetry rather than hiding it.

**Prevention Strategy**: Documentation defects cluster by type, and each type has one cheap check. A path is checkable with `[ -e "$path" ]`. A count is checkable by counting. A version string is checkable with `uname -r` — and on a rolling-release distro any version written into a doc decays on its own, so a maintenance procedure must show the reader how to re-derive it rather than hand them a number to trust. The one that bit hardest here was the prompt fix: substituting a config variable for a literal is not the same as making the variable render, and the only way to know was to run it. Every change in this batch that altered behaviour rather than prose was verified by executing it, not by re-reading the diff.

---

### [RESOLVED] Batch C — three security findings that did not survive verification against the live repo (REVIEW-029, 032, 081)

Re-verified October 12, 2026. None of the three produced a code change, for three different reasons: one had already been empirically disproven by a successful push, one described code that does not exist in the repo, and one was never a secret. Closing them here rather than leaving them to be "fixed" against a premise that turned out to be wrong.

- **REVIEW-029 — 24 `sk-`-shaped strings in committed transcripts.** The finding predicted these "will hard-fail secret scanning" and block pushes. **They have already been pushed.** `origin/main` is `github.com/worriee/linux-dotfiles.git` and `git grep -cE 'sk-[A-Za-z0-9]{20,}' origin/main -- sessions/` returns a hit in `session-oct-10.md`, `session-oct-8.md`, `session-oct_6.md` and `session-oct_6-1.md` — all four are in the public remote's history right now. GitHub push protection and secret scanning both ran over that push and passed it. The empirical test has already happened and the prediction was wrong. The matches were also confirmed false positives on inspection: every one is the tail of an SVG attribute dump, e.g. `...font-stretchmask-clipclipPathUnitsfont-variant...`, where `sk-clip` sits inside `mask-clip`. Six distinct strings, all `mask-<attribute>` concatenations, one line per file. The recommended `.gitattributes` with `sessions/* -diff` was **not** added: `-diff` only suppresses diff rendering and does nothing against push protection, so it would have been a change that looks like a mitigation and is not one. REVIEW-040 separately records the owner's decision to keep the transcripts, so the only real remedy — removing them — remains out of scope by that decision.
- **REVIEW-032 — unpinned third-party kernel module built as root.** **This entry described code that does not exist in this repo.** It cited `xfce/setup.sh:381-392` and a `git clone --depth=1` of an unpinned branch. The MT7902 driver path vendors its sources in-repo at `xfce/drivers/mt7902/{mt7902-wifi,mt7902-bt}/`, each with a `dkms.conf` carrying `PACKAGE_VERSION="1.0"`, and the installer copies them with `sudo cp -r "$REPO/drivers/mt7902/..."` before `dkms install -m mt7902-wifi -v 1.0`. There is no clone and no floating ref in that block — the version is pinned by `dkms.conf` in the tree. The `git clone --depth=1 https://github.com/frederik-h/acer-wmi-battery.git /tmp/acer-wmi-battery` that REVIEW-032 describes is the **Acer battery** block, which is REVIEW-111 at its current lines 473-484; the line numbers in REVIEW-032 were captured before several earlier edits shifted them, and the finding was written against the wrong block. REVIEW-032 is therefore a stale duplicate of REVIEW-111 and is closed with it.
- **REVIEW-081 — spotatui commits a playlist ID and a 161-track manifest.** One playlist, `2npedfnskpte`, 648 lines, already pushed to the public remote. A YouTube playlist ID is not a credential: it is the identifier in the URL of a playlist anyone can already view, and it grants no access beyond what the link itself gives. The track manifest is a cache of titles the tool re-fetches. This is a privacy preference about publishing listening history, not a vulnerability, and there is no secret to remove. Left in place; the remedy if the owner ever wants it is to drop `youtube_playlists.yml` from the repo and let spotatui rebuild it locally.

**Prevention Strategy**: A security finding is a claim about what a system will do, so it has to be tested against that system before it is carried as open. REVIEW-029 asserted an outcome ("will hard-fail") that a completed push had already contradicted; REVIEW-032 asserted a defect in a code path that did not exist, because its line numbers were never re-validated after the file was edited around them. Both survived two review passes because the log records the reasoning rather than the evidence. The habit that catches this is cheap: for any claim of the form "X will fail" or "X is unpinned", run the one command that settles it — `git grep` against the remote, or re-derive the line number and read the block — and paste the result into the finding. A finding whose file:line no longer resolves is not a finding, it is a stale pointer.

---

### [RESOLVED] Batch B — a fresh machine now gets every asset the configs reference (REVIEW-028, 107, 108, 109, 110)

Five findings, all the same root cause: assets that the shared config references lived in a DE-specific tree, so the installers that copy `common/.config` were restoring configs whose assets no one had installed. Fixed October 12, 2026. The three setup scripts were already structurally correct — each had a guarded `cp -rb "$COMMON_DIR/…"` block for `.config`. Batch B extended that same pattern to `.local`, `assets` and `wallpapers` rather than adding anything new.

- **REVIEW-107 — Nerd Fonts reachable only to XFCE.** The four JetBrains Mono Nerd Font TTFs sat at `xfce/.local/share/fonts/` and `xfce/setup.sh` was the only script that copied them, while `gnome/setup.sh:191` and `cosmic/setup.sh:400` both claimed in prose that fonts came from the XFCE tree. Neither ever read it. A fresh COSMIC or GNOME box therefore restored kitty, fastfetch and starship configs that all reference Nerd Font glyphs with no Nerd Font installed. The tree moved to `common/.local/share/fonts/` and all three scripts now copy it before restoring any config.
- **REVIEW-108 — wallpaper move was half-applied.** The owner had moved `wallpapers/bg1.jpg` to `common/wallpapers/` because it is used across all three DEs, but no script copied it and six documentation lines still claimed the image was absent from the repo. Every installer now copies `common/wallpapers/` to `~/wallpapers/`, which is where the restored COSMIC config and the slick-greeter both point. The `README.md` rows and all four `cosmic/setup.md` claims were corrected. The file also remains untracked and needs `git add` by the owner.
- **REVIEW-110 — fastfetch logo unreachable outside GNOME.** `common/.config/fastfetch/config.jsonc:5` points at `/home/julry/Documents/jm-icon.png`; the image was vendored at `gnome/assets/jm-icon.png` and only `gnome/setup.sh` copied it there. COSMIC and XFCE installed the shared fastfetch config without the asset, so the logo silently fell back to the default. The image moved to `common/assets/jm-icon.png` and all three installers now place it in `Documents/`, where the dash-to-panel dconf dump also expects it.
- **REVIEW-109 — twelve non-script files at mode 0755.** `git ls-files -s | grep '^100755'` returned 26 entries, of which twelve were Markdown and JSON data files that are never executed: `AGENTS.md`, `opencode.json`, `common/.config/zed/keymap.json`, five `.opencode/archives/*.md` and four `.opencode/memory/*.md`. All twelve are now `644` in the working tree; the mode change lands in the index on the owner's next `git add`. This extends REVIEW-076, which was logged against two files and captured four of the twelve.
- **REVIEW-028 — slick-greeter wrote an unconditional config for a deleted wallpaper.** `xfce/setup.sh` tested for `xfce/background.jpg`, which was deleted in commit `0b970457`, warned, and then wrote `/etc/lightdm/slick-greeter.conf` anyway with an unconditional `OK` — so a fresh XFCE install got a greeter pointing at a file that was never installed. The greeter step now takes its wallpaper from the freshly copied `~/wallpapers/` tree, and when none is found it says so plainly instead of claiming success.

**Prevention Strategy**: A config file and the assets it references are one unit, and the copy step that installs one without the other is worse than installing neither — it produces a config that looks applied and silently falls back at runtime. The rule that generalises: when a file is shared across desktops, everything it points at by path is shared too, and it ships in the same directory. REVIEW-053 flagged 20+ hardcoded `/home/julry` paths as a MEDIUM cosmetic issue in the same repo where three assets sat in the wrong tree and no installer could reach them; a path count is not a measure of impact. Severity should follow what breaks on a fresh machine, not how many lines mention it.

---

### [RESOLVED] Batch A — setup scripts stopped reporting failures that were not happening (REVIEW-071, 072, 073, 074, 075, 105)

Six findings in the installer scripts, fixed October 12, 2026. Five were the "the script lies about system state" class; one was a portability crash. The sharpest was 105: all three installers verified zram on every run using a binary that is not on the user PATH, so the check could never succeed and every run appended a false `zram verify` failure.

- **REVIEW-105 — `zramctl` called unprivileged.** The binary is `/usr/sbin/zramctl`; this machine's user PATH has no `/usr/sbin` (`command -v zramctl` returns nothing). `2>/dev/null` swallowed the "command not found" text, so `zramctl --noheadings --output ALGORITHM | grep -qi zstd` always evaluated false. All three scripts therefore printed `zram config written but zstd not active — reboot` and appended `zram verify` to `FAILED_STEPS` on **every run**, against a zram that was working correctly (verified live: `/sys/block/zram0/disksize` = 7511998464). Six call sites at `gnome/setup.sh:273,282`, `xfce/setup.sh:286,295`, `cosmic/setup.sh:159,168` now use `/usr/sbin/zramctl`, matching the pattern already used correctly for `sysctl` in `common/.bashrc:135`.
- **REVIEW-071 — `pkg_in()` defined and never called.** `gnome/setup.sh` defined the helper at line 46 while installing packages through an inline `bash -c 'sudo zypper -n ref && sudo zypper -n in ...'` string, leaving dead code and a second divergent install path. The install now routes through `pkg_in`, which absorbed the metadata refresh; the inline string is gone.
- **REVIEW-072 — `sudo zypper se` inside a per-package loop.** Nine (GNOME) and twelve (XFCE) iterations each ran a full privileged repo query — repeated metadata work and repeated credential prompts for a purely informational dry-check. Both scripts now do one `sudo zypper -n ref` up front and then probe unprivileged, since `/var/cache/zypp/raw` is world-readable (`755`, verified). Measured on this machine: a single unprivileged `zypper se` resolves in ~4.8s against the existing cache, with no refresh and no prompt.
- **REVIEW-073 — multi-unit `systemctl disable --now`.** `systemctl disable --now cups.service cups.socket avahi-daemon.service avahi-daemon.socket` returns non-zero if **any** named unit is absent, so on a machine without Avahi three units disabled correctly and the script still emitted a `WARN` plus a `FAILED_STEPS` entry. `gnome/setup.sh` now checks each unit with `systemctl list-unit-files` and disables it individually, reporting disabled and not-present sets separately. Genuine per-unit failures still record a `FAILED_STEPS` entry, now naming the unit that actually failed.
- **REVIEW-074 — `REPO` resolution under `set -u`.** `dirname "${BASH_SOURCE[0]}"` aborts with an unbound-variable error when the script is piped (`curl … | bash`) or fed via stdin, because `BASH_SOURCE[0]` is unset in those cases. All three scripts now use `${BASH_SOURCE[0]:-$0}`, which is the same fallback `COMMON_DIR` already used.
- **REVIEW-075 — `systemctl restart dev-zram0.swap`.** Restarting the swap unit does not recreate `/dev/zram0` with the new compression settings, so the line could never make the following `zramctl` verification succeed — it only added a failure path. The restart was removed from the install path in all three scripts and replaced with a plain statement that a reboot is required, plus the manual `zramctl` command to check afterwards. The `rest` alias in `common/.bashrc:134` is unchanged: restarting swap plus the display manager is a legitimate user-initiated reboot substitute.

**Prevention Strategy**: A verification step that cannot succeed is worse than no verification step — it manufactures false failures that train the reader to ignore the summary. Two rules follow. First, a privileged binary is called by absolute path in an installer that runs unprivileged; `command -v` succeeding on the author's shell is not evidence that the binary is reachable from the script. Second, any tool whose contract is "all of these or nothing" (`systemctl disable` across a unit list) must be decomposed per item when the units are independently optional. REVIEW-089 predicted both the 105 and 073 classes from a three-line symptom and sat at LOW severity for too long — a log entry's severity reflects when it was written, not what it eventually costs.

---

### [RESOLVED] Verified fixed on re-audit — Batch 3 and the `common/` consolidation (REVIEW-030, 031, 033, 035, 046, 047, 048, 049, 050, 051, 052, 055, 094, 095)

These fourteen were repaired during the October 11, 2026 batches but were retained in Section 1 as status stubs, which made the log report them as open. Re-verified against the repo on October 12, 2026, 10:12 AM PST before migrating; all fourteen confirmed fixed.

- **REVIEW-030 / 095 — `.bashrc` guard and alias naming.** The install guard compared a marker string instead of content, so after the first run no later `.bashrc` edit could ever land; a companion `sed` deleted the user's own alias and re-appended it renamed, and the README documented a `fresh` alias plus three `batt*` aliases that exist nowhere (`grep -c batt` → 0). The guard now compares content (`cmp -s "$COMMON_DIR/.bashrc" "$HOME_DIR/.bashrc"`), the installers write `alias rest=` matching the shipped file, the `sed` removes only the `# distro-fresh-alias` marker, and the README's false claims are gone. `grep -c 'alias fresh='` → 0 across all three files.
- **REVIEW-031 — unpinned `curl | sh`.** `curl -sS https://starship.rs/install.sh | sh` had no `-f`, so an HTTP error body was piped into a shell and the step still printed `OK`. Both installers now use `curl -fsSL -o "$_SH_TMP"`, verify the download is non-empty, and `rm -f` the temp file on both paths. `grep -c 'curl -sS'` → 0.
- **REVIEW-033 — dead directory at the front of `PATH`.** `common/.bashrc:123` prepended `/home/julry/.opencode/bin`, which does not exist — a binary-hijack vector on any shared account. Line deleted; `grep -c 'opencode/bin'` → 0.
- **REVIEW-035 — `A && B || C` misreported copy failure.** `[ -d src ] && cp … || WARN "missing"` printed "missing" when the *copy* failed, sending the user to the wrong cause. Both XFCE copies converted to `if/else` with distinct "copy failed" and "missing" messages. The 187MB icon-recopy half became moot when `xfce/.icons/` was deleted.
- **REVIEW-046 — predictable `/tmp` state file.** `/tmp/.screen_dim_toggle_state` is a name any local user can pre-create to break the brightness toggle. Now `${XDG_RUNTIME_DIR:-/tmp}/…` (per-user, mode 0700), plus an explicit exit when the `xrandr` display lookup finds nothing. `grep -c` → 0.
- **REVIEW-047 — DKMS copy nested on re-run.** `cp -r src /usr/src/mt7902-wifi-1.0` copies *into* an existing destination, producing `…/mt7902-wifi-1.0/mt7902-wifi/…` and breaking `dkms install`. Destinations are now cleared first.
- **REVIEW-048 — always exit 0.** Both scripts reported success even when every step failed, so any wrapper or CI job saw green on a total failure. Both now test `${#FAILED_STEPS[@]}` before the final `exit 0`.
- **REVIEW-049 — path rewrite hid its errors.** `sed -i … 2>/dev/null || true` followed by an unconditional `OK` printed success even when no target existed. Rewritten to model the working version in `cosmic/setup.sh`: short-circuit when `HOME_DIR` is already `/home/julry`, verify the rewrite landed, and record `FAILED_STEPS` on failure.
- **REVIEW-050 / 051 / 052 — duplicated files.** Three byte-identical `.bashrc` (git blob `6e6f15cc`), three identical `fastfetch/config.jsonc` (blob `2bd2cf39`), and two identical 21KB spotatui manifests. The duplication had already produced four separate drift bugs. All consolidated into `common/`; `find` now returns exactly one `.bashrc`, one fastfetch config, and one playlist manifest in the repo. `gnome/setup.sh` and `xfce/setup.sh` copy from `COMMON_DIR` before their DE-specific pass.
- **REVIEW-055 — repo drifted from live.** `common/.config/zed/settings.json` carried `"dark": "Transparent Prism - Sunset"` while live had `"dark": "Ayu Glass Dark"`; a September 2026 review had fixed this once and it drifted back. Now byte-identical to live, and the other shared files (kitty, starship, fastfetch, `.bashrc`) were verified already converged.
- **REVIEW-094 — plugins unbacked.** The OpenCode tree was untracked, so the documented backup did not exist in the repo. Now consolidated at `common/.config/opencode/` with `opencode.jsonc`, `plugins/{rtk,caveman}.ts` and the caveman skill.

**Prevention Strategy**: A marker string cannot distinguish "already up to date" from "written once and never updated again" — an idempotency guard must compare the thing it guards. A file vendored in N places is N bugs waiting to happen; this repo produced four before the consolidation. And a fix that is never migrated out of Section 1 is indistinguishable from an unfixed one, which is why a periodic re-verification against the repo — not against the log — is the only reliable way to know what is actually still broken.

---

### [RESOLVED] Autostart grants root permanent X11 access — kept by owner decision (REVIEW-027)

- **The Issue**: `cosmic/.config/autostart/xhost-root.desktop` runs `Exec=xhost +si:localuser:root` at every login and nothing ever revokes it with `xhost -SI:localuser:root`. Any local X client bug — image decoding, clipboard, fontconfig, browser rendering — would execute as root for the life of the session. A second copy of the same grant sits in the archived `sway/.config/sway/config:276`.
- **The Resolution**: Kept deliberately by the repository owner on October 11, 2026. No code change. Required for the YaST GUI, which needs root X access to draw, and COSMIC is the daily driver where that workflow is actually used.
- **Compensating Control**: Documented in `cosmic/setup.md` §9 alongside the on-demand alternative (`xhost +SI:localuser:root` immediately before the privileged launch, `-SI` in a trap after), so the exposure is recorded rather than accidental.
- **Prevention Strategy**: A permanent privilege grant should be a decision with a written rationale, not a config that exists because it was added once. If the YaST workflow ever changes, this is the line to revisit first.

---

### [RESOLVED] Sway idle lock commented out while docs promise a 900s lock — archived DE (REVIEW-036)

- **The Issue**: `sway/.config/sway/config:46-48` is entirely commented out — no `swayidle` process ever starts. The prose directly below it at lines 50-51 states "Locks after 900s (15min) idle", and `sway/README.md:13-14` lists "idle lock 900s" as a feature. An unattended sway session would stay unlocked indefinitely while two documents claim otherwise.
- **The Resolution**: Kept by the repository owner on October 11, 2026. No code change. Sway was removed from the live system; `rpm -q sway` returns not installed and the entire toolchain (swaylock, swayidle, waybar, wofi, mako, grim, slurp, brightnessctl, playerctl) is absent. The config is retained as a historical record only and cannot be started on this machine.
- **Compensating Control**: `sway/README.md` carries an ARCHIVED banner naming every absent package, so the false claim is marked as historical rather than offered as current behaviour.
- **Prevention Strategy**: When a config is archived, comments describing disabled behaviour must be marked as disabled at the point of the comment, not only in a README far away — a reader who opens `config` alone should not believe a lock exists.

---

### [RESOLVED] WiFi passphrase visible in `nmcli` argv — archived DE (REVIEW-037)

- **The Issue**: `sway/.local/bin/wifi-menu.sh:24-25` captures the passphrase with `wofi --password` and passes it as `nmcli device wifi connect "$SSID" password "$PASS"`, putting the PSK in `/proc/<pid>/cmdline` and in `ps` output for the lifetime of the call, readable by any local user.
- **The Resolution**: Kept by the repository owner on October 11, 2026. No code change. Sway is archived and uninstalled, so the script is never executed. The safe alternative (`nmcli --ask device wifi connect "$SSID"`, letting nmcli prompt itself and keeping the secret out of argv) is recorded here should the config ever be revived.
- **Compensating Control**: None needed while the package is absent; the fix is documented for the case where sway is restored.
- **Prevention Strategy**: Never pass a secret as a command-line argument — argv is world-readable through `/proc` for the life of the process. Use a prompt, a file with restrictive permissions, or stdin.

---

### [RESOLVED] 13 AI transcripts, 3.6MB, committed to a public repo — kept by owner decision (REVIEW-040)

- **The Issue**: All 13 `sessions/*.md` files are tracked. `session-oct-10.md` alone is 8,092 lines / 451KB. They are conversation transcripts, not configuration — 827 hardcoded `/home/julry` path references and every debugging dead-end. A `git add -A` from a fresh clone would pull 3.6MB of non-config, and they permanently widen the blast radius of any future `grep`.
- **The Resolution**: Kept deliberately by the repository owner on October 11, 2026, as the personal record of how this dotfiles repo was built. No code change. They are the primary source for much of the drift analysis in this log.
- **Compensating Control**: The 24 `sk-`-shaped strings these files contain (REVIEW-029) are confirmed false positives — concatenated SVG `mask-*` attributes from a resvg glyph dump — but they remain a secret-scanner trip risk on a public remote.
- **Prevention Strategy**: Non-configuration content in a config repo needs a deliberate decision and a stated rationale. Keeping it is fine; keeping it accidentally is not.

---

### [RESOLVED] `xfce/setup.md` claims the Acer battery driver is loaded — Mint-era doc (REVIEW-057)

- **The Issue**: `xfce/setup.md` states "**Current state (this machine):** driver is installed and loading at boot" and documents `batt80` / `batt100` / `battstat` aliases reading `/sys/bus/wmi/drivers/acer-wmi-battery/health_mode`. On the live system `lsmod | grep -i acer` shows only `acer_wmi`, `acer_wireless` and `wmi-bmof` — there is no `acer-wmi-battery` module, and `/sys/bus/wmi/drivers/` contains only `wmi-bmof`. Every documented alias would fail.
- **The Resolution**: Kept by the repository owner on October 11, 2026. No code change. The document is a Linux Mint / Ubuntu-era guide; the machine runs openSUSE Tumbleweed, where GNOME's equivalent doc correctly records the driver as skipped. The claim is wrong for Mint too, but it describes a machine that does not exist here.
- **Compensating Control**: None. `gnome/setup.md:164` states the accurate position for the platform actually in use.
- **Prevention Strategy**: A "current state (this machine)" claim is an assertion about live hardware and must be re-verified whenever the platform changes — or removed, because it decays silently.

---

### [RESOLVED] MT7902 DKMS shown as live procedure while the doc calls it deprecated — Mint-era doc (REVIEW-058)

- **The Issue**: `xfce/setup.md` §2A is written as an active 6-step DKMS install, while a deprecation note 60 lines later says the opposite, and the summary table claims "Wi-Fi + BT work on MediaTek 7902 cards". On the live system the in-kernel `mt7921e` driver is loaded and `dkms` is not installed at all.
- **The Resolution**: Kept by the repository owner on October 11, 2026. No code change. MT7902 works out of the box on Tumbleweed via the in-kernel driver, so the procedure is irrelevant to the platform in use; `gnome/setup.md` handles the same section correctly as fully deprecated.
- **Compensating Control**: The inaccuracy is confined to the Mint-oriented guide. The internal contradiction between §2A and its own summary table remains documented rather than silently edited.
- **Prevention Strategy**: A procedure and its own deprecation note in the same file is a contradiction a reader will resolve wrongly. When a path is deprecated, the procedure moves to an appendix — it does not stay in the main flow with a caveat below it.

---

### [RESOLVED] `workspace.json` identity names a project that no longer exists — owner to change (REVIEW-060)

- **The Issue**: `.opencode/workspace.json:3-4` sets both `workspace_id` and `project_name` to `linux-configs`, while the repo directory, the git remote and the README all say `linux-dotfiles`. `.clinerules` §OBSIDIAN SYNC mandates using the exact `project_name` to build the vault mirror path, so `-obsidian` would mirror into a directory corresponding to nothing in this repo.
- **The Resolution**: Deferred to the repository owner, who will make the change personally. No automated fix was attempted. `.clinerules:118` forbids the AI from editing workspace identity fields after init — `template_version` during `-update` is the sole exception.
- **Compensating Control**: The mismatch is recorded here so a later `-obsidian` run is known to produce a `linux-configs/` path until the owner corrects it.
- **Prevention Strategy**: Identity fields in a config file are load-bearing for every path-building consumer. They must be renamed together with the thing they name, in the same change that renames the thing.

---

### [RESOLVED] 187MB icon theme removed; repo cut from 43,797 files to 884 (REVIEW-039)

- **The Issue**: `xfce/.icons/` was a vendored WhiteSur icon theme totalling 187MB across 43,099 files — 98.5% of every tracked file in a repo whose real configuration is roughly 60 files. The working tree was 205MB and `.git` carried 44MB including 5.38 MiB of orphaned garbage from an aborted gc. With no root `.gitignore`, the `git add -A` that `xfce/fresh-install.md:130` instructs would also have swept in the `*.log`, `*.bak` and `*~` files both installers generate via `cp -b`.
- **The Resolution**: All three WhiteSur themes were removed from the repo and committed in `936ea2e1`, which deleted 234,158 lines. `xfce/setup.sh` lost its unconditional 187MB copy step and now carries a comment pointing at `setup.md` §0 instead; `setup.md` §0 documents the theme as not vendored, with an install step and an explicit note that the upstream URL is unpinned on purpose. October 11, 2026. Verified after the restructure: `git ls-files | wc -l` returns 884 (was 43,797), `.git` is 40MB (was 187MB), and the working tree excluding `.git` is 81MB (was 205MB).
- **Residual**: A root `.gitignore` is still absent — only `.opencode/.gitignore` and two inside `xfce/drivers/` exist. Without one, a fresh `git add -A` can still sweep in `*.log`, `*.bak`, `*~` and `.cache/` produced by the installers' `cp -b` backups. Tracked as a separate follow-up rather than folded in here, because writing `.gitignore` was explicitly deferred by the owner.
- **Prevention Strategy**: Vendoring a large upstream asset into a config repo inverts the cost ratio — 43,000 files to maintain a theme that has a download URL. Vendor text; fetch binaries at install time. And a repo with no `.gitignore` has no guard against generated files at all, regardless of how disciplined the current workflow happens to be.

---

### [RESOLVED] README path drift and stale claims fixed; compaction block made schema-valid (REVIEW-038, 041, 042, 044, 045)

- **The Issue**: Five defects, four of them documentation drift and one a schema violation. `README.md` documented a pre-rename repo layout: every Getting Started command invoked `xfce-setup/setup.sh` or `gnome-setup/setup.sh`, neither of which existed, so the file described zero working setup paths; all 29 Contents rows carried the dead prefix; both clone blocks used the retired `linux-configs.git` URL and `cd linux-configs`; `sway/` was presented as a live setup despite none of its packages being installed; and COSMIC — the actual daily driver — was never mentioned at all. Separately, every `opencode.jsonc` carried a `compaction` block using four keys (`threshold`, `strategy`, `preserveRecentMessages`, `preserveSystemPrompt`) that the OpenCode 2.x schema rejects under `additionalProperties: false`.
- **The Resolution**: README rewritten October 11, 2026 — path prefixes corrected, clone URL and `cd` target fixed, COSMIC added as daily driver with GNOME named as the deliberate fallback, sway marked ARCHIVED, `sessions/` and `wallpapers/` given rows, Hyprland/ML4W recorded as tried-and-removed, per-DE swappiness stated explicitly, icon theme moved to a "Not vendored" section, and a "no license granted" line added under the title. `sway/README.md` gained an ARCHIVED banner naming every absent package. The compaction block was replaced with schema-valid `auto` + `tail_turns` in all three DE copies and the live config. October 11, 2026, 08:08 PM PST. Verified: zero `xfce-setup`/`gnome-setup` references and zero `linux-configs` references in README; ARCHIVED banner present; 5 COSMIC mentions; zero occurrences of `threshold` or `preserveRecentMessages` in any `opencode.jsonc`.
- **Prevention Strategy**: After a directory rename, grep every doc for the old path prefix — the rename touched the tree but never the prose, and no test caught it. When documenting a directory, verify each claimed path exists before writing the sentence. For config schemas, a field the loader rejects is silent: it produces a WARN in the log and no visible error, so validate against the published schema rather than assuming an unknown key is harmless.

---

### [RESOLVED] Installer correctness pass — `.bashrc` guard, PATH, curl, exit codes (REVIEW-030, 031, 033)

- **The Issue**: Three defects that would each silently break a fresh install. The `.bashrc` idempotency guard tested a marker string rather than content, so after the first run the copy was skipped forever and no later `.bashrc` edit could ever land. `common/.bashrc:123` prepended `/home/julry/.opencode/bin` to `PATH` — a directory that does not exist on this machine, sitting at the FRONT of `PATH`, which is a binary-hijack vector on any shared account, while the very next line already did the same thing correctly with `$HOME`. Both installers piped an unpinned `curl -sS` into `sh` with no `-f`, so an HTTP error body would be executed as a shell script and the step would still print `OK`.
- **The Resolution**: The guard now compares content (`cmp -s "$COMMON_DIR/.bashrc" "$HOME_DIR/.bashrc"`), so edits to the shared file actually propagate. The dead `PATH` entry was deleted from `common/.bashrc`. Both installers download starship with `curl -fsSL -o "$_SH_TMP"`, check the file is non-empty, run it, and `rm -f` the temp file in both the success and failure paths. October 11, 2026, 07:47 PM PST. Verified: `grep -c 'opencode/bin' common/.bashrc` → 0; `grep -c 'curl -sS'` → 0 in both scripts; `grep -c 'cmp -s'` → 1 in each; `bash -n` passes on all four scripts.
- **Prevention Strategy**: An idempotency guard must compare the thing it is guarding — content — not a marker that the same script writes. A marker string cannot distinguish "already up to date" from "written once and never updated again". Separately: never pipe a network response straight into an interpreter without `-f`; a 404 page is a valid shell script that does nothing and reports success.

---

### [RESOLVED] `A && B || C` misreported copy failure as a missing source (REVIEW-035)

- **The Issue**: `xfce/setup.sh` used `[ -d src ] && cp -rb src/. dest/ || WARN "src missing"` for its `.config` and `.themes` copies. Because `||` binds to the whole `&&` chain, a *failed copy* reported "missing" and sent the user looking in the wrong place. The finding also flagged an unconditional 187MB icon-theme recopy on every run — that half became moot when `xfce/.icons/` was deleted on October 11, 2026, and the copy line was removed in the same pass.
- **The Resolution**: Both copies converted to explicit `if [ -d … ]; then cp … || WARN "copy failed"; else WARN "missing"; fi`, so the failure reason is accurate. October 11, 2026, 07:47 PM PST. Verified: `grep -c 'copy failed' xfce/setup.sh` → 2.
- **Prevention Strategy**: `A && B || C` cannot distinguish "A was false" from "B failed" — the shell discards that information. When the two branches mean different things, write them as separate branches.

---

### [RESOLVED] Screen-dim state file and DKMS copy made safe and idempotent (REVIEW-046, 047)

- **The Issue**: The generated `toggle-screen-dim.sh` keyed its toggle state on `/tmp/.screen_dim_toggle_state`, a predictable world-writable name any local user could pre-create to force the victim into the wrong brightness branch; `rm -f` then failed silently on a file it did not own. The `DISPLAY_NAME` lookup was also unguarded, so no match produced `xrandr --output ""` with no error path. Separately, the MT7902 DKMS step used `cp -r src /usr/src/mt7902-wifi-1.0`, which copies *into* an existing destination — a second run produced `/usr/src/mt7902-wifi-1.0/mt7902-wifi/…` and broke `dkms install`.
- **The Resolution**: `STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/.screen_dim_toggle_state"` — per-user, mode 0700 — with an explicit `[ -z "$DISPLAY_NAME" ] && exit 1` guard. The DKMS step now clears `/usr/src/mt7902-{wifi,bt}-1.0` before copying. October 11, 2026, 07:47 PM PST. Verified: `grep -c '/tmp/.screen_dim_toggle_state'` → 0; `grep -c 'rm -rf /usr/src/mt7902'` → 1.
- **Prevention Strategy**: Anything with per-user state in a shared namespace belongs in `$XDG_RUNTIME_DIR`, never a fixed path in `/tmp` — a predictable name in a world-writable directory is a symlink-attack surface. And any `cp -r` into a directory that may already exist is not idempotent; remove or replace the destination first.

---

### [RESOLVED] Scripts exited 0 on total failure; path rewrite hid its own errors (REVIEW-048, 049)

- **The Issue**: Both `gnome/setup.sh` and `xfce/setup.sh` ended in an unconditional `exit 0`, so a run where zram, dconf, packages, and drivers all failed still reported success to any wrapper or CI job. Their path-rewrite step ran `sed -i "s|/home/julry|$HOME_DIR|g" … 2>/dev/null || true` and then printed `OK "paths rewritten"` unconditionally — the `|| true` swallowed every "can't read file" error, so the success message printed even when no target existed.
- **The Resolution**: Both scripts now end `[ "${#FAILED_STEPS[@]}" -gt 0 ] && exit 1` followed by `exit 0`, with a comment explaining that the step-collector pattern is sound but the exit code must reflect it. The path-rewrite block was rewritten to model the working implementation already in `cosmic/setup.sh`: short-circuit when `HOME_DIR` is already `/home/julry`, short-circuit when there are no target files, verify the rewrite landed with a follow-up `grep`, and append `path rewrite` to `FAILED_STEPS` on failure. October 11, 2026, 07:47 PM PST. Verified: the unconditional tail `exit 0` is preceded by the guard in both files; `grep -c 'HOME_DIR" = "/home/julry"'` → 1 in each.
- **Prevention Strategy**: An exit code is an API — a script that collects failures and then always exits 0 has silently disabled every caller that checks it. And `|| true` after a mutating command converts "it failed" into "it worked", which is worse than no error handling at all.

---

### [RESOLVED] Alias naming unified on `rest` across file, installers and README (REVIEW-095)

- **The Issue**: Three sources disagreed about one alias. `README.md` documented a `fresh` alias plus `batt80`/`batt100`/`battstat`, none of which exist — `grep -c batt` returns 0 across every `.bashrc` in the repo. All three DE copies defined `alias rest=...` with `fresh` appearing only inside the trailing comment, while both installers wrote a literal `alias fresh=` and a `sed` deleted `^alias fresh=` before re-appending, so the installer silently renamed the user's own alias on every run.
- **The Resolution**: The user chose `rest`. The installers in `gnome/setup.sh` and `xfce/setup.sh` now write `alias rest=`, and the marker comment is preserved because the cleanup `sed` relies on it. The README's false `batt*` and `fresh` claims were removed in Batch 1. October 11, 2026, 07:47 PM PST. Verified: `grep -c 'alias fresh='` → 0 in `common/.bashrc`, `gnome/setup.sh` and `xfce/setup.sh`; `alias rest=` still present in `common/.bashrc`.
- **Prevention Strategy**: Two naming conventions for one thing will drift, and here it had already produced a silent rewrite of the user's shell. When a script post-processes a file it also ships, it must never delete a line it did not author — the `sed` now removes only the `# distro-fresh-alias` marker and leaves the alias alone.

---

### [RESOLVED] Swappiness unified to 180 across all desktops, scripts, docs and live (REVIEW-034)

- **The Issue**: One knob had four different values. All three `.bashrc` files and `xfce/setup.sh` used `180`, but `gnome/setup.sh:123` rewrote the shipped `code` alias from `180` to `200` and `gnome/setup.sh:228` wrote `200` into `/etc/sysctl.d/99-swappiness.conf`. `gnome/setup.md` contradicted itself — line 39 wrote `200` while line 404 documented `180`. `README.md` described the split. Live ran `200`.
- **The Resolution**: Standardised on `180` — the conventional zram-first value, and correct given zram already holds 100% of RAM on this machine. Updated `gnome/setup.sh:123,228` (alias and drop-in, plus the step label), `gnome/setup.md:39,671`, and `README.md:80`. The user then applied it live: `/etc/sysctl.d/99-swappiness.conf` now reads `vm.swappiness=180` and `sysctl vm.swappiness` returns `180`. October 11, 2026, 06:59 PM PST. Verified: zero occurrences of `swappiness=200` remain anywhere in the repo; the only other value present is `10` in the four `game` alias definitions, which is deliberate.
- **Prevention Strategy**: One kernel tuning knob, one value, written in one place per installer. The `.bashrc` file and the installer both defining the same sysctl call is the root defect — the installer rewrites a line the config file already owns, so the two can silently disagree. Derive both from a single variable, or pick one owner and delete the other.

---

### [RESOLVED] Shared config consolidated into common/; per-DE duplicates deleted (REVIEW-050, 051, 052, 105)

- **The Issue**: Identical files were vendored as independent copies in every DE directory — three byte-identical `.bashrc` (git blob `6e6f15cc`), three identical `fastfetch/config.jsonc` (blob `2bd2cf39`), three identical 21KB spotatui playlist manifests, two identical kitty/starship/zed pairs, and two identical opencode trees. The duplication had already caused three separate drift bugs (REVIEW-034 swappiness, REVIEW-095 alias naming, REVIEW-038 compaction) because each copy needed a separate edit. There was no single source of truth.
- **The Resolution**: Created `common/` holding one canonical copy of all 21 shared files plus `detect-distro.sh`, and rewired `gnome/setup.sh` and `xfce/setup.sh` to copy from `COMMON_DIR` before their DE-specific copy. `git mv` recorded 8 renames (all R100, byte-identical); the 6 untracked opencode files were moved with plain `mv` because git refuses to rename untracked paths. Then, at the user's direction, `opencode.jsonc` was consolidated fully: the `provider`/`models` block was stripped from the live config and from every backup, the three per-DE copies were deleted, and the DE directories removed. `cosmic/setup.sh` and `cosmic/setup.md` were corrected — the guide had claimed the models block was the reason the file was per-DE, which the change invalidated. October 11, 2026, 07:25 PM PST. Verified: zero model strings and zero `REPO/.config/opencode` references remain in `cosmic/ gnome/ xfce/ common/ README.md`; `bash -n` passes on all three scripts.
- **Prevention Strategy**: When the same file appears in N places, it is N bugs waiting to happen — this repo produced four of them before the consolidation. A single source plus per-DE deltas is the only arrangement that stays correct. When moving shared files out of a directory that an installer copies wholesale, the script's path references MUST be updated in the same commit, or the installer silently restores nothing.

---

### [RESOLVED] Repo copies drifted from the live home configs they mirror (REVIEW-055)

- **The Issue**: `gnome/.config/zed/settings.json:131` in the repo carried `"dark": "Transparent Prism - Sunset"` while live had `"dark": "Ayu Glass Dark"`, so restoring the repo would silently revert a live theme change. A September 2026 review had resolved this once (REVIEW-010) by copying live into the repo; it drifted back.
- **The Resolution**: The consolidated `common/.config/zed/settings.json` now matches `~/.config/zed/settings.json` byte-for-byte. Verified the rest of the shared tree had not drifted either — `kitty.conf`, `kitty/current-theme.conf`, `starship.toml`, `fastfetch/config.jsonc` and `.bashrc` were already identical to live. October 11, 2026, 07:25 PM PST.
- **Prevention Strategy**: A dotfiles repo that mirrors live files is only correct at the moment of copying. The same September 2026 fix had already been applied once and undone, so the durable answer is not re-copying on demand — it is having exactly one copy, so there is nothing to drift. That is what REVIEW-050/051/052/105 addressed.

---

### [RESOLVED] opencode config row claimed jsonc only; plugins now backed up (REVIEW-094)

- **The Issue**: `README.md` described the gnome opencode directory as holding `opencode.jsonc` only, while it also held the `rtk.ts` and `caveman.ts` plugins and the caveman skill — and those were untracked, so the backup claim was not actually backed by the repo.
- **The Resolution**: The OpenCode tree now lives entirely at `common/.config/opencode/` — one `opencode.jsonc`, `plugins/rtk.ts`, `plugins/caveman.ts`, and `caveman/SKILL.md` with its three command files. `README.md` was updated to point at the shared path and the duplication table reduced the entry from 2 copies to 1. October 11, 2026, 07:25 PM PST.
- **Prevention Strategy**: A documented backup that is untracked is not a backup. Verify with `git ls-files` that what the README promises is actually in the index, not just on disk.

---

### [RESOLVED] README accuracy pass — 13 findings (REVIEW-090 to 104)

- **The Issue**: The README documented a pre-rename repo layout. Both Getting Started commands invoked `xfce-setup/setup.sh` and `gnome-setup/setup.sh`, neither of which existed, so the file described zero working setup paths. All 29 Contents rows carried the dead prefix. COSMIC — the actual daily driver — was never mentioned. sway was presented as live despite none of its packages being installed. Additional drift: stale `linux-configs` clone URL, no LICENSE on a public repo, understated 187MB icon theme, swappiness stated as 180 when live is 200, 4 of 8 dconf dumps listed, typo on the title line.
- **The Resolution**: README rewritten October 11, 2026, 06:48 PM PST — now 81 lines. Path prefixes corrected, clone URL and `cd` target fixed to `linux-dotfiles`, COSMIC added as daily driver with GNOME named as the deliberate fallback, sway marked ARCHIVED, Hyprland/ML4W recorded as tried-and-removed, `sessions/` and `wallpapers/` given rows, per-DE swappiness stated explicitly (XFCE 180 / GNOME 200), all 8 dconf dumps listed, EarlyOOM summary corrected to the live `EARLYOOM_ARGS`, icon theme moved to a "Not vendored" section with the reason, and an explicit "no license granted" line added under the title. `sway/README.md` gained an ARCHIVED banner naming every absent package. One self-inflicted error was caught during verification and reverted: the first draft documented `cosmic/setup.sh` and `cosmic/.config/cosmic/`, neither of which exists yet — COSMIC was rewritten as config-only with an explicit warning that rebuilding a COSMIC machine from this repo is not currently possible.
- **Prevention Strategy**: After a directory rename, grep every doc for the old path prefix — the rename touched the tree but never the prose, and no test caught it. When documenting a directory, verify each claimed path exists before writing the sentence; a doc that lists files which were never created is the exact failure being fixed here.

---

> STRICT RULE: When a review finding in Section 1 is remediated, the AI MUST migrate it to this section within the SAME response using `### [RESOLVED] Short Review Description (REVIEW-XXX)`. All headers in this file are IMMUTABLE. Existing resolved entries MUST NOT be deleted, truncated, or rewritten. New resolved entries are prepended (LIFO) directly under the Section 2 header. The original REVIEW-XXX tracking number MUST be preserved in the resolved header. Failure to migrate immediately is a CRITICAL VIOLATION.

### [RESOLVED] Stale duplicate docs (REVIEW-026)

- **The Issue**: Map listed old root `background.jpg`, `fresh-install.md`, `mint-setup.md`; no GNOME entrypoint pointer.
- **The Resolution**: `codebase_map.md` tree + table rewritten to split layout (`xfce-setup/` + `gnome-setup/` with dconf/extensions/assets rows); timestamp September 13, 2026, 08:53 AM PST. Verified via read-back.
- **Prevention Strategy**: Refresh map on every repo restructure; grep for moved filenames before closing.

---

### [RESOLVED] Scripts block automation, weak guards (REVIEW-025)

- **The Issue**: Both scripts ended with blocking `read -rp`; XFCE bulk `cp -rb` unchecked. Breaks non-interactive runs.
- **The Resolution**: Both tails gated on `[ -t 0 ]` with non-interactive skip note; XFCE copies split into per-dir `[ -d ]` guarded lines (September 13, 2026, 08:54 AM PST). Verified `bash -n` ok both.
- **Prevention Strategy**: Gate every `read` on TTY; guard every bulk copy on `[ -d ]`.

---

### [RESOLVED] Hardcoded path rewrite incomplete (REVIEW-024)

- **The Issue**: GNOME path fix covered only `opencode.jsonc`; `/home/julry` remained in `.bashrc` + dconf dump.
- **The Resolution**: `gnome-setup/setup.sh` sed extended to `.bashrc` + `dconf/dash-to-panel.dconf` (September 13, 2026, 08:54 AM PST). Verified via grep.
- **Prevention Strategy**: Grep repo for `/home/julry` before closing portability reviews.

---

### [RESOLVED] Dconf icon path mismatch assets (REVIEW-023)

- **The Issue**: Dump pointed at `~/Documents/opensuse-icon.webp`; script never installed the asset.
- **The Resolution**: New `Panel app icon` step copies `assets/opensuse-icon.webp` to `$HOME/Documents/` with `cp -b`, warns + logs `FAILED_STEPS` when missing (September 13, 2026, 08:54 AM PST). Verified `bash -n` ok.
- **Prevention Strategy**: Every dconf-referenced absolute path needs an install step or rewrite.

---

### [RESOLVED] Background.jpg missing, cp unguarded (REVIEW-022)

- **The Issue**: XFCE login step ran unconditional `sudo cp "$REPO/background.jpg"`; file absent on fresh clone.
- **The Resolution**: Wrapped in `[ -f ]` guard — copies when present, else `WARN` + `FAILED_STEPS+=("wallpaper missing")` (September 13, 2026, 08:54 AM PST). Verified `bash -n` ok.
- **Prevention Strategy**: Guard every asset `cp` on `[ -f ]`; never assume vendored media.

---

### [RESOLVED] Fresh-install.md misplaced (REVIEW-021)

- **The Issue**: Guide lived in `.opencode/` tool dir; refs assumed sibling file.
- **The Resolution**: Confirmed already at `xfce-setup/fresh-install.md` (move predated audit); fixed stale `bash setup.sh` refs inside to `bash xfce-setup/setup.sh` + corrected both `setup.sh` header lines to per-DE paths (September 13, 2026, 08:54 AM PST).
- **Prevention Strategy**: Keep guides next to their scripts; fix internal command paths on move.

---

### [RESOLVED] One-command target missing (REVIEW-020)

- **The Issue**: `bash setup.sh` at root fails post-split.
- **The Resolution**: `xfce-setup/fresh-install.md:12,119` now `bash xfce-setup/setup.sh`; both `setup.sh` headers show per-DE commands; README shows both per-DE commands (September 13, 2026, 08:54 AM PST). Verified via grep.
- **Prevention Strategy**: Grep for bare `bash setup.sh` after any layout split.

---

### [RESOLVED] README stale root layout (REVIEW-019)

- **The Issue**: Table listed root-level scripts/assets; real layout is split `gnome-setup/` + `xfce-setup/`.
- **The Resolution**: README rewritten — split scope note, per-DE table rows, two clone commands, hardened-notes paragraph; refs updated to `xfce-setup/fresh-install.md` (September 13, 2026, 08:54 AM PST). Verified all linked paths exist.
- **Prevention Strategy**: Rewrite README table on every top-level move; verify each linked path exists.

### [RESOLVED] snapper snapshot per re-run (REVIEW-018)

- **The Issue**: Every re-run minted a `pre-dotfiles` snapshot, littering `snapper list`.
- **The Resolution**: Description date-tagged: `snapper create -d "pre-dotfiles $(date +%Y-%m-%d)"` (September 09, 2026, 04:02 PM PST).
- **Prevention Strategy**: Snapshot descriptions must carry dates.

---

### [RESOLVED] btrfs root printed misleading ext4 WARN (REVIEW-017)

- **The Issue**: On btrfs, findmnt SOURCE carries `[/@]`, lsblk failed, every TW run printed a scary "not ext4 — skipped" warning.
- **The Resolution**: Step rewritten — strips `[...]` suffix, explicit btrfs branch prints OK "reserve step N/A (snapper covers rollback)", ext4 branch unchanged (September 09, 2026, 04:02 PM PST).
- **Prevention Strategy**: Fstype checks must name btrfs explicitly; never infer from lsblk failure.

---

### [RESOLVED] pkg_sync() dead code removed (REVIEW-016)

- **The Issue**: `pkg_sync()` defined but step 2 inlined sync inside the run_step subshell; never called.
- **The Resolution**: Function deleted; `pkg_in()` retained and used (September 09, 2026, 04:02 PM PST).
- **Prevention Strategy**: Grep for callers before adding shell helpers.

---

### [RESOLVED] xrandr dep declared on TW (REVIEW-015)

- **The Issue**: Dim-toggle script needs xrandr at keypress time; TW XFCE pattern might not ship it.
- **The Resolution**: `xrandr` added to TW zypper pkg list + dry-check loop (September 09, 2026, 04:02 PM PST).
- **Prevention Strategy**: Runtime deps of generated scripts must be install-time packages.

---

### [RESOLVED] curl installed on both distros (REVIEW-014)

- **The Issue**: Starship/Brave/Zed steps pipe `curl`; Mint pre-installs it, TW XFCE might not.
- **The Resolution**: `curl` added to apt list and TW zypper list + dry-check loop (September 09, 2026, 04:02 PM PST).
- **Prevention Strategy**: Never assume fetch tools; declare them.

---

### [RESOLVED] ZRAM moved to verified zram-generator flow (REVIEW-013)

- **The Issue**: Config targeted /etc/systemd/zram-generator.conf with no guarantee the mechanism existed; fallbacks enabled unknown defaults silently.
- **The Resolution**: Web-verified (upstream systemd/zram-generator + TW forum Jan 2026 + SLES docs): TW pkg list now installs `zram-generator` (replacing `systemd-zram-service`), writes `[zram0] zram-size = min(ram)` + `compression-algorithm = zstd`, parks legacy `zramswap`, daemon-reload + enable `systemd-zram-setup@zram0` + start `dev-zram0.swap`, and ASSERTS post-state via `zramctl` (zstd active → OK; else FAILED_STEPS "zram verify"). TW `fresh` alias + fresh-install/docs updated to `dev-zram0.swap` (September 09, 2026, 04:02 PM PST).
- **Prevention Strategy**: Swap setup must assert via zramctl/swapon, never assume from config files.

---

### [RESOLVED] EarlyOOM guard uses policy signature (REVIEW-012)

- **The Issue**: `grep -q EARLYOOM_ARGS` matched vendor templates (TW fillup sysconfig VERIFIED to ship uncommented SUSE-default EARLYOOM_ARGS via OBS), so our avoid-zed/prefer-brave policy would silently never apply.
- **The Resolution**: Guard changed to `grep -qF "brave-browser"` — matches only our policy, both distros (September 09, 2026, 04:02 PM PST).
- **Prevention Strategy**: Idempotency guards must match our signature, never generic variable names.

---

### [RESOLVED] Kitty doc heredoc synced with live config (REVIEW-011)

- **The Issue**: S11B heredoc listed 7 kitty settings; live + repo kitty.conf have 4 more: `cursor_shape block`, `remember_window_size no`, `initial_window_width 900`, `initial_window_height 800`.
- **The Resolution**: Added the 4 lines (with comment markers) + explainer bullets to S11B, matching live kitty.conf byte-for-byte.
- **Prevention Strategy**: Doc heredocs should be diffed against live config during `-codebase` sync.

---

### [RESOLVED] Zed settings.json mirrored to live (REVIEW-010)

- **The Issue**: Repo `settings.json` had `"line_ending": "enforce_crlf"`; live uses `"detect"`.
- **The Resolution**: Copied live `~/.config/zed/settings.json` into repo (verified identical).
- **Prevention Strategy**: Mirror dotfiles to the repo after any manual settings change.

---

### [RESOLVED] opencode.jsonc mirrored to live (REVIEW-009)

- **The Issue**: Repo opencode.jsonc still carried the removed obsidian MCP block + `/home/julry` path; live version dropped it and fixed a trailing comma.
- **The Resolution**: Copied live `~/.config/opencode/opencode.jsonc` into repo (verified identical; setup.sh `/home/julry` sed still applies on install).
- **Prevention Strategy**: Keep `.config/opencode` in sync with live; treat doc mentions of MCP as historical.

---

### [RESOLVED] picom.conf mirrored to live, Plank artifacts removed (REVIEW-008)

- **The Issue**: Repo picom.conf had dormant Plank `opacity-rule` + old `fade-delta 8`/`steps 0.04`; live is clean (`opacity-rule=[]`, fade-delta 2, steps 0.02, `use-damage`, `no-fading-openclose`).
- **The Resolution**: Copied live `~/.config/picom/picom.conf` into repo (verified identical) — consistent with plank removal.
- **Prevention Strategy**: picom.conf should be mirrored from live; run a Plank-class grep on commit.

---

### [RESOLVED] Plank.desktop deletion staged for commit (REVIEW-007)

- **The Issue**: `Plank.desktop` deleted in worktree but still tracked in HEAD — a fresh clone would reinstall plank autostart.
- **The Resolution**: Deletion is in the worktree and staged with the review-fix batch; user commits it themselves.
- **Prevention Strategy**: Verify `git ls-files` for removed autostart entries before considering a removal done.

---

### [RESOLVED] .bashrc added to git tracking (REVIEW-006)

- **The Issue**: `.bashrc` backup was untracked — fresh clone would lose aliases (`fresh`, batt80/100/stat, starship hook) and setup.sh would WARN-skip.
- **The Resolution**: `.bashrc` is staged for commit with this fix batch; user commits it.
- **Prevention Strategy**: New repo backup files must be `git add`ed in the same session they are created.

---

### [RESOLVED] Rofi palette switched to gruvbox (REVIEW-003)

- **The Issue**: Doc + setup.sh claimed Gruvbox palette, but live AND repo `shared/colors.rasi` imported `onedark.rasi`.
- **The Resolution**: `colors.rasi` line 18 updated to `@import "~/.config/rofi/colors/gruvbox.rasi"` in both live `~/.config/rofi/` and repo copy. Doc S10A/10B + setup.sh already consistent.
- **Prevention Strategy**: Keep file state and docs in sync during a commit; re-audit `colors.rasi` import on future theme changes.

---

### [RESOLVED] Acer battery doc clarified to current 100% state (REVIEW-002)

- **The Issue**: Doc described driver installed with 80% limit active, but live `health_mode` = `0` (100% charge).
- **The Resolution**: User confirmed driver is installed and working; 100% limit is intentional for now. Added a "Current state (this machine)" note to S9 explaining limit is off by choice and how to re-enable via the `batt80` alias. Guide left intact.
- **Prevention Strategy**: Doc must separate "setup guide" from "current machine state" — annotate runtime state explicitly.

---

### [RESOLVED] Autostart section corrected — Plank removed, disabled apps fixed (REVIEW-001)

- **The Issue**: Doc listed Plank as checked/enabled (user had deleted plank); Update Manager + Warpinator listed checked but were `Hidden=true` disabled; undocumented Bitwarden entry present.
- **The Resolution**: Dropped `plank` from setup.sh packages, fresh-install.md, README autostart line; deleted repo `.config/autostart/Plank.desktop`; removed Plank from S6 checked list, command table, and restore prose (all checked apps are now system defaults); moved Update Manager + Warpinator to the Unchecked list to mirror live. Left dormant plank assets (.themes plank dock.theme, picom `class_g = 'Plank'` rules) untouched by design. Bitwarden autostart not documented (manual-app leftover).
- **Prevention Strategy**: Verify live planted state, then recount autostart checked/unchecked against `~/.config/autostart/` + `/etc/xdg/autostart/` before documenting.

---

### [RESOLVED] Keyboard shortcut table synced to live binds (REVIEW-004)

- **The Issue**: 4 stale rows: `Super+Return`→kitty (doc said x-terminal-emulator), close = `Super+q` (doc said `Super+w`), workspaces only 1–4 (doc said 1–5), plain arrows are cursor keys not workspace nav.
- **The Resolution**: S4 tables updated: `Super + Return` → "Open Kitty terminal (`kitty`)", `Super + 1..4`, `Super + q`, removed the `Left/Right/Up/Down` "Move between workspaces" row. Repo keybind XML already matched live — no XML change.
- **Prevention Strategy**: Generate keybind tables from the repo `xfce4-keyboard-shortcuts.xml` (single source of truth) instead of hand-writing.

---

### [RESOLVED] ext4 reserved space verified at 1% (REVIEW-005)

- **The Issue**: `tune2fs -l` needs root — reserve % unconfirmed; `df` math estimated ~1.2%.
- **The Resolution**: User confirmed root reserve is 1% on `/dev/nvme0n1p5`. No doc change needed.
- **Prevention Strategy**: Confirm root-reserve value during `-context` scans with `sudo tune2fs -l` when possible.

---

## 3. Review Summary Metrics

- **Total Reviews Conducted**: 5
- **Critical Findings**: 4
- **High Findings**: 21
- **Medium Findings**: 26
- **Low Findings**: 28
- **Last Review Date**: `October 11, 2026, 08:35 PM PST`
- **Current Split (October 12, 2026, after Batch G)**: **0 open · 53 resolved. The review log is closed.** Every finding from the original 63-finding October 11 audit plus the 8 added by the second `-r` pass has been either fixed, closed by owner decision, or closed after its premise failed verification. Nothing is pending.
- **Permanently out of scope — do not re-raise**: `sway/` (archived install record — 065, 077, 078, 079, 083, 088), the out-of-tree kernel-driver path in `xfce/setup.sh` (Mint-only — 106, 111), the personal shell workflow in `.bashrc`/fastfetch/kitty/lock-screen (062, 067, 068, 069, 070, 080, 082), and REVIEW-054 (prompt username — fix attempted, reverted, owner keeps the literal).
- **Batch history**: A migrated 6 (071, 072, 073, 074, 075, 105) · B migrated 5 (028, 107, 108, 109, 110) · C closed 3 with no code change (029, 032, 081 — every premise failed verification) · D migrated 11 (043, 053, 056, 059, 061, 063, 064, 084, 085, 086, 087) · E closed 10 with no code change (062, 066, 067, 068, 069, 070, 080, 082, 089, 112) · F closed 8 with no code change (054, 065, 076, 077, 078, 079, 083, 088) · G closed 2 with no code change (106, 111). Net code changes across all batches: 22 findings fixed, 31 closed without a code change.

---

## 4. ARCHIVE STATUS

- **Archive File**: `.opencode/archives/review_archive.md`
- **Threshold**: 10 active entries per section
- **Total Archived**: 0
- **Last Archive Check**: `Not yet performed`

| Entries Archived | Archived At (PST) |
| ---------------- | ----------------- |
| 0                | —                 |

<!-- c: worrie -->
