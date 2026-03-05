SHELL      := /bin/bash
SRCDIR     := $(abspath .)
SHEME_DIR  := $(wildcard $(SRCDIR)/../sheme)
BUMP       ?= patch

.DEFAULT_GOAL := help

.PHONY: install install-scm uninstall uninstall-scm check test example release help

help: ## Show available make targets
	@awk 'BEGIN {FS = ":.*##"}; /^[a-zA-Z_-]+:.*##/ { printf "  %-20s %s\n", $$1, $$2 }' \
	  $(MAKEFILE_LIST)

install: ## Install all shemacs (and sheme) sources to home directory
	@echo "Installing shemacs to home directory..."
	@cp "$(SRCDIR)/em.sh"     "$(HOME)/.em.sh"
	@cp "$(SRCDIR)/em.zsh"    "$(HOME)/.em.zsh"
	@cp "$(SRCDIR)/em.scm.sh" "$(HOME)/.em.scm.sh"
	@if ! cmp -s "$(SRCDIR)/em.scm" "$(HOME)/.em.scm" 2>/dev/null; then \
		cp "$(SRCDIR)/em.scm" "$(HOME)/.em.scm"; \
		echo "  Updated ~/.em.scm"; \
	fi
	@if [ -n "$(SHEME_DIR)" ] && [ -f "$(SHEME_DIR)/bs.sh" ]; then \
		if ! cmp -s "$(SHEME_DIR)/bs.sh" "$(HOME)/.bs.sh" 2>/dev/null; then \
			cp "$(SHEME_DIR)/bs.sh" "$(HOME)/.bs.sh"; \
			echo "  Updated ~/.bs.sh from sheme"; \
		fi; \
	elif [ ! -f "$(HOME)/.bs.sh" ]; then \
		echo "WARNING: sheme not found. Install from: https://github.com/jordanhubbard/sheme"; \
	fi
	@echo "Installed shemacs files."
	@if ! grep -q '# shemacs install marker' "$(HOME)/.bashrc" 2>/dev/null; then \
		if ! grep -q '# sheme install marker' "$(HOME)/.bashrc" 2>/dev/null; then \
			echo "WARNING: sheme is not installed in ~/.bashrc. Install sheme first for full functionality."; \
		fi; \
		echo '' >> "$(HOME)/.bashrc"; \
		echo '# shemacs install marker' >> "$(HOME)/.bashrc"; \
		echo '[[ -f "$$HOME/.em.scm.sh" ]] && source "$$HOME/.em.scm.sh"' >> "$(HOME)/.bashrc"; \
		echo "Added source line to ~/.bashrc"; \
	else \
		echo "~/.bashrc already has shemacs installed"; \
	fi
	@if ! grep -q '# shemacs install marker' "$(HOME)/.zshrc" 2>/dev/null; then \
		if ! grep -q '# sheme install marker' "$(HOME)/.zshrc" 2>/dev/null; then \
			echo "WARNING: sheme is not installed in ~/.zshrc. Install sheme first for full functionality."; \
		fi; \
		echo '' >> "$(HOME)/.zshrc"; \
		echo '# shemacs install marker' >> "$(HOME)/.zshrc"; \
		echo '[[ -f "$$HOME/.em.zsh" ]] && source "$$HOME/.em.zsh"' >> "$(HOME)/.zshrc"; \
		echo "Added source line to ~/.zshrc"; \
	else \
		echo "~/.zshrc already has shemacs installed"; \
	fi
	@echo "Installed. Open a new shell or source your rc file."

install-scm: install ## (Legacy alias for install)

uninstall: ## Remove shemacs from home directory
	@rm -f "$(HOME)/.em.sh" "$(HOME)/.em.zsh"
	@rm -f "$(HOME)/.em.scm.sh" "$(HOME)/.em.scm" "$(HOME)/.em.scm.cache"
	@[ -f "$(HOME)/.bashrc" ] && sed -i '' '/# shemacs install marker/d; /# shemacs-scm install marker/d; /# em - bad emacs/d; /# em - shemacs/d; /source.*\.em\.sh/d; /sourceif.*\.em\.sh/d; /\[.*\.em\.sh.*\] && source/d; /source.*\.em\.scm\.sh/d; /sourceif.*\.em\.scm\.sh/d; /\[.*\.em\.scm\.sh.*\] && source/d' "$(HOME)/.bashrc" 2>/dev/null || \
		sed -i '/# shemacs install marker/d; /# shemacs-scm install marker/d; /# em - bad emacs/d; /# em - shemacs/d; /source.*\.em\.sh/d; /sourceif.*\.em\.sh/d; /\[.*\.em\.sh.*\] && source/d; /source.*\.em\.scm\.sh/d; /sourceif.*\.em\.scm\.sh/d; /\[.*\.em\.scm\.sh.*\] && source/d' "$(HOME)/.bashrc" 2>/dev/null || true
	@[ -f "$(HOME)/.zshrc" ] && sed -i '' '/# shemacs install marker/d; /# shemacs-scm install marker/d; /# em - bad emacs/d; /# em - shemacs/d; /source.*\.em\.zsh/d; /sourceif.*\.em\.zsh/d; /\[.*\.em\.zsh.*\] && source/d' "$(HOME)/.zshrc" 2>/dev/null || \
		sed -i '/# shemacs install marker/d; /# shemacs-scm install marker/d; /# em - bad emacs/d; /# em - shemacs/d; /source.*\.em\.zsh/d; /sourceif.*\.em\.zsh/d; /\[.*\.em\.zsh.*\] && source/d' "$(HOME)/.zshrc" 2>/dev/null || true
	@echo "Uninstalled shemacs."

uninstall-scm: uninstall ## (Legacy alias for uninstall)

check: ## Validate shell syntax without running tests
	@echo "Checking bash version..."
	@bash -n em.sh && echo "  em.sh:      Syntax OK"
	@echo "Checking zsh version..."
	@zsh -n em.zsh && echo "  em.zsh:     Syntax OK"
	@echo "Checking Scheme launcher..."
	@bash -n em.scm.sh && echo "  em.scm.sh:  Syntax OK"

test: check ## Run full integration test suite (requires expect)
	@./tests/run_tests.sh

example: check ## Run bash and zsh editor smoke examples
	@if ! command -v expect >/dev/null 2>&1; then \
		echo "expect is required for make example"; \
		exit 1; \
	fi
	@echo ""
	@echo "── Bash smoke example (start and quit) ──"
	@expect tests/test_bash_start_quit.exp
	@echo ""
	@echo "── Zsh smoke example (start and quit) ──"
	@if command -v zsh >/dev/null 2>&1; then \
		expect tests/test_zsh_start_quit.exp; \
	else \
		echo "zsh is required for make example"; \
		exit 1; \
	fi
	@echo ""
	@echo "Done! Smoke examples passed."

release: ## Create a release: make release BUMP=patch|minor|major
	@bash scripts/release.sh $(BUMP)
