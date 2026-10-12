#!/usr/bin/env bash
# setup.sh — One-command restore of this dotfiles repo onto a fresh openSUSE COSMIC install (COSMIC-only).
# Run from inside the cloned repo:  bash cosmic/setup.sh
# Full instructions: cosmic/setup.md
#
# Esc hatch for running from a TTY that is not COSMIC (see Section 0 of setup.md):
#   COSMIC_SETUP_ALLOW_ANY_DE=1 bash cosmic/setup.sh
# COSMIC is the primary payload of this repo — without it there is nothing to restore.

set -u

REPO="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/../common" 2>/dev/null && pwd)"
HOME_DIR="${HOME}"
OK()   { printf '  \033[32m[ok]\033[0m %s\n' "$*"; }
WARN() { printf '  \033[33m[!!]\033[0m %s\n' "$*"; }
STEP() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }

FAILED_STEPS=()
run_step() { # run_step <label> <command...>  — a failed step is logged, not fatal
    local label="$1"; shift
    STEP "$label"
    if "$@"; then OK "$label"
    else WARN "$label failed — continuing"; FAILED_STEPS+=("$label"); fi
}

# ------------------------------------------------
# 0. DE guard (COSMIC-only)
# ------------------------------------------------
# Upstream (gnome/, xfce/) is openSUSE-only; here the package layer goes through
# common/detect-distro.sh so zypper and apt both work, but the DE guard stays strict.
case "${XDG_CURRENT_DESKTOP:-}" in
    *COSMIC*|*cosmic*)
        DE_LABEL="${XDG_CURRENT_DESKTOP}"
        ;;
    *)
        if pgrep -x cosmic-comp >/dev/null 2>&1 || pgrep -x cosmic-session >/dev/null 2>&1; then
            DE_LABEL="${XDG_CURRENT_DESKTOP:-cosmic-comp (detected via pgrep)}"
        elif [ "${COSMIC_SETUP_ALLOW_ANY_DE:-0}" = "1" ]; then
            DE_LABEL="${XDG_CURRENT_DESKTOP:-unknown} (override: COSMIC_SETUP_ALLOW_ANY_DE=1)"
            echo "  override accepted — desktop is '${DE_LABEL}', not COSMIC."
            echo "  Panel/dock/theme restore will not be picked up until you log into COSMIC."
        else
            echo "COSMIC-only repo: detected desktop '${XDG_CURRENT_DESKTOP:-unknown}'. Aborting." >&2
            echo "  Log into a COSMIC session, or re-run with COSMIC_SETUP_ALLOW_ANY_DE=1" >&2
            echo "  (see cosmic/setup.md Section 0)." >&2
            exit 1
        fi
        ;;
esac

if [ -z "${COMMON_DIR:-}" ] || [ ! -f "$COMMON_DIR/detect-distro.sh" ]; then
    echo "common/detect-distro.sh not found next to cosmic/ — repo layout broken. Aborting." >&2
    exit 1
fi
# shellcheck disable=SC1091
. "$COMMON_DIR/detect-distro.sh"
confirm_distro

echo "==============================================="
echo " COSMIC dotfiles restore (COSMIC-only)"
echo " repo   : $REPO"
echo " user   : $(whoami)  home: $HOME_DIR"
echo " distro : ${DISTRO:-unknown} (family: ${DISTRO_FAMILY:-unknown}, pkg mgr: ${PKG_MGR:-none})"
echo " desktop: $DE_LABEL"
echo "==============================================="

# ------------------------------------------------
# 1. Fix hardcoded paths in repo copies
# ------------------------------------------------
# Unlike gnome/setup.sh, this verifies the rewrite landed instead of swallowing sed's
# exit status with `2>/dev/null || true` and printing OK regardless.
STEP "Fixing hardcoded paths (/home/julry -> $HOME_DIR)"
_PATH_FILES=()
for _f in "$COMMON_DIR/.bashrc" "$COMMON_DIR/.config/opencode/opencode.jsonc" "$COMMON_DIR/.config/fastfetch/config.jsonc"; do
    [ -f "$_f" ] && _PATH_FILES+=("$_f")
done
if [ "$HOME_DIR" = "/home/julry" ]; then
    # The rewrite target equals the source: sed would be a no-op, and a
    # "no /home/julry left" check would false-positive on every run here.
    OK "HOME is already /home/julry — nothing to rewrite (${#_PATH_FILES[@]} file(s) checked)"
