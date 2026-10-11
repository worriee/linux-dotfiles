#!/usr/bin/env bash
# Shared distro detection and package helpers.
#
# Sourced by every setup.sh. Detect-then-confirm: works out which distro it is
# on and lets the user override before any package is installed.
#
# Scope is deliberate: this repo targets Ubuntu-family (apt) and openSUSE-family
# (zypper) only. Anything else resolves to no package manager and the caller warns.
# shortcut: 2 families only — add a branch when a machine actually needs a third.

detect_distro() {
    DISTRO="unknown"
    if [ -r /etc/os-release ]; then . /etc/os-release; DISTRO="${ID:-unknown}"; DISTRO_NAME="${PRETTY_NAME:-$DISTRO}"; fi

    case "$DISTRO" in
        opensuse*|suse*|sles*)   PKG_MGR="zypper"; DISTRO_FAMILY="opensuse" ;;
        ubuntu|linuxmint|mint|pop) PKG_MGR="apt";    DISTRO_FAMILY="ubuntu" ;;
        *)                       PKG_MGR="";        DISTRO_FAMILY="unsupported" ;;
    esac
    export DISTRO DISTRO_NAME PKG_MGR DISTRO_FAMILY
}

confirm_distro() {
    detect_distro
    echo
    echo "  Detected: ${DISTRO_NAME:-$DISTRO}  (family: $DISTRO_FAMILY, package manager: ${PKG_MGR:-none})"
    if [ -t 0 ]; then
        printf "  Press Enter to accept, or type ubuntu / opensuse to override: "
        read -r _override || true
        if [ -n "${_override:-}" ]; then
            case "$_override" in
                ubuntu)   DISTRO_FAMILY="ubuntu";   PKG_MGR="apt" ;;
                opensuse) DISTRO_FAMILY="opensuse"; PKG_MGR="zypper" ;;
                *) echo "  Unsupported family '$_override' — keeping detected value." ;;
            esac
            export DISTRO_FAMILY PKG_MGR
        fi
    fi
    echo
}

pkg_install() {
    case "$PKG_MGR" in
        zypper) sudo zypper -n install "$@" ;;
        apt)    sudo apt-get install -y "$@" ;;
        *) echo "  WARN unsupported distro (${DISTRO:-unknown}) — skipping: $*" >&2; return 1 ;;
    esac
}

pkg_query() {
    case "$PKG_MGR" in
        zypper) zypper --non-interactive search --match-exact "$1" >/dev/null 2>&1 ;;
        apt)    apt-cache show "$1" >/dev/null 2>&1 ;;
        *) return 1 ;;
    esac
}