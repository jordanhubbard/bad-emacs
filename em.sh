#!/usr/bin/env bash
# em.sh - Launcher for the Scheme-powered shemacs editor
#
# Source this file in your .bashrc:  source /path/to/em.sh
# Then run:  em [filename]
# Or run standalone:  bash em.sh [filename]
#
# All editor logic is in em.scm (Scheme), compiled to native bash via bs-compile.
# On first run, this file compiles em.scm and caches the result; subsequent
# runs source the compiled cache directly. bs.sh remains loaded to provide the
# editor's explicit eval-string feature; em.scm itself is not interpreted.
#
# Requires sheme to be installed: https://github.com/jordanhubbard/sheme
#   Install:  cd ~/src/sheme && make install   (puts both interpreters in place)
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
if [[ -n "${_SHEMACS_LOADED:-}" && "${BASH_SOURCE[0]}" != "$0" ]]; then
    return 0 2>/dev/null
fi
_SHEMACS_LOADED=1

# Capture the defining file now. BASH_SOURCE inside a later function call can
# otherwise describe the caller rather than the launcher in unusual wrappers.
_SHEMACS_BASH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || \
    _SHEMACS_BASH_DIR=""

em() {
    local _em_script_dir="$_SHEMACS_BASH_DIR"

    # Enable checkwinsize so LINES and COLUMNS are updated
    shopt -s checkwinsize 2>/dev/null

    # Find bs.sh path (needed for cache staleness check and compilation)
    local _em_bs_path="" _bs_candidate _runtime_candidate
    local -a _em_bs_candidates=()
    if [[ -n "${SHEME_BS:-}" && ! -f "$SHEME_BS" ]]; then
        echo "em: SHEME_BS does not name a file: $SHEME_BS" >&2
        return 1
    fi
    for _bs_candidate in \
            "${SHEME_BS:-}" \
            "${_em_script_dir:+$_em_script_dir/../sheme/bs.sh}" \
            "$HOME/.bs.sh" \
            /usr/local/lib/sheme/bs.sh \
            /opt/sheme/bs.sh; do
        [[ -n "$_bs_candidate" && -f "$_bs_candidate" ]] || continue
        _em_bs_candidates+=("$_bs_candidate")
        [[ -z "$_em_bs_path" ]] && _em_bs_path="$_bs_candidate"
    done

    # Find em.scm: an explicit override wins; a checkout uses its adjacent
    # source; an installed launcher falls back to ~/.em.scm.
    local _em_scm_file
    if [[ -n "${SHEMACS_SCHEME_FILE:-}" ]]; then
        if [[ ! -f "$SHEMACS_SCHEME_FILE" ]]; then
            echo "em: SHEMACS_SCHEME_FILE does not name a file: $SHEMACS_SCHEME_FILE" >&2
            return 1
        fi
        _em_scm_file="$SHEMACS_SCHEME_FILE"
    elif [[ -n "$_em_script_dir" && -f "$_em_script_dir/em.scm" ]]; then
        _em_scm_file="$_em_script_dir/em.scm"
    elif [[ -f "$HOME/.em.scm" ]]; then
        _em_scm_file="$HOME/.em.scm"
    else
        echo "em: cannot find em.scm" >&2
        return 1
    fi

    # The injected runtime owns shemacs-specific nested state. Keeping it next
    # to em.scm lets sheme's compiler remain application-neutral.
    local _em_runtime_file=""
    if [[ -n "${SHEMACS_RUNTIME_FILE:-}" && ! -f "$SHEMACS_RUNTIME_FILE" ]]; then
        echo "em: SHEMACS_RUNTIME_FILE does not name a file: $SHEMACS_RUNTIME_FILE" >&2
        return 1
    fi
    for _runtime_candidate in \
            "${SHEMACS_RUNTIME_FILE:-}" \
            "$(dirname "$_em_scm_file")/.em.aot-runtime.sh" \
            "${_em_script_dir:+$_em_script_dir/em.aot-runtime.sh}"; do
        [[ -n "$_runtime_candidate" && -f "$_runtime_candidate" ]] || continue
        _em_runtime_file="$_runtime_candidate"
        break
    done
    if [[ -z "$_em_runtime_file" ]]; then
        echo "em: cannot find em.aot-runtime.sh" >&2
        return 1
    fi

    # Load compiled cache, or compile from source.
    # Cache file is the output of bs-compile — a plain bash script.
    local _em_cache_file="${SHEMACS_CACHE_FILE:-${_em_scm_file}.cache}"
    if [[ -f "$_em_cache_file" \
          && "$_em_cache_file" -nt "$_em_scm_file" \
          && "$_em_cache_file" -nt "$_em_runtime_file" \
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
        # Compile in a child Bash so trying multiple installations cannot be
        # confused by bs.sh's include guard and no compiler internals leak here.
        local _em_compiled=""
        for _bs_candidate in "${_em_bs_candidates[@]}"; do
            local _em_tmp
            _em_tmp=$(umask 077; mktemp "${_em_cache_file}.tmp.XXXXXXXX") || continue
            if bash -c '
                    source "$1" || exit
                    type bs-compile &>/dev/null || exit 2
                    bs-reset
                    bs-compile --runtime "$2" "$(< "$3")"
                ' _ "$_bs_candidate" "$_em_runtime_file" "$_em_scm_file" > "$_em_tmp" \
               && bash -n "$_em_tmp" \
               && mv -f "$_em_tmp" "$_em_cache_file"; then
                _em_compiled=1
                _em_bs_path="$_bs_candidate"
                break
            fi
            rm -f "$_em_tmp"
        done
        if [[ -z "$_em_compiled" ]]; then
            echo "em: unable to build a valid Bash cache with the discovered sheme compiler" >&2
            return 1
        fi
        if ! source "$_em_cache_file" || ! type em_main &>/dev/null; then
            echo "em: generated cache did not load" >&2
            return 1
        fi
    fi

    # eval-string is an editor feature. Loading the interpreter defines it for
    # both cold and warm cache paths without evaluating em.scm at runtime.
    if ! type bs &>/dev/null; then
        if [[ -z "$_em_bs_path" ]]; then
            echo "em: cannot find bs.sh — install the complete sheme package" >&2
            return 1
        fi
        # shellcheck source=/dev/null
        source "$_em_bs_path" || return 1
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

    # Run the editor — em_main is a native Bash function from the compiled cache.
    # Keep cleanup reliable even when the editor reports an error.
    local _em_status
    if em_main "${1:-}"; then _em_status=0; else _em_status=$?; fi

    # Restore traps
    trap - INT TERM HUP
    [[ -n "$_em_saved_traps" ]] && eval "$_em_saved_traps"
    return "$_em_status"
}

# Standalone execution: bash em.sh [filename]
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    em "$@"
fi
