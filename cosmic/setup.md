# openSUSE COSMIC Post-Install Setup (COSMIC-only)

One-command restore of this dotfiles repo onto a COSMIC session on openSUSE Tumbleweed: swap and kernel tuning, the full 189-file COSMIC desktop-config backup, the shared terminal/shell/OpenCode workspace, and the deliberate root-X grant for YaST.

Run from inside the cloned repo:

```bash
bash cosmic/setup.sh
```

Read this file first if you are doing the steps by hand, or if `setup.sh` reported a failure. Every section maps 1:1 onto a step in the script.

---

## 0. Support scope (read first)

- **COSMIC-only.** The COSMIC desktop config backup is the primary payload of this repo. `setup.sh` aborts if it is not running inside a COSMIC session:

  ```bash
  # Guard logic, abbreviated
  case "$XDG_CURRENT_DESKTOP" in *COSMIC*|*cosmic*) ;; *) abort ;; esac
  ```

  There is one documented escape hatch, for running the non-COSMIC parts from a TTY:

  ```bash
  COSMIC_SETUP_ALLOW_ANY_DE=1 bash cosmic/setup.sh
  ```

  Under the override the panel, dock, theme and font changes still land on disk, but COSMIC will not read them until you actually log into a COSMIC session.

- **GDM is the active display manager. `greetd` is installed and disabled.** Verified live on this machine:

  ```bash
  systemctl is-enabled greetd   # → disabled
  systemctl is-enabled gdm      # → enabled
  ```

  `cosmic-greeter` 1.10.0 *is* installed, but nothing runs it, because greetd — not gdm — is what would invoke it. **`setup.sh` deliberately does not enable greetd and does not disable gdm.** The summary prints this state so nobody has to guess later. If you ever do want the COSMIC login screen, that is a separate, deliberate change: `sudo systemctl enable greetd --now`, which removes GDM from the running session. Read Section 11 before doing that.

- **Package layer is distro-portable.** Unlike `gnome/setup.sh` and `xfce/setup.sh` (which hardcode zypper vs apt), `cosmic/setup.sh` sources `common/detect-distro.sh` and uses `pkg_install` / `pkg_query`, so it covers Ubuntu-family (apt) and openSUSE-family (zypper) only. Any other distro resolves to no package manager and `pkg_install` warns instead of installing. `confirm_distro` prompts for an override when run interactively; the prompt is skipped entirely when stdin is not a TTY.

- **What this repo does NOT touch:**

  | Not touched | Why |
  | ----------- | --- |
  | GNOME specifics (`gnome/`) | Separate DE tree with its own `setup.sh`. Not a fallback for COSMIC. |
  | XFCE specifics (`xfce/`) | Separate DE tree. |
  | Archived `sway/` | Archived, no setup script. |
  | Display manager (GDM/greetd) | Deliberately left exactly as found — see above. |
  | Bootloader / Secure Boot chain | `untouched (by design)`; see `gnome/setup.md` Sections 12–13 if you need it. |
  | Fonts | Not vendored under `cosmic/`. See Section 6. |

- **`.bashrc` moved to `common/`.** It is no longer under `cosmic/`. `cosmic/setup.sh` copies it from `common/.bashrc` with the same `grep`-guarded, backup-preserving block the GNOME script uses.

---

## 1. System optimizations

These four blocks are shared verbatim (in spirit) with `gnome/setup.sh`. They are proven working on this machine; nothing here is redesigned for COSMIC, because none of it is desktop-specific.

### 1A. Swappiness 180 + page-cluster 0

Swappiness controls how eagerly the kernel pushes idle RAM pages into swap. With ZRAM (Section 1B) available, `180` is safe: pages go into fast *compressed RAM*, not the SSD. The `game` alias in `.bashrc` drops it to 10 for gaming.

```bash
printf "vm.swappiness=180\nvm.page-cluster=0\n" | sudo tee /etc/sysctl.d/99-swappiness.conf
sudo sysctl --system
```

Verify — the machine currently reports **180** everywhere:

```bash
cat /proc/sys/vm/swappiness    # → 180
cat /proc/sys/vm/page-cluster  # → 0
```

`page-cluster = 0` means one page per swap I/O. ZRAM I/O is random compressed-RAM access, so multi-page readahead would only amplify decompression work.

### 1B. ZRAM (zstd, 100% of RAM)

```bash
printf '[zram0]\nzram-size = min(ram)\ncompression-algorithm = zstd\n' \
  | sudo tee /etc/systemd/zram-generator.conf
sudo systemctl daemon-reload
sudo systemctl enable --now systemd-zram-setup@zram0.service
sudo systemctl restart dev-zram0.swap
```

Verify — `setup.sh` asserts this rather than assuming it:

```bash
zramctl                      # ALGORITHM should read zstd, DISKSIZE ≈ 7G on this 8GB laptop
swapon --show               # /dev/zram0 at priority 100, /swapfile at -1
```

If `zramctl` reports an algorithm other than zstd after a config write, reboot and check again — the device does not re-init cleanly mid-session. That is also why this step is in the REBOOT list.

### 1C. Kernel VM tuning