elif [ "${#_PATH_FILES[@]}" -eq 0 ]; then
    WARN "no path-carrying files found — rewrite skipped"
else
    if sed -i "s|/home/julry|$HOME_DIR|g" "${_PATH_FILES[@]}"; then
        _LEFT="$(grep -l '/home/julry' "${_PATH_FILES[@]}" 2>/dev/null || true)"
        if [ -z "${_LEFT:-}" ]; then
            OK "paths rewritten in ${#_PATH_FILES[@]} file(s), no /home/julry left"
        else
            WARN "path rewrite incomplete: $_LEFT"; FAILED_STEPS+=("path rewrite verify")
        fi
        unset _LEFT
    else
        WARN "sed failed on: ${_PATH_FILES[*]}"; FAILED_STEPS+=("path rewrite")
    fi
fi
unset _f _PATH_FILES

# ------------------------------------------------
# 2. Packages — availability dry-run
# ------------------------------------------------
# zed/brave-browser: brave is in the Tumbleweed repos, zed is NOT (it is a manual
# tarball in ~/.local/zed.app). Availability is queried, never assumed.
STEP "Checking package availability (dry-run)"
CORE_PKGS="kitty starship fastfetch brave-browser opencode earlyoom zram-generator xhost"
DE_PKGS="cosmic-session cosmic-comp cosmic-settings"
AVAILABLE_PKGS=""
MANUAL_PKGS=""
for _pkg in $CORE_PKGS $DE_PKGS; do
    if pkg_query "$_pkg"; then
        AVAILABLE_PKGS="${AVAILABLE_PKGS:+$AVAILABLE_PKGS }$_pkg"
        case " $CORE_PKGS " in *" $_pkg "*) OK "$_pkg found" ;; esac
    else
        case " $CORE_PKGS " in
            *" $_pkg "*) WARN "$_pkg not in repos — expect a manual install"; MANUAL_PKGS="${MANUAL_PKGS:+$MANUAL_PKGS }$_pkg" ;;
            *) WARN "$_pkg not in repos — COSMIC stack may be incomplete" ;;
        esac
    fi
done
unset _pkg
[ -n "${MANUAL_PKGS:-}" ] && OK "manual leftovers flagged: $MANUAL_PKGS"

# ------------------------------------------------
# 3. Install tooling
# ------------------------------------------------
STEP "Installing DE-agnostic tooling via pkg_install ($PKG_MGR)"
if [ -z "${AVAILABLE_PKGS:-}" ]; then
    OK "nothing installable found — skip (install by hand)"
else
    # A missing optional package must not fail the run: -n install aborts the whole
    # transaction on an unresolvable name, so anything unavailable was already dropped
    # from AVAILABLE_PKGS above.
    if [ "${PKG_MGR}" = "zypper" ]; then
        sudo zypper -n ref >/dev/null 2>&1 || true
    fi
    _rc=0
    pkg_install $AVAILABLE_PKGS || _rc=$?
    if [ "$_rc" -eq 0 ]; then
        OK "installed: $AVAILABLE_PKGS"
    else
        WARN "pkg_install returned $_rc — some packages missing, continuing"; FAILED_STEPS+=("pkg install")
    fi
    unset _rc
fi

# ------------------------------------------------
# 4. System optimizations (sudo)
# ------------------------------------------------
run_step "Swappiness 180 + page-cluster 0 (zram)" bash -c 'printf "vm.swappiness=180\nvm.page-cluster=0\n" | sudo tee /etc/sysctl.d/99-swappiness.conf >/dev/null && sudo sysctl --system >/dev/null'

OK "bootloader untouched (by design)"
OK "btrfs root — ext4 reserve N/A (snapper covers rollback)"

# ZRAM: zstd + 100% RAM via zram-generator (see setup.md Section 1)
STEP "ZRAM compressed swap (zstd, 100% RAM)"
# Post-state is asserted via zramctl — never assumed.
if grep -q "zram-size = min(ram)" /etc/systemd/zram-generator.conf 2>/dev/null \
    && grep -q "compression-algorithm = zstd" /etc/systemd/zram-generator.conf 2>/dev/null \
    && /usr/sbin/zramctl --noheadings --output ALGORITHM 2>/dev/null | grep -qi zstd; then
    OK "zram already configured (zstd, 100% RAM, active)"
