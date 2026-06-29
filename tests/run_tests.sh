#!/bin/bash
# Run the expect-based integration tests against both AOT targets.
# Usage: ./tests/run_tests.sh
# Requires: expect, Bash 4+, zsh, and both sheme interpreter files.

set -euo pipefail

cd "$(dirname "$0")/.."
REPO_DIR=$(pwd -P)

PASS=0
FAIL=0
ERRORS=()

run_test() {
    local name="$1" script="$2"
    printf "  %-40s " "$name"
    if output=$(expect "$script" 2>&1); then
        echo "PASS"
        PASS=$((PASS + 1))
    else
        echo "FAIL"
        ERRORS+=("$name: $output")
        FAIL=$((FAIL + 1))
    fi
}

run_runtime_test() {
    local shell_name="$1"
    local name="$shell_name: portable runtime invariants"
    printf "  %-40s " "$name"
    if output=$("$shell_name" tests/runtime-tests.sh 2>&1); then
        echo "PASS"
        PASS=$((PASS + 1))
    else
        echo "FAIL"
        ERRORS+=("$name: $output")
        FAIL=$((FAIL + 1))
    fi
}

run_launcher_test() {
    local name="launcher precedence and exit status"
    printf "  %-40s " "$name"
    if output=$(bash tests/launcher-tests.sh 2>&1); then
        echo "PASS"
        PASS=$((PASS + 1))
    else
        echo "FAIL"
        ERRORS+=("$name: $output")
        FAIL=$((FAIL + 1))
    fi
}

echo "=== em integration tests ==="
echo ""

# Syntax checks
echo "Syntax checks:"
printf "  %-40s " "bash syntax (bash -n em.sh)"
if bash -n em.sh 2>&1; then
    echo "PASS"
    PASS=$((PASS + 1))
else
    echo "FAIL"
    FAIL=$((FAIL + 1))
fi

printf "  %-40s " "zsh syntax (zsh -n em.zsh)"
if command -v zsh >/dev/null 2>&1 && zsh -n em.zsh 2>&1; then
    echo "PASS"
    PASS=$((PASS + 1))
else
    echo "FAIL"
    FAIL=$((FAIL + 1))
fi

printf "  %-40s " "portable runtime syntax"
if bash -n em.aot-runtime.sh && zsh -n em.aot-runtime.sh; then
    echo "PASS"
    PASS=$((PASS + 1))
else
    echo "FAIL"
    FAIL=$((FAIL + 1))
fi
run_runtime_test bash
run_runtime_test zsh
echo ""

# Locate sheme without depending on a developer's shell startup files.
SHEME_BS=${SHEME_BS:-}
SHEME_ZSH=${SHEME_ZSH:-}
for candidate in "$REPO_DIR/../sheme/bs.sh" "$HOME/.bs.sh"; do
    [[ -n "$SHEME_BS" ]] && break
    [[ -f "$candidate" ]] && SHEME_BS="$candidate"
done
for candidate in "$REPO_DIR/../sheme/bs.zsh" "$HOME/.bs.zsh"; do
    [[ -n "$SHEME_ZSH" ]] && break
    [[ -f "$candidate" ]] && SHEME_ZSH="$candidate"
done
if [[ ! -f "$SHEME_BS" || ! -f "$SHEME_ZSH" ]]; then
    echo "ERROR: complete sheme installation not found (need bs.sh and bs.zsh)"
    echo ""
    echo "=== Results: $PASS passed, $FAIL failed ==="
    exit 1
fi
export SHEME_BS SHEME_ZSH

echo "Launcher checks:"
run_launcher_test
echo ""

# Interactive workflows are the substance of this suite; a missing runner is a
# failed prerequisite, not a successful skip.
if ! command -v expect >/dev/null 2>&1; then
    echo "ERROR: expect is required for the editor integration tests"
    echo ""
    echo "=== Results: $PASS passed, $((FAIL + 1)) failed ==="
    exit 1
fi

# Use isolated source, runtime, and cache files. Besides preventing installed
# files from hiding regressions, this lets the cache test change source mtimes
# without touching the checkout.
TEST_TMP=$(mktemp -d "${TMPDIR:-/tmp}/shemacs-tests.XXXXXXXX")
trap 'rm -rf "$TEST_TMP"' EXIT

run_editor_suite() {
    local shell_name="$1" launcher="$2" cache_suffix="$3"
    export EM_SHELL="$shell_name" EM_LAUNCHER="$launcher"
    export SHEMACS_SCHEME_FILE="$TEST_TMP/em.${cache_suffix}.scm"
    export SHEMACS_RUNTIME_FILE="$TEST_TMP/em.${cache_suffix}.runtime.sh"
    export SHEMACS_CACHE_FILE="$TEST_TMP/em.${cache_suffix}.cache"
    cp "$REPO_DIR/em.scm" "$SHEMACS_SCHEME_FILE"
    cp "$REPO_DIR/em.aot-runtime.sh" "$SHEMACS_RUNTIME_FILE"
    echo "$shell_name editor tests:"
    run_test "$shell_name: start and quit" tests/test_scm_start_quit.exp
    run_test "$shell_name: open file" tests/test_scm_open_file.exp
    run_test "$shell_name: save file" tests/test_scm_save_file.exp
    run_test "$shell_name: upcase word (M-u)" tests/test_scm_upcase.exp
    run_test "$shell_name: isearch highlight" tests/test_scm_isearch.exp
    run_test "$shell_name: eval-buffer runtime bridge" tests/test_scm_eval_buffer.exp
    run_test "$shell_name: modified-buffer kill guard" tests/test_scm_kill_modified.exp
    run_test "$shell_name: cache round-trip" tests/test_scm_cache.exp
    echo ""
}

run_editor_suite bash em.sh bash
run_editor_suite zsh em.zsh zsh

# Summary
echo "=== Results: $PASS passed, $FAIL failed ==="

if ((FAIL > 0)); then
    echo ""
    echo "Failures:"
    for err in "${ERRORS[@]}"; do
        echo "  - $err" | head -3
    done
    exit 1
fi
