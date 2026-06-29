#!/usr/bin/env bash
# Direct invariants for the portable AOT runtime. Run with both Bash and zsh.

set -eo pipefail
if [[ -n "${ZSH_VERSION:-}" ]]; then
    setopt KSH_ARRAYS
fi

cd "$(dirname "$0")/.."
# shellcheck source=../em.aot-runtime.sh
source ./em.aot-runtime.sh

fail() {
    printf 'runtime test failed: %s\n' "$1" >&2
    exit 1
}

# Length-prefix serialization must preserve empty fields, colons, newlines, and
# the control separators used by older cache formats.
sentinel=$'alpha:beta\nline-two\x1d\x1e\x1fomega'
em_pack_fields "" "$sentinel" "tail:"
packed="$__r"
em_unpack_fields "$packed" || fail "valid packed fields were rejected"
unpacked=("${__r[@]}")
(( ${#unpacked[@]} == 3 )) || fail "packed field count changed"
[[ "${unpacked[0]}" == "" ]] || fail "empty field changed"
[[ "${unpacked[1]}" == "$sentinel" ]] || fail "control-character field changed"
[[ "${unpacked[2]}" == "tail:" ]] || fail "colon field changed"
if em_unpack_fields "9:short"; then fail "truncated packed data was accepted"; fi

# Buffer snapshots must round-trip the same data through associative storage.
em_cur_buf_id=1
em_make_buffer 1 "*scratch*" ""
em_buf_ids=(1)
em_bufname="*scratch*"; em_filename=""
em_lines=("first" "$sentinel" ""); em_nlines=3
em_cy=1; em_cx=2; em_top=1; em_left=3
em_modified=1; em_goal_col=7
em_mark_y=0; em_mark_x=1
em_undo_stack=("undo:$sentinel" "")
em_kill_ring=("$sentinel" "tail:")
em_save_buffer_state

em_lines=("corrupt"); em_nlines=1
em_undo_stack=(); em_kill_ring=()
em_restore_buffer_state 1 || fail "saved buffer state was rejected"
(( ${#em_lines[@]} == 3 )) || fail "line count changed"
[[ "${em_lines[1]}" == "$sentinel" && "${em_lines[2]}" == "" ]] || +    fail "buffer lines changed"
(( ${#em_undo_stack[@]} == 2 )) || fail "undo stack count changed"
[[ "${em_undo_stack[0]}" == "undo:$sentinel" && "${em_undo_stack[1]}" == "" ]] || +    fail "undo stack changed"
[[ "${em_kill_ring[0]}" == "$sentinel" && "${em_kill_ring[1]}" == "tail:" ]] || +    fail "kill ring changed"

# Undo records use the same encoding and must preserve arbitrary inserted text.
em_ensure_visible() { :; }
em_lines=("ab"); em_nlines=1
em_cy=0; em_cx=0; em_modified=0; em_message=""
em_undo_stack=()
em_undo_push insert_char 0 1 "$sentinel"
em_undo
[[ "${em_lines[0]}" == "a${sentinel}b" ]] || fail "undo payload changed"
[[ "$em_message" == "Undo!" ]] || fail "undo did not complete"

printf 'portable runtime invariants passed\n'
