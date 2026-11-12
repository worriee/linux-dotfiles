# ~/.config/fish/config.fish — fish equivalent of my ~/.bashrc

# no welcome banner (bash had none)
set -g fish_greeting

# ── nvm via bash shim (nvm.sh is bash-only; stateless: `nvm use` lasts one call) ──
# your nvm default alias = node 24, so node/npm/npx resolve it every call
function nvm --description 'nvm via bash shim (stateless)'
    bash -c 'source "$HOME/.config/nvm/nvm.sh" >/dev/null 2>&1; nvm "$@"' _ $argv
end
function node --description 'node via nvm default alias'
    bash -c 'source "$HOME/.config/nvm/nvm.sh" >/dev/null 2>&1; exec node "$@"' _ $argv
end
function npm --description 'npm via nvm default alias'
    bash -c 'source "$HOME/.config/nvm/nvm.sh" >/dev/null 2>&1; exec npm "$@"' _ $argv
end
function npx --description 'npx via nvm default alias'
    bash -c 'source "$HOME/.config/nvm/nvm.sh" >/dev/null 2>&1; exec npx "$@"' _ $argv
end

# ── basic ls/grep colors (port of dircolors aliases) ──
alias ls 'ls --color=auto'
alias grep 'grep --color=auto'
alias ll 'ls -alF'
alias la 'ls -A'
alias l 'ls -CF'

###

# ── h : cheat sheet
function h --description 'my cheat sheet (bash-powered + fish-only section)'
    pushd /tmp
    bash -ic 'h' 2>/dev/null
    popd
    set -l bnames (bash -c 'source <(awk "/^# down below is my own mods/{f=1} /^bind -x/{if(f) exit} f" ~/.bashrc); _h_rows' 2>/dev/null | cut -f1 | string trim)
    set -l fishonly
    for r in (_f_rows)
        set -l n (string split \t -- $r)[1]
        if not contains -- $n $bnames
            set -a fishonly $r
        end
    end
    if set -q fishonly[1]
        echo ''
        echo 'FISH-ONLY'
        for r in $fishonly
            set -l p (string split \t -- $r)
            printf '%-20s→ %s\n' $p[1] $p[2]
        end
    end
end

# _unquote: strip one matching outer quote pair (never touch inner escapes)
function _unquote --description 'strip outer quote pair from a fish source string'
    set -l q (string match -r "^(\"|')(.*)\1\$" -- $argv[1])
    if set -q q[1]
        printf '%s\n' $q[3]
    else
        printf '%s\n' $argv[1]
    end
end

# _comment_desc: description from the comment line directly above, or nothing.
# Section headers (# ── … ──) never count as descriptions.
function _comment_desc --description 'desc text from a comment line, or nothing'
    set -l p (string trim --left -- $argv[1])
    if string match -q '#*' -- $p; and not string match -q '# ──*' -- $p
        set -l d (string trim --chars="# -" -- $p)
        if test -n "$d"
            printf '%s\n' $d
        end
    end
end

# _f_rows: fish catalog parser — same contract as bash _h_rows (name ─ desc ─ value)
# reads config.fish live: alias lines (desc = comment above or #? suffix),
# function lines (desc = --description, fallback comment above), skips machinery
function _f_rows --description 'catalog rows from config.fish'
    set -l prev ''
    while read -l raw
        if not set -q started
            if test (string trim -- $raw) = '# down below is my own mods'
                set started 1
            end
            continue
        end
        set -l trimmed (string trim -- $raw)
        set -l am (string match -r '^alias\s+([\w-]+)\s+(.+)$' -- $trimmed)
        set -l fm (string match -r '^function\s+([\w-]+)' -- $trimmed)
        if set -q am[1]
            set -l name $am[2]
            set -l value (_unquote $am[3])
            set -l desc $value
            if string match -rq '#\?' -- $trimmed
                set -l d (string match -r '#\?\s*(.+)$' -- $trimmed)[2]
                test -n "$d"; and set desc $d
            else
                set -l d (_comment_desc $prev)
                test -n "$d"; and set desc $d
            end
            printf '%s\t%s\t%s\n' $name $desc $value
        else if set -q fm[1]
            set -l name $fm[2]
            if not contains -- $name h _h_pick _f_rows _unquote _comment_desc _launch_and_exit _phone_path
                set -l value $name
                set -l desc ''
                set -l dm (string match -r -- '--description\s+(.+)$' -- $trimmed)
                if set -q dm[1]
                    set desc (_unquote $dm[2])
                else
                    set desc (_comment_desc $prev)
                end
                test -z "$desc"; and set desc $value
                printf '%s\t%s\t%s\n' $name $desc $value
            end
        end
        set prev $raw
    end < ~/.config/fish/config.fish