else
    # Park the legacy script-based service if present (avoids double zram devices)
    sudo systemctl disable --now zramswap >/dev/null 2>&1 || true
    if printf '[zram0]\nzram-size = min(ram)\ncompression-algorithm = zstd\n' | sudo tee /etc/systemd/zram-generator.conf >/dev/null \
        && sudo systemctl daemon-reload >/dev/null 2>&1 \
        && sudo systemctl enable --now systemd-zram-setup@zram0.service >/dev/null 2>&1; then
        # No `systemctl restart dev-zram0.swap`: restarting the unit does not recreate
        # /dev/zram0 with the new settings. A reboot is what activates them; the `rest`
        # alias is the user's manual way to do that.
        if /usr/sbin/zramctl --noheadings --output ALGORITHM 2>/dev/null | grep -qi zstd; then
            OK "zram configured + active (zstd, 100% RAM, verified via zramctl)"
        else
            WARN "zram config written but not yet active — REBOOT required, then run: zramctl"; FAILED_STEPS+=("zram verify (reboot pending)")
        fi
    else
        WARN "zram config failed — see setup.md Section 1"; FAILED_STEPS+=("zram config")
    fi
fi

# Kernel VM tuning: cache pressure, writeback, watermark (see setup.md Section 1)
STEP "Kernel VM tuning (vfs cache, dirty ratios, watermark)"
if grep -q "^vm.vfs_cache_pressure=125" /etc/sysctl.d/70-vfs-cache-pressure.conf 2>/dev/null \
    && grep -q "^vm.watermark_scale_factor=150" /etc/sysctl.d/86-watermark-scale.conf 2>/dev/null; then
    OK "VM tuning already configured"
else
    if printf 'vm.vfs_cache_pressure=125\n' | sudo tee /etc/sysctl.d/70-vfs-cache-pressure.conf >/dev/null \
        && printf 'vm.dirty_ratio=10\nvm.dirty_background_ratio=5\n' | sudo tee /etc/sysctl.d/80-dirty-ratios.conf >/dev/null \
        && printf 'vm.watermark_boost_factor=0\n' | sudo tee /etc/sysctl.d/85-watermark-boost.conf >/dev/null \
        && printf 'vm.watermark_scale_factor=150\n' | sudo tee /etc/sysctl.d/86-watermark-scale.conf >/dev/null \
        && sudo sysctl --system >/dev/null 2>&1; then
        OK "VM tuning applied (vfs 125, dirty 10/5, watermark 0/150)"
    else
        WARN "VM tuning failed — see setup.md Section 1"; FAILED_STEPS+=("VM tuning")
    fi
fi

# EarlyOOM: guard daemon — protects the coding stack, prefers killing Brave (see setup.md Section 1)
STEP "EarlyOOM guard (protect zed/opencode/kitty, prefer killing Brave)"
_EARLYOOM_CONF="/etc/sysconfig/earlyoom"
if grep -qF "brave-browser" "$_EARLYOOM_CONF" 2>/dev/null; then
    OK "earlyoom already configured (our policy present)"
else
    if printf '%s\n' 'EARLYOOM_ARGS="-m 5 -s 5 -r 3600 --avoid \"(^|/)(zed|opencode|node|kitty|bash)$\" --prefer \"(^|/)(brave|brave-browser)$\""' | sudo tee "$_EARLYOOM_CONF" >/dev/null \
        && sudo systemctl enable --now earlyoom >/dev/null 2>&1 \
        && sudo systemctl restart earlyoom >/dev/null 2>&1; then
        OK "earlyoom active (avoid: zed/opencode/node/kitty/bash, prefer: brave)"
    else
        WARN "earlyoom setup failed — see setup.md Section 1"; FAILED_STEPS+=("earlyoom")
    fi
fi
unset _EARLYOOM_CONF

# ------------------------------------------------
# 5. Dotfiles — shared first, then DE-specific
# ------------------------------------------------
mkdir -p "$HOME_DIR/.config"

STEP "Copying shared config (common/.config)"
# Shared config first; DE-specific files below win on any conflict.
if [ -d "$COMMON_DIR/.config" ]; then
    cp -rb "$COMMON_DIR/.config/." "$HOME_DIR/.config/" \
        && OK "shared config applied from common/" \
        || { WARN "common/.config copy failed"; FAILED_STEPS+=("common config"); }
else
    WARN "common/.config missing — shared dotfiles skipped"
fi

