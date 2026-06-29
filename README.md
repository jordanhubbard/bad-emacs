# shemacs (`em`)

shemacs is an Emacs/mg-inspired terminal editor invoked as an `em` shell
function. The editor logic is written once in Scheme (`em.scm`) and
AOT-compiled to native Bash or zsh functions by
[sheme](https://github.com/jordanhubbard/sheme).

Features include multiple buffers, undo, a 60-entry kill ring, incremental
search, query replace, keyboard macros, region highlighting, fill paragraph,
rectangles, system-clipboard integration, indentation, and universal argument.

The generated cache defines the editor's helper functions and state in the
current shell; `em()` is the user-facing entry point. Standard terminal/file
operations still invoke utilities such as `stty`, `tput`, `cat`, `mv`, and
`stat`. sheme's interpreter is also loaded to provide `eval-string`, but the
editor source itself is not interpreted after compilation.

## Shell support

The Scheme source is shell-neutral and both generated targets are supported:

| Path | Current status |
|---|---|
| `em.sh` → Bash cache | Supported. Cold-cache compilation and interactive editor workflows are exercised by `make test`. |
| `em.zsh` → zsh cache | Supported. The launcher invokes the compiler through a child Bash, then loads native zsh output and the zsh interpreter extensions. The same workflows run under zsh. |
| `em.scm` | The sole editor-logic source for both targets. It is not a third runtime implementation. |
| `em.aot-runtime.sh` | Portable Bash/zsh runtime for nested buffer and undo state that the generic compiler cannot flatten. |

Both launchers can rebuild a missing or stale cache, preserve spaces in editor
output, edit and save files, search, change case, confirm modified-buffer
kills, and invalidate/rebuild the cache. Those paths are exercised from an
isolated clean cache under both shells.

## Requirements

- Bash 4.3+ to host sheme's AOT compiler (`bs.sh`), including when the editor
  itself runs under zsh
- zsh 5+ to run zsh-targeted output
- Standard terminal and file utilities (`stty`, `tput`, `cat`, `mktemp`,
  `chmod`, `mv`, `rm`, and `stat`)
- `expect` only for the integration tests

## Install

```bash
git clone https://github.com/jordanhubbard/shemacs.git ~/em
cd ~/em
make install
```

`make install` automatically copies a sibling sheme checkout or fetches sheme
if the complete `~/.bs.sh` / `~/.bs.zsh` pair is absent. `bs.sh` hosts both AOT
compiler targets; each launcher loads its native interpreter afterward for
runtime evaluation. The target then copies `em.sh`, `em.zsh`, `em.scm`, and
`em.aot-runtime.sh` to your home directory and adds source lines to both
`~/.bashrc` and `~/.zshrc`.

On macOS, `em.zsh` searches `PATH` and the usual Homebrew locations for a
modern Bash instead of assuming `/bin/bash` is new enough. Set `SHEMACS_BASH`
to an explicit Bash 4.3+ executable when it is installed elsewhere.

Reload your shell and `em` is available:

```bash
source ~/.bashrc       # or open a new terminal
em myfile.txt          # edit a file
em                     # open a *scratch* buffer
```

For zsh, source `~/.zshrc` instead.

### Makefile targets

```bash
make install           # install shemacs (auto-installs sheme if needed)
make install-sheme     # install both sheme interpreter files
make uninstall         # remove copied files and source lines
make check             # syntax-check both launchers and portable runtime
make test              # run clean-cache Bash and zsh editor workflows
make example           # run Bash and zsh start/quit smoke tests
```

### Standalone (no sourcing)

The launcher also works as a plain executable:

```bash
chmod +x em.sh
./em.sh myfile.txt

zsh ./em.zsh myfile.txt
```

### First-run compile

On first run, each launcher compiles `em.scm` to a native shell cache
(`em.scm.cache` for Bash, `em.scm.zsh.cache` for zsh). `bs.sh` is always run by
Bash as the compiler host; `em.zsh` asks that child process to emit zsh.
Subsequent runs source the cache directly.

The cache is rebuilt when `em.scm`, `em.aot-runtime.sh`, or the selected
compiler is newer. To force a rebuild manually:

```bash
rm -f ~/.em.scm.cache ~/.em.scm.zsh.cache
```

## Contributor Pre-Push Checks

Run these once from the repository root:

```bash
make test
make example
```

This syntax-checks both launchers and the portable runtime, then runs the same
start, open, save, edit, search, modified-buffer, and cache workflows against
fresh Bash and zsh caches, including the compiled-to-interpreter `eval-buffer`
bridge. It also checks runtime serialization and launcher precedence/error
propagation. GitHub Actions runs the gate on Ubuntu and macOS.

For performance work, `bash tests/bake-off.sh --quick` rebuilds both local AOT
caches when their source, runtime, or compiler is newer, then compares startup,
self-insert, and render costs; `mg` is an optional reference. The separate
`tests/bench_render.sh` is a historical synthetic renderer comparison and does
not exercise the current editor cache.

## Keybindings

### File Operations
| Key       | Action                    |
|-----------|---------------------------|
| C-x C-s   | Save buffer              |
| C-x C-c   | Quit (confirm unsaved buffers) |
| C-x C-f   | Find (open) file         |
| C-x C-w   | Write file (save as)     |
| C-x i     | Insert file at point     |

### Buffers
| Key       | Action                    |
|-----------|---------------------------|
| C-x b     | Switch buffer            |
| C-x k     | Kill buffer (confirm if modified) |
| C-x C-b   | List buffers             |

### Movement
| Key            | Action              |
|----------------|----------------------|
| C-f / Right    | Forward char         |
| C-b / Left     | Backward char        |
| C-n / Down     | Next line            |
| C-p / Up       | Previous line        |
| C-a / Home     | Beginning of line    |
| C-e / End      | End of line          |
| M-f            | Forward word         |
| M-b            | Backward word        |
| C-v / PgDn     | Page down            |
| M-v / PgUp     | Page up              |
| M-<            | Beginning of buffer  |
| M->            | End of buffer        |
| C-l            | Recenter display     |

### Editing
| Key        | Action                    |
|------------|---------------------------|
| C-d / Del  | Delete char forward       |
| Backspace  | Delete char backward      |
| C-k        | Kill to end of line       |
| C-y        | Yank (paste)              |
| C-w        | Kill region               |
| M-w        | Copy region               |
| C-SPC / M-SPC | Set mark               |
| C-x C-x    | Exchange point and mark   |
| C-x h      | Mark whole buffer         |
| C-t        | Transpose characters      |
| C-o        | Open line                 |
| M-d        | Kill word forward         |
| M-DEL      | Kill word backward        |
| M-u        | Uppercase word            |
| M-l        | Lowercase word            |
| M-c        | Capitalize word           |
| C-i / Tab  | Indent line/region by two spaces |
| Shift-Tab  | Dedent line/region by two spaces |

### Undo
| Key           | Action                 |
|---------------|------------------------|
| C-x u / C-_   | Undo last change      |

### Search & Replace
| Key       | Action                    |
|-----------|---------------------------|
| C-s       | Incremental search fwd    |
| C-r       | Incremental search bwd    |
| M-%       | Query replace             |

### Keyboard Macros
| Key       | Action                    |
|-----------|---------------------------|
| C-x (     | Start recording macro    |
| C-x )     | Stop recording macro     |
| C-x e     | Execute last macro       |

### Rectangles

| Key       | Action                    |
|-----------|---------------------------|
| C-x r k   | Kill rectangle            |
| C-x r y   | Yank rectangle            |
| C-x r r   | Copy rectangle            |
| C-x r d   | Delete rectangle          |
| C-x r t   | Replace rectangle with a string |
| C-x r o   | Open rectangle            |

### Other
| Key       | Action                    |
|-----------|---------------------------|
| C-u N     | Universal argument (repeat N times) |
| C-q       | Quoted insert (literal control char) |
| M-q       | Fill paragraph            |
| C-z       | Suspend editor            |
| C-g       | Cancel / keyboard quit    |
| C-x =     | Show cursor position info |
| C-h b     | Describe keybindings     |
| M-x       | Execute extended command  |

### Extended Commands (M-x)

`goto-line`, `what-line`, `query-replace`, `what-cursor-position`,
`save-buffer`, `find-file`, `write-file`, `insert-file`, `kill-buffer`,
`switch-to-buffer`, `list-buffers`, `set-fill-column`,
`describe-bindings`, `help`, `save-buffers-kill-emacs`, `clipboard-yank`,
`eval-buffer`

## Why?

Because sometimes you just need a quick editor that feels like Emacs
without installing Emacs. shemacs is about 2300 lines of Scheme, depends on
sheme plus ordinary terminal/file utilities, and
once compiled it runs as shell functions without spawning a separate editor
process.

## The Totally True and Not At All Embellished History of shemacs

### The continuing adventures of Jordan Hubbard and Sir Reginald von Fluffington III

> *A note on provenance: This section exists as the author's official memory marker for projects that have been substantially co-developed with an AI assistant.  The author will not remember which projects these are in ten years.  He will also not remember this note.  He will, however, be able to grep for it, and that is the point.  All future AI-assisted projects will include an equally implausible origin story as a breadcrumb.  The convention is simple: if a project has one of these sections, an AI was meaningfully involved.  If it doesn't, the author did it alone, and it will show.*
>
> *Part 1 of an ongoing chronicle.  [Part 2: sheme →](https://github.com/jordanhubbard/sheme#the-totally-true-and-not-at-all-embellished-history-of-sheme)*
> *Sir Reginald von Fluffington III appears throughout.  He does not endorse any of it.*

It began, as so many catastrophic ideas do, with a small act of stubbornness.

The programmer had been using a server — a perfectly nice server, by server standards — that had no text editor installed beyond `vi`.  The programmer would like to be clear that this is not a moral failing on the server's part.  The server did not choose to be born editorless.  Nevertheless, the programmer typed `:q!` for the forty-seventh time, missed, and found himself staring at the bottom of a shell prompt with a half-edited configuration file and a deep, smoldering grievance.

"I could install nano," he said.

Sir Reginald von Fluffington III, who had accompanied the programmer on what the programmer had described as "a quick server-room visit" and Sir Reginald had accurately described as "inexplicable," looked up from the keyboard cable he had been attempting to eat.  He blinked once.

"I could also," the programmer continued, "write my own editor.  In bash.  It would start instantly, require no installation, and would travel with me wherever my `.bashrc` goes."  He paused.  "Like a friend.  But reliable."

Sir Reginald returned to the cable.

This was the moment.  This was the seed.  Historians, had they been present, would have quietly left the room.

What followed was six weeks that the programmer later referred to as "rapid prototyping" and his colleagues referred to as "that thing you did instead of reviewing my PR."  A terminal went raw.  Escape sequences were learned, forgotten, relearned, and in one memorable case, accidentally sent to a production server.  The kill ring emerged on a Tuesday, motivated by the discovery that bash arrays could hold arbitrary strings, and grew to sixty entries by Wednesday for reasons that remain unclear to this day.

"It's just a function," the programmer explained to no one in particular.  "A shell function.  Sourced into the shell.  Zero latency.  Like... like Emacs, but if Emacs were a perfectly reasonable person who doesn't require three separate config files to open a file."

Sir Reginald knocked a mug off the desk.  He had been building up to this for some time.

By the time the function grew past a thousand lines, it had undo.  By fifteen hundred, it had incremental search — real incremental search, with highlighting, which required the programmer to learn approximately fourteen ANSI escape codes he hadn't needed since 1993 and one he's still not entirely sure is valid.  By two thousand lines, it had multiple buffers, because of course it did.

"Keyboard macros?" said the programmer, at two thousand and three hundred lines, to Sir Reginald, who had retreated to the top of the monitor to judge from elevation.  "Obviously keyboard macros.  What is an Emacs-compatible editor without keyboard macros?  I ask you, Reggie.  I ask you rhetorically."

Sir Reginald declined to engage.  He had declined to engage for six weeks.

The finished function — approximately 2,451 lines of pure bash that functioned as a full-featured terminal text editor with multiple buffers, a kill ring, undo, incremental search, query-replace, keyboard macros, region highlighting, fill-paragraph, and universal argument — was named `em`, because `emacs` was already taken and `shemacs` was what it became when the programmer realized it needed a repository name and all the good ones were gone.

"It's elegant," the programmer told Sir Reginald, who was at this point sitting directly on top of the laptop that contained the file that contained the main rendering function.  "It sources into your shell in milliseconds.  It has no external dependencies.  It is, in a very real sense, the purest possible text editor."

Sir Reginald yawned.  He had six teeth and used all of them.

"I should port it to zsh," the programmer said.  "For the other people."

He did.  It worked.  He was unreasonably surprised.

Then, one dark and stormy evening, the programmer sat hunched over the 2,451-line mass of tangled bash functions that shemacs had become, and he had a thought.  Not about shemacs, exactly.  About something worse.

"What if I wrote a Scheme interpreter," he whispered, "in bash?"

Sir Reginald left the room.  He had seen this look before.  He didn't like where it went.

The rest of that story is documented in the [sheme repository](https://github.com/jordanhubbard/sheme), where Sir Reginald continues to withhold his endorsement, and the programmer continues to be unreasonably proud of things that arguably should not exist.
