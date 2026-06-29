# shemacs AOT runtime
#
# This file is injected verbatim into code generated from em.scm.  It contains
# the shell-native representations that cannot be expressed directly by the
# compiler's flat array model: nested buffer records and compact undo records.
# Keep the syntax valid in both Bash 4+ and zsh with KSH_ARRAYS enabled.

# Arrays are serialized with decimal length prefixes. Unlike delimiter-based
# packing, this round-trips every non-NUL character the shell can represent,
# including newlines and ASCII control separators found in edited files.
em_pack_fields() {
    local packed="" item
    for item in "$@"; do packed+="${#item}:$item"; done
    __r=("$packed")
}

em_unpack_fields() {
    local packed="$1" length
    local -a fields=()
    while [[ -n "$packed" ]]; do
        [[ "$packed" == *:* ]] || return 1
        length="${packed%%:*}"
        case "$length" in ""|*[!0-9]*) return 1 ;; esac
        packed="${packed#*:}"
        (( length <= ${#packed} )) || return 1
        fields+=("${packed:0:$(( length ))}")
        packed="${packed:$(( length ))}"
    done
    __r=("${fields[@]}")
}

em_undo_push() {
    local record
    em_pack_fields "$@"
    record="$__r"
    em_undo_stack=("$record" "${em_undo_stack[@]}")
    (( ${#em_undo_stack[@]} <= 200 )) || \
        em_undo_stack=("${em_undo_stack[@]:0:200}")
}

em_undo() {
    if (( ${#em_undo_stack[@]} == 0 )); then
        em_message="No further undo information"
        return
    fi

    local record="${em_undo_stack[0]}"
    local -a fields=()
    if ! em_unpack_fields "$record"; then
        em_message="Corrupt undo record"
        return 1
    fi
    fields=("${__r[@]}")
    em_undo_stack=("${em_undo_stack[@]:1}")

    local type="${fields[0]}" line next
    local -i y x idx sy current_count saved_cy saved_cx i
    local -a saved=()
    case "$type" in
        insert_char)
            y=${fields[1]}; x=${fields[2]}; line="${em_lines[y]:-}"
            em_lines[y]="${line:0:$x}${fields[3]}${line:$x}"
            em_cy=$y; em_cx=$x
            ;;
        delete_char)
            y=${fields[1]}; x=${fields[2]}; line="${em_lines[y]:-}"
            em_lines[y]="${line:0:$x}${line:$(( x + 1 ))}"
            em_cy=$y; em_cx=$x
            ;;
        join_lines)
            y=${fields[1]}; x=${fields[2]}; line="${em_lines[y]:-}"
            em_lines[y]="${line:0:$x}"
            idx=$(( y + 1 ))
            em_lines=("${em_lines[@]:0:$idx}" "${line:$x}" "${em_lines[@]:$idx}")
            (( em_nlines++ )) || true
            em_cy=$y; em_cx=$x
            ;;
        split_line)
            y=${fields[1]}; x=${fields[2]}
            line="${em_lines[y]:-}"; next="${em_lines[y+1]:-}"
            em_lines[y]="${line}${next}"
            idx=$(( y + 1 ))
            em_lines=("${em_lines[@]:0:$idx}" "${em_lines[@]:$(( idx + 1 ))}")
            (( em_nlines-- )) || true
            em_cy=$y; em_cx=$x
            ;;
        replace_line)
            y=${fields[1]}; x=${fields[2]}
            em_lines[y]="${fields[3]}"
            em_cy=$y; em_cx=$x
            ;;
        replace_region)
            sy=${fields[1]}; current_count=${fields[2]}
            saved_cy=${fields[3]}; saved_cx=${fields[4]}
            saved=("${fields[@]:5}")
            for (( i=0; i<current_count && em_nlines>0; i++ )); do
                em_lines=("${em_lines[@]:0:$sy}" "${em_lines[@]:$(( sy + 1 ))}")
                (( em_nlines-- )) || true
            done
            for (( i=0; i<${#saved[@]}; i++ )); do
                idx=$(( sy + i ))
                em_lines=("${em_lines[@]:0:$idx}" "${saved[i]}" "${em_lines[@]:$idx}")
                (( em_nlines++ )) || true
            done
            if (( em_nlines == 0 )); then em_lines=(""); em_nlines=1; fi
            em_cy=$saved_cy; em_cx=$saved_cx
            ;;
    esac
    em_modified=1
    em_ensure_visible
    em_message="Undo!"
}

em_lines_list() {
    local -i start=$1 end=$2
    __r=("${em_lines[@]:$start:$(( end - start + 1 ))}")
}

# Buffer vectors in Scheme become records in this associative array.  A regular
# array preserves display order and supplies stable numeric buffer IDs.
typeset -gA em_bufs=()
typeset -ga em_buf_ids=()

em_make_buffer() {
    local -i id=$1
    local name="$2" filename="$3"
    em_bufs["${id}_name"]="$name"
    em_bufs["${id}_filename"]="$filename"
    em_bufs["${id}_nlines"]=1
    em_bufs["${id}_line_0"]=""
    em_bufs["${id}_cy"]=0; em_bufs["${id}_cx"]=0
    em_bufs["${id}_top"]=0; em_bufs["${id}_left"]=0
    em_bufs["${id}_modified"]=0
    em_bufs["${id}_goal_col"]=-1
    em_bufs["${id}_mark_y"]=-1; em_bufs["${id}_mark_x"]=-1
    em_bufs["${id}_undo"]=""; em_bufs["${id}_kill"]=""
    __r=$id
}

em_find_buffer_by_id() {
    local -i wanted=$1 id
    for id in "${em_buf_ids[@]}"; do
        if (( id == wanted )); then __r=$id; return 0; fi
    done
    __r=0
    return 1
}

em_find_buffer_by_name() {
    local wanted="$1" id
    for id in "${em_buf_ids[@]}"; do
        if [[ "${em_bufs["${id}_name"]}" == "$wanted" ]]; then
            __r=$id
            return 0
        fi
    done
    __r=0
    return 1
}

em_find_buffer_by_filename() {
    local wanted="$1" id
    for id in "${em_buf_ids[@]}"; do
        if [[ "${em_bufs["${id}_filename"]}" == "$wanted" ]]; then
            __r=$id
            return 0
        fi
    done
    __r=0
    return 1
}

em_save_buffer_state() {
    local -i id=$em_cur_buf_id i old_count=${em_bufs["${em_cur_buf_id}_old_nlines"]:-0}
    em_bufs["${id}_name"]="$em_bufname"
    em_bufs["${id}_filename"]="$em_filename"
    em_bufs["${id}_nlines"]=$em_nlines
    em_bufs["${id}_cy"]=$em_cy; em_bufs["${id}_cx"]=$em_cx
    em_bufs["${id}_top"]=$em_top; em_bufs["${id}_left"]=$em_left
    em_bufs["${id}_modified"]=$em_modified
    em_bufs["${id}_goal_col"]=$em_goal_col
    em_bufs["${id}_mark_y"]=$em_mark_y; em_bufs["${id}_mark_x"]=$em_mark_x
    for (( i=em_nlines; i<old_count; i++ )); do
        unset "em_bufs[${id}_line_${i}]" 2>/dev/null
    done
    em_bufs["${id}_old_nlines"]=$em_nlines
    for (( i=0; i<em_nlines; i++ )); do
        em_bufs["${id}_line_${i}"]="${em_lines[i]}"
    done

    em_pack_fields "${em_undo_stack[@]}"
    em_bufs["${id}_undo"]="$__r"
    em_pack_fields "${em_kill_ring[@]}"
    em_bufs["${id}_kill"]="$__r"
}

em_restore_buffer_state() {
    local -i id=$1 i count
    em_cur_buf_id=$id
    em_bufname="${em_bufs["${id}_name"]}"
    em_filename="${em_bufs["${id}_filename"]}"
    em_nlines=${em_bufs["${id}_nlines"]:-1}
    em_cy=${em_bufs["${id}_cy"]:-0}; em_cx=${em_bufs["${id}_cx"]:-0}
    em_top=${em_bufs["${id}_top"]:-0}; em_left=${em_bufs["${id}_left"]:-0}
    em_modified=${em_bufs["${id}_modified"]:-0}
    em_goal_col=${em_bufs["${id}_goal_col"]:--1}
    em_mark_y=${em_bufs["${id}_mark_y"]:--1}; em_mark_x=${em_bufs["${id}_mark_x"]:--1}
    em_lines=()
    count=$em_nlines
    for (( i=0; i<count; i++ )); do em_lines+=("${em_bufs["${id}_line_${i}"]}"); done
    (( ${#em_lines[@]} > 0 )) || em_lines=("")

    em_undo_stack=()
    if [[ -n "${em_bufs["${id}_undo"]}" ]]; then
        if ! em_unpack_fields "${em_bufs["${id}_undo"]}"; then
            em_message="Corrupt saved undo state"
            return 1
        fi
        em_undo_stack=("${__r[@]}")
    fi
    em_kill_ring=()
    if [[ -n "${em_bufs["${id}_kill"]}" ]]; then
        if ! em_unpack_fields "${em_bufs["${id}_kill"]}"; then
            em_message="Corrupt saved kill-ring state"
            return 1
        fi
        em_kill_ring=("${__r[@]}")
    fi
}

em_new_buffer() {
    local name="$1" filename="$2"
    (( em_buf_id_counter++ )) || true
    em_make_buffer "$em_buf_id_counter" "$name" "$filename"
    em_buf_ids+=("$em_buf_id_counter")
    em_cur_buf_id=$em_buf_id_counter
    em_bufname="$name"; em_filename="$filename"
    em_lines=(""); em_nlines=1
    em_cy=0; em_cx=0; em_top=0; em_left=0
    em_modified=0; em_goal_col=-1
    em_mark_y=-1; em_mark_x=-1
    em_undo_stack=(); em_kill_ring=()
    __r=$em_buf_id_counter
}

em_buf_update_name() {
    em_bufs["${em_cur_buf_id}_name"]="$1"
    em_bufs["${em_cur_buf_id}_filename"]="$2"
}

em_do_switch_buffer() {
    local target="$1"
    [[ -n "$target" ]] || target="$em_bufname"
    if em_find_buffer_by_name "$target"; then
        local -i id=$__r
        em_save_buffer_state
        em_restore_buffer_state "$id"
        em_message="$em_bufname"
    else
        em_message="No buffer named '${target}'"
    fi
}

em_do_kill_buffer() {
    local target="$1"
    local -i force=${2:-0}
    [[ -n "$target" ]] || target="$em_bufname"
    if (( ${#em_buf_ids[@]} <= 1 )); then
        em_message="Cannot kill the only buffer"
        return
    fi
    if ! em_find_buffer_by_name "$target"; then
        em_message="No buffer named '${target}'"
        return
    fi

    local -i id=$__r is_current=0 modified
    (( id == em_cur_buf_id )) && is_current=1
    if (( is_current )); then modified=$em_modified
    else modified=${em_bufs["${id}_modified"]:-0}
    fi
    if (( ! force && modified == 1 )) && [[ "$target" != "*scratch*" ]]; then
        em_pending_kill_buffer="$target"
        em_minibuffer_start "Buffer '${target}' modified; kill anyway? (yes or no) " \
            "kill-buffer-confirm"
        return
    fi

    local -a remaining=()
    local candidate
    for candidate in "${em_buf_ids[@]}"; do
        (( candidate == id )) || remaining+=("$candidate")
    done
    em_buf_ids=("${remaining[@]}")
    if (( is_current )); then em_restore_buffer_state "${em_buf_ids[0]}"; fi

    local key
    local -i i old_count=${em_bufs["${id}_old_nlines"]:-${em_bufs["${id}_nlines"]:-0}}
    for key in name filename nlines old_nlines cy cx top left modified goal_col mark_y mark_x undo kill; do
        unset "em_bufs[${id}_${key}]"
    done
    for (( i=0; i<old_count; i++ )); do unset "em_bufs[${id}_line_${i}]"; done
    em_message="Killed buffer '${target}'"
}

em_list_buffers() {
    em_save_buffer_state
    local -a lines=(" MR  Buffer               Size    File"
                    " --  --------------------  ----    ----")
    local id name file cursor modified_marker padding
    local -i modified count
    for id in "${em_buf_ids[@]}"; do
        name="${em_bufs["${id}_name"]}"; file="${em_bufs["${id}_filename"]}"
        modified=${em_bufs["${id}_modified"]:-0}; count=${em_bufs["${id}_nlines"]:-1}
        cursor=" "; modified_marker=" "
        (( id == em_cur_buf_id )) && cursor="."
        (( modified == 1 )) && modified_marker="*"
        string_repeat " " "$(( 20 - ${#name} > 1 ? 20 - ${#name} : 1 ))"
        padding="$__r"
        lines+=(" ${cursor}${modified_marker}  ${name}${padding}  ${count}  ${file}")
    done
    lines+=("" "[Press C-g or q to return]")
    em_lines=("${lines[@]}"); em_nlines=${#lines[@]}
    em_cy=0; em_cx=0; em_top=0
    em_bufname="*Buffer List*"; em_filename=""; em_modified=0; em_message=""
    while true; do
        em_render
        em_read_key
        case "$__r" in
            C-g|SELF:q) break ;;
            C-n|DOWN) em_next_line ;;
            C-p|UP) em_previous_line ;;
            C-v|PGDN) em_scroll_down ;;
            M-v|PGUP) em_scroll_up ;;
        esac
    done
    em_restore_buffer_state "$em_cur_buf_id"
    em_message=""
}

em_complete_buffer() {
    local input="$1" id name
    __r=()
    for id in "${em_buf_ids[@]}"; do
        name="${em_bufs["${id}_name"]}"
        if [[ -z "$input" || "$name" == "$input"* ]]; then __r+=("$name"); fi
    done
}

em_do_quit() {
    em_save_buffer_state
    local -i unsaved=0 id
    for id in "${em_buf_ids[@]}"; do
        if (( ${em_bufs["${id}_modified"]:-0} == 1 )) && \
           [[ "${em_bufs["${id}_name"]}" != "*scratch*" ]]; then
            (( unsaved++ )) || true
        fi
    done
    if (( unsaved > 0 )); then
        em_minibuffer_start "${unsaved} modified buffer(s) not saved; exit anyway? (yes or no) " \
            "quit-confirm"
    else
        em_running=0
    fi
}
