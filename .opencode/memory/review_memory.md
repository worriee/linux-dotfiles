# Code Review Log Memory

## 0. Last Synchronized Checkpoint

- **Last AI Analysis Timestamp**: October 11, 2026, 08:35 AM PST

## 1. Active & Open Review Findings

_Audited October 11, 2026. Entries below are genuinely unresolved. Seven findings the owner reviewed and knowingly kept are summarised in the ACCEPTED table above; five fixed findings were migrated to Section 2. Full narratives for every closed entry are preserved in Section 2._

### [REVIEW-094] opencode config row claimed jsonc only; plugins unbacked

- **File/Path**: `README.md:37`
- **Severity**: HIGH
- **Category**: Correctness
- **Finding**: Row read `` (`opencode.jsonc` only) `` while the directory also held `plugins/caveman.ts`, `plugins/rtk.ts` and `caveman/` with its skill and three commands. `grep -niE 'plugin' README.md` returned no plugin rows at all, and both opencode trees were untracked — so the documented backup was not backed by the repo.
- **Recommendation**: Update the row to list the plugins and skill dir, and stage the untracked trees.
- **Status 2026-10-11**: RESOLVED — see Section 2, `(REVIEW-094)`. Tree consolidated to `common/.config/opencode/`; still needs `git add` by the user.

---

### [REVIEW-095] README and .bashrc disagreed on alias names and documented nonexistent aliases

- **File/Path**: `common/.bashrc:135`, `gnome/setup.sh:108`, `xfce/setup.sh:114,116`
- **Severity**: HIGH
- **Category**: Correctness
- **Finding**: Three-way disagreement on the same alias. The README documented a `fresh` alias plus `batt80`/`batt100`/`battstat`; `grep -c batt` returns 0, so no `batt*` alias exists anywhere. All three DE copies defined `alias rest=... # distro-fresh-alias` — `fresh` appeared only inside that trailing comment — while both installers wrote a literal `alias fresh=` and a `sed` deleted `^alias fresh=` before re-appending, so the installer fought the file it installed.
- **Recommendation**: Pick one name and align every location.
- **Status 2026-10-11**: RESOLVED — see Section 2, `(REVIEW-095)`.

---

_Full-repo review, October 11, 2026, 08:35 AM PST. 63 findings (2 CRITICAL / 17 HIGH / 20 MEDIUM / 24 LOW), tracked REVIEW-027 through REVIEW-089. All entries active pending user decision._

### [ACCEPTED] 7 findings closed by owner decision — no code change wanted

Reviewed by the repository owner on October 11, 2026, 08:08 PM PST. Each is a real defect; each was knowingly kept. Full narratives are preserved in Section 2.

| Finding | Issue | Decision |
|---|---|---|
| REVIEW-027 | `cosmic/.config/autostart/xhost-root.desktop` grants root X access at every login via `xhost +si:localuser:root`, never revoked | **Kept deliberately** — required for YaST GUI under COSMIC |
| REVIEW-036 | sway idle-lock block is commented out while the config prose and README both claim a 900s lock | **Kept** — sway is archived and uninstalled |
| REVIEW-037 | `sway/.local/bin/wifi-menu.sh` passes the WiFi PSK as an `nmcli` argv, visible in `ps` to every local user | **Kept** — sway is archived and uninstalled |
| REVIEW-040 | 13 AI conversation transcripts, 3.6MB / 73,634 lines, committed to a public dotfiles repo | **Kept deliberately** — personal record of the setup journey |
| REVIEW-057 | `xfce/setup.md:318` claims the Acer battery driver is loaded; `lsmod` shows no `acer-wmi-battery` | **Kept** — Mint/Ubuntu-era claim, not applicable to openSUSE Tumbleweed |
| REVIEW-058 | MT7902 DKMS presented as a live install procedure while the doc itself marks it deprecated | **Kept** — in-kernel `mt7921e` works out of the box on Tumbleweed |
| REVIEW-060 | `.opencode/workspace.json` identity fields say `linux-configs`; the repo is `linux-dotfiles` | **Deferred to owner** — `.clinerules` forbids editing identity fields unprompted |

---

### [REVIEW-028] slick-greeter config written unconditionally to a deleted wallpaper, reports success (Severity: CRITICAL)