```bash
echo "vm.vfs_cache_pressure=125"          | sudo tee /etc/sysctl.d/70-vfs-cache-pressure.conf
printf 'vm.dirty_ratio=10\nvm.dirty_background_ratio=5\n' | sudo tee /etc/sysctl.d/80-dirty-ratios.conf
echo "vm.watermark_boost_factor=0"        | sudo tee /etc/sysctl.d/85-watermark-boost.conf
echo "vm.watermark_scale_factor=150"      | sudo tee /etc/sysctl.d/86-watermark-scale.conf
sudo sysctl --system
```

| Setting | Default | Here | Effect |
| ------- | ------- | ---- | ------ |
| `vm.vfs_cache_pressure` | 100 | **125** | Reclaims dentry/inode cache 25% faster, freeing RAM for editors. |
| `vm.dirty_ratio` | 20 | **10** | Halves the writeback threshold — smaller, smoother flushes during git/builds. |
| `vm.dirty_background_ratio` | 10 | **5** | Starts background flush earlier. |
| `vm.watermark_boost_factor` | 10000 | **0** | Disables watermark boost, which causes sudden reclaim stalls on 8GB machines. |
| `vm.watermark_scale_factor` | 10 | **150** | Wakes `kswapd` far earlier so reclaim is gradual. |

```bash
sysctl vm.vfs_cache_pressure vm.dirty_ratio vm.dirty_background_ratio \
       vm.watermark_boost_factor vm.watermark_scale_factor
# Expected: 125  10  5  0  150
```

### 1D. EarlyOOM guard

Kills the biggest memory hog *before* the kernel OOM killer freezes the desktop. The policy protects the coding stack and sacrifices the browser — a tab is recoverable, an editor session is not.

```bash
echo 'EARLYOOM_ARGS="-m 5 -s 5 -r 3600 --avoid \"(^|/)(zed|opencode|node|kitty|bash)$\" --prefer \"(^|/)(brave|brave-browser)$\""' \
  | sudo tee /etc/sysconfig/earlyoom
sudo systemctl enable --now earlyoom && sudo systemctl restart earlyoom
```

```bash
systemctl is-active earlyoom   # → active
```

### 1E. Snapper snapshot

openSUSE only, and guarded on `command -v snapper` — a missing snapper is a warning, never a failure.

```bash
sudo snapper create -d "post-cosmic-restore $(date +%Y-%m-%d)"
```

Note the ordering: `setup.sh` takes this snapshot **after** the config restore, not before. It captures the state the script produced, so a bad run is one rollback away. The *pre*-restore state of `~/.config/cosmic/` is covered separately by the tar backup in Section 2.

### 1F. ModemManager

This laptop has no mobile broadband, so ModemManager is pure background overhead. Disabled by `setup.sh`; Wi-Fi and Bluetooth are unaffected (they run through NetworkManager).

```bash
systemctl is-enabled ModemManager   # → disabled
```

---

## 2. COSMIC desktop config restore

**This is the main payload of `cosmic/`.** Everything else in this repo is shared with the GNOME and XFCE trees; this is not.

### What ships

```
cosmic/.config/cosmic/          189 files, 756K, 33 per-app setting dirs
```

Each subdirectory is one COSMIC component's settings, stored as flat key files under a versioned `v1/` or `v2/` subdirectory in RON format:

| Dir | What it controls |
| --- | ---------------- |
| `com.system76.CosmicComp` | **Tiling + workspaces.** `autotile`, `workspaces`, `focus_follows_cursor`, `input_default`, `xkb_config`, `appearance_settings`. |
| `com.system76.CosmicWorkspaces` | Per-workspace state (which windows live where). |
| `com.system76.CosmicTk` | **Global theme toolkit.** `icon_theme`, `interface_font`, `monospace_font`, `header_size`, `interface_density`, window button visibility. |
| `com.system76.CosmicTheme.Dark` / `.Light` | Full colour definitions per mode (~40 keys each: palette, accent, backgrounds, frosted). |
| `com.system76.CosmicTheme.Dark.Builder` / `.Light.Builder` | Accent-generation inputs that the builder themes derive from. |
| `com.system76.CosmicTheme.Mode` | Which mode is active (dark/light). |
| `com.system76.CosmicPanel.Panel` | **Top panel** — anchor, size, autohide, applet layout. |
| `com.system76.CosmicPanel.Dock` | **Dock** — same key set, bottom anchored. |
| `com.system76.CosmicPanel` | Panel bookkeeping / entry list. |
| `com.system76.CosmicPanelButton` | Panel button configuration. |
| `com.system76.CosmicAppletTime` | Clock format. |
| `com.system76.CosmicAppletBattery` | Battery percentage display. |
| `com.system76.CosmicAppletAudio` | Volume applet. |
| `com.system76.CosmicAppList` / `AppLibrary` | App launcher contents and filtering. |
| `com.system76.CosmicBackground` | **Wallpaper** — source, scaling, rotation. |
| `com.system76.CosmicSettings.Wallpaper` | Custom wallpaper image list. |
| `com.system76.CosmicSettings.Shortcuts` | **Keyboard shortcuts** (Section 10). |
| `com.system76.CosmicSettings.WindowRules` | Per-app window placement rules. |
| `com.system76.CosmicSettings` | Settings app shell state. |
| `com.system76.CosmicSettingsDaemon` | Background settings daemon state. |
| `com.system76.CosmicStore` | Store integration state. |
| `com.system76.CosmicPortal` | Portal config (screenshots, file chooser). |
| `com.system76.CosmicFiles` | Nautilus-equivalent state incl. favourites. |
| `com.system76.CosmicEdit` | Text editor state. |
| `com.system76.CosmicTerm` | COSMIC terminal state. |
| `com.system76.CosmicAudio` | Volume levels / output device. |
| `com.system76.CosmicIdle` | Idle / screen blanking timers. |
| `com.system76.CosmicNotifications` | Notification placement, timeouts, DND. |
| `com.system76.CosmicTk` (widget half) | Panel/dock sizing, spacing, corner radii. |
| `dev.edfloreshz.CosmicTweaks` | Community tweak panel. |
| `dev.edfloreshz.CosmicTweaks.ColorScheme` | Active tweak colour scheme. |

