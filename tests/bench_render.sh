#!/bin/bash
# bench_render.sh — historical synthetic render-loop microbenchmark
#
# This models helpers from the retired native-shell implementations. It does
# not source the current AOT cache or benchmark em_render, so it is useful as a
# historical experiment rather than as a regression test for current shemacs.
#
# Optimisations being validated:
#   1. Pre-computed _em_spaces / _em_dashes strings eliminate per-line
#      printf calls for padding (used 22+ times per render).
#   2. Inlining expand_tabs logic in the render loop eliminates per-line
#      function-call overhead (~14 µs each in bash).
#
# Usage:
#   bash tests/bench_render.sh           # run both baseline and optimised
#   bash tests/bench_render.sh --verify  # assert optimised < baseline
#
# Exit code:  0 = success / improvement confirmed
#             1 = optimised was not faster than baseline (regression)

set -uo pipefail

cd "$(dirname "$0")/.." || { echo "ERROR: cannot cd to repo root" >&2; exit 1; }

VERIFY=0
[[ "${1:-}" == "--verify" ]] && VERIFY=1

# ── shared setup ────────────────────────────────────────────────────────────
ESC=$'\x1b'
_em_rows=24
_em_cols=80
_em_left=0
_em_tab_width=8
_em_top=0
_em_modified=0
_em_bufname="bench.txt"
_em_message=""
_em_msg_persist=0
_em_isearch_active=0
_em_isearch_y=-1
_em_cy=10
_em_cx=5
_em_display_col=0
_em_expanded_line=""

# 200 lines: 90 % plain text, 10 % containing tabs
declare -a _em_lines=()
for ((i = 0; i < 200; i++)); do
    if ((i % 10 == 0)); then
        _em_lines+=($'col1\tcol2\tcol3\tdata here')
    else
        _em_lines+=("Line $i: some content here for benchmarking purposes")
    fi
done

visible_rows=$((_em_rows - 2))
NUM_RENDERS=2000   # renders per measurement

# ── baseline helpers ─────────────────────────────────────────────────────────
# The baseline and optimised helpers below deliberately preserve the old
# before/after logic. They are not expected to track current em.scm behavior.
_em_expand_tabs_baseline() {
    local line="$1"
    if [[ "$line" != *$'\t'* ]]; then _em_expanded_line="$line"; return; fi
    local result="" i ch col=0
    local -i len=${#line}
    for ((i = 0; i < len; i++)); do
        ch="${line:i:1}"
        if [[ "$ch" == $'\t' ]]; then
            local -i spaces=$((_em_tab_width - (col % _em_tab_width)))
            local pad=""; printf -v pad '%*s' "$spaces" ''
            result+="$pad"; ((col += spaces))
        else result+="$ch"; ((col++)); fi
    done
    _em_expanded_line="$result"
}

run_baseline() {
    local output
    for ((screen_row = 1; screen_row <= visible_rows; screen_row++)); do
        local i=$((_em_top + screen_row - 1))
        output+="${ESC}[${screen_row};1H"
        _em_expand_tabs_baseline "${_em_lines[i]}"
        local full_display="${_em_expanded_line}"
        local display="${full_display:_em_left:_em_cols}"
        local -i dlen=${#display}
        if ((dlen < _em_cols)); then
            local pad=""; printf -v pad '%*s' "$((_em_cols - dlen))" ''
            display+="$pad"
        fi
        output+="$display"
    done
    # Status bar
    local status="-UUU:--  bench.txt               (Fundamental) L11     All"
    local -i slen=${#status}
    if ((slen < _em_cols)); then
        local spad=""; printf -v spad '%*s' "$((_em_cols - slen))" ''
        status+="${spad// /-}"
    fi
    output+="${ESC}[${_em_rows};1H${ESC}[7m${status}${ESC}[0m"
    : "$output"
}

# ── optimised helpers ────────────────────────────────────────────────────────
printf -v _em_spaces '%*s' 256 ''
_em_dashes="${_em_spaces// /-}"

run_optimised() {
    local output
    for ((screen_row = 1; screen_row <= visible_rows; screen_row++)); do
        local i=$((_em_top + screen_row - 1))
        output+="${ESC}[${screen_row};1H"
        local line="${_em_lines[i]}"
        local full_display
        if [[ "$line" == *$'\t'* ]]; then
            full_display=""
            local _et_i _et_ch _et_col=0 _et_spaces
            local -i _et_len=${#line}
            for ((_et_i = 0; _et_i < _et_len; _et_i++)); do
                _et_ch="${line:_et_i:1}"
                if [[ "$_et_ch" == $'\t' ]]; then
                    _et_spaces=$((_em_tab_width - (_et_col % _em_tab_width)))
                    full_display+="${_em_spaces:0:_et_spaces}"
                    ((_et_col += _et_spaces))
                else full_display+="$_et_ch"; ((_et_col++)); fi
            done
        else
            full_display="$line"
        fi
        local display="${full_display:_em_left:_em_cols}"
        local -i dlen=${#display}
        if ((dlen < _em_cols)); then
            display+="${_em_spaces:0:_em_cols - dlen}"
        fi
        output+="$display"
    done
    # Status bar
    local status="-UUU:--  bench.txt               (Fundamental) L11     All"
    local -i slen=${#status}
    if ((slen < _em_cols)); then
        status+="${_em_dashes:0:_em_cols - slen}"
    fi
    output+="${ESC}[${_em_rows};1H${ESC}[7m${status}${ESC}[0m"
    : "$output"
}

# ── run measurements ─────────────────────────────────────────────────────────
echo "=== em render-loop benchmark (24×80 terminal, $NUM_RENDERS renders) ==="
echo ""

t_start=$(date +%s%N)
for ((k = 0; k < NUM_RENDERS; k++)); do run_baseline; done
t_end=$(date +%s%N)
ms_baseline=$(( (t_end - t_start) / 1000000 ))
us_baseline=$(( ms_baseline * 1000 / NUM_RENDERS ))
printf "  baseline  (printf padding + function call): %5d ms / %d = %d µs/render\n" \
    "$ms_baseline" "$NUM_RENDERS" "$us_baseline"

t_start=$(date +%s%N)
for ((k = 0; k < NUM_RENDERS; k++)); do run_optimised; done
t_end=$(date +%s%N)
ms_opt=$(( (t_end - t_start) / 1000000 ))
us_opt=$(( ms_opt * 1000 / NUM_RENDERS ))
printf "  optimised (spaces cache  + inline expand):  %5d ms / %d = %d µs/render\n" \
    "$ms_opt" "$NUM_RENDERS" "$us_opt"

echo ""
if ((us_baseline > 0)); then
    pct_saved=$(( (us_baseline - us_opt) * 100 / us_baseline ))
    echo "  Improvement: ${pct_saved}% faster per render"
fi

if (( VERIFY )); then
    echo ""
    if (( ms_opt < ms_baseline )); then
        echo "PASS: optimised render is faster than baseline"
        exit 0
    else
        echo "FAIL: optimised render was not faster than baseline (regression?)"
        exit 1
    fi
fi
