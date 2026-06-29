# Changelog

All notable changes to shemacs are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Changed
- move shemacs-specific buffer and undo lowering out of sheme and into the
  portable, injected `em.aot-runtime.sh`
- make cache compilation isolated, syntax-checked, atomic, and sensitive to
  source, runtime, and compiler freshness
- run the same clean-cache integration workflows for Bash and zsh on Ubuntu
  and macOS
- make release retries idempotent and run tests before changelog mutation

### Fixed
- make the zsh launcher rebuild its cache through a child Bash, resolve its own
  source directory correctly, and load `bs.zsh` for runtime evaluation
- prefer checkout-adjacent editor sources over stale installed copies and
  propagate editor failures after restoring launcher traps
- preserve whitespace in compiled editor output and support dynamic string
  offsets in generated zsh
- preserve arbitrary non-NUL editor text in serialized undo, kill-ring, and
  buffer state by using validated length-prefixed records
- prompt before killing modified buffers and preserve them unless the user
  answers exactly `yes`
- replace stale CI references and test readiness patterns that could report
  false positives
- exercise the `eval-buffer` interpreter bridge under both generated targets

## [1.1.1] - 2026-04-13

### Changed
- Retire native bash (`em.sh`) and zsh (`em.zsh`) implementations; sheme is now a mandatory dependency
- `em.sh` and `em.zsh` are now the Scheme AOT launchers (previously `em.scm.sh` / `em.scm.zsh`)
- `em-scm()` function renamed to `em()` in zsh launcher; include guards updated
- Tests and Makefile updated to reflect single Scheme implementation

### Fixed
- use space-free patterns in expect tests

## [1.1.0] - 2026-04-12

### Added
- add include guards to prevent redundant re-sourcing
- add zsh sheme backend + render optimisation + bake-off harness

### Fixed
- add $ prefix to $last in KSH_ARRAYS slice expression

### Other
- perf: inline expand_tabs and pre-compute padding strings in render loop
- perf: fix benchmark script issues from code review


## [1.0.8] - 2026-03-05

### Added
- use compiled cache for native bash speed at runtime

### Fixed
- make install/uninstall idempotent with safe portable sourcing
- make install now copies all sources including Scheme and sheme
- default to shell install with explicit Scheme opt-in


## [1.0.7] - 2026-03-02

### Fixed
- show progress while Scheme cache builds
- make release changelog insertion awk-safe

### Other
- perf: pre-compile and cache Scheme interpreter state for fast startup


## [1.0.6] - 2026-03-01


## [1.0.5] - 2026-03-01


## [1.0.4] - 2026-03-01


## [1.0.3] - 2026-03-01

### Fixed
- increase Scheme editor test timeouts for CI
- raise Scheme test timeouts for slow CI keystroke processing


## [1.0.2] - 2026-03-01

### Fixed
- split stty to isolate macOS-only dsusp option


## [1.0.1] - 2026-03-01

### Fixed
- correct bash regex patterns in changelog categorizer
- correct ((PASS++)) arithmetic under set -e, skip expect when absent
- make release changelog insertion awk-safe

### Other
- Rename bad-emacs → shemacs
- Address issue #2 feedback: dsusp, rect r/d, minibuffer display, help trim
- Move Scheme editor into shemacs; add em.scm.sh launcher
- Bring em.scm to feature parity with em.sh; update docs for 3 implementations

## [1.0.0] - 2026-02-28

### Added
- Emacs-like editor (`em`) as a sourceable shell function for bash and zsh
- Multiple buffer support, undo history, and keyboard macros
- Isearch with highlight, tab completion, clipboard integration, and rectangle
  operations
- Zsh-native implementation (`em.zsh`) with full keybinding parity
- Scheme backend (`em.scm`) powered by sheme for extended scripting
- Horizontal scrolling, standalone mode, and stdin pipe support
- Mark-preserving indent and bash 4+/5+ version guard
- CI/CD pipeline with GitHub Actions (Ubuntu and macOS matrix)
- Integration test suite using `expect` (bash and zsh)
- `make release` target for automated versioning and GitHub releases

### Fixed
- Terminal handling, Enter key, and file I/O robustness
- C-x C-c terminal corruption on exit
- C-v pagination and lnext-character interception
- ESC as Meta prefix and terminal cleanup on exit
- Return key, minibuffer input, and rendering corruption
- Ctrl-C handling on macOS (undefine intr/quit/susp)
- Large file performance (#5)
- Printf status-line rendering artifact in CI
