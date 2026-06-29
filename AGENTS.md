<!-- CODEGRAPH_START -->
## CodeGraph

In repositories indexed by CodeGraph (a `.codegraph/` directory exists at the
repo root), reach for it before grep/find or reading files when you need to
understand or locate code:

- MCP tools (when available): `codegraph_explore` answers most code questions
  in one call; `codegraph_node` returns one symbol or a whole file.
- Shell (always works): `codegraph explore "<symbol names or question>"` and
  `codegraph node <symbol-or-file>` provide the same information.

If there is no `.codegraph/` directory, skip CodeGraph entirely; indexing is
the user's decision.
<!-- CODEGRAPH_END -->

# AGENTS.md — shemacs (`em`)

## Project Summary

`em` is an Emacs/mg-inspired terminal editor exposed through a shell function.
The editor logic (~2300 lines) is written in Scheme (`em.scm`) and AOT-compiled
to native Bash or zsh functions by
[sheme](https://github.com/jordanhubbard/sheme). The generated cache defines
many helper functions and globals; `em()` is the user-facing launcher.

**Dependency**: sheme's `bs.sh` hosts both AOT compiler targets. `make install`
installs it and `bs.zsh` automatically when necessary. The zsh launcher invokes
`bs.sh` through a child Bash for compilation and loads `bs.zsh` afterward to
provide runtime `eval-string`; it never asks zsh to parse the Bash compiler.

License: BSD 2-Clause. Author: Jordan Hubbard.

## Repository Layout

```
em.scm          — The editor, ~2300 lines of shell-neutral Scheme
em.sh           — Bash launcher: AOT-compiles em.scm and sources the result
em.zsh          — zsh launcher: compiles through Bash, sources native zsh
em.aot-runtime.sh — Portable nested buffer/undo runtime injected at compile time
Makefile        — install/uninstall/check/test targets
README.md       — User-facing documentation and keybinding reference
LICENSE         — BSD 2-Clause
AGENTS.md       — This file (LLM-oriented project documentation)
.github/        — Issue templates (bug_report.md, feature_request.md)
tests/          — expect-based integration tests and bench scripts
```

There is one authoritative editor-logic source file: `em.scm`. The launchers
also own cache discovery/invalidation, terminal safety traps, large-file
warnings, and shell-specific startup behavior.

The generic compiler cannot flatten all of the editor's nested buffer and undo
records. `em.aot-runtime.sh` therefore owns handwritten replacements for that
state model and is injected with sheme's `--runtime` interface. The compiled
result can differ from a literal translation of those Scheme functions. Keep
application logic here: sheme owns the injection mechanism, not editor state.

## The Implementation

### `em.scm` — The editor (Scheme)

~2300 lines of Scheme. Shell-neutral: all terminal I/O, file I/O, and
key reading are handled through sheme's built-in primitives (`read-byte`,
`write-stdout`, `terminal-raw!`, etc.). The source itself contains no
bash- or zsh-specific code.

### `em.sh` — Bash launcher

Launcher (~140 lines). On first run it:

1. Locates `bs.sh` (sheme interpreter and compiler)
2. Locates `em.scm`
3. Locates `em.aot-runtime.sh`
4. Compiles `em.scm` through a child Bash using `bs-compile --runtime`,
   syntax-checks the result, and atomically installs `em.scm.cache`
5. Sources the cache and `bs.sh` (for `eval-string`), then calls `em_main`

Subsequent runs reuse a fresh cache and go straight to the load/run path,
giving instant startup. Can be sourced into `~/.bashrc` to define `em()` as
a shell function, or run standalone as `bash em.sh file.txt`.

### `em.zsh` — Zsh launcher

Parallels `em.sh`, using `bs-compile-zsh` and `em.scm.zsh.cache`. It captures
the launcher's directory while the file is sourced, finds Bash 4+ on `PATH` or
in the usual Homebrew locations (with `SHEMACS_BASH` as an explicit override),
invokes the Bash-only compiler in that child, validates the generated file
with `zsh -n`, and atomically installs the cache. It then loads `bs.zsh` for
runtime evaluation.
Dynamic offsets, ordinary editing, file operations, search, case conversion,
modified-buffer confirmation, and cold-cache rebuilds are covered by the same
Expect workflows as Bash.

