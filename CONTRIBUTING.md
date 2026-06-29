# Contributing to shemacs

## Filing Bugs

Open a GitHub issue. Include:
- Your shell and version (`bash --version` or `zsh --version`)
- OS and terminal emulator
- Which target (`em.sh`/Bash or `em.zsh`/zsh). Both are generated from
  `em.scm`; they are not separate editor implementations.
- The sheme commit or release used to generate the cache
- Steps to reproduce
- Expected vs actual behaviour

## Submitting Pull Requests

1. Fork the repo and create a feature branch from `main`.
2. Make your changes.
3. Before every push, run `make test` and `make example` once from the
   repository root.
4. If editor state, the compiler contract, or either launcher changed, make
   sure the test output includes a cold cache build for both targets.
5. Open a PR against `main` with a clear description of what changed and why.

### PR Checklist

- [ ] `make test` passes (clean-cache Bash and zsh AOT workflows)
- [ ] `make example` passes (Bash and zsh smoke tests)
- [ ] `make check` passes (syntax validation)
- [ ] No regressions in existing keybindings
- [ ] README updated if keybindings or install steps changed
- [ ] If `em.scm` was changed: both generated cache targets were checked

## Running Tests

```bash
make check          # syntax validation only (fast)
make test           # clean-cache Bash and zsh integration workflows
make example        # Bash and zsh start/quit smoke tests
```

Tests are driven by parameterized `expect` scripts under `tests/`. The
`test_scm_*` names are historical: Scheme is now the only editor source, and
each workflow runs once through `em.sh` and once through `em.zsh`. The runner
uses isolated caches and explicit dependency paths so tests cannot accidentally
reuse installed files. GitHub Actions runs the same gate on Ubuntu and macOS.

To run the Scheme editor tests locally, install sheme first:

```bash
git clone https://github.com/jordanhubbard/sheme.git ~/sheme
cd ~/sheme && make install    # installs ~/.bs.sh and ~/.bs.zsh
cd /path/to/shemacs
make test
```

## Commit Messages

Use [Conventional Commits](https://www.conventionalcommits.org/) — the release
script uses these to categorize changelog entries automatically:

```
feat: add M-d delete-word keybinding
fix: correct C-v scroll when buffer is shorter than screen
docs: update keybinding table in README
refactor: extract status-line construction from em-render
chore: update CI to use actions/checkout@v4
```

## Code Conventions

- **Bash launcher (`em.sh`)**: requires Bash 4.3+. It locates sources, validates
  or builds the Bash cache, installs safety traps, and calls `em_main`.
- **zsh launcher (`em.zsh`)**: requires zsh 5+. Keep its cache/trap/large-file
  behavior aligned with `em.sh`, but use native zsh syntax. Its cold-cache
  path discovers Bash 4+ (or honors `SHEMACS_BASH`) to host the compiler; test
  it from a working directory other than the repository.
- **Editor source (`em.scm`)**: the sole editor implementation. It uses sheme
  extensions in addition to the R5RS subset, so do not call it portable R5RS.
- **AOT runtime (`em.aot-runtime.sh`)**: portable Bash/zsh replacements for
  nested undo and buffer records. Keep its semantics aligned with `em.scm` and
  validate syntax in both shells. Application-specific replacements belong
  here, not in sheme's generic compiler.
- sheme's `bs.sh` owns the `--runtime` injection interface and both compiler
  targets. Changes to that contract must be coordinated across repositories.
- Generated functions and globals share the user's shell. Keep launcher names
  under `_em_` and generated editor names under `em_`.
- Terminal/file operations use standard utilities; the project is not limited
  to shell builtins at runtime.

## Release Process

Maintainers only:

```bash
make release           # patch bump (default)
make release BUMP=minor
make release BUMP=major
```

This runs the test and example gates before changing files, updates
`CHANGELOG.md`, tags, and creates a GitHub release. Retries recognize an
existing version heading or a tag already at `HEAD` so transient release
failures do not bump twice.