end

# Ctrl+O: h with fzf picker
function _h_pick --description 'Ctrl+O: fzf picker, types command at fish prompt'
    set -l all (_f_rows)
    set -l seen
    set -l rows
    for r in $all
        set -l n (string trim -- (string split \t -- $r)[1])
        if not contains -- $n $seen
            set -a seen $n
            set -a rows $r
        end
    end
    # pad name column to longest name + 1 space (h-style alignment)
    set -l w 14
    for r in $rows
        set -l len (string length -- (string trim -- (string split \t -- $r)[1]))
        if test $len -gt $w
            set w $len
        end
    end
    set -l fmt '%-'(math $w + 1)'s\t%s\t%s\n'
    set -l padded
    for r in $rows
        set -l p (string split \t -- $r)
        set -a padded (printf $fmt (string trim -- $p[1]) $p[2] $p[3])
    end
    set -l sel (printf '%s\n' $padded | fzf --delimiter '\t' --with-nth=1,2 --reverse --cycle --header='command ─ description  (Esc=cancel)' --height=55%)
    if test -n "$sel"
        commandline --replace (string split \t -- $sel)[3]
    end
end
bind \co _h_pick

# down below is my own mods

# ── env & PATH ──
fish_add_path $HOME/.opencode/bin $HOME/.local/bin

set -gx ANI_CLI_DOWNLOAD_DIR "$HOME/Videos/ani-cli"
set -gx NODE_OPTIONS "--max-old-space-size=1536"

# ── tool inits ──
zoxide init fish | source
starship init fish | source

# fastfetch only when starting in home dir
if test "$PWD" = "$HOME"
    fastfetch
end

# ── zzi: zoxide + fzf picker, launch zed, close window ──
function _launch_and_exit
    nohup zed $argv >/dev/null 2>&1 &
    disown
    exit 0
end

function zzi --description 'zoxide+zed launcher: zzi <dir/file words>, zzi -i for fzf picker'
    if test (count $argv) -eq 0; or test "$argv[1]" = "-i"
        set -l args $argv
        if test "$args[1]" = "-i"
            set args $args[2..-1]
        end
        set -l target (zoxide query -i $args)
        if test -z "$target"
            return 1
        end
        _launch_and_exit "$target"
        return
    end

    set -l joined (string join "/" $argv)
    if test -e "$joined"
        _launch_and_exit "$joined"
        return
    end

    set -l target (zoxide query $argv 2>/dev/null)
    if test -n "$target"
        _launch_and_exit "$target"
        return
    end

    if test (count $argv) -gt 1
        set -l dirs $argv[1..-2]
        set -l file $argv[-1]
        set -l target (zoxide query $dirs 2>/dev/null)
        if test -n "$target"
            _launch_and_exit "$target/$file"
            return
        end
    end

    set -l target (zoxide query -i $argv)
    if test -z "$target"
        echo "zzi: could not find '$argv' locally or in zoxide"
        return 1
    end
    _launch_and_exit "$target"
end

