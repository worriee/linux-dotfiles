# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
#force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
	# We have color support; assume it's compliant with Ecma-48
	# (ISO/IEC-6429). (Lack of such support is extremely rare, and such
	# a case would tend to support setf rather than setaf.)
	color_prompt=yes
    else
	color_prompt=
    fi
fi

if [ "$color_prompt" = yes ]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;36m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# colored GCC warnings and errors
#export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# some more ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi


# down below is my own mods

# nvm init
export NVM_DIR="$HOME/.config/nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# opencode init
export PATH="/home/julry/.opencode/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"

# ani-cli download folder
export ANI_CLI_DOWNLOAD_DIR="$HOME/Videos/ani-cli"

# run fastfetch only if in home dir
if [ "$PWD" = "$HOME" ]; then
    fastfetch
fi

# dir prompt ui in kitty or other term
eval "$(starship init bash)"

# zoxide pkg init (cd alternative)
eval "$(zoxide init bash)"

# some node optimization
export NODE_OPTIONS="--max-old-space-size=1536"

# run zoxide + fzf + zed ide
# command: zzi
_launch_and_exit() {
  local target="$1"
  nohup zed "$target" >/dev/null 2>&1 &
  disown
  exit 0
}

zzi() {
  if [ $# -eq 0 ] || [ "$1" = "-i" ]; then
    local target
    [ "$1" = "-i" ] && shift
    target="$(zoxide query -i "$@")" || return 1
    [ -n "$target" ] && _launch_and_exit "$target"
    return
  fi

  local joined
  joined="$(IFS="/"; echo "$*")"
  if [ -e "$joined" ]; then
    _launch_and_exit "$joined"
    return
  fi

  local target
  target="$(zoxide query "$@" 2>/dev/null)"
  if [ -n "$target" ]; then
    _launch_and_exit "$target"
    return
  fi

  if [ $# -gt 1 ]; then
    local dir_keywords=("${@:1:$#-1}")
    local file_name="${!#}"
    target="$(zoxide query "${dir_keywords[@]}" 2>/dev/null)"
    if [ -n "$target" ]; then
      _launch_and_exit "$target/$file_name"
      return
    fi
  fi

  target="$(zoxide query -i "$@")" || return 1
  if [ -n "$target" ]; then
    _launch_and_exit "$target"
  else
    echo "zzi: could not find '$*' locally or in zoxide"
    return 1
  fi
}

# command: repo ref
# refreshes the /home/julry/repo folders to add them in zzed -i ui
repo() {
  if [ "$1" = "ref" ]; then
    for d in "$HOME/repo"/*/; do
      [ -d "$d" ] && zoxide add "$d"
    done
  fi
}

# update opensuse system + flatpak packages in one pass
# command: sysup
sysup() {
  echo "--- Refresh Repositories ---"
  sudo zypper ref
  echo "--- Updating Flatpaks ---"
  flatpak update
  echo "--- Cleanup Flatpak ---"
  flatpak uninstall --unused
  echo "--- Updating openSUSE Tumbleweed ---"
  sudo zypper dup
}

# --- DITO Hotspot Bypass Helpers ---

# Permanently apply bypass (TTL 65, IPv6 disabled)
bypass-dito() {
    echo "Applying permanent DITO bypass settings..."
    sudo rm -f /etc/sysctl.d/99-default-ttl.conf
    sudo tee /etc/sysctl.d/99-dito-hotspot.conf >/dev/null << 'EOF'
net.ipv4.ip_default_ttl = 65
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
EOF
    sudo sysctl --system >/dev/null
    sudo dracut --regenerate-all --force
    echo "Done! Bypass configuration saved to 99-dito-hotspot.conf and rebuilt into boot image."
}

# Permanently revert to defaults (TTL 64, IPv6 enabled)
revert-bypass-dito() {
    echo "Applying permanent system default settings..."
    sudo rm -f /etc/sysctl.d/99-dito-hotspot.conf
    sudo tee /etc/sysctl.d/99-default-ttl.conf >/dev/null << 'EOF'
net.ipv4.ip_default_ttl = 64
net.ipv6.conf.all.disable_ipv6 = 0
net.ipv6.conf.default.disable_ipv6 = 0
EOF
    sudo sysctl --system >/dev/null
    sudo dracut --regenerate-all --force
    echo "Done! Default configuration saved to 99-default-ttl.conf and rebuilt into boot image."
}

# Verification guide and status check
verify-bypass-dito() {
    local ttl=$(cat /proc/sys/net/ipv4/ip_default_ttl 2>/dev/null)
    local ipv6_disabled=$(cat /proc/sys/net/ipv6/conf/all/disable_ipv6 2>/dev/null)

    ttl=${ttl:-0}
    ipv6_disabled=${ipv6_disabled:-0}

    echo "=========================================="
    echo "       DITO Network Status Check          "
    echo "=========================================="
    echo "Active IPv4 TTL      : $ttl"
    if [ "$ipv6_disabled" -eq 1 ]; then
        echo "Active IPv6 Status   : Disabled (1)"
    else
        echo "Active IPv6 Status   : Enabled (0)"
    fi
    echo "------------------------------------------"

    if [ "$ttl" -eq 65 ] && [ "$ipv6_disabled" -eq 1 ]; then
        echo "Current Mode: [ BYPASSED SETTING ]"
        echo "  - TTL is 65 (Disguised phone traffic)"
        echo "  - IPv6 Disabled (Prevents hotspot timeouts)"
    elif [ "$ttl" -eq 64 ] && [ "$ipv6_disabled" -eq 0 ]; then
        echo "Current Mode: [ DEFAULT SETTING ]"
        echo "  - TTL is 64 (Standard Linux default)"
        echo "  - IPv6 Enabled (Standard Linux default)"
    else
        echo "Current Mode: [ CUSTOM / MIXED STATE ]"
        echo "  - Settings do not match pure bypass or pure default."
    fi
    echo "=========================================="
}

# Some alias in this section

# restart + flush ram & zram
alias rest='sudo systemctl restart dev-zram0.swap && sudo systemctl restart display-manager'
alias game='sudo /usr/sbin/sysctl -w vm.swappiness=10 >/dev/null && echo game: swappiness 10'
alias code='sudo /usr/sbin/sysctl -w vm.swappiness=180 >/dev/null && echo code: swappiness 180'
alias sepkg='zypper se -i | grep '^i+''
alias sepkgfull='zypper se -i'
alias ani='mpv "$(find ~/Videos/ani-cli -type f \( -name "*.mp4" -o -name "*.mkv" \) | sort -V | fzf --layout=reverse)"'
alias orgz='organize.sh'
alias orgz-log='cat /home/julry/.local/state/organize.log'
alias dots-log='cat /home/julry/.local/state/dots.log'
alias sessions-log='cat /home/julry/.local/state/sessions.log'
alias bak='dots.sh && sessions.sh'
# open crontab with zed
alias cron='EDITOR="zed --wait" crontab -e'
alias phone='nautilus "$(ls -d /run/user/1000/gvfs/sftp:*/storage/emulated/0 2>/dev/null | head -1)"'
alias phonecd='cd "$(ls -d /run/user/1000/gvfs/sftp:*/storage/emulated/0 2>/dev/null | head -1)"'