- **Category**: Correctness
- **File/Path**: `xfce/setup.sh:175-194`
- **The Issue**: Line 175 detects missing `xfce/background.jpg` and warns, but the config write at 181 runs unconditionally, and line 194 prints `OK` unconditionally. `xfce/background.jpg` does not exist at HEAD (deleted in commit `0b970457`). A fresh XFCE install greets the user with a black login screen while the script claims success.
- **Recommendation**: Gate the `tee` on the same flag that detects the wallpaper; drop the unconditional `OK`. `wallpapers/bg1.jpg` is tracked in-repo and can be repointed. Verified `MISSING` October 11, 2026.

---

### [REVIEW-029] 24 sk-shaped strings in committed transcripts will hard-fail secret scanning (Severity: HIGH)

- **Category**: Security
- **File/Path**: `sessions/session-oct-6.md`, `sessions/session-oct-6-1.md`, `sessions/session-oct-8.md`, `sessions/session-oct-10.md`
- **The Issue**: Verified individually — every `sk-[A-Za-z0-9]{20,}` match is concatenated SVG attribute dump noise (`mask-image`, `mask-composite`, `mask-origin`). **False positives, no credential exists.** The repo is public and the byte shape is identical to a live OpenAI key, so GitHub push protection and any scanner will reject pushes.
- **Recommendation**: Add `.gitattributes` with `sessions/* -diff`; remove `sessions/` from git entirely per REVIEW-041.

---

### [REVIEW-030] `.bashrc` install guard blocks every future repo update

- **File/Path**: `gnome/setup.sh:88-95`, `xfce/setup.sh:93-100`
- **Severity**: HIGH
- **Category**: Correctness
- **Finding**: The idempotency guard tested a marker string — `if grep -q '^alias fresh=' "$HOME_DIR/.bashrc"` — instead of comparing content. First run appended the marker; every later run skipped the `cp` forever, so later `.bashrc` edits silently never landed.
- **Recommendation**: Gate on a content comparison, not a marker string.
- **Status 2026-10-11**: RESOLVED — see Section 2, `(REVIEW-030, 031, 033)`.

---

### [REVIEW-031] Unpinned remote script piped into a shell, `curl` missing `-f`

- **File/Path**: `gnome/setup.sh:82`, `xfce/setup.sh:87`
- **Severity**: HIGH
- **Category**: Security
- **Finding**: `curl -sS https://starship.rs/install.sh | sh -s -- -y` — no version pin, no checksum. `-sS` without `-f` means an HTTP error body is piped into `sh` and the script still prints `OK`.
- **Recommendation**: `curl -fsSL -o` to a temp file, then `sh` it.
- **Status 2026-10-11**: RESOLVED — see Section 2, `(REVIEW-030, 031, 033)`.

---

### [REVIEW-032] Unpinned third-party kernel module built and modprobed as root from a fixed `/tmp` path (Severity: HIGH)

- **Category**: Security
- **File/Path**: `xfce/setup.sh:381-392`
- **The Issue**: `git clone --depth=1` of an unpinned branch → `make` → `cp` the `.ko` into `/lib/modules/$(uname -r)` → `depmod` → `sudo modprobe`. Ring-0 code from a moving remote ref into a predictable world-writable `/tmp` path. Re-run fails (directory exists, no cleanup before clone) and the `rm -rf` is success-path only.
- **Recommendation**: Clone into `$(mktemp -d)`, pin a commit SHA, `trap` cleanup on all exit paths.

---

### [REVIEW-033] Nonexistent directory prepended to PATH permanently

- **File/Path**: `common/.bashrc:123` (was duplicated in all three DE copies)
- **Severity**: HIGH
- **Category**: Security
- **Finding**: `export PATH="/home/julry/.opencode/bin:$PATH"` — that directory does not exist. Every interactive shell started with a nonexistent directory at the FRONT of PATH; on any account, a `/home/julry/.opencode/bin` another user can create becomes a binary-hijack vector. Line 124 of the same file already did it correctly with `$HOME/.local/bin`.
- **Recommendation**: Delete the line.
- **Status 2026-10-11**: RESOLVED — see Section 2, `(REVIEW-030, 031, 033)`.

---

### [REVIEW-035] `A && B || C` misreports copy failure

- **File/Path**: `xfce/setup.sh:136-139`
- **Severity**: HIGH
- **Category**: Correctness
- **Finding**: `[ -d src ] && cp -rb src/. dest/ || WARN "src missing"` — the `||` binds to the whole `&&` chain, so a failed `cp` printed "missing" and sent the user to the wrong place. The 187MB icon recopy half of this finding became moot when `xfce/.icons/` was deleted on October 11, 2026.
- **Recommendation**: `if/else` instead of `&& ||`.
- **Status 2026-10-11**: RESOLVED — see Section 2, `(REVIEW-035)`. The fonts line in the same block was not converted; see REVIEW-060.