### How restore works

```bash
REPO=/home/julry/repo/linux-dotfiles
cp -a "$REPO/cosmic/.config/cosmic/." "$HOME/.config/cosmic/"
```

That is the whole mechanism — COSMIC reads these plain files at startup, there is no schema or import tool. Two details matter:

1. **`cp -a`, not `cp -b`.** This is a whole-tree overwrite of a live, actively-written config directory. `setup.sh` tars the existing directory first:

   ```bash
   tar -czf ~/.cache/cosmic-config-$(date +%Y%m%d-%H%M%S).tar.gz -C ~/.config cosmic
   ```

   Snapper (Section 1E) does **not** cover this — snapshots are system-level, and `~/.config/cosmic/` is user-level. The tar is the only rollback for a bad restore.

2. **Absolute paths are rebased on the installed copy.** Four files carry the original machine's `/home/julry`:

   | File | Contains |
   | ---- | -------- |
   | `com.system76.CosmicBackground/v1/all` | wallpaper `Path("/home/julry/wallpapers/bg1.jpg")` |
   | `com.system76.CosmicFiles/v1/favorites` | bookmark paths |
   | `com.system76.CosmicSettings.Wallpaper/v1/custom-images` | wallpaper list |
   | `dev.edfloreshz.CosmicTweaks.ColorScheme/v1/current_config` | colour scheme path |

   `setup.sh` rewrites those to `$HOME` **after** copying, not in the repo — so the repo itself stays portable and does not get dirtied by whoever runs it. The step verifies the rewrite landed (counting files still containing `/home/julry` after the fact) rather than trusting `sed`'s exit status.

> Note: `setup.sh` intentionally does **not** use `cp -rb` for the `cosmic/` subtree, and skips it in the general config copy. A blanket `cp -rb` would back up all 189 files as `<name>~` seconds before `cp -a` overwrites them with identical content — 189 useless backup files, and a file count that reads 378 instead of 189.

### Verify

```bash
find ~/.config/cosmic -maxdepth 1 -mindepth 1 -type d | wc -l   # → 33 setting dirs
find ~/.config/cosmic -type f | wc -l                          # → 189 files
cat ~/.config/cosmic/com.system76.CosmicTk/v1/icon_theme        # → "Reversal-grey"
cat ~/.config/cosmic/com.system76.CosmicComp/v1/autotile       # → true
```

`setup.sh` prints exactly this verification block at the end, reading from the restored files rather than from the repo, and warns if `icon_theme` or `autotile` does not match the captured state.

COSMIC reads config at session start, so **log out and back in** for the restore to take effect. Restarting the display manager does this fastest.

---

## 3. Panel & Dock

Two independent surfaces, each with the same ~24-key config schema. Both are restored by Section 2.

### Panel (top bar)

| Key | Value | Note |
| --- | ----- | ---- |
| `anchor` | `Left` | Panel is on the left edge, not the top. |
| `size` | `XS` | Extra-small — maximum horizontal room. |
| `autohide` | `Never` | Always visible. |
| `exclusive_zone` | `true` | Windows do not tile underneath it. |

Center segment: the clock (`com.system76.CosmicAppletTime`).

Wings, left → `CosmicAppletWorkspaces`, `CosmicAppList`. Wings, right → `CosmicAppletTiling`, `Notifications`, `Audio`, `Bluetooth`, `Network`, `Battery`, `Power`.

### Dock (bottom)

| Key | Value | Note |
| --- | ----- | ---- |
| `anchor` | `Bottom` | |
| `autohide` | `Never` | |
| `exclusive_zone` | `true` | |
| `size_center` | `None` | Uses the auto/default dock icon size. |

Center: `CosmicAppList` (pinned/favourites) and `CosmicAppletMinimize`. Both wings empty.

### Clock and battery

| Applet | Key | Value |
| ------ | --- | ----- |
| `CosmicAppletTime` | `military_time` | `false` — 12-hour clock |
| | `show_date_in_top_panel` | `true` |
| | `first_day_of_week` | `6` (Saturday) |
| `CosmicAppletBattery` | `show_percentage` | `true` |

