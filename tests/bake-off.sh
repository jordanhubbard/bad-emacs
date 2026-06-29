#!/usr/bin/env bash
# tests/bake-off.sh — shemacs performance bake-off vs mg
#
# Measures startup latency and per-keystroke latency for:
#   0. mg        — C binary reference (micrognuemacs)
#   1. em.sh     — Scheme AOT-compiled → bash  (em.scm.cache)
#   2. em.zsh    — Scheme AOT-compiled → zsh   (em.scm.zsh.cache)
#
# Benchmarks:
#   A. Startup    — time from spawn to first render → quit
#   B. Keystroke  — µs/key for self-insert (TYPE_N chars), derived as:
#                   (type_ms − startup_ms) / TYPE_N
#                   Note: includes 200ms drain wait → subtract 2000µs/key
#                   for true keystroke latency.
#   C. Render µbench — direct em_render() timing for compiled shell variants
#
# Harness note: uses "vwait" (Tcl event-loop wait) instead of "after N"
# (blocking sleep) so PTY output is consumed continuously.  This avoids
# bash's tcsetattr(TCSADRAIN) stall that inflated first-key reads by
# 600-1100ms in earlier harness versions.
#
# Usage:
#   bash tests/bake-off.sh            # full bake-off (3 trials each)
#   bash tests/bake-off.sh --quick    # 1 trial
#
# Requires: expect, Bash 4+, zsh 5+, sheme, Python 3, and optionally mg

set -uo pipefail
cd "$(dirname "$0")/.."

TRIALS=3
[[ "${1:-}" == "--quick" ]] && TRIALS=1

PASS=0; FAIL=0

# ── helpers ──────────────────────────────────────────────────────────────────

_ms() { python3 -c "import time; print(int(time.time()*1000))"; }

# Write a temp expect script, run N trials, return median ms
_bench_script() {
    local n="$1" script="$2"
    local tmp; tmp=$(mktemp /tmp/bake_XXXXXX.exp)
    printf 'log_user 0\n%s\n' "$script" > "$tmp"
    local -a times=()
    for (( t=0; t<n; t++ )); do
        local t0 t1
        t0=$(_ms)
        expect "$tmp" &>/dev/null
        t1=$(_ms)
        times+=("$(( t1 - t0 ))")
    done
    rm -f "$tmp"
    _median "${times[@]}"
}

