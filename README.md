# linux-dotfiles

Per-desktop backup of my Linux setup.

- `cosmic/` — COSMIC DE on openSUSE Tumbleweed. **Daily driver.** Config only — no restore script yet.
- `gnome/` — GNOME on openSUSE Tumbleweed. Retained as a deliberate fallback.
- `xfce/` — XFCE on Mint/Ubuntu (apt) or openSUSE TW (zypper). XFCE-only.
- `sway/` — **ARCHIVED.** Config backup from a removed session; none of its packages are installed.
- `sessions/` — AI conversation transcripts from setting this repo up. History, not config.
- `common/` — assets and config shared by all three desktops: shell config, Nerd Fonts, wallpaper, logo.

Personal backup. No license granted — all rights reserved.

## Contents

| Path                                  | Description                                                                                                                                                             |
| ------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `cosmic/.config/autostart/`           | `xhost-root.desktop` — grants root X access for YaST GUI. **Kept deliberately; kept knowingly.**                                                 |
| `common/.config/opencode/`            | Single shared OpenCode config + plugins (`rtk.ts`, `caveman.ts`) + caveman skill                                                                                         |
| `cosmic/.bashrc`                      | Shell aliases, starship hook, `NODE_OPTIONS=1536`                                                                                                                       |
| `gnome/setup.sh`                      | One-command restore for fresh openSUSE TW GNOME install — GNOME-only, zypper only, GDM restart                                                                          |
| `gnome/setup.md`                      | Post-install guide: kernel/ZRAM/EarlyOOM/ModemManager/Node tunings, extensions, dconf, search+index mask, autostart masks                                                 |
| `gnome/dconf/`                        | Text dumps only (8 files): dash-to-panel, blur-my-shell panel+apps, interface, media-keys, and the wm/shell/mutter keybindings. Never the binary `~/.config/dconf/user` |
| `gnome/extensions/list.txt`           | Enabled extensions (blur-my-shell, dash-to-panel, disable-workspace-switcher)                                                                                            |
| `common/assets/jm-icon.png`           | Custom dash-to-panel app icon + fastfetch logo referenced by the dconf dump. Copied to `~/Documents/` by every `setup.sh`                                              |
| `xfce/setup.sh`                       | One-command restore for fresh XFCE install — per-distro branches                                                                                                       |
| `xfce/setup.md`                       | Post-install guide: performance, storage, MT7902 + Acer drivers, keybinds, cleanup, autostart, rofi, screen dim, ZRAM                                                    |
| `xfce/fresh-install.md`               | XFCE one-command guide (Mint / TW XFCE)                                                                                                                                  |
| `xfce/drivers/mt7902/`                | Vendored MediaTek MT7902 Wi-Fi + Bluetooth DKMS sources + firmware — MediaTek 7902 cards only                                                                           |
| `xfce/.config/xfce4/`                 | XFCE keyboard shortcuts (Super+B Brave, Super+R rofi, Super+Return Kitty)                                                                                             |
| `xfce/.config/rofi/`                  | Rofi Type-3 launcher (Gruvbox palette, WhiteSur icons)                                                                                                                  |
| `xfce/.config/picom/`, `gtk-3.0/`, `autostart/` | Compositor config, panel CSS, autostart overrides (`Hidden=true` disables Mint welcome/reports)                                                             |
| `xfce/.themes/`                       | Gruvbox XFCE window themes (BL-LB-Dark-Soft + hdpi/xhdpi)                                                                                                             |
| `common/.local/share/fonts/`          | Shared Nerd fonts (JetBrains Mono etc.). Every `setup.sh` copies these — kitty/fastfetch/starship need them on any DE                                                      |
| `sway/.config/{sway,waybar,mako,wofi}/` | Archived sway compositor + bar + notification config                                                                                                                 |
| `sway/.local/bin/`                    | Archived sway helper scripts (shot, wifi-menu, power-menu, launcher)                                                                                                    |
| `sessions/`                           | AI conversation transcripts (13 files, ~3.6MB) — setup history, not config                                                                                            |
| `common/wallpapers/bg1.jpg`           | Shared wallpaper. Every `setup.sh` copies it to `~/wallpapers/`; the COSMIC config and the XFCE slick-greeter both point at that copy                                           |
| `opencode.json`, `.opencode/`         | Agent workspace config, rules, memory, skills                                                                                                                           |
| `AGENTS.md`                           | Agent workspace instructions                                                                                                                                              |

### Shared across desktops

These files are **byte-identical copies** in `cosmic/`, `gnome/` and `xfce/`. Edit one and you must edit all three until they are consolidated into a single `common/` tree:

| File                                              | Copies |
| ------------------------------------------------- | ------ |
| `.bashrc`                                         | 3      |
| `.config/fastfetch/config.jsonc`                  | 3      |
| `.config/spotatui/youtube_playlists.yml`          | 3      |
| `.config/kitty/`, `.config/starship.toml`         | 2 (gnome, xfce) |
| `.config/zed/`                                    | 2 (gnome, xfce) |
| `.config/opencode/` (config + plugins + skill)    | 1 (common/) |

### Not vendored

- **Icon themes.** `xfce/.icons/` (WhiteSur-grey) was 187 MB across 43,099 files — 98% of the repo — and was removed so clones stay small. `xfce/setup.sh` no longer installs icons. See `xfce/setup.md` §0 for the install step.
- **Hyprland / ML4W.** Tried and removed. `rpm -q hyprland` → not installed. Do not re-attempt without reason.

## Getting Started on a New Machine

XFCE (Mint/Ubuntu or openSUSE TW XFCE, details in `xfce/fresh-install.md`):

```bash
if command -v apt >/dev/null; then sudo apt install -y git; else sudo zypper in -y git; fi && git clone --depth=1 https://github.com/worriee/linux-dotfiles.git && cd linux-dotfiles && bash xfce/setup.sh
```

GNOME (openSUSE Tumbleweed GNOME only, details in `gnome/setup.md`):

```bash
sudo zypper in -y git && git clone --depth=1 https://github.com/worriee/linux-dotfiles.git && cd linux-dotfiles && bash gnome/setup.sh
```

## What each script applies

**COSMIC** — config only. No restore script and no desktop-config backup exist yet; rebuilding a COSMIC machine from this repo alone is not currently possible.

**XFCE** — dotfiles/themes/fonts copy, swappiness 180 + page-cluster 0 (zram pairing), kernel VM tuning (vfs 125, dirty 10/5, watermark 0/150), EarlyOOM guard (protect zed/opencode/node/kitty/bash, prefer brave/brave-browser), ModemManager disable, GRUB timeout 5s (Mint only), ext4 reserve 1% (btrfs auto-skips), ZRAM zstd 100% RAM, slick-greeter login screen, screen dim toggle, optional MT7902 + Acer battery drivers. Icons are not installed (see above). Manual leftovers (Brave, Zed) in the fresh-install guide.

**GNOME** — same tunings as XFCE via `zram-generator` + `/etc/sysconfig/earlyoom`: swappiness 180 + page-cluster 0, dotfiles + `dconf load` (all 8 dumps), extensions reinstall, animations off, localsearch-3 + evolution masks, software download-updates off, cups/avahi disable (bluetooth kept), bootloader untouched, btrfs snapper snapshot. MT7902 skipped by design (in-kernel `mt7921e`); Acer charge cap skipped.

Prefer doing it manually? Follow the matching `setup.md` section by section.