# refresh the /home/julry/repo path for zzi picker
function repo --description 'repo ref: add ~/repo subdirs to zoxide'
    if test "$argv[1]" = "ref"
        for d in $HOME/repo/*/
            zoxide add "$d"
        end
    end
end

# update opensuse + flatpaks + purge old kernels & snapshots in one pass
function sysup --description 'update opensuse + flatpaks, purge kernels & snapshots'
    echo "--- Refresh Repositories ---"
    sudo zypper ref
    echo "--- Updating Flatpaks ---"
    flatpak update; or begin
        flatpak repair; and flatpak update
    end
    echo "--- Cleanup Flatpak ---"
    flatpak uninstall --unused
    echo "--- Updating openSUSE Tumbleweed ---"
    sudo zypper dup
    echo "--- Purging Obsolete Kernels & Snapshots ---"
    sudo zypper purge-kernels
    sudo snapper cleanup number
    echo "=== System Update & Maintenance Complete! ==="
end

# ── DITO Hotspot Bypass Helpers ──
function bypass-dito --description 'permanent DITO bypass (TTL 65, IPv6 off)'
    echo "Applying permanent DITO bypass settings..."
    sudo rm -f /etc/sysctl.d/99-default-ttl.conf
    printf 'net.ipv4.ip_default_ttl = 65\nnet.ipv6.conf.all.disable_ipv6 = 1\nnet.ipv6.conf.default.disable_ipv6 = 1\n' | sudo tee /etc/sysctl.d/99-dito-hotspot.conf >/dev/null
    sudo sysctl --system >/dev/null
    sudo dracut --regenerate-all --force
    echo "Done! Bypass configuration saved to 99-dito-hotspot.conf and rebuilt into boot image."
end

function revert-bypass-dito --description 'revert to system defaults (TTL 64, IPv6 on)'
    echo "Applying permanent system default settings..."
    sudo rm -f /etc/sysctl.d/99-dito-hotspot.conf
    printf 'net.ipv4.ip_default_ttl = 64\nnet.ipv6.conf.all.disable_ipv6 = 0\nnet.ipv6.conf.default.disable_ipv6 = 0\n' | sudo tee /etc/sysctl.d/99-default-ttl.conf >/dev/null
    sudo sysctl --system >/dev/null
    sudo dracut --regenerate-all --force
    echo "Done! Default configuration saved to 99-default-ttl.conf and rebuilt into boot image."
end

function verify-bypass-dito --description 'show current DITO bypass state'
    set -l ttl (cat /proc/sys/net/ipv4/ip_default_ttl 2>/dev/null)
    set -l ipv6_disabled (cat /proc/sys/net/ipv6/conf/all/disable_ipv6 2>/dev/null)
    test -z "$ttl"; and set ttl 0
    test -z "$ipv6_disabled"; and set ipv6_disabled 0

    echo "=========================================="
    echo "       DITO Network Status Check          "
    echo "=========================================="
    echo "Active IPv4 TTL      : $ttl"
    if test "$ipv6_disabled" = 1
        echo "Active IPv6 Status   : Disabled (1)"
    else
        echo "Active IPv6 Status   : Enabled (0)"
    end
    echo "------------------------------------------"

    if test "$ttl" = 65; and test "$ipv6_disabled" = 1
        echo "Current Mode: [ BYPASSED SETTING ]"
        echo "  - TTL is 65 (Disguised phone traffic)"
        echo "  - IPv6 Disabled (Prevents hotspot timeouts)"
    else if test "$ttl" = 64; and test "$ipv6_disabled" = 0
        echo "Current Mode: [ DEFAULT SETTING ]"
        echo "  - TTL is 64 (Standard Linux default)"
        echo "  - IPv6 Enabled (Standard Linux default)"
    else
        echo "Current Mode: [ CUSTOM / MIXED STATE ]"
        echo "  - Settings do not match pure bypass or pure default."
    end
    echo "=========================================="
end

# ── Kernel & Snapper Auto-Setup Helpers ──
function kcfg --description 'enforce 2-kernel rolling rotation in zypp.conf.d'
    set -l f /etc/zypp/zypp.conf.d/50-multiversion.conf
    if test -f $f; and grep -q "latest,latest-1,running" $f 2>/dev/null
        echo "Notice: Kernel multiversion rule is ALREADY configured in $f."
        return 0
    end
    echo "Writing $f..."
    sudo mkdir -p /etc/zypp/zypp.conf.d
    printf '[main]\nmultiversion.kernels = latest,latest-1,running\n' | sudo tee $f >/dev/null
    echo "Done! Kernel rule set to 'latest,latest-1,running'."
end

function snapcfg --description 'keep 2-5 snapper snapshot pairs'
    set -l f /etc/snapper/configs/root
    if grep -q '^NUMBER_LIMIT="2-5"' $f 2>/dev/null; and grep -q '^NUMBER_LIMIT_IMPORTANT="2-5"' $f 2>/dev/null
        echo "Notice: Snapper limits (2-5) are ALREADY configured in $f."
        return 0
    end
    echo "Setting Snapper limits to 2-5 in $f..."
    sudo sed -i 's/^NUMBER_LIMIT=.*/NUMBER_LIMIT="2-5"/' $f
    sudo sed -i 's/^NUMBER_LIMIT_IMPORTANT=.*/NUMBER_LIMIT_IMPORTANT="2-5"/' $f
    echo "Running cleanup and refreshing bootloader..."
    sudo snapper cleanup number
    sudo update-bootloader --refresh
    echo "Done! Snapper limit set to 2-5 pairs and boot menu refreshed."