### Changing them

COSMIC has no dconf equivalent — these are RON files. Edit them, then log out and back in. The GUI equivalent is **Settings → Desktop → Panel/Dock**.

```bash
# Example: make the panel autohide — never -> always, then re-login
echo Always > ~/.config/cosmic/com.system76.CosmicPanel.Panel/v1/autohide
```

Prefer the GUI. Hand-editing RON across a versioned `v1/`/`v2/` layout is easy to get wrong, and a malformed value can make COSMIC fall back to defaults for that app on next start.

---

## 4. Theme, Fonts & Density

All in `com.system76.CosmicTk/v1/` (or the `CosmicTheme.*` dirs for colours).

| Key | File | Live value |
| --- | ---- | ---------- |
| Icon theme | `CosmicTk/v1/icon_theme` | **`"Reversal-grey"`** |
| Interface font | `CosmicTk/v1/interface_font` | **`family: "JetBrainsMonoNL Nerd Font"`** (weight/stretch/style all Normal) |
| Monospace font | `CosmicTk/v1/monospace_font` | **`family: "JetBrains Mono"`** |
| Header size | `CosmicTk/v1/header_size` | **`Compact`** |
| Interface density | `CosmicTk/v1/interface_density` | **`Compact`** |

`Compact` + `Compact` is the tightest layout COSMIC offers: smaller window headers and denser spacing throughout. This matters on a 1366×768-class laptop panel where every vertical pixel is visible.

### Dark / light / auto mode

`com.system76.CosmicTheme.Mode` selects which of the two colour sets applies. Both are shipped (`CosmicTheme.Dark/v2/` and `CosmicTheme.Light/v2/`, ~40 keys each: palette, accent, backgrounds, frosted/transparency, corner radii, spacing, button tints). Switching mode in **Settings → Appearance** just flips which set is active — no files need to change.

### Accent

`com.system76.CosmicTheme.Dark/v2/accent` (+ `accent_button`, `accent_text`) sets the highlight colour. The `.Builder` themes (`CosmicTheme.Dark.Builder/v2/`, `.Light.Builder/v2/`) hold the *generator inputs* — accent colour plus neutrals — from which COSMIC derives a full consistent palette. Editing `accent` directly is fine; editing the Builder dirs by hand is not.

### Font dependency

**`JetBrainsMonoNL Nerd Font` and `JetBrains Mono` are not vendored in `cosmic/`.** They come from the font tree under the other DE directories. On a genuinely fresh machine, install them before running the restore, or COSMIC will silently fall back to a default font:

```bash
fc-cache -f
fc-list | grep -i 'jetbrains'
```

`setup.sh` runs `fc-cache -f` and then refreshes the GTK4 (or GTK3) icon cache, since GTK-based apps — including some COSMIC components — cache icon theme and font choices at startup.

---

## 5. Tiling & Workspaces

`com.system76.CosmicComp/v1/` — this is the compositor config, and it is where the most opinionated choices live.

| Key | Value | What it means |
| --- | ----- | ------------- |
| `autotile` | **`true`** | Windows tile automatically as they open. This is the big one — no manual tiling needed. |
| `autotile_behavior` | `PerWorkspace` | Tiling is tracked per workspace, not globally. |
| `workspaces.workspace_mode` | **`OutputBound`** | Each monitor gets its own independent workspace set. |
| `workspaces.workspace_layout` | **`Horizontal`** | Workspaces are a horizontal strip. |
| `workspaces.action_on_typing` | `OpenLauncher` | Toggling a workspace while typing opens the launcher instead of switching — protects text entry. |
| `workspaces.workspace_wraparound` | `true` | Moving right off the last workspace wraps to the first. |
| `focus_follows_cursor` | `true` | Keyboard focus follows the mouse. |
| `focus_follows_cursor_delay` | (default) | Grace period before focus actually moves. |

### OutputBound vs Global

With **`OutputBound`** (what this machine uses), workspaces are scoped to an output. On the single internal panel this behaves like normal workspaces, but it means an external monitor gets its own workspace sequence rather than mirroring the laptop's. That is the right default for a dualboot laptop that gets plugged into a desk monitor sometimes.

`Global` would share one workspace sequence across all outputs. Switch with **Settings → Desktop → Workspaces**.

### Input

`com.system76.CosmicComp/v1/input_default` — pointer is **Enabled** with a **Flat** acceleration profile at `speed: -0.102886…`, `left_handed: false`. The flat profile is the near-linear one: it gives a usable throw distance without the acceleration curve fighting a trackpad.

### Appearance

`appearance_settings` has `clip_floating_windows`, `clip_tiled_windows` and `shadow_tiled_windows` all `false` — no rounded corners or drop shadows on tiled windows. Combined with `interface_density: Compact` this is the flat, dense look the rest of the config is built around.

### XKB

`xkb_config`: model `pc105+inet`, layout `us`, options `terminate:ctrl_alt_bksp`, repeat delay 600ms, rate 25. Note there is **no `Super` key** — `Super` here is the GNOME-style mapping handled by COSMIC itself, not an XKB remap.

---

## 6. Terminal, Shell & Prompt

