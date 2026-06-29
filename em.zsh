#!/usr/bin/env zsh
# em.zsh - Launcher for the Scheme-powered shemacs editor (zsh native)
#
# Source this file in your .zshrc:  source /path/to/em.zsh
# Then run:  em [filename]
# Or run standalone:  zsh em.zsh [filename]
#
# All editor logic is in em.scm (Scheme), AOT-compiled to native zsh via
# bs-compile-zsh (defined in bs.sh and run through a child Bash). On first run
# this launcher compiles em.scm and caches the result as em.scm.zsh.cache;
# subsequent runs source the cache directly. bs.zsh remains loaded to provide
# the editor's explicit eval-string feature; em.scm itself is not interpreted.
#
# Requires sheme to be installed: https://github.com/jordanhubbard/sheme
#   Install:  cd ~/src/sheme && make install   (puts ~/.bs.sh and ~/.bs.zsh in place)
#   Or dev layout: shemacs/ and sheme/ are siblings on the filesystem.

# Include guard: skip re-sourcing, but allow standalone execution
if [[ -n "${_SHEMACS_ZSH_LOADED:-}" && "${(%):-%N}" != "$0" ]]; then
    return 0 2>/dev/null
fi
_SHEMACS_ZSH_LOADED=1

# %N is reliable while this file is being sourced; inside em() it names the
# function/caller instead. Capture the launcher directory once at definition.
typeset -g _SHEMACS_ZSH_DIR="${${(%):-%N}:A:h}"