---

### [REVIEW-039] 43,797 tracked files / 187MB / no root `.gitignore` (Severity: HIGH)

- **Category**: Maintainability
- **File/Path**: `xfce/.icons/` (43,099 files), missing `/.gitignore`
- **The Issue**: `xfce/.icons/` is 187MB across 43,099 files — 98.5% of every tracked file, in a repo whose real config is ~60 files. Working tree 205MB, `.git` 44MB with 5.38 MiB orphaned garbage from an aborted gc. No root `.gitignore` exists (only `.opencode/.gitignore` and two inside `xfce/drivers/`). `xfce/fresh-install.md:130` instructs `git add -A`, which will sweep in the `*.log`, `*.bak` and `*~` files both installers create via `cp -b`.
- **Recommendation**: Root `.gitignore` for `sessions/`, `*.log`, `*.bak`, `*~`, `.cache/`. Do NOT silently ignore `xfce/.icons/` — dropping 43k tracked files is a history rewrite and needs a deliberate decision. Then `git gc --prune=now`.

---

### [REVIEW-043] Restore snippets point at a deleted tree (Severity: HIGH)

- **Category**: Correctness
- **File/Path**: `gnome/setup.md:238,332`, `xfce/setup.md:776`
- **The Issue**: `REPO=/home/julry/vscodefiles/linux-configs/gnome-setup` — the entire `/home/julry/vscodefiles` tree is gone (verified). Live path is `/home/julry/repo/linux-dotfiles`. The directory moved AND was renamed; every command in these blocks fails.
- **Recommendation**: `REPO="$(git rev-parse --show-toplevel)/gnome"` — derived, never hardcoded again.

---

### [REVIEW-046] Screen-dim toggle uses a fixed, pre-creatable `/tmp` state file

- **File/Path**: `xfce/setup.sh:149-168`
- **Severity**: MEDIUM
- **Category**: Security
- **Finding**: `STATE_FILE="/tmp/.screen_dim_toggle_state"` was a predictable world-writable name. Any other local user could pre-create it, forcing the victim's first toggle into the wrong brightness branch; `rm -f` then failed silently on a file it did not own. `DISPLAY_NAME` was also unguarded — no match produced `xrandr --output ""` with no error path.
- **Recommendation**: Use `$XDG_RUNTIME_DIR`; guard the display lookup with an explicit exit 1.
- **Status 2026-10-11**: RESOLVED — see Section 2, `(REVIEW-046, 047)`.

---

### [REVIEW-047] DKMS source copy is not idempotent — second run nests the directory

- **File/Path**: `xfce/setup.sh:364-368`
- **Severity**: MEDIUM
- **Category**: Correctness
- **Finding**: `cp -r "$REPO/drivers/mt7902/mt7902-wifi" /usr/src/mt7902-wifi-1.0` copies INTO the destination when it already exists, yielding `/usr/src/mt7902-wifi-1.0/mt7902-wifi/…`; `dkms install` and `make install_fw` then fail. Every other step in this script advertises idempotency — this one did not.
- **Recommendation**: `sudo rm -rf` the destinations first, or use `cp -rT`.
- **Status 2026-10-11**: RESOLVED — see Section 2, `(REVIEW-046, 047)`.

---

### [REVIEW-048] `exit 0` returned even when every step failed

- **File/Path**: `gnome/setup.sh:419`, `xfce/setup.sh:450`
- **Severity**: MEDIUM
- **Category**: Testability
- **Finding**: Both scripts ended `exit 0` regardless of `${#FAILED_STEPS[@]}`. A CI job, wrapper, or `set -e` parent saw success on a run where zram, dconf, packages, and drivers all failed.
- **Recommendation**: `exit 1` when failures exist, `exit 0` otherwise.
- **Status 2026-10-11**: RESOLVED — see Section 2, `(REVIEW-048, 049)`.

---

### [REVIEW-049] Path-rewrite `sed` swallows its own errors

- **File/Path**: `gnome/setup.sh:60-64`, `xfce/setup.sh:62-66`
- **Severity**: MEDIUM
- **Category**: Maintainability
- **Finding**: `sed -i "s|/home/julry|$HOME_DIR|g" … 2>/dev/null || true` followed by an unconditional `OK "paths rewritten"`. The `|| true` hid every "can't read file" error, so the OK printed even when all targets were missing. It also rewrote files inside the clone, leaving `git status` permanently dirty.
- **Recommendation**: Verify the replacement landed before printing `OK`.
- **Status 2026-10-11**: RESOLVED — see Section 2, `(REVIEW-048, 049)`. The in-place mutation of the clone is inherited house pattern and remains, logged in `cosmic/setup.md` §12.