### kitty

Config lives in **`common/.config/kitty/`** (`kitty.conf`, `current-theme.conf`) — shared with the GNOME tree, not duplicated under `cosmic/`. JetBrains Mono, reduced opacity, GPU rendering.

```bash
ls ~/.config/kitty/          # → current-theme.conf  kitty.conf
fc-list | grep -i jetbrains  # fonts must exist before kitty looks right
```

### Starship

`common/.config/starship.toml` — Tokyo Night preset with rounded segments, git status and time.

Starship **is** in the Tumbleweed repos, so `pkg_install` handles it. (The GNOME script predates that and still uses the curl installer; this one does not.)

```bash
zypper se -x --match-exact starship
command -v starship && starship --version
```

### .bashrc — now shared

`cosmic/.bashrc` **no longer exists**. It moved to **`common/.bashrc`**, shared by all three DE trees. `setup.sh` copies it with the same guarded block `gnome/setup.sh` uses: if your `~/.bashrc` already carries the common aliases it is left untouched, otherwise it is copied with a `.bashrc~` backup.

The file ships everything already wired:

```bash
eval "$(starship init bash)"
export NODE_OPTIONS="--max-old-space-size=1536"      # cap the V8 heap so builds cannot starve 8GB RAM
alias rest='sudo systemctl restart dev-zram0.swap && sudo systemctl restart display-manager'  # distro-fresh-alias
alias game='sudo /usr/sbin/sysctl -w vm.swappiness=10 >/dev/null && echo game: swappiness 10'
alias code='sudo /usr/sbin/sysctl -w vm.swappiness=180 >/dev/null && echo code: swappiness 180'
```

Two things to know:

- The alias is **`rest`**, not `fresh` as in the older GNOME docs.
- `game` and `code` change swappiness **for the current boot only**. The persistent value is `/etc/sysctl.d/99-swappiness.conf` (Section 1A); run either alias again after a reboot to match.

### PATH

```bash
export PATH="/home/julry/.opencode/bin:$PATH"   # ← hardcoded; setup.sh rebases this to $HOME
export PATH="$HOME/.local/bin:$PATH"
```

`setup.sh` rewrites the first line on **every run** (and verifies the rewrite landed). Two caveats:

- `~/.opencode/bin` **does not exist** on this machine — the entry is harmless but dead, since `opencode` actually resolves through the nvm Node install (`~/.config/nvm/versions/node/v24.21.0/bin/opencode`).
- This is a `sed` into a tracked file in the repo. If you pull and the file conflicts, resolve by hand.

---

## 7. OpenCode Workspace

### Layout

| Path | Scope |
| ---- | ----- |
| `common/.config/opencode/opencode.jsonc` | **Shared.** The single OpenCode config. |
| `common/.config/opencode/plugins/rtk.ts` | Shared. Command-rewrite hook. |
| `common/.config/opencode/plugins/caveman.ts` | Shared. Caveman skill/command loader. |
| `common/.config/opencode/caveman/SKILL.md` | Shared. The skill body. |
| `common/.config/opencode/caveman/commands/` | Shared. `caveman.md`, `caveman-commit.md`, `caveman-review.md`. |

`common/.config/opencode/` is the **only** OpenCode config in the repo. The `plugins/` and `caveman/` subtrees live there too, so all three DE trees get identical agent behaviour from one copy.

### The shared config

