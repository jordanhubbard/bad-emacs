# bademacs

A micro GNU Emacs (mg) compatible text editor implemented as a single bash
shell function. No compiled languages, no dependencies beyond a standard
Linux install -- just bash and `/usr/bin`.

## Install

Add one line to your `~/.bashrc`:

```bash
source /path/to/bademacs
```

Or use the Makefile:

```bash
make install   # appends source line to ~/.bashrc
```

Then open a new shell (or `source ~/.bashrc`) and run:

```bash
bademacs myfile.txt
```

It also works as a standalone script: `./bademacs myfile.txt`

## Keybindings

### File Operations
| Key       | Action                    |
|-----------|---------------------------|
| C-x C-s   | Save buffer              |
| C-x C-c   | Quit (prompts to save)   |
| C-x C-f   | Find (open) file         |
| C-x C-w   | Write file (save as)     |
| C-x i     | Insert file at point     |
| C-x k     | Kill (clear) buffer      |

### Movement
| Key            | Action              |
|----------------|----------------------|
| C-f / Right    | Forward char         |
| C-b / Left     | Backward char        |
| C-n / Down     | Next line            |
| C-p / Up       | Previous line        |
| C-a / Home     | Beginning of line    |
| C-e / End      | End of line          |
| M-f / Ctrl-Right | Forward word      |
| M-b / Ctrl-Left  | Backward word     |
| C-v / PgDn     | Page down            |
| M-v / PgUp     | Page up              |
| M-<            | Beginning of buffer  |
| M->            | End of buffer        |
| C-l            | Recenter display     |
| M-g / C-x g    | Goto line           |

### Editing
| Key       | Action                    |
|-----------|---------------------------|
| C-d / Del  | Delete char forward      |
| Backspace  | Delete char backward     |
| C-k        | Kill to end of line      |
| C-y        | Yank (paste)             |
| C-w        | Kill region              |
| M-w        | Copy region              |
| C-SPC      | Set mark                 |
| C-x C-x    | Exchange point and mark  |
| C-x h      | Mark whole buffer        |
| C-t        | Transpose characters     |
| C-o        | Open line                |
| M-d        | Kill word forward        |
| M-DEL      | Kill word backward       |
| M-u        | Uppercase word           |
| M-l        | Lowercase word           |
| M-c        | Capitalize word          |

### Search & Replace
| Key       | Action                    |
|-----------|---------------------------|
| C-s       | Incremental search fwd    |
| C-r       | Incremental search bwd    |
| M-%       | Query replace             |

### Other
| Key       | Action                    |
|-----------|---------------------------|
| C-g       | Cancel / keyboard quit    |
| C-z       | Suspend editor            |
| C-x =     | Show cursor position info |
| M-x       | Execute extended command  |

### Extended Commands (M-x)

`goto-line`, `query-replace`, `what-cursor-position`, `save-buffer`,
`find-file`, `write-file`, `insert-file`, `kill-buffer`,
`save-buffers-kill-emacs`

## Why?

Because every Linux box has bash, and sometimes you just need a quick
editor that feels like emacs without installing anything.