# Median of N values passed as args
_median() {
    local vals=("$@")
    local n=${#vals[@]}
    for (( i=1; i<n; i++ )); do
        local key="${vals[$i]}" j=$(( i-1 ))
        while (( j>=0 && vals[j] > key )); do
            vals[$((j+1))]="${vals[$j]}"; j=$((j-1))
        done
        vals[$((j+1))]="$key"
    done
    echo "${vals[$((n/2))]}"
}

# ── expect script templates ───────────────────────────────────────────────────

# $1=spawn_cmd  $2=ready_pattern  — start+quit
# Uses vwait after match to drain remaining PTY output via event loop.
_mk_start_quit() {
    local spawn_cmd="$1" ready_pat="$2"
    cat <<EEXP
#!/usr/bin/expect -f
set timeout 30
spawn $spawn_cmd
expect {
    -re {$ready_pat} { }
    timeout { exit 1 }
}
after 30 { set _go 1 }
vwait _go
send "\\x18\\x03"
expect { eof { } timeout { exit 1 } }
EEXP
}

# $1=spawn_cmd  $2=ready_pattern  $3=nchars — start+type N keys+quit
# Keys are sent all at once; we vwait 200ms (event-loop driven) so:
#   • PTY output is consumed → tcsetattr(TCSADRAIN) completes instantly
#   • Editor finishes processing all keys before we quit
# Net overhead added to keystroke timing: 200ms / TYPE_N  (≤ 2ms/key for N≥100)
_mk_type_n() {
    local spawn_cmd="$1" ready_pat="$2" nchars="$3"
    local keys=""
    for (( i=0; i<nchars; i++ )); do keys+="a"; done
    cat <<EEXP
#!/usr/bin/expect -f
set timeout 30
spawn $spawn_cmd
expect {
    -re {$ready_pat} { }
    timeout { exit 1 }
}
after 30 { set _go 1 }
vwait _go
send "$keys"
after 200 { set _go 1 }
vwait _go
send "\\x18\\x03"
expect { eof { } timeout { exit 1 } }
EEXP
}

TYPE_N=100     # keypresses for keystroke benchmark

# ── variant definitions ───────────────────────────────────────────────────────

# Startup ready-pattern: match any first byte of output from the editor.
# Using '.' (any char) because Tcl's {} quoting suppresses \-escapes, so
# {\033\[} does NOT match ESC[; using '.' is universal and avoids the issue.
ANSI_PAT='.'

declare -A V_LABEL V_SPAWN V_SHELL V_CACHE V_PAT

MG_BIN=$(command -v mg 2>/dev/null || true)
V_LABEL[mg_ref]="mg                    (C binary)"
V_SPAWN[mg_ref]="${MG_BIN:-mg}"
V_SHELL[mg_ref]="none"
V_CACHE[mg_ref]=""
V_PAT[mg_ref]="$ANSI_PAT"

V_LABEL[bash_aot]="em.sh              AOT bash (sheme)"
# Source a local cache directly so startup measurements exclude discovery and
# compilation. The preflight below builds or refreshes this exact cache.
# Tcl {}-quoting passes the -c argument as a single word to bash.
V_SPAWN[bash_aot]="bash --norc --noprofile -c {source ./em.scm.cache; em_main}"
V_SHELL[bash_aot]="bash"
V_CACHE[bash_aot]="em.scm.cache"
V_PAT[bash_aot]="$ANSI_PAT"

V_LABEL[zsh_aot]="em.zsh             AOT zsh  (sheme)"
# Tcl {}-quoting passes the -c argument as a single word to zsh.
V_SPAWN[zsh_aot]="zsh -f -c {source ./em.scm.zsh.cache; em_main}"
V_SHELL[zsh_aot]="zsh"
V_CACHE[zsh_aot]="em.scm.zsh.cache"
V_PAT[zsh_aot]="$ANSI_PAT"

VARIANTS=(mg_ref bash_aot zsh_aot)

# ── preflight ─────────────────────────────────────────────────────────────────

echo "=== shemacs Performance Bake-Off vs mg ==="
echo "  Trials per measurement: $TRIALS"
echo "  Keystroke sample size:  $TYPE_N self-inserts"
echo "  Harness:                vwait (event-loop) — no TCSADRAIN stalls"
echo ""

if ! command -v expect &>/dev/null; then
    echo "ERROR: expect is required" >&2; exit 1
fi
if ! command -v python3 &>/dev/null; then
    echo "ERROR: python3 is required for timing" >&2; exit 1
fi

# Build both benchmark inputs from the checked-out source. Reusing an old cache
# can otherwise compare different editor/compiler versions while looking valid.
SHEME_BS=${SHEME_BS:-}
for candidate in "$(pwd)/../sheme/bs.sh" "$HOME/.bs.sh"; do
    [[ -n "$SHEME_BS" ]] && break
    [[ -f "$candidate" ]] && SHEME_BS="$candidate"
done
if [[ ! -f "$SHEME_BS" ]]; then
    echo "ERROR: sheme bs.sh not found (set SHEME_BS or use sibling checkouts)" >&2
    exit 1
fi

_build_cache() {
    local target="$1" output="$2" checker="$3" tmp
    if [[ -f "$output" && "$output" -nt em.scm \
          && "$output" -nt em.aot-runtime.sh && "$output" -nt "$SHEME_BS" ]]; then
        return
    fi
    printf '  BUILD %-36s' "$output"
    tmp=$(umask 077; mktemp "${output}.tmp.XXXXXXXX")
    if bash -c '
            source "$1" || exit
            bs-reset
            "$2" --runtime "$3" "$(< "$4")"
        ' _ "$SHEME_BS" "$target" "$(pwd)/em.aot-runtime.sh" "$(pwd)/em.scm" \
            > "$tmp" \
       && "$checker" -n "$tmp" \
       && mv -f "$tmp" "$output"; then
        echo " OK"
    else
        rm -f "$tmp"
        echo " FAIL"
        exit 1
    fi
}

_build_cache bs-compile em.scm.cache bash
_build_cache bs-compile-zsh em.scm.zsh.cache zsh

echo "Checking variants..."
for v in "${VARIANTS[@]}"; do
    label="${V_LABEL[$v]}"
    spawn="${V_SPAWN[$v]}"
    cache="${V_CACHE[$v]}"
    exe="${spawn%% *}"
    # skip if spawn binary missing
    if [[ ! -x "$exe" ]] && ! command -v "$exe" &>/dev/null; then
        echo "  SKIP  $label — not found: $exe"
        V_SPAWN[$v]=""
        continue
    fi
    if [[ -n "$cache" && ! -f "$cache" ]]; then
        echo "  SKIP  $label — cache not found: $cache"
        V_SPAWN[$v]=""
        continue
    fi
    echo "  OK    $label"
done
echo ""

# ── benchmark A: startup time ─────────────────────────────────────────────────

echo "──────────────────────────────────────────────────────────"
echo "A. STARTUP TIME  (spawn → first render → quit)"
echo "──────────────────────────────────────────────────────────"
printf "  %-44s  %8s\n" "Variant" "Median ms"
printf "  %-44s  %8s\n" "-------------------------------------------" "---------"

declare -A STARTUP_MS

for v in "${VARIANTS[@]}"; do
    [[ -z "${V_SPAWN[$v]:-}" ]] && continue
    script=$(_mk_start_quit "${V_SPAWN[$v]}" "${V_PAT[$v]}")
    ms=$(_bench_script "$TRIALS" "$script")
    STARTUP_MS[$v]="$ms"
    printf "  %-44s  %8d ms\n" "${V_LABEL[$v]}" "$ms"
done
echo ""

# ── benchmark B: per-keystroke latency ────────────────────────────────────────

echo "──────────────────────────────────────────────────────────"
echo "B. KEYSTROKE LATENCY  ($TYPE_N self-inserts, derived)"
echo "   Derived µs/key = (type_total − startup) / $TYPE_N"
echo "   Harness overhead = 200ms/$TYPE_N = ~2ms/key (same for all variants)"
echo "──────────────────────────────────────────────────────────"
printf "  %-44s  %8s  %10s  %10s\n" "Variant" "Total ms" "µs/key(raw)" "µs/key(net)"
printf "  %-44s  %8s  %10s  %10s\n" "-------------------------------------------" "--------" "-----------" "-----------"

declare -A TYPING_MS KEY_US KEY_US_NET

for v in "${VARIANTS[@]}"; do
    [[ -z "${V_SPAWN[$v]:-}" ]] && continue
    script=$(_mk_type_n "${V_SPAWN[$v]}" "${V_PAT[$v]}" "$TYPE_N")
    ms=$(_bench_script "$TRIALS" "$script")
    TYPING_MS[$v]="$ms"
    startup=${STARTUP_MS[$v]:-0}
    net=$(( ms - startup ))
    (( net < 0 )) && net=0
    us_key=$(( net * 1000 / TYPE_N ))
    # subtract 200ms harness drain wait
    us_net=$(( us_key > 2000 ? us_key - 2000 : 0 ))
    KEY_US[$v]="$us_key"
    KEY_US_NET[$v]="$us_net"
    printf "  %-44s  %8d ms  %8d µs  %8d µs\n" "${V_LABEL[$v]}" "$ms" "$us_key" "$us_net"
done
echo ""

# ── benchmark C: render µbench (compiled shell variants only) ─────────────────

echo "──────────────────────────────────────────────────────────"
echo "C. RENDER MICRO-BENCHMARK  (direct em_render() call)"
echo "   N=500 renders, 24×80"
echo "──────────────────────────────────────────────────────────"
printf "  %-44s  %8s  %10s\n" "Variant" "Total ms" "µs/render"
printf "  %-44s  %8s  %10s\n" "-------------------------------------------" "--------" "----------"

N_RENDERS=500

_render_bench_bash() {
    local cache="$1"
    bash --norc --noprofile <<EOBASH
source "$cache" >/dev/null 2>&1
em_init 24 80 >/dev/null 2>&1
em_render >/dev/null 2>&1
t0=\$(python3 -c "import time; print(int(time.time()*1000))")
for (( i=0; i<$N_RENDERS; i++ )); do em_render >/dev/null 2>&1; done
t1=\$(python3 -c "import time; print(int(time.time()*1000))")
echo \$(( t1 - t0 ))
EOBASH
}

_render_bench_zsh() {
    local cache="$1"
    zsh -f <<EOZSH
source "$cache" >/dev/null 2>&1
em_rows=24; em_cols=80
em_lines=(""); em_nlines=1; em_cy=0; em_cx=0; em_top=0; em_left=0
em_modified=0; em_bufname="*scratch*"; em_message=""
em_mark_y=-1; em_mark_x=-1; em_mode="normal"; em_macro_recording=0
em_render >/dev/null 2>&1
t0=\$(python3 -c "import time; print(int(time.time()*1000))")
for (( i=0; i<$N_RENDERS; i++ )); do em_render >/dev/null 2>&1; done
t1=\$(python3 -c "import time; print(int(time.time()*1000))")
echo \$(( t1 - t0 ))
EOZSH
}

_bench_render_variant() {
    local v="$1"
    local cache="${V_CACHE[$v]}"
    local shell="${V_SHELL[$v]}"
    local -a trial_ms=()
    for (( t=0; t<TRIALS; t++ )); do
        local ms
        if [[ "$shell" == "zsh" ]]; then
            ms=$(_render_bench_zsh "$cache")
        else
            ms=$(_render_bench_bash "$cache")
        fi
        trial_ms+=("${ms:-9999}")
    done
    local total
    total=$(_median "${trial_ms[@]}")
    local us_render=$(( total * 1000 / N_RENDERS ))
    printf "  %-44s  %8d ms  %8d µs\n" "${V_LABEL[$v]}" "$total" "$us_render"
}

for v in bash_aot zsh_aot; do
    [[ -z "${V_SPAWN[$v]:-}" ]] && continue
    _bench_render_variant "$v"
done
echo ""

# ── summary table ─────────────────────────────────────────────────────────────

echo "──────────────────────────────────────────────────────────"
echo "SUMMARY  (µs/key net = minus 2000µs harness drain overhead)"
echo "──────────────────────────────────────────────────────────"
printf "  %-44s  %10s  %12s\n" "Variant" "Startup ms" "µs/key (net)"
printf "  %-44s  %10s  %12s\n" "-------------------------------------------" "----------" "------------"
for v in "${VARIANTS[@]}"; do
    [[ -z "${V_SPAWN[$v]:-}" ]] && continue
    marker=""
    [[ "$v" == "mg_ref" ]] && marker=" ← reference"
    printf "  %-44s  %10d  %12d%s\n" \
        "${V_LABEL[$v]}" \
        "${STARTUP_MS[$v]:-0}" \
        "${KEY_US_NET[$v]:-0}" \
        "$marker"
done
echo ""

mg_key=${KEY_US_NET[mg_ref]:-0}
if (( mg_key > 0 )); then
    echo "Ratio vs mg (lower is better):"
    for v in bash_aot zsh_aot; do
        [[ -z "${V_SPAWN[$v]:-}" ]] && continue
        v_key=${KEY_US_NET[$v]:-0}
        if (( v_key > 0 && mg_key > 0 )); then
            ratio=$(python3 -c "print(f'  {$v_key/$mg_key:.1f}x slower')")
            printf "  %-44s  %s\n" "${V_LABEL[$v]}" "$ratio"
        fi
    done
    echo ""
fi
