#!/usr/bin/env bash
# Start and quit each generated editor target from an isolated cold cache.

set -euo pipefail

cd "$(dirname "$0")/.."
repo_dir=$(pwd -P)

command -v expect >/dev/null 2>&1 || {
    echo "expect is required for make example" >&2
    exit 1
}
command -v zsh >/dev/null 2>&1 || {
    echo "zsh is required for make example" >&2
    exit 1
}

sheme_bash=${SHEME_BS:-}
sheme_zsh=${SHEME_ZSH:-}
for candidate in "$repo_dir/../sheme/bs.sh" "$HOME/.bs.sh"; do
    [[ -n "$sheme_bash" ]] && break
    [[ -f "$candidate" ]] && sheme_bash="$candidate"
done
for candidate in "$repo_dir/../sheme/bs.zsh" "$HOME/.bs.zsh"; do
    [[ -n "$sheme_zsh" ]] && break
    [[ -f "$candidate" ]] && sheme_zsh="$candidate"
done
if [[ ! -f "$sheme_bash" || ! -f "$sheme_zsh" ]]; then
    echo "complete sheme installation not found (need bs.sh and bs.zsh)" >&2
    exit 1
fi

tmp=$(mktemp -d "${TMPDIR:-/tmp}/shemacs-examples.XXXXXXXX")
trap 'rm -rf "$tmp"' EXIT

run_example() {
    local shell_name="$1" launcher="$2"
    local scheme_file="$tmp/em.${shell_name}.scm"
    local runtime_file="$tmp/em.${shell_name}.runtime.sh"
    cp "$repo_dir/em.scm" "$scheme_file"
    cp "$repo_dir/em.aot-runtime.sh" "$runtime_file"

    echo ""
    echo "── ${shell_name} AOT editor smoke example (start and quit) ──"
    EM_SHELL="$shell_name" \
    EM_LAUNCHER="$launcher" \
    SHEME_BS="$sheme_bash" \
    SHEME_ZSH="$sheme_zsh" \
    SHEMACS_SCHEME_FILE="$scheme_file" \
    SHEMACS_RUNTIME_FILE="$runtime_file" \
    SHEMACS_CACHE_FILE="$tmp/em.${shell_name}.cache" \
        expect tests/test_scm_start_quit.exp
}

run_example bash em.sh
run_example zsh em.zsh

echo ""
echo "Done! Smoke examples passed."