`opencode.jsonc` lives **only** at `common/.config/opencode/opencode.jsonc` — there is no per-DE copy, and `cosmic/`, `gnome/` and `xfce/` no longer contain an `opencode/` directory at all.

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "compaction": { "auto": true, "tail_turns": 10 },
  "plugin": ["@dietrichgebert/ponytail"]
}
```

The `provider` / `models` block was **removed deliberately**. No DE declares a model, a context ceiling or an output ceiling any more, so OpenCode falls back to its own defaults instead of a hand-pinned per-DE free model. To change the model configuration, edit `common/.config/opencode/opencode.jsonc` — every DE picks it up on its next run, because they all restore from the same shared tree.

Compaction is automatic at 10 tail turns — deliberate, because long agent sessions on this hardware otherwise accumulate context faster than the model's window allows.

### Why `caveman.ts` is a local fork

`caveman.ts` is a **port of `opencode-caveman@0.1.4`, not a dependency on it**, and the reason is an API break:

- The V1 plugin API exports a `server()` function. The OpenCode 2.x loader rejects it with `PluginModule.LoadError` — the V1 plugin simply does not load.
- V2 has **no `config` hook**. The domains that own skills and commands own them now. Instead of copying files into the config dir from a `config` hook, the port registers both through the transforms those domains expose.

So the local file is not gratuitous duplication — it is the only version of this plugin that runs on the installed OpenCode.

`rtk.ts` hooks `execute.before` and pipes Bash/shell commands through `rtk rewrite` before they run. It fails open: if `rtk` is missing or returns empty, the original command is used unchanged.

### Verify

```bash
ls ~/.config/opencode/plugins/          # caveman.ts  rtk.ts
ls ~/.config/opencode/caveman/commands/ # caveman-commit.md  caveman-review.md  caveman.md
opencode --version
```

If a skill does not appear, check that `caveman/SKILL.md` has valid YAML frontmatter — the loader reads the description from it, and a malformed block makes the skill silently unregister.

---

## 8. Fastfetch & Wallpaper

### Fastfetch

Config is **`common/.config/fastfetch/config.jsonc`** (shared). The logo is a kitty-graphics image, so it renders only inside kitty; other terminals get the fallback.

### Wallpaper

Stored inside the COSMIC config backup, which is why it is a Section 2 concern rather than a separate file:

```
com.system76.CosmicBackground/v1/all
```

```ron
(
    output: "all",
    source: Path("/home/julry/wallpapers/bg1.jpg"),
    filter_by_theme: true,
    rotation_frequency: 300,
    filter_method: Lanczos,
    scaling_mode: Zoom,
    sampling_method: Alphanumeric,
)
```

- `rotation_frequency: 300` — the wallpaper changes every 5 minutes from the custom image list.
- `filter_by_theme: true` — a different image per light/dark mode.
- `scaling_mode: Zoom` — crops to fill, no letterboxing. Right choice for a laptop panel.
- `same-on-all: true` — one wallpaper across every output.

**The wallpaper image itself is not in the repo.** `~/wallpapers/bg1.jpg` lives only on this machine. On a fresh install, copy your images there first, or `setup.sh`'s path rebase will point at a file that does not exist and COSMIC falls back to a solid colour.

```bash
ls ~/wallpapers/                       # images must exist here
mkdir -p ~/wallpapers                  # if not
```

---

## 9. YaST / root GUI access — read this before using it

**`cosmic/.config/autostart/xhost-root.desktop` is shipped in this repo on purpose. Do not delete it unless you have decided you do not need it.**

```
[Desktop Entry]
Type=Application
Name=Allow Root GUI Apps
Exec=xhost +si:localuser:root
Terminal=false
```

### What it does, stated plainly

At every login, this runs `xhost +si:localuser:root`, which **adds the local `root` user to the X server's access list.**

That means: for the remainder of the session, **any process running as root on this machine can open windows on your display and read everything on it** — every window title, every screenshot-able pixel, and the keystrokes of anything you type into a root-owned window. This is not a theoretical risk. A malicious script launched via `sudo` can render a window that looks exactly like a YaST dialog and capture what you type into it.

It is persisted at session level, not system level. `setup.sh` verifies the file is present and prints:

```
[ok] autostart/xhost-root.desktop installed — root X access is GRANTED (setup.md Section 9)
```

so the grant is never silent.

The reason it exists: YaST (`yast`) and some YaST modules have poor or absent terminal UIs. Without this grant, a GUI module either refuses to start or renders blank.

### How to revoke

```bash
# Revoke now (this session only):
xhost -si:localuser:root

# Revoke permanently — move the autostart entry out of the way:
mv ~/.config/autostart/xhost-root.desktop ~/.config/autostart/xhost-root.desktop.disabled
```

Confirm it is gone:

```bash
xhost                                   # root should NOT appear in the output
ls ~/.config/autostart/                 # no xhost-root.desktop
```

### The safe alternative (on demand)

Run YaST in a terminal instead. No grant, no persistent exposure:

```bash
sudo yast2                                   # full YaST, TUI/text where it exists
sudo yast2 bootloader                        # e.g. bootloader config
sudo yast2 users-and-groups
```

For the few modules that genuinely need X — `yast2` with an explicit GTK flag, or the hardware/`nvidia` modules — grant it for the duration of one command and drop it immediately:

```bash
xhost +si:localuser:root
sudo yast2 <module>
xhost -si:localuser:root
```

If that two-step dance gets old enough to annoy you, that annoyance is the argument for the safe alternative rather than a reason to keep the permanent grant.

---

## 10. Keyboard shortcuts

`com.system76.CosmicSettings.Shortcuts/v1/` — two files, `custom` and `system_actions`, in RON.

| File | Contents |
| ---- | -------- |
| `custom` | User-defined shortcuts. Entries explicitly `Disable`d show up here as explicit disables, so a distro default that has been switched off stays off after a restore. |
| `system_actions` | The COSMIC-side action list the bindings map onto. |

Selected live bindings:

| Shortcut | Action |
| -------- | ------ |
| `Super+Return` | Terminal |
| `Super+e` | Home folder |
| `Super+f` | Maximize |
| `Shift+Super+f` | Fullscreen |
| `Super` (alone) | Workspace overview |
| `Super+F11` | `Disable` — explicitly unbound, not merely absent |
| `Ctrl+a` | `Disable` — unbound, so select-all keeps the app default |
| `Super+t`, `Super+m`, `Super+z` | `Disable` |

`Super+e` here is the **COSMIC file manager**, not GNOME Files. On this machine that is `cosmic-files` via the cosmic-session launcher, which is a different binary from Nautilus.

Changing these: **Settings → Keyboard → Shortcuts**, which writes back to the same files. Hand-editing RON is possible but error-prone — a malformed map can make COSMIC ignore the whole file and fall back to defaults. **Log out and back in after any change**; the compositor does not hot-reload the shortcut table.

---

## 11. Fresh Install / No-Reboot Reset

### Full undo

```bash
# 1. Remove what this script installed
sudo zypper -r earlyoom zram-generator   # if you installed them only for this setup

