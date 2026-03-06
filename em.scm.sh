#!/usr/bin/env bash
# em.scm.sh - Launcher for the Scheme-powered shemacs editor
#
# Source this file in your .bashrc:  source /path/to/em.scm.sh
# Then run:  em [filename]
# Or run standalone:  bash em.scm.sh [filename]
#
# All editor logic is in em.scm (Scheme), compiled to native bash via bs-compile.
# On first run, this file compiles em.scm and caches the result; subsequent
# runs source the compiled cache directly — no interpreter needed at runtime.
#
# Requires sheme to be installed: https://github.com/jordanhubbard/sheme
#   Install:  cd ~/src/sheme && make install   (puts ~/.bs.sh in place)
#   Or dev layout: shemacs/ and sheme/ are siblings on the filesystem.

# Require bash 4+
if [[ "${BASH_VERSINFO:-0}" -lt 4 ]]; then
    if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
        for _em_try_bash in /opt/homebrew/bin/bash /usr/local/bin/bash /usr/bin/bash; do
            if [[ -x "$_em_try_bash" ]] && "$_em_try_bash" -c '[[ ${BASH_VERSINFO[0]} -ge 4 ]]' 2>/dev/null; then
                exec "$_em_try_bash" "$0" "$@"
            fi
        done
    fi
    echo "em requires Bash 4+. Install via: brew install bash" >&2
    return 2>/dev/null || exit 1
fi

# Include guard: skip re-sourcing, but allow standalone execution
if [[ -n "${_SHEMACS_SCM_LOADED:-}" && "${BASH_SOURCE[0]}" != "$0" ]]; then
    return 0 2>/dev/null
fi
_SHEMACS_SCM_LOADED=1

em() {
    local _em_script_dir
    _em_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || _em_script_dir=""

    # Enable checkwinsize so LINES and COLUMNS are updated
    shopt -s checkwinsize 2>/dev/null

    # Find bs.sh path (needed for cache staleness check and compilation)
    local _em_bs_path="" _em_bs_candidates=()
    for _bs_candidate in \
            "$HOME/.bs.sh" \
            "${_em_script_dir:+$_em_script_dir/../sheme/bs.sh}" \
            /usr/local/lib/sheme/bs.sh \
            /opt/sheme/bs.sh; do
        [[ -n "$_bs_candidate" && -f "$_bs_candidate" ]] || continue
        _em_bs_candidates+=("$_bs_candidate")
        [[ -z "$_em_bs_path" ]] && _em_bs_path="$_bs_candidate"
    done

    # Find em.scm: prefer ~/.em.scm (user override), then alongside this script.
    local _em_scm_file
    if [[ -f "$HOME/.em.scm" ]]; then
        _em_scm_file="$HOME/.em.scm"
    elif [[ -n "$_em_script_dir" && -f "$_em_script_dir/em.scm" ]]; then
        _em_scm_file="$_em_script_dir/em.scm"
    else
        echo "em: cannot find em.scm" >&2
        return 1
    fi

    # Load compiled cache, or compile from source.
    # Cache file is the output of bs-compile — a plain bash script.
    local _em_cache_file="${_em_scm_file}.cache"
    if [[ -f "$_em_cache_file" \
          && "$_em_cache_file" -nt "$_em_scm_file" \
          && ( -z "$_em_bs_path" || "$_em_cache_file" -nt "$_em_bs_path" ) ]] \
       && source "$_em_cache_file" && type em_main &>/dev/null; then
        : # compiled cache loaded
    else
        # Need to compile: load interpreter + compiler
        if (( ${#_em_bs_candidates[@]} == 0 )); then
            echo "em: cannot find bs.sh — install sheme: https://github.com/jordanhubbard/sheme" >&2
            return 1
        fi
        if [[ ! -f "$_em_cache_file" ]]; then
            printf "em: Still working - first-time Scheme compile in progress.\n" >&2
            printf "em: This can take a while; future runs will use the cache and start much faster.\n" >&2
        else
            printf "em: Scheme cache is stale; rebuilding cache for this run.\n" >&2
        fi
        # Source a bs.sh that has bs-compile
        local _em_compiled=""
        for _bs_candidate in "${_em_bs_candidates[@]}"; do
            # shellcheck source=/dev/null
            source "$_bs_candidate"
            type bs-compile &>/dev/null || continue
            bs-reset
            local _em_tmp="${_em_cache_file}.tmp.$$"
            bs-compile "$(cat "$_em_scm_file")" > "$_em_tmp"
            mv -f "$_em_tmp" "$_em_cache_file" 2>/dev/null || { rm -f "$_em_tmp"; }
            _em_compiled=1
            break
        done
        if [[ -z "$_em_compiled" ]]; then
            echo "em: bs.sh found but bs-compile missing — update sheme: https://github.com/jordanhubbard/sheme" >&2
            return 1
        fi
        source "$_em_cache_file"
    fi

    # Safety-net trap: restore terminal if killed unexpectedly
    local _em_saved_traps
    _em_saved_traps=$(trap -p INT TERM HUP 2>/dev/null)
    trap 'printf "\e[0m\e[?25h\e[?1049l"; [[ -n "${__bsc_stty_saved:-}" ]] && stty "$__bsc_stty_saved" 2>/dev/null; __bsc_stty_saved=""; trap - INT TERM HUP; return 130' INT
    trap 'printf "\e[0m\e[?25h\e[?1049l"; [[ -n "${__bsc_stty_saved:-}" ]] && stty "$__bsc_stty_saved" 2>/dev/null; __bsc_stty_saved=""; trap - INT TERM HUP; return 143' TERM
    trap 'printf "\e[0m\e[?25h\e[?1049l"; [[ -n "${__bsc_stty_saved:-}" ]] && stty "$__bsc_stty_saved" 2>/dev/null; __bsc_stty_saved=""; trap - INT TERM HUP; return 129' HUP

    # Warn before loading very large files (>= 10MB)
    if [[ -n "${1:-}" && -f "$1" ]]; then
        local _em_fsize
        _em_fsize=$(stat -f%z "$1" 2>/dev/null) || _em_fsize=$(stat --format=%s "$1" 2>/dev/null) || _em_fsize=0
        if (( _em_fsize >= 10485760 )); then
            local _em_mb=$(( _em_fsize / 1048576 ))
            printf "Warning: %s is %d MB.\n" "$1" "$_em_mb" >&2
            case "$1" in
                *.json)       printf "  Hint: consider 'jq' for JSON files.\n" >&2 ;;
                *.html|*.htm) printf "  Hint: consider 'tidy' for HTML files.\n" >&2 ;;
                *.xml)        printf "  Hint: consider 'xmllint' for XML files.\n" >&2 ;;
                *.csv)        printf "  Hint: consider a spreadsheet or 'csvtool'.\n" >&2 ;;
                *.log)        printf "  Hint: consider 'less' or 'tail' for logs.\n" >&2 ;;
            esac
            printf "Press Enter to continue or Ctrl-C to abort: " >&2
            read -r || { trap - INT TERM HUP; [[ -n "$_em_saved_traps" ]] && eval "$_em_saved_traps"; return 130; }
        fi
    fi

    # Run the editor — em_main is a native bash function from the compiled cache
    em_main "${1:-}"

    # Restore traps
    trap - INT TERM HUP
    [[ -n "$_em_saved_traps" ]] && eval "$_em_saved_traps"
    return 0
}

# Standalone execution: bash em.scm.sh [filename]
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    em "$@"
fi