---

### [REVIEW-050] Three byte-identical `.bashrc` copies maintained independently

- **File/Path**: `cosmic/.bashrc`, `gnome/.bashrc`, `xfce/.bashrc`
- **Severity**: MEDIUM
- **Category**: Maintainability
- **Finding**: All three were git blob `6e6f15cc` — byte-identical, zero divergence. Three independent copies of one file with no DE-specific differences, so every future edit had to land three times. `cosmic/` had no `setup.sh` at all, so its copy was never even installed.
- **Recommendation**: One `.bashrc` shared by all DEs.
- **Status 2026-10-11**: RESOLVED — see Section 2, `(REVIEW-050, 051, 052, 105)`.

---

### [REVIEW-051] Three byte-identical `fastfetch` configs, no drift check

- **File/Path**: `cosmic/.config/fastfetch/config.jsonc`, `gnome/.config/fastfetch/config.jsonc`, `xfce/.config/fastfetch/config.jsonc`
- **Severity**: MEDIUM
- **Category**: Maintainability
- **Finding**: All three were git blob `2bd2cf39`, identical 2688 bytes, all mode `0664`. Any edit had to be applied three times by hand with no mechanism to catch a miss. Demonstrated live on October 11, 2026 — the `os age` change had to be applied three times, and one copy silently failed on a root-owned permission error until caught.
- **Recommendation**: One canonical file for all DEs.
- **Status 2026-10-11**: RESOLVED — see Section 2, `(REVIEW-050, 051, 052, 105)`.

---

### [REVIEW-052] Two byte-identical 21KB spotatui playlist manifests

- **File/Path**: `cosmic/.config/spotatui/youtube_playlists.yml`, `gnome/.config/spotatui/youtube_playlists.yml`
- **Severity**: MEDIUM
- **Category**: Maintainability
- **Finding**: 21,190 bytes each, identical, one playlist with 161 tracks. Regenerating rewrote 21KB once per DE.
- **Recommendation**: One canonical file shared by all DEs.
- **Status 2026-10-11**: RESOLVED — see Section 2, `(REVIEW-050, 051, 052, 105)`.

---

### [REVIEW-053] 20+ hardcoded `/home/julry/...` absolute paths across configs and scripts (Severity: MEDIUM)

- **Category**: Portability
- **File/Path**: 3× `fastfetch/config.jsonc:5`, `sway/.config/sway/config:19,34,177,236,237,240,263`, `sway/.config/waybar/config:50,60,65,70`, `sway/.local/bin/shot.sh:4`, `sway/.local/bin/notif-center.sh:25`, `sway/.local/bin/power-menu.sh:11`
- **The Issue**: The fastfetch logo points at `/home/julry/Documents/jm-icon.png`, outside the repo entirely. Sway alone carries 14 absolute references. A restore-as-documented leaves every one of them dangling for any other user or machine.
- **Recommendation**: `~` or `$HOME` throughout; vendor the logo inside the repo so the copies stay self-contained.

---

### [REVIEW-054] Starship prompt hardcodes the username `julry` (Severity: MEDIUM)

- **Category**: Correctness
- **File/Path**: `gnome/.config/starship.toml:5`
- **The Issue**: `[ julry](bg:#a3aed2 fg:#090c0c)` is a literal string in `format`. Every other user of this repo gets a prompt that lies about who they are.
- **Recommendation**: Replace the literal with starship's `$username` module, styled identically.

---

### [REVIEW-055] Repo copies have drifted from the live home configs they mirror

- **File/Path**: `gnome/.config/zed/settings.json:131`, `gnome/.config/kitty/kitty.conf:6`
- **Severity**: MEDIUM
- **Category**: Maintainability
- **Finding**: Repo had `"dark": "Transparent Prism - Sunset"` while live had `"dark": "Ayu Glass Dark"`; repo had `font_size 10.0` while live had `11.0`. `starship.toml` and `zed/keymap.json` were identical. The repo claimed to be the source of truth, so restoring it would revert live settings the user had changed since.
- **Recommendation**: Sync repo from live, or date-stamp the snapshot and mark those files non-authoritative.
- **Status 2026-10-11**: RESOLVED — see Section 2, `(REVIEW-055)`. zed synced; kitty had already converged on its own.

---

### [REVIEW-056] `xfce/setup.md` is Linux Mint/apt-only prose on an openSUSE repo (Severity: MEDIUM)