### Cache invalidation

The launchers consider a cache reusable only if:

- The cache is newer than `em.scm`
- The cache is newer than `em.aot-runtime.sh`
- The cache is newer than the selected `bs.sh`
- Sourcing it succeeds and it defines `em_main`

Delete either cache to force a supported rebuild:
```bash
rm -f ~/.em.scm.cache ~/.em.scm.zsh.cache
# or in the repo:
rm -f em.scm.cache em.scm.zsh.cache
```

## Architecture

### State Model

The logical editor state is defined by Scheme variables in `em.scm`; the AOT
runtime maps nested buffer/undo values to shell-native records:

| Variable(s) | Purpose |
|---|---|
| `em-lines` | Buffer content — vector of strings, one per line |
| `em-nlines` | Cached number of entries in `em-lines` |
| `em-cy`, `em-cx` | Cursor position (0-indexed line, 0-indexed column) |
| `em-top`, `em-left` | First visible line and horizontal scroll offset |
| `em-rows`, `em-cols` | Terminal dimensions |
| `em-mark-y`, `em-mark-x` | Mark position (-1 = unset) |
| `em-modified` | Dirty flag for current buffer (integer 0/1) |
| `em-filename` | File path of current buffer |
| `em-bufname` | Display name of current buffer |
| `em-message` | Minibuffer/echo-area message |
| `em-kill-ring` | Kill ring (max 60 entries) |
| `em-undo-stack` | Undo stack (max 200 entries, auto-trimmed) |
| `em-buffers` | List of 15-element buffer-record vectors |
| `em-macro-keys` | Keyboard macro recording |
| `em-goal-col` | Sticky column for vertical movement |
| `em-mode` | Current input mode (`normal`, `minibuffer`, `isearch`, etc.) |

### Subsystems (in source order)

1. **Terminal Setup / Cleanup** (`em-main`, `em-init`)
   - `em-main` enters/restores raw mode; launchers install safety traps
   - Enters raw mode via `terminal-raw!` / `terminal-restore!`
   - Uses the alternate screen buffer (`\e[?1049h`)

2. **Undo System** (`em-undo-push`, `em-undo`)
   - Record types: `insert_char`, `delete_char`, `join_lines`, `split_line`,
     `replace_line`, `replace_region`

3. **Rendering** (`em-render`)
   - Full-screen redraw on every keystroke
   - Tab expansion, region highlighting (ANSI reverse video)
   - Status line in Emacs format (`-UUU:**-- bufname (Fundamental) L## %%`)

4. **Input / Key Reading** (`em-read-key`)
   - Reads raw bytes via `read-byte`
   - Decodes control chars, ESC sequences, Meta key

5. **Movement** — char, word, line, page, buffer-level; goal-column tracking

6. **Editing** — self-insert, newline, open-line, delete, backward-delete

7. **Kill/Yank** — 60-entry kill ring; consecutive `C-k` appends

8. **Mark/Region** — set mark, exchange, mark whole buffer, kill/copy region

9. **Incremental Search** (`em-isearch-start`, `em-isearch-do`) — forward and backward

10. **Minibuffer** (`em-minibuffer-start`) — line editor with tab completion

11. **File I/O** — atomic save, load, find-file, write-file, insert-file

12. **Buffer Management** — multiple buffers, switch, kill, list

13. **Word Operations** — forward/backward word, kill word

14. **Transpose, Universal Argument, Quoted Insert**

15. **Query Replace** — interactive y/n/!/q/. (emacs-compatible)

16. **M-x Extended Commands** — dispatched by the `mx-command` callback in
    `em-minibuffer-handle-key`; completion names live in `em-mx-commands`

17. **Help / Describe Bindings**

18. **Case Conversion** — capitalize, upcase, downcase word

19. **Fill Paragraph** — blank-line delimited, wraps at fill column (default 72)

20. **Keyboard Macros** — record/playback

21. **Key Dispatch** (`em-dispatch`, `em-cx-dispatch`, `em-cx-r-dispatch`,
    `em-ch-dispatch`, `em-esc-dispatch`)

22. **Eval Buffer** (`em-eval-buffer`) — evaluate current buffer as Scheme code