# Shared assets used by all three DEs (see the same block in gnome/setup.sh for why
# these are not GNOME- or XFCE-only): Nerd Fonts, the fastfetch logo, the wallpaper.
# The COSMIC config restored in step 6 points at $HOME/wallpapers/bg1.jpg, so without
# this the restored desktop comes up on a flat background.
STEP "Copying shared assets (fonts, logo, wallpaper)"
if [ -d "$COMMON_DIR/.local" ]; then
    mkdir -p "$HOME_DIR/.local/share"
    if cp -rb "$COMMON_DIR/.local/." "$HOME_DIR/.local/"; then OK "Nerd Fonts -> $HOME_DIR/.local/share/fonts"
    else WARN "common/.local copy failed"; FAILED_STEPS+=("fonts"); fi
else
    WARN "common/.local missing — Nerd Fonts skipped"
fi
if [ -f "$COMMON_DIR/assets/jm-icon.png" ]; then
    mkdir -p "$HOME_DIR/Documents"
    if cp -b "$COMMON_DIR/assets/jm-icon.png" "$HOME_DIR/Documents/jm-icon.png" 2>/dev/null; then
        OK "icon -> $HOME_DIR/Documents/jm-icon.png (fastfetch)"
    else
        WARN "icon copy failed"; FAILED_STEPS+=("fastfetch logo")
    fi
else
    WARN "common/assets/jm-icon.png missing — fastfetch logo skipped"; FAILED_STEPS+=("logo missing")
fi
if [ -d "$COMMON_DIR/wallpapers" ]; then
    mkdir -p "$HOME_DIR/wallpapers"
    if cp -rb "$COMMON_DIR/wallpapers/." "$HOME_DIR/wallpapers/"; then OK "wallpaper -> $HOME_DIR/wallpapers"
    else WARN "common/wallpapers copy failed"; FAILED_STEPS+=("wallpaper"); fi
else
    WARN "common/wallpapers missing — wallpaper skipped"
fi

STEP "Installing .bashrc (aliases: rest, game, code)"
# common/.bashrc already carries starship init, NODE_OPTIONS=1536MB and the
# distro-specific rest/game/code aliases — copying it wholesale is the whole step.
if grep -q 'starship init bash' "$HOME_DIR/.bashrc" 2>/dev/null; then
    OK ".bashrc already has the common aliases — left as is"
elif [ -f "$COMMON_DIR/.bashrc" ]; then
    cp -b "$COMMON_DIR/.bashrc" "$HOME_DIR/.bashrc" \
        && OK ".bashrc installed (backup: .bashrc~)" \
        || { WARN ".bashrc copy failed"; FAILED_STEPS+=(".bashrc"); }
else
    WARN "$COMMON_DIR/.bashrc missing — aliases skipped"
fi