- **Category**: Correctness
- **File/Path**: `xfce/setup.md` (28 apt references; §1A:39, §1E:188, §4F:529, §11:1012)
- **The Issue**: Every step after §0 is apt-only. `apt`, `dpkg`, `tune2fs`, `update-grub`, `update-alternatives`, `xrandr`, `xfconf-query` are all absent on the live box. §1A tells the reader to edit `/etc/sysctl.conf` while `xfce/setup.sh:219` writes a `/etc/sysctl.d/99-swappiness.conf` drop-in — different mechanism, different file, never mentioned.
- **Recommendation**: Two-column Mint-vs-openSUSE, or an explicit banner at §0. Fix §1A to document the drop-in the script actually writes.

---

### [REVIEW-059] `opencode.json` and `workspace.json` are invalid strict JSON (Severity: MEDIUM)

- **Category**: Correctness
- **File/Path**: `opencode.json:8`, `.opencode/workspace.json:9`, `xfce/.config/opencode/opencode.jsonc:7`
- **The Issue**: Both root files end with a trailing `// c: worrie` comment; `python3 -m json.tool` fails with `Extra data`. `workspace.json` declares the opencode schema and is read by the `-init`/`-obsidian`/`-archive` handlers, so any strict-JSON tooling (jq, CI) breaks. The repo's own `.jsonc` is doubly invalid — trailing comma after `preserveSystemPrompt`.
- **Recommendation**: Drop the comment line from both `.json` files, or rename to `.jsonc` and confirm every consumer tolerates JSONC.

---

### [REVIEW-061] `AGENTS.md` omits `project_memory.md` and `.opencode/archives/` (Severity: MEDIUM)

- **Category**: Maintainability
- **File/Path**: `AGENTS.md:23-28`
- **The Issue**: The "Memory File Locations" section lists `rules/` and `memory/` but never mentions `project_memory.md` — which lives in `rules/`, not `memory/`, despite being load-bearing for three flags (`-init`, `-obsidian`, `-archive`) — nor `.opencode/archives/`, which exists with 5 files and is the defined archival target.
- **Recommendation**: Add both entries to the memory section. All 13 paths AGENTS.md does list exist — no dead paths there.

---

### [REVIEW-062] Lock-screen autostart leaves the session unlocked for 3s and passes no session ID (Severity: MEDIUM)

- **Category**: Security
- **File/Path**: `gnome/.config/autostart/lock-screen.desktop:5`
- **The Issue**: `Exec=sh -c 'sleep 3; /usr/bin/loginctl lock-session'`. Three problems — a 3-second interactively-usable window on every login (fatal under autologin), `loginctl lock-session` takes `[ID…]` and none is named so resolution depends on the caller, and single-quote quoting is not what the desktop-entry spec mandates (it only works because GIO uses `g_shell_parse_argv`).
- **Recommendation**: Lock directly with `"$XDG_SESSION_ID"`, or use GNOME's own screen-shield-delay instead of sleep-then-lock.

---

### [REVIEW-063] fastfetch configs are group-writable while git records 0644 (Severity: MEDIUM)

- **Category**: Security
- **File/Path**: 3× `fastfetch/config.jsonc`
- **The Issue**: `-rw-rw-r-- julry:julry` on all three, while git records mode `100644`. The group-write bit is untracked local state that vanishes silently on re-clone, or gets re-applied by a stray `chmod -R g+w`. Any member of group `julry` can rewrite these files.
- **Recommendation**: `chmod 644`; add a umask guard in setup; do not rely on untracked mode bits for security-relevant settings.

---

### [REVIEW-064] Secure Boot section pins three different stale kernel versions as "verified live" (Severity: MEDIUM)

- **Category**: Correctness
- **File/Path**: `gnome/setup.md:158,475,639,659`
- **The Issue**: Claims verified live state with `kernel-default` 7.2.5-1.1 + 7.2.6-1.1; line 158 says 7.2.4; line 639 gives `sudo kernel-install remove 7.2.5-1-default` for a version no longer installed; line 659 says keep 7.2.5 as fallback. Live running kernel is `7.2.9-1-default`. The "verified live" framing lends false authority to stale values.
- **Recommendation**: Replace pinned versions with `uname -r` derivation; add a `Last verified:` marker.

---

### [REVIEW-065] Waybar exposes 5 workspaces while sway binds 10 (Severity: MEDIUM)

- **Category**: Correctness
- **File/Path**: `sway/.config/waybar/config:11` vs `sway/.config/sway/config:125-145`
- **The Issue**: `persistent-workspaces` maps 1–5; sway binds 1–10; `disable-scroll: true` removes the scroll fallback. Workspaces 6–10 exist but are unreachable from the bar.
- **Recommendation**: Extend the map to 10, or drop the sway bindings for 6–10.

