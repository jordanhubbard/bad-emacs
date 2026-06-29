#!/usr/bin/env bash
# Non-interactive launcher invariants shared by the Bash and zsh front ends.

set -eo pipefail
cd "$(dirname "$0")/.."
repo_dir=$(pwd -P)

sheme_bash=${SHEME_BS:-}
sheme_zsh=${SHEME_ZSH:-}
[[ -f "$sheme_bash" && -f "$sheme_zsh" ]] || {
    echo "SHEME_BS and SHEME_ZSH must name the two sheme sources" >&2
    exit 1
}

tmp=$(mktemp -d "${TMPDIR:-/tmp}/shemacs-launcher-tests.XXXXXXXX")
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/home"

# A sourceable cache stub lets us test launcher lifecycle without entering a
# terminal. Its distinctive status verifies that cleanup does not hide errors.
printf '%s\n' 'em_main() { return 7; }' > "$tmp/cache.sh"
sleep 1
touch "$tmp/cache.sh"
sleep 1

# This newer installed source is intentionally invalid. A launcher sourced from
# the checkout must prefer its adjacent em.scm and therefore reuse the valid
# explicit cache instead of trying to compile this file.
printf '%s\n' 'not valid Scheme (' > "$tmp/home/.em.scm"

run_launcher() {
    local shell_name="$1" launcher="$2" status
    HOME="$tmp/home" \
    SHEME_BS="$sheme_bash" \
    SHEME_ZSH="$sheme_zsh" \
    SHEMACS_CACHE_FILE="$tmp/cache.sh" \
        "$shell_name" -c '
            source "$1" || exit
            em >/dev/null 2>&1
            status=$?
            if [[ -n "${_bs_candidate+x}${_runtime_candidate+x}${_zsh_candidate+x}" ]]; then
                exit 99
            fi
            exit "$status"
        ' _ "$repo_dir/$launcher" >/dev/null 2>&1
    status=$?
    [[ "$status" == 7 ]] || {
        printf '%s returned %s, expected em_main status 7\n' "$launcher" "$status" >&2
        return 1
    }
}

# Capture nonzero statuses without errexit bypassing the second target.
set +e
run_launcher bash em.sh
bash_status=$?
run_launcher zsh em.zsh
zsh_status=$?
set -e
(( bash_status == 0 && zsh_status == 0 ))

printf 'launcher precedence, exit-status, and namespace invariants passed\n'