STEP "Copying COSMIC config (autostart)"
# cosmic/ is deliberately NOT copied here — its 189 files get their own step with a
# tar safety net. Blind `cp -rb` over the tree would back up all 189 as `~` and then
# be overwritten seconds later by `cp -a`, leaving 189 useless backup files behind.
if [ -d "$REPO/.config" ]; then
    _CP_OK=0
    for _entry in "$REPO/.config"/* "$REPO/.config"/.[!.]*; do
        [ -e "$_entry" ] || continue
        [ "$(basename "$_entry")" = "cosmic" ] && continue
        # -b: back up any pre-existing file as <name>~
        cp -rb "$_entry" "$HOME_DIR/.config/" && _CP_OK=$((_CP_OK + 1)) \
            || { WARN "copy failed: $entry"; FAILED_STEPS+=("dotfiles: $(basename "$_entry")"); }
    done
    unset _entry
    if [ "$_CP_OK" -gt 0 ]; then
        OK "dotfiles applied ($_CP_OK entr(y/ies), backups: <file>~)"
    else
        WARN "$REPO/.config had nothing to copy outside cosmic/"; FAILED_STEPS+=("dotfiles")
    fi
    unset _CP_OK
else
    WARN "$REPO/.config missing — dotfiles skipped"; FAILED_STEPS+=("dotfiles")
fi

# ------------------------------------------------
# 6. Restore the COSMIC desktop config — the primary payload
# ------------------------------------------------
# 189 files / 33 per-app setting dirs under cosmic/.config/cosmic/. This is a whole-tree
# overwrite of a live, actively-written config dir, so take a tar first.
STEP "Restoring COSMIC desktop config (189-file backup)"
_COSMIC_SRC="$REPO/.config/cosmic"
_COSMIC_DST="$HOME_DIR/.config/cosmic"
if [ ! -d "$_COSMIC_SRC" ]; then
    WARN "$_COSMIC_SRC missing — THIS IS THE PRIMARY PAYLOAD, restore skipped"; FAILED_STEPS+=("cosmic config missing")
else
    mkdir -p "$HOME_DIR/.cache"
    if [ -d "$_COSMIC_DST" ]; then
        if tar -czf "$HOME_DIR/.cache/cosmic-config-$(date +%Y%m%d-%H%M%S).tar.gz" -C "$HOME_DIR/.config" cosmic 2>/dev/null; then
            OK "pre-restore tar backup -> $HOME_DIR/.cache/cosmic-config-*.tar.gz"
        else
            WARN "tar backup failed — restoring in place anyway"
        fi
    fi
    mkdir -p "$_COSMIC_DST"
    if cp -a "$_COSMIC_SRC/." "$_COSMIC_DST/"; then
        # The backup carries absolute paths from the machine it was taken on
        # (wallpaper, Files favourites, Tweaks colour scheme). Rewrite them on the
        # installed copy so the repo itself stays portable.
        find "$_COSMIC_DST" -type f ! -name '*~' -exec sed -i "s|/home/julry|$HOME_DIR|g" {} + 2>/dev/null || true
        _CLEFT="$(grep -rl '/home/julry' --exclude='*~' "$_COSMIC_DST" 2>/dev/null || true)"
        if [ "$HOME_DIR" = "/home/julry" ]; then
            OK "COSMIC config restored (HOME is already /home/julry — no rebase needed)"
        elif [ -z "${_CLEFT:-}" ]; then
            OK "COSMIC config restored + absolute paths rebased to $HOME_DIR"
        else
            WARN "absolute paths still hardcoded in: $_CLEFT"; FAILED_STEPS+=("cosmic path rebase")
        fi
        unset _CLEFT
    else
        WARN "cp -a of $_COSMIC_SRC failed"; FAILED_STEPS+=("cosmic config restore")
    fi
fi
unset _COSMIC_SRC _COSMIC_DST

# ------------------------------------------------
# 7. Caches
# ------------------------------------------------
STEP "Refreshing font + GTK caches"
if command -v fc-cache >/dev/null 2>&1; then
    fc-cache -f >/dev/null 2>&1 && OK "font cache rebuilt" || WARN "fc-cache failed (non-fatal)"
else
    WARN "fc-cache not installed — font cache not rebuilt"
fi
# GTK4 apps pick up icon-theme/font changes on next launch; nudging the caches is free.
if command -v gtk4-update-icon-cache >/dev/null 2>&1; then
    gtk4-update-icon-cache -f -t ~/.local/share/icons 2>/dev/null || true
    OK "gtk4 icon cache refreshed"
elif command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -f -t ~/.icons ~/.local/share/icons 2>/dev/null || true
    OK "gtk3 icon cache refreshed"
else
    OK "no gtk-update-icon-cache — skipped (COSMIC loads its own icon theme)"
fi

# ------------------------------------------------
# 8. Verification — read back what actually landed
# ------------------------------------------------
STEP "Verifying restored COSMIC config"
_CD="$HOME_DIR/.config/cosmic"
if [ -d "$_CD" ]; then
    _NDIRS="$(find "$_CD" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')"
    _NFILES="$(find "$_CD" -type f 2>/dev/null | wc -l | tr -d ' ')"
    echo "   setting dirs : $_NDIRS"
    echo "   files        : $_NFILES"
else
    WARN "$_CD missing — nothing to verify"
    _NDIRS=0; _NFILES=0
fi
_ICON_THEME="$(cat "$_CD/com.system76.CosmicTk/v1/icon_theme" 2>/dev/null | tr -d '"[:space:]')"
_AUTOTILE="$(cat "$_CD/com.system76.CosmicComp/v1/autotile" 2>/dev/null | tr -d '[:space:]')"
_HEADER="$(cat "$_CD/com.system76.CosmicTk/v1/header_size" 2>/dev/null | tr -d '[:space:]')"
_DENSITY="$(cat "$_CD/com.system76.CosmicTk/v1/interface_density" 2>/dev/null | tr -d '[:space:]')"
_WSMODE="$(grep -m1 'workspace_mode' "$_CD/com.system76.CosmicComp/v1/workspaces" 2>/dev/null | tr -d ' (),')"
echo "   icon theme   : ${_ICON_THEME:-<unset>}"
echo "   autotile     : ${_AUTOTILE:-<unset>}"
echo "   header/density: ${_HEADER:-<unset>} / ${_DENSITY:-<unset>}"
echo "   workspaces   : ${_WSMODE:-<unset>}"
if [ "$_ICON_THEME" = "Reversal-grey" ] && [ "$_AUTOTILE" = "true" ]; then
    OK "COSMIC config matches the captured live state"
else
    WARN "COSMIC config differs from the captured state (see setup.md Section 2)"
fi
unset _CD _NDIRS _NFILES _ICON_THEME _AUTOTILE _HEADER _DENSITY _WSMODE

if [ -f "$HOME_DIR/.config/autostart/xhost-root.desktop" ]; then
    OK "autostart/xhost-root.desktop installed — root X access is GRANTED (setup.md Section 9)"
else
    WARN "autostart/xhost-root.desktop missing — YaST GUI needs 'xhost +si:localuser:root'"
fi

# ------------------------------------------------
# 9. Snapper snapshot
# ------------------------------------------------
# Runs AFTER the restore on purpose: it captures the state this script produced, so a
# bad run is one rollback away. The user-level config backup in ~/.cache covers the
# pre-restore state.
STEP "Snapper post-restore snapshot (openSUSE only)"
if command -v snapper >/dev/null 2>&1; then
    if sudo snapper create -d "post-cosmic-restore $(date +%Y-%m-%d)" >/dev/null 2>&1; then
        OK "snapper snapshot post-cosmic-restore created"
    else
        WARN "snapper snapshot failed — continuing"
    fi
else
    WARN "snapper not installed — snapshot skipped"
fi

# ------------------------------------------------
# 10. Summary
# ------------------------------------------------
echo
echo "==============================================="
echo " DONE — summary"
echo "==============================================="
echo " applied : common dotfiles (kitty, starship.toml, fastfetch, zed, spotatui,"
echo "           opencode config/ + plugins/ + caveman/), common .bashrc,"
echo "           autostart/xhost-root.desktop, COSMIC desktop config (189-file backup)"
echo "           swappiness 180 + page-cluster 0, ZRAM (zstd, zram-generator),"
echo "           VM tuning (vfs 125, dirty 10/5, watermark 0/150), earlyoom"
echo "           font + GTK caches; bootloader untouched (by design)"
echo " display : GDM is the active display manager (greetd disabled) — left exactly as found"
if [ "${#FAILED_STEPS[@]}" -gt 0 ]; then
    echo " FAILED  : ${FAILED_STEPS[*]}  (re-run script or do manually via setup.md)"
fi
echo
echo " manual leftovers:"
command -v brave-browser >/dev/null 2>&1 && echo "   brave-browser : installed" \
    || echo "   brave-browser : NOT installed — sudo zypper in brave-browser"
command -v zed >/dev/null 2>&1 && echo "   zed           : installed" \
    || echo "   zed           : NOT in Tumbleweed repos — see setup.md Section 12"
echo "   display mgr   : GDM enabled, greetd disabled (cosmic-greeter installed, inactive)"
echo "   fonts         : Nerd Fonts from common/.local/share/fonts/"
echo
if [ -t 0 ]; then
    read -rp "Restart the login screen now? (logs you out!) [y/N] " ans
    if [ "${ans:-n}" = y ]; then
        sudo systemctl restart display-manager
    fi
else
    echo "Non-interactive shell — restart skipped (run manually)."
fi

# gnome/setup.sh ends in `exit 0` no matter how many steps failed, so a broken restore
# reports success to CI/callers. Non-zero here: a non-empty FAILED_STEPS means the
# machine is NOT in the intended state.
if [ "${#FAILED_STEPS[@]}" -gt 0 ]; then
    echo
    echo " REBOOT REQUIRED"
    echo "   needs a reboot : sysctl (swappiness 180, page-cluster 0, VM tuning) re-read"
    echo "                    /etc/sysctl.d at boot; ZRAM (zram-generator) comes up clean"
    echo "                    only after a reboot."
    echo "   no reboot need : all dotfiles, kitty/starship/fastfetch, the restored COSMIC"
    echo "                    config, fonts — log out and back in to pick these up."
    exit 1
fi

echo
echo " REBOOT RECOMMENDED (not required for dotfiles)"
echo "   needs a reboot : sysctl drop-ins + ZRAM settle properly on the next boot."
echo "   no reboot need : dotfiles and the COSMIC config — log out and back in instead."
exit 0