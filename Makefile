SHELL      := /bin/bash
SRCDIR     := $(abspath .)
SHEME_DIR  := $(wildcard $(SRCDIR)/../sheme)
SHEME_REPO := https://github.com/jordanhubbard/sheme.git
BUMP       ?= patch

.DEFAULT_GOAL := help

.PHONY: install install-sheme uninstall check test example release help

help: ## Show available make targets
	@awk 'BEGIN {FS = ":.*##"}; /^[a-zA-Z_-]+:.*##/ { printf "  %-20s %s\n", $$1, $$2 }' \
	  $(MAKEFILE_LIST)

# ── sheme bootstrap ──────────────────────────────────────────────────────────
#
# Installs ~/.bs.sh and ~/.bs.zsh from the first available source:
#   1. sibling sheme/ directory (dev layout)
#   2. already-installed ~/.bs.sh + ~/.bs.zsh pair (no-op)
#   3. git clone from GitHub into a temp dir, copy both files, remove temp dir
#
define INSTALL_SHEME
	@if [ -n "$(SHEME_DIR)" ] && [ -f "$(SHEME_DIR)/bs.sh" ] && [ -f "$(SHEME_DIR)/bs.zsh" ]; then \
		echo "  sheme: installing from sibling sheme/ directory..."; \
		cp "$(SHEME_DIR)/bs.sh" "$(HOME)/.bs.sh"; \
		cp "$(SHEME_DIR)/bs.zsh" "$(HOME)/.bs.zsh"; \
		echo "  sheme: installed ~/.bs.sh and ~/.bs.zsh"; \
	elif [ -f "$(HOME)/.bs.sh" ] && [ -f "$(HOME)/.bs.zsh" ]; then \
		echo "  sheme: ~/.bs.sh and ~/.bs.zsh already present — skipping"; \
	elif command -v git >/dev/null 2>&1; then \
		echo "  sheme: not found — cloning $(SHEME_REPO) ..."; \
		_sheme_tmp=$$(mktemp -d /tmp/sheme_XXXXXX); \
		git clone --quiet --depth 1 "$(SHEME_REPO)" "$$_sheme_tmp" \
		    || { echo "ERROR: git clone failed"; rm -rf "$$_sheme_tmp"; exit 1; }; \
		cp "$$_sheme_tmp/bs.sh" "$(HOME)/.bs.sh"; \
		cp "$$_sheme_tmp/bs.zsh" "$(HOME)/.bs.zsh"; \
		rm -rf "$$_sheme_tmp"; \
		echo "  sheme: installed ~/.bs.sh and ~/.bs.zsh"; \
	else \
		echo "ERROR: sheme is required but not installed, and git is not available."; \
		echo "  Install sheme manually: $(SHEME_REPO)"; \
		exit 1; \
	fi
endef

install-sheme: ## Install sheme interpreters/compiler to home directory
	@echo "Installing sheme..."
	$(INSTALL_SHEME)
	@echo "Done."

# ── shemacs install ───────────────────────────────────────────────────────────

install: ## Install shemacs (auto-installs sheme if needed)
	@echo "Installing shemacs..."
	$(INSTALL_SHEME)
	@cp "$(SRCDIR)/em.sh"  "$(HOME)/.em.sh"
	@cp "$(SRCDIR)/em.zsh" "$(HOME)/.em.zsh"
	@cp "$(SRCDIR)/em.aot-runtime.sh" "$(HOME)/.em.aot-runtime.sh"
	@if ! cmp -s "$(SRCDIR)/em.scm" "$(HOME)/.em.scm" 2>/dev/null; then \
		cp "$(SRCDIR)/em.scm" "$(HOME)/.em.scm"; \
		echo "  Updated ~/.em.scm"; \
	fi
	@echo "  Installed ~/.em.sh, ~/.em.zsh, ~/.em.scm, ~/.em.aot-runtime.sh"
	@if ! grep -q '\[.*\.em\.sh.*\] && source' "$(HOME)/.bashrc" 2>/dev/null; then \
		if ! grep -q '# shemacs install marker' "$(HOME)/.bashrc" 2>/dev/null; then \
			echo '' >> "$(HOME)/.bashrc"; \
			echo '# shemacs install marker' >> "$(HOME)/.bashrc"; \
		fi; \
		echo '[[ -f "$$HOME/.em.sh" ]] && source "$$HOME/.em.sh"' >> "$(HOME)/.bashrc"; \
		echo "  Added source line to ~/.bashrc"; \
	else \
		echo "  ~/.bashrc already sources ~/.em.sh"; \
	fi
	@if ! grep -q '\[.*\.em\.zsh.*\] && source' "$(HOME)/.zshrc" 2>/dev/null; then \
		if ! grep -q '# shemacs install marker' "$(HOME)/.zshrc" 2>/dev/null; then \
			echo '' >> "$(HOME)/.zshrc"; \
			echo '# shemacs install marker' >> "$(HOME)/.zshrc"; \
		fi; \
		echo '[[ -f "$$HOME/.em.zsh" ]] && source "$$HOME/.em.zsh"' >> "$(HOME)/.zshrc"; \
		echo "  Added source line to ~/.zshrc"; \
	else \
		echo "  ~/.zshrc already sources ~/.em.zsh"; \
	fi
	@echo "Done. Open a new shell or source your rc file to use em."