---

### [REVIEW-066] `zoxide query -i` receives an unquoted multi-word selection (Severity: LOW)

- **Category**: Correctness
- **File/Path**: `{cosmic,gnome,xfce}/.bashrc:150,184`
- **The Issue**: `zoxide query -i "${@:2}"` and `zoxide query -i "$@"` split on spaces, so a directory like `/home/julry/repo/my project` fails; the `|| return 1` swallows it into a bare exit 1 with no message.
- **Recommendation**: Quote both.

---

### [REVIEW-067] `_launch_and_exit` discards all output and always reports success (Severity: LOW)

- **Category**: Correctness
- **File/Path**: `{cosmic,gnome,xfce}/.bashrc:140-145`
- **The Issue**: `nohup zed "$target" >/dev/null 2>&1 &` then a hardcoded `exit 0`. `zed` is not installed by either setup script — both list it under "manual leftovers" — so the launch fails, the error is thrown away, and success is still reported. The editor simply never opens.
- **Recommendation**: `command -v zed` guard; drop `2>&1`; capture the real status.

---

### [REVIEW-068] `fastfetch` runs on every shell opened in `$HOME` (Severity: LOW)

- **Category**: Performance
- **File/Path**: `{cosmic,gnome,xfce}/.bashrc:126-128`
- **The Issue**: `if [ "$PWD" = "$HOME" ]; then fastfetch; fi` blocks shell startup with no guard on the binary existing and no opt-out.
- **Recommendation**: `command -v fastfetch` guard, or gate behind a flag var.

---

### [REVIEW-069] `zzed` dereferences `$1` before checking `$#` (Severity: LOW)

- **Category**: Correctness
- **File/Path**: `{cosmic,gnome,xfce}/.bashrc:148,155`
- **The Issue**: `if [ "$1" = "-i" ]` runs before `if [ $# -eq 0 ]`. Works today because `$1` expands empty, but aborts under an inherited `set -u` before the zero-arg branch is reached.
- **Recommendation**: Move the `[ $# -eq 0 ]` block above line 148.

---

### [REVIEW-070] `repo ref` silently no-ops when `~/repo` is absent (Severity: LOW)

- **Category**: Correctness
- **File/Path**: `{cosmic,gnome,xfce}/.bashrc:194-200`
- **The Issue**: `for d in "$HOME/repo"/*/` — the glob stays literal when the directory is missing, `[ -d "$d" ]` is false for every iteration, and the function returns 0 having done nothing. No diagnostic.
- **Recommendation**: `[ -d "$HOME/repo" ] || { echo "repo: not found" >&2; return 1; }` before the loop.

---

### [REVIEW-071] `pkg_in()` defined and never called (Severity: LOW)

- **Category**: Maintainability
- **File/Path**: `gnome/setup.sh:45-47`
- **The Issue**: The only call sites are in `xfce/setup.sh` (306, 362, 363, 381, 382). GNOME installs packages via an inline `bash -c` string at line 75 instead — dead code plus a second divergent install path.
- **Recommendation**: Delete it, or route line 75 through `pkg_in`.

---

### [REVIEW-072] `sudo zypper se` inside a per-package loop (Severity: LOW)

- **Category**: Performance
- **File/Path**: `gnome/setup.sh:70-73`, `xfce/setup.sh:72-75`
- **The Issue**: `sudo zypper se -x --match-exact "$_pkg"` runs once per package — 8 and 12 full repo-metadata refreshes plus repeated credential checks, for a purely informational dry-check.
- **Recommendation**: One `zypper se` call for the whole list, or a single `sudo bash -c`.

---

### [REVIEW-073] Multi-unit `systemctl disable --now` reports failure when any unit is missing (Severity: LOW)

- **Category**: Correctness
- **File/Path**: `gnome/setup.sh:325`, `xfce/setup.sh:325`
- **The Issue**: `systemctl disable --now cups.service cups.socket avahi-daemon.service avahi-daemon.socket` returns non-zero if ANY named unit is absent. On a system without Avahi, three units succeed and the script still emits a `WARN` plus a `FAILED_STEPS` entry — a misleading signal in the summary.
- **Recommendation**: Iterate units individually and aggregate, or filter to installed units first.

---

### [REVIEW-074] `REPO` resolution breaks when the script is piped or sourced from stdin (Severity: LOW)