em() {
    emulate -L zsh
    setopt KSH_ARRAYS
    local _em_script_dir="$_SHEMACS_ZSH_DIR"

    # Find bs.sh (needed for the AOT compiler bs-compile-zsh)
    local _em_bs_path="" _bs_candidate _runtime_candidate _zsh_candidate
    local -a _em_bs_candidates=()
    if [[ -n "${SHEME_BS:-}" && ! -f "$SHEME_BS" ]]; then
        print "em: SHEME_BS does not name a file: $SHEME_BS" >&2
        return 1
    fi
    for _bs_candidate in \
            "${SHEME_BS:-}" \
            "${_em_script_dir}/../sheme/bs.sh" \
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
            print "em: SHEMACS_SCHEME_FILE does not name a file: $SHEMACS_SCHEME_FILE" >&2
            return 1
        fi
        _em_scm_file="$SHEMACS_SCHEME_FILE"
    elif [[ -n "$_em_script_dir" && -f "$_em_script_dir/em.scm" ]]; then
        _em_scm_file="$_em_script_dir/em.scm"
    elif [[ -f "$HOME/.em.scm" ]]; then
        _em_scm_file="$HOME/.em.scm"
    else
        print "em: cannot find em.scm" >&2
        return 1
    fi

    local _em_runtime_file=""
    if [[ -n "${SHEMACS_RUNTIME_FILE:-}" && ! -f "$SHEMACS_RUNTIME_FILE" ]]; then
        print "em: SHEMACS_RUNTIME_FILE does not name a file: $SHEMACS_RUNTIME_FILE" >&2
        return 1
    fi
    for _runtime_candidate in \
            "${SHEMACS_RUNTIME_FILE:-}" \
            "${_em_scm_file:h}/.em.aot-runtime.sh" \
            "${_em_script_dir}/em.aot-runtime.sh"; do
        [[ -n "$_runtime_candidate" && -f "$_runtime_candidate" ]] || continue
        _em_runtime_file="$_runtime_candidate"
        break
    done
    if [[ -z "$_em_runtime_file" ]]; then
        print "em: cannot find em.aot-runtime.sh" >&2
        return 1
    fi

    # AOT-compiled zsh cache (parallel to em.scm.cache for bash)
    local _em_cache_file="${SHEMACS_CACHE_FILE:-${_em_scm_file}.zsh.cache}"

    # Check if cache is fresh; source it if so
    if [[ -f "$_em_cache_file" \
          && "$_em_cache_file" -nt "$_em_scm_file" \
          && "$_em_cache_file" -nt "$_em_runtime_file" \
          && ( -z "$_em_bs_path" || "$_em_cache_file" -nt "$_em_bs_path" ) ]] \
       && source "$_em_cache_file" && (( ${+functions[em_main]} )); then
        : # AOT cache loaded
    else
        # Need to compile. bs.sh is a Bash program, so invoke its zsh target in
        # a child Bash instead of asking zsh to parse the compiler host.
        if (( ${#_em_bs_candidates[@]} == 0 )); then
            print "em: cannot find bs.sh — install sheme: https://github.com/jordanhubbard/sheme" >&2
            return 1
        fi
        local _em_bash_bin="" _bash_candidate
        if [[ -n "${SHEMACS_BASH:-}" ]]; then
            if [[ ! -x "$SHEMACS_BASH" ]] || \
               ! "$SHEMACS_BASH" -c '(( BASH_VERSINFO[0] >= 4 ))' 2>/dev/null; then
                print "em: SHEMACS_BASH must name Bash 4 or newer: $SHEMACS_BASH" >&2
                return 1
            fi
            _em_bash_bin="$SHEMACS_BASH"
        else
            local _em_path_bash
            _em_path_bash="$(command -v bash 2>/dev/null)"
            for _bash_candidate in \
                    "$_em_path_bash" \
                    /opt/homebrew/bin/bash \
                    /usr/local/bin/bash \
                    /usr/bin/bash; do
                [[ -x "$_bash_candidate" ]] || continue
                if "$_bash_candidate" -c '(( BASH_VERSINFO[0] >= 4 ))' 2>/dev/null; then
                    _em_bash_bin="$_bash_candidate"
                    break
                fi
            done
        fi
        if [[ -z "$_em_bash_bin" ]]; then
            print "em: Bash 4 or newer is required to rebuild the zsh cache" >&2
            return 1
        fi
        if [[ ! -f "$_em_cache_file" ]]; then
            printf "em: First run — compiling Scheme to zsh (this may take a moment).\n" >&2
            printf "em: Subsequent runs use the cache and start instantly.\n" >&2
        else
            printf "em: Cache is stale; recompiling.\n" >&2
        fi

        local _em_compiled=""
        for _bs_candidate in "${_em_bs_candidates[@]}"; do
            local _em_tmp
            _em_tmp=$(umask 077; mktemp "${_em_cache_file}.tmp.XXXXXXXX") || continue
            if "$_em_bash_bin" -c '
                    source "$1" || exit
                    type bs-compile-zsh &>/dev/null || exit 2
                    bs-reset
                    bs-compile-zsh --runtime "$2" "$(< "$3")"
                ' _ "$_bs_candidate" "$_em_runtime_file" "$_em_scm_file" > "$_em_tmp" \
               && zsh -n "$_em_tmp" \
               && mv -f "$_em_tmp" "$_em_cache_file"; then
                _em_compiled=1
                _em_bs_path="$_bs_candidate"
                break
            fi
            rm -f "$_em_tmp"
        done

        if [[ -z "$_em_compiled" ]]; then
            print "em: unable to build a valid zsh cache with the discovered sheme compiler" >&2
            return 1
        fi

        if ! source "$_em_cache_file" || (( ! ${+functions[em_main]} )); then
            print "em: generated zsh cache did not load" >&2
            return 1
        fi
    fi

    # Supply eval-string through the zsh interpreter on both cache paths.
    if (( ! ${+functions[bs]} )); then
        local _em_bszsh=""
        if [[ -n "${SHEME_ZSH:-}" && ! -f "$SHEME_ZSH" ]]; then
            print "em: SHEME_ZSH does not name a file: $SHEME_ZSH" >&2
            return 1
        fi
        for _zsh_candidate in \
                "${SHEME_ZSH:-}" \
                "${_em_script_dir}/../sheme/bs.zsh" \
                "$HOME/.bs.zsh" \
                /usr/local/lib/sheme/bs.zsh \
                /opt/sheme/bs.zsh; do
            [[ -n "$_zsh_candidate" && -f "$_zsh_candidate" ]] || continue
            _em_bszsh="$_zsh_candidate"
            break
        done
        if [[ -z "$_em_bszsh" ]]; then
            print "em: cannot find bs.zsh — install the complete sheme package" >&2
            return 1
        fi
        source "$_em_bszsh" || return 1
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
            printf "Press Enter to continue or Ctrl-C to abort: " >&2
            read -r || { trap - INT TERM HUP; [[ -n "$_em_saved_traps" ]] && eval "$_em_saved_traps"; return 130; }
        fi
    fi

    # Run the editor — em_main is a native zsh function from the compiled cache.
    # Keep cleanup reliable even when the editor reports an error.
    local -i _em_status
    if em_main "${1:-}"; then _em_status=0; else _em_status=$?; fi

    # Restore traps
    trap - INT TERM HUP
    [[ -n "$_em_saved_traps" ]] && eval "$_em_saved_traps"
    return "$_em_status"
}

# Standalone execution: zsh em.zsh [filename]
if [[ "${(%):-%N}" == "$0" ]]; then
    em "$@"
fi