# 2. Remove the sysctl drop-ins
sudo rm -f /etc/sysctl.d/99-swappiness.conf \
           /etc/sysctl.d/70-vfs-cache-pressure.conf \
           /etc/sysctl.d/80-dirty-ratios.conf \
           /etc/sysctl.d/85-watermark-boost.conf \
           /etc/sysctl.d/86-watermark-scale.conf
sudo sysctl --system

# 3. Stop the zram swap device
sudo systemctl disable --now systemd-zram-setup@zram0.service dev-zram0.swap

# 4. Restore the earlyoom policy to stock
sudo rm -f /etc/sysconfig/earlyoom && sudo systemctl restart earlyoom

# 5. Remove the COSMIC config and re-log-in for defaults
mv ~/.config/cosmic ~/.config/cosmic.disabled

# 6. Remove the shared dotfiles
rm -rf ~/.config/{kitty,fastfetch,opencode,spotatui,zed} ~/.config/starship.toml

# 7. Remove the root X grant — see Section 9
mv ~/.config/autostart/xhost-root.desktop ~/.config/autostart/xhost-root.desktop.disabled
xhost -si:localuser:root
```

**What the bootloader and Secure Boot chain need:** nothing. This setup never touches them. If you want them gone, that is the `gnome/setup.md` Section 12/13 territory and you should read it first — removing the wrong EFI binary from a dualboot machine is how you lose Windows.

### No-reboot reset (fast path)

Most of this needs a log-out, not a reboot:

```bash
alias rest='sudo systemctl restart dev-zram0.swap && sudo systemctl restart display-manager'
```

That restarts the zram swap and the display manager in one go — **it logs you out.** Save your work first.

| Change | Needs | Why |
| ------ | ----- | --- |
| COSMIC config restore | Log out / `rest` | COSMIC reads config at session start. |
| Dotfiles, kitty, starship, opencode | Log out | Apps read config at startup. |
| Font + icon cache | Log out | `fc-cache` alone is not enough for already-running apps. |
| `vm.swappiness` | New shell | `code` / `game` aliases are per-boot. |
| sysctl drop-ins | **Reboot** | Kernel re-reads `/etc/sysctl.d` at boot. |
| ZRAM | **Reboot** | Device does not re-init cleanly mid-session. |
| EarlyOOM | None | `systemctl restart earlyoom` applies immediately. |

### If you want the COSMIC greeter instead of GDM

Read this before running it. Enabling greetd takes over the login screen from GDM:

```bash
sudo systemctl enable greetd --now
```

There is no clean "run both" state — `display-manager.service` points at one or the other. To go back:

```bash
sudo systemctl disable greetd --now
sudo systemctl enable gdm --now
```

`setup.sh` does none of this by design. This machine currently runs **GDM**, greetd is **disabled**, and `cosmic-greeter` is installed but never invoked.

---

## 12. Known Drift & TODO

Things that are true right now and will bite later.

| # | Issue | Impact | Fix |
| - | ----- | ------ | --- |
| 1 | **`~/.opencode/bin` in `common/.bashrc` does not exist** | Dead `PATH` entry. `opencode` actually resolves via nvm (`~/.config/nvm/versions/node/v24.21.0/bin`). | Drop the line, or point it at the nvm bin dir. |
| 2 | **Four cosmic files hardcode `/home/julry`** | Restoring onto another account gives broken wallpaper and bookmarks. | `setup.sh` rebases them on the installed copy. Do **not** commit a rebased copy back to the repo. |
| 3 | **`~/wallpapers/bg1.jpg` is not in the repo** | Fresh install gets a flat background. | Copy the images to `~/wallpapers/` before restoring. |
| 4 | **`zed` is not in the Tumbleweed repos** | `zypper se -x --match-exact zed` returns nothing. Installed manually at `~/.local/zed.app` with a symlink in `~/.local/bin`. | Install manually; `setup.sh` reports it as a leftover, not a failure. |
| 5 | **The `rest` alias name** | Older docs say `fresh`. | Use `rest`. |
| 6 | **`setup.sh` mutates two tracked repo files** | `common/.bashrc` and `common/.config/opencode/opencode.jsonc` are `sed`-ed in place on every run. A pull can conflict. | Resolve conflicts by hand; consider moving the rewrite to a non-tracked copy. |
| 7 | **COSMIC config is versioned `v1/`/`v2/` per app** | A COSMIC upgrade that bumps the version leaves the old dir in place and the new one at defaults. | After a COSMIC upgrade, check whether any dir gained a `v3/`, then re-run the restore. |
| 8 | **Autotile + `action_on_typing: OpenLauncher`** | Occasionally surprising: typing while switching workspaces opens the launcher. | `com.system76.CosmicComp/v1/workspaces` → `action_on_typing`, or via Settings. |
| 9 | **Shortcuts do not hot-reload** | Edits appear to do nothing until re-login. | Log out and back in. |
| 10 | **README not yet updated for the `common/` split** | `cosmic/.bashrc`, `cosmic/.config/fastfetch/`, kitty and starship configs all moved. | Update `README.md` and `gnome/setup.md` §8 references. |
| 11 | **snapper step is post-restore, not pre-restore** | A bad run is captured *by* the snapshot, not protected from it. | That is deliberate — the tar in `~/.cache/` is the pre-restore net. |
| 12 | **No `.output~`-style rollback for `common/.config`** | `cp -rb` backs up per file as `~`, but there is no whole-tree tar like the cosmic one. | Back up `~/.config/{kitty,fastfetch,opencode,spotatui,zed}` by hand before a risky run. |

### TODO

- [ ] Drop or fix the dead `~/.opencode/bin` `PATH` entry (item 1).
- [ ] Make `setup.sh` write rebased copies to a scratch dir instead of mutating tracked repo files (item 6).
- [ ] Reconcile `README.md` and `gnome/setup.md` §8 with the `common/` split (item 10).
- [ ] Decide whether the COSMIC greeter should ever replace GDM — currently it never runs (Section 11).
- [ ] Confirm whether `cosmic-greeter` should stay installed at all while greetd is disabled.

---

## Summary Table

### System

| What this applies | Before | After | Notes |
| ----------------- | ------ | ----- | ----- |
| `vm.swappiness` | `60` | **`180`** | ZRAM-first. `code` alias re-applies per boot, `game` drops to 10. |
| `vm.page_cluster` | `0` | `0` | One page per swap I/O. |
| `vm.vfs_cache_pressure` | `100` | **`125`** | Faster dentry/inode reclaim. |
| `vm.dirty_ratio` / `_background_ratio` | `20` / `10` | **`10` / `5`** | Smaller writeback bursts. |
| `vm.watermark_boost_factor` | `10000` | **`0`** | No sudden reclaim stalls. |
| `vm.watermark_scale_factor` | `10` | **`150`** | Earlier, gentler reclaim. |
| ZRAM swap | SSD swapfile | **zstd, `min(ram)`** | Via `zram-generator`. Asserted with `zramctl`. |
| EarlyOOM | none | **`active`** | Protects zed/opencode/node/kitty/bash; prefers killing Brave. |
| ModemManager | enabled | **disabled** | No mobile broadband on this laptop. |
| Bootloader / Secure Boot | — | **untouched** | By design. See `gnome/setup.md` §12–13. |
| Snapper | — | **`post-cosmic-restore` snapshot** | Guarded on `command -v snapper`. |

### Desktop

| What this applies | Before | After | Notes |
| ----------------- | ------ | ----- | ----- |
| COSMIC config restore | stock / empty | **189 files, 33 setting dirs** | The primary payload. `cp -a`, tar-backed. |
| Icon theme | distro default | **`Reversal-grey`** | Not vendored — must be installed separately. |
| Interface font | default | **`JetBrainsMonoNL Nerd Font`** | From the font tree in the other DE dirs. |
| Monospace font | default | **`JetBrains Mono`** | |
| Header size / density | default | **`Compact` / `Compact`** | Tightest layout. |
| Panel | default | **Left-anchored, XS, never autohide, exclusive zone** | Clock centre; workspaces + applets in the wings. |
| Dock | default | **Bottom, never autohide, exclusive zone** | App list + minimise centre, empty wings. |
| Clock | default | **12-hour, date shown, week starts Saturday** | |
| Battery applet | default | **percentage shown** | |
| Autotile | off | **`true`, `PerWorkspace`** | |
| Workspaces | default | **OutputBound, Horizontal**, wraparound on | Typing opens the launcher instead of switching. |
| Pointer accel | default | **Enabled, Flat profile** | `left_handed: false`. |
| Window clipping/shadows | on | **all off** | Flat tiled windows. |
| Wallpaper | stock | `bg1.jpg`, Zoom, 5-min rotation, theme-filtered | Image itself is **not** in the repo. |
| Keyboard shortcuts | defaults | **COSMIC binding set** | No hot-reload — re-login required. |

### Workspace

| What this applies | Before | After | Notes |
| ----------------- | ------ | ----- | ----- |
| `.bashrc` | per-DE copies | **`common/.bashrc`** | Ships starship init, `NODE_OPTIONS=1536`, `rest`/`game`/`code`. |
| kitty + starship | per-DE | **`common/.config/`** | Shared tree. |
| OpenCode config | per-DE | **`common/.config/opencode/`** | Single shared `opencode.jsonc`. No per-DE copy, no declared model ceilings. |
| OpenCode plugins + caveman | per-DE | **`common/.config/opencode/`** | `plugins/rtk.ts`, `plugins/caveman.ts`, `caveman/` |
| `caveman.ts` | `opencode-caveman@0.1.4` | **local V2 port** | V1 `server()` export is rejected by the OpenCode 2.x loader. |
| Fastfetch | per-DE | **`common/.config/fastfetch/`** | |
| Root GUI access | none | **`xhost +si:localuser:root` at login** | Deliberate. **Persistent X-server exposure** — see Section 9. |
| Display manager | GDM | **GDM (unchanged)** | `greetd` stays disabled; `cosmic-greeter` stays inactive. |