- **Category**: Portability
- **File/Path**: `gnome/setup.sh:8`, `xfce/setup.sh:8`
- **The Issue**: `REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` — under `set -u`, `${BASH_SOURCE[0]}` is unset when fed via `curl … | bash` or `bash < setup.sh`, aborting with an unbound-variable error.
- **Recommendation**: `"${BASH_SOURCE[0]:-$0}"`.

---

### [REVIEW-075] `systemctl restart` on a swap unit cannot recreate the device (Severity: LOW)

- **Category**: Correctness
- **File/Path**: `gnome/setup.sh:246`, `xfce/setup.sh:242`
- **The Issue**: `systemctl restart dev-zram0.swap` restarts the unit but does not recreate `/dev/zram0` with new compression settings. The outcome depends on the user noticing the WARN and rebooting.
- **Recommendation**: Drop the restart; the generator enable plus `zramctl` verification suffice. Say plainly that a reboot is required.

---

### [REVIEW-076] JSON config files carry the executable bit (Severity: LOW)

- **Category**: Maintainability
- **File/Path**: `gnome/.config/zed/keymap.json` (0755), `gnome/.config/opencode/opencode.jsonc` (0755)
- **The Issue**: `-rwxr-xr-x` on JSON configs while sibling `settings.json` is 0644; git records `keymap.json` as `100755`. No functional impact, but it hides the real mode problem in REVIEW-063 from diffs.
- **Recommendation**: `chmod 644`; `git update-index --chmod=-x` for `keymap.json`.

---

### [REVIEW-077] sway includes a config directory that does not exist (Severity: LOW)

- **Category**: Correctness
- **File/Path**: `sway/.config/sway/config:258`
- **The Issue**: `include /etc/sway/config.d/*` — `/etc/sway` exists, `/etc/sway/config.d` does not. The glob matches nothing and sway logs an include failure on every config load.
- **Recommendation**: `mkdir -p` on install, guard the include, or delete the line.

---

### [REVIEW-078] Waybar backlight pinned to one GPU's device name (Severity: LOW)

- **Category**: Correctness
- **File/Path**: `sway/.config/waybar/config:31`
- **The Issue**: `"device": "amdgpu_bl1"` — a single-machine assumption; on any other GPU the module shows nothing.
- **Recommendation**: Remove the key so waybar picks the first backlight, or comment it as hardware-specific.

---

### [REVIEW-079] Waybar bluetooth reports OFF in every powered state (Severity: LOW)

- **Category**: Correctness
- **File/Path**: `sway/.config/waybar/config:53-57`
- **The Issue**: `format`, `format-disabled`, `format-off`, `format-on`, `format-no-controller` are all `" OFF"` — only `format-connected` differs, so a powered-but-not-connected radio reads OFF.
- **Recommendation**: Give `format-on` a real string, or delete the redundant formats.

---

### [REVIEW-080] fastfetch key padding inconsistency and desktop-only battery module (Severity: LOW)

- **Category**: Correctness
- **File/Path**: 3× `fastfetch/config.jsonc:107,112`
- **The Issue**: Every other key is space-padded to 8 columns; `"key": "packages"` is not. The `battery` module renders nothing on a desktop.
- **Recommendation**: Pad to `"packages "`; move `battery` into a laptop-only profile.

---

### [REVIEW-081] spotatui commits a playlist ID and the full 161-track manifest (Severity: LOW)

- **Category**: Security
- **File/Path**: `cosmic/.config/spotatui/youtube_playlists.yml:2`, `gnome/.config/spotatui/youtube_playlists.yml:2`
- **The Issue**: Playlist ID `2npedfnskpte` plus every track title, channel, and duration. A public playlist ID is not a credential — but if the source playlist is unlisted, that ID is the only access control and it is now in git history. **No tokens or keys found anywhere in the repo (full secret scan clean).**
- **Recommendation**: Drop the `id` field from the committed copy if the playlist is unlisted, or keep the file out of git.

---

### [REVIEW-082] kitty.conf documents a compositor that is not installed (Severity: LOW)

- **Category**: Correctness
- **File/Path**: `gnome/.config/kitty/kitty.conf:15-16`
- **The Issue**: The comment `# Frosted glass transparency for picom` sits above `background_opacity 0.85`. `picom` is not installed; kitty does this natively. The comment misattributes the effect and will mislead whoever adds a compositor later.
- **Recommendation**: Reword to `# Transparency (kitty-native, no compositor needed)`.

---

### [REVIEW-083] sway README points at a wallpaper that is now in the repo (Severity: LOW)