## Key Design Decisions & Constraints

- **Pure Scheme editor logic**: No shell-specific code in `em.scm`. All I/O
  goes through sheme primitives.
- **AOT compilation**: `em.scm` is compiled to native shell code and the cache
  is sourced directly. The generated program may invoke standard utilities and
  includes shemacs-specific state code from `em.aot-runtime.sh`.
- **No EXIT trap**: Shell functions that set EXIT traps are dangerous (the
  trap lingers after the function returns). Cleanup is called explicitly and
  via INT/TERM/HUP traps.
- **Full redraw**: Every keystroke triggers a complete screen redraw. No
  dirty-line tracking.
- **Atomic saves**: File writes go to a temporary sibling first, then `mv` to
  the target. This is rename-based replacement, not a durability guarantee.
- **Push gate**: `make test` syntax-checks both launchers and the runtime, then
  exercises clean-cache Bash and zsh workflows. `make example` starts and quits
  both generated targets.

## Naming Conventions

- Scheme functions: `em-<name>` (dash-separated)
- Scheme globals: `em-<name>`
- Key names: `C-x` (control), `M-x` (meta/alt), `SELF:x` (printable self-insert)

## Keybindings

The editor aims for familiar mg/Emacs behavior rather than full compatibility.
Bindings are summarized in the header comment of `em.scm` and in `README.md`.
The dispatch tables are `em-dispatch`, `em-cx-dispatch`,
`em-cx-r-dispatch`, `em-ch-dispatch`, and `em-esc-dispatch`.

## Building and Testing

```bash
make check                       # syntax-check launchers and AOT runtime
make install                     # install launchers, Scheme source, and runtime
make uninstall                   # remove all installed shemacs files/source lines
make test                        # clean-cache Bash + zsh AOT workflows
make example                     # Bash + zsh start/quit smoke tests
```

The launchers also run standalone:
```bash
bash em.sh file.txt
zsh em.zsh file.txt
```

`tests/bake-off.sh` refreshes local Bash/zsh caches before timing the current
editor. `tests/bench_render.sh` is intentionally historical/synthetic and must
not be cited as a current `em_render` benchmark.

## Common Modification Patterns

**Adding a new keybinding**: Add a case to `em-dispatch`, `em-cx-dispatch`,
`em-cx-r-dispatch`, `em-ch-dispatch`, or `em-esc-dispatch`, as appropriate.
Write the handler as a new `em-*` function.
Remember to push undo records for any buffer mutations.

**Adding an M-x command**: Add a branch to the `mx-command` callback in
`em-minibuffer-handle-key` and add its name to `em-mx-commands`.

**Adding a new undo type**: Add a case to `em-undo` and call `em-undo-push`
with the new type from the mutation function. `replace-region` is the most
general existing type.

**Modifying buffer state**: Push an undo record *before* mutating `em-lines`.
Set `em-modified` to integer `1` (the compiled representation relies on 0/1).
Call `em-ensure-visible` if the cursor moved. Reset `em-goal-col` to -1 if
horizontal position changed. If the changed function has a handwritten
replacement, update `em.aot-runtime.sh` and its tests in this repository.

## Gotchas

- Lines are 0-indexed internally; line numbers displayed to the user are 1-indexed.
- `em-lines` always has at least one element (empty string for empty buffer).
- The undo stack retains the 200 most recent entries.
- The kill ring caps at 60 entries.
- Tab characters are expanded for *display* only — stored as literal `\t`.
- The sheme cache files (`em.scm.cache`, `em.scm.zsh.cache`) are listed in
  `.gitignore` and should not be committed.
- If either editor behaves strangely after changing sheme, `em.scm`, or the
  runtime, delete that target's cache. Both launchers regenerate it safely.
- Modified non-scratch buffers prompt before being killed. Only the exact
  confirmation `yes` forces the kill; any other response preserves the buffer.
- Integration tests set explicit source, runtime, interpreter, and cache paths
  so an installed file or stale developer cache cannot hide a regression.
- Launcher invariants verify checkout-over-installed source precedence and
  preserve `em_main` failures after terminal-trap cleanup.
- Runtime arrays use validated decimal length prefixes, not delimiter joining;
  edited text may legitimately contain ASCII record/unit separators.