end

function ksnap --description 'check kernels, EFI space, snapshots'
    echo "=== Active Kernels ==="
    rpm -q kernel-default
    echo ""
    echo "=== EFI Boot Partition (/boot/efi) ==="
    df -h /boot/efi
    echo ""
    echo "=== Active Snapper Snapshots ==="
    sudo snapper list
end

# ── phone storage helpers ──
function _phone_path
    find /run/user/1000/gvfs -maxdepth 4 -type d -path '*storage/emulated/0' 2>/dev/null | head -1
end

function phone --description 'open phone storage in nautilus'
    set -l p (_phone_path)
    if test -n "$p"
        nautilus "$p"
    end
end

function phonecd --description 'cd into phone storage'
    set -l p (_phone_path)
    if test -n "$p"
        cd "$p"
    end
end

# my custom aliases below

# trash items instead of rm or rm -rf
alias tr 'gio trash'
# gaming mode: swappiness 10
alias game 'sudo /usr/sbin/sysctl -w vm.swappiness=10 >/dev/null && echo game: swappiness 10'
# coding mode: swappiness 180
alias code 'sudo /usr/sbin/sysctl -w vm.swappiness=180 >/dev/null && echo code: swappiness 180'
# list installed packages marked i+
alias sepkg "zypper se -i | grep '^i+'"
# list all explicitly installed packages
alias sepkgfull 'zypper se -i'
# fzf-pick ani-cli episode, play in mpv
alias ani 'mpv (find ~/Videos/ani-cli -type f \( -name "*.mp4" -o -name "*.mkv" \) | sort -V | fzf --layout=reverse)'
# check watched anime history (ani-cli)
alias ani-log 'ani-cli -l | tail -10'
# sort files via organize.sh
alias orgz 'organize.sh'
# read organize.sh log
alias orgz-log 'cat /home/julry/.local/state/organize.log'
# read dots.sh log
alias dots-log 'cat /home/julry/.local/state/dots.log | tail -10'
# read sessions.sh log
alias sessions-log 'cat /home/julry/.local/state/sessions.log | tail -10'
# main backups: dots.sh + sessions.sh
alias bak 'dots.sh && sessions.sh'
# open crontab with zed
function cron --description 'open crontab with zed'
    env EDITOR="zed --wait" crontab -e
end