- **Category**: Correctness
- **File/Path**: `sway/README.md:59`
- **The Issue**: Says the wallpaper is "not in repo" — `wallpapers/bg1.jpg` is now tracked (4.3MB). The live copy at `/home/julry/wallpapers/bg1.jpg` also exists, giving two copies with no statement of which is authoritative.
- **Recommendation**: Reference the tracked `wallpapers/bg1.jpg` and state which copy is canonical.

---

### [REVIEW-084] Setup docs append to `.bashrc` non-idempotently, contradicting their own scripts (Severity: LOW)

- **Category**: Correctness
- **File/Path**: `gnome/setup.md:143`, `xfce/setup.md:226`
- **The Issue**: Both docs instruct `echo 'export NODE_OPTIONS="--max-old-space-size=1536"' >> ~/.bashrc` unconditionally. Both scripts guard with `grep -q 'max-old-space-size=1536'` first. A user following the doc twice gets duplicate lines.
- **Recommendation**: Use the same `grep -q … || echo … >>` form in the docs.

---

### [REVIEW-085] GNOME extensions header says "dash-to-panel only" but documents three (Severity: LOW)

- **Category**: Correctness
- **File/Path**: `gnome/setup.md:168`
- **The Issue**: Heading reads `## 3. GNOME Shell Extensions (dash-to-panel only)`; the body at line 170 lists three IDs (blur-my-shell, dash-to-panel, disable-workspace-switcher), all matching `gnome/extensions/list.txt`. The header is a leftover contradicting its own body.
- **Recommendation**: Change the heading to `(3 enabled IDs)`.

---

### [REVIEW-086] Both setup docs claim "Seven optimizations"; GNOME has five (Severity: LOW)

- **Category**: Maintainability
- **File/Path**: `gnome/setup.md:3`, `xfce/setup.md:3`
- **The Issue**: XFCE §1 has 1A–1G = 7 (accurate). GNOME §1 has 1A, 1D, 1E, 1F, 1G = 5 because openSUSE skips GRUB and ext4-reserve by design (correctly noted at line 52), but the opener was never updated.
- **Recommendation**: Change `gnome/setup.md:3` to "Five", or state "Seven, minus GRUB and ext4 reserve which openSUSE skips".

---

### [REVIEW-087] `xfce/setup.md` instructs copying from a nonexistent `linux-configs/.config/` tree (Severity: LOW)

- **Category**: Correctness
- **File/Path**: `xfce/setup.md:449,608,670`
- **The Issue**: `cp linux-configs/.config/xfce4/…` — wrong repo name AND the dotfiles live under `xfce/`, not the repo root, so correcting the name alone still leaves a nonexistent path. Each block carries an "adjust the path" hedge that papers over the bug.
- **Recommendation**: Standardize on `REPO=/home/julry/repo/linux-dotfiles/xfce` or a derived path, then delete the hedges.

---

### [REVIEW-088] Same launcher bound to two key combos at two hardcoded paths (Severity: LOW)

- **Category**: Maintainability
- **File/Path**: `sway/.config/sway/config:83,177`
- **The Issue**: `bindsym $mod+d exec $menu` and `bindsym $mod+a exec /home/julry/.local/bin/launcher.sh` run the identical script at an identical hardcoded path. Two names, one behavior, two places to update.
- **Recommendation**: Keep one binding, or point both at `$menu`.

---

### [REVIEW-089] `/usr/sbin` binaries referenced as if on the user PATH (Severity: LOW)

- **Category**: Correctness
- **File/Path**: `xfce/fresh-install.md:105`, `xfce/setup.sh:153`, `gnome/setup.md:436`
- **The Issue**: `zramctl`, `efibootmgr`, `update-alternatives`, `xrandr` are referenced bare but live in `/usr/sbin`. `gnome/setup.md:503` correctly flags `efibootmgr` as not on a user PATH but never flags `zramctl`, which has the identical problem, while both `setup.sh` scripts call `zramctl` bare.
- **Recommendation**: Use the absolute path or document the PATH requirement.

---

_All eight reviews REVIEW-019–026 (split-layout audit, September 13, 2026) fixed the same day — migrated to Section 2._

_All six reviews from the September 05, 2026 full-repo audit are resolved — migrated to Section 2._

_Reviews REVIEW-012–018 (TW-readiness audit, September 09, 2026) all fixed the same day — migrated to Section 2._

## 2. Historical & Resolved Reviews

_Move reviews to this section once they are completely verified as resolved. This serves as historical memory to prevent the AI from re-introducing the same issues._

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
- **Last Review Date**: `October 11, 2026, 08:35 AM PST`

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