uninstall: ## Remove shemacs from home directory
	@rm -f "$(HOME)/.em.sh" "$(HOME)/.em.zsh" "$(HOME)/.em.scm" \
	       "$(HOME)/.em.aot-runtime.sh" "$(HOME)/.em.scm.cache" \
	       "$(HOME)/.em.scm.zsh.cache"
	@[ -f "$(HOME)/.bashrc" ] && sed -i '' \
		'/# shemacs install marker/d; /# shemacs-scm install marker/d; /# em - bad emacs/d; /# em - shemacs/d; /source.*\.em\.sh/d; /sourceif.*\.em\.sh/d; /\[.*\.em\.sh.*\] && source/d; /source.*\.em\.scm\.sh/d; /sourceif.*\.em\.scm\.sh/d; /\[.*\.em\.scm\.sh.*\] && source/d' \
		"$(HOME)/.bashrc" 2>/dev/null || \
		sed -i \
		'/# shemacs install marker/d; /# shemacs-scm install marker/d; /# em - bad emacs/d; /# em - shemacs/d; /source.*\.em\.sh/d; /sourceif.*\.em\.sh/d; /\[.*\.em\.sh.*\] && source/d; /source.*\.em\.scm\.sh/d; /sourceif.*\.em\.scm\.sh/d; /\[.*\.em\.scm\.sh.*\] && source/d' \
		"$(HOME)/.bashrc" 2>/dev/null || true
	@[ -f "$(HOME)/.zshrc" ] && sed -i '' \
		'/# shemacs install marker/d; /# shemacs-scm install marker/d; /# em - bad emacs/d; /# em - shemacs/d; /source.*\.em\.zsh/d; /sourceif.*\.em\.zsh/d; /\[.*\.em\.zsh.*\] && source/d; /source.*\.em\.scm\.zsh/d; /sourceif.*\.em\.scm\.zsh/d; /\[.*\.em\.scm\.zsh.*\] && source/d' \
		"$(HOME)/.zshrc" 2>/dev/null || \
		sed -i \
		'/# shemacs install marker/d; /# shemacs-scm install marker/d; /# em - bad emacs/d; /# em - shemacs/d; /source.*\.em\.zsh/d; /sourceif.*\.em\.zsh/d; /\[.*\.em\.zsh.*\] && source/d; /source.*\.em\.scm\.zsh/d; /sourceif.*\.em\.scm\.zsh/d; /\[.*\.em\.scm\.zsh.*\] && source/d' \
		"$(HOME)/.zshrc" 2>/dev/null || true
	@echo "Uninstalled shemacs."

check: ## Validate shell syntax without running tests
	@echo "Checking bash launcher..."
	@bash -n em.sh && echo "  em.sh:   Syntax OK"
	@echo "Checking zsh launcher..."
	@zsh -n em.zsh && echo "  em.zsh:  Syntax OK"
	@echo "Checking portable AOT runtime..."
	@bash -n em.aot-runtime.sh && zsh -n em.aot-runtime.sh && echo "  em.aot-runtime.sh: Syntax OK"

test: check ## Run Bash and zsh AOT integration workflows
	@./tests/run_tests.sh

example: check ## Run Bash and zsh AOT start/quit smoke examples
	@bash tests/run_examples.sh

release: ## Create a release: make release BUMP=patch|minor|major
	@bash scripts/release.sh $(BUMP)
