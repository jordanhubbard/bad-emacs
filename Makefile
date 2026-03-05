SHELL      := /bin/bash
SRCDIR     := $(abspath .)
SHEME_DIR  := $(wildcard $(SRCDIR)/../sheme)
BUMP       ?= patch

.DEFAULT_GOAL := help

.PHONY: install install-scm uninstall uninstall-scm check test example release help

help: ## Show available make targets
	@awk 'BEGIN {FS = ":.*##"}; /^[a-zA-Z_-]+:.*##/ { printf "  %-20s %s\n", $$1, $$2 }' \
	  $(MAKEFILE_LIST)

install: ## Install shell versions (bash + zsh) to home directory
	@echo "Installing shemacs shell versions to home directory..."
	@cp "$(SRCDIR)/em.sh"  "$(HOME)/.em.sh"
	@cp "$(SRCDIR)/em.zsh" "$(HOME)/.em.zsh"
	@[ -f "$(HOME)/.bashrc" ] && sed -i '' '/# shemacs-scm install marker/d; /source.*\.em\.scm\.sh/d; /sourceif.*\.em\.scm\.sh/d; /\[.*\.em\.scm\.sh.*\] && source/d' "$(HOME)/.bashrc" 2>/dev/null || \
		sed -i '/# shemacs-scm install marker/d; /source.*\.em\.scm\.sh/d; /sourceif.*\.em\.scm\.sh/d; /\[.*\.em\.scm\.sh.*\] && source/d' "$(HOME)/.bashrc" 2>/dev/null || true
	@echo "Installed ~/.em.sh and ~/.em.zsh"
	@if ! grep -q '\[.*\.em\.sh.*\] && source' "$(HOME)/.bashrc" 2>/dev/null; then \
		if ! grep -q '# shemacs install marker' "$(HOME)/.bashrc" 2>/dev/null; then \
			echo '' >> "$(HOME)/.bashrc"; \
			echo '# shemacs install marker' >> "$(HOME)/.bashrc"; \
		fi; \
		echo '[[ -f "$$HOME/.em.sh" ]] && source "$$HOME/.em.sh"' >> "$(HOME)/.bashrc"; \
		echo "Added source line to ~/.bashrc"; \
	else \
		echo "~/.bashrc already sources ~/.em.sh"; \
	fi
	@if ! grep -q '\[.*\.em\.zsh.*\] && source' "$(HOME)/.zshrc" 2>/dev/null; then \
		if ! grep -q '# shemacs install marker' "$(HOME)/.zshrc" 2>/dev/null; then \
			echo '' >> "$(HOME)/.zshrc"; \
			echo '# shemacs install marker' >> "$(HOME)/.zshrc"; \
		fi; \
		echo '[[ -f "$$HOME/.em.zsh" ]] && source "$$HOME/.em.zsh"' >> "$(HOME)/.zshrc"; \
		echo "Added source line to ~/.zshrc"; \
	else \
		echo "~/.zshrc already sources ~/.em.zsh"; \
	fi
	@echo "Installed shell versions. Open a new shell or source your rc file."

install-scm: install ## Install optional sheme-backed editor (bash, slower startup)
	@echo "Installing shemacs Scheme backend..."
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
	@if ! grep -q '\[.*\.em\.scm\.sh.*\] && source' "$(HOME)/.bashrc" 2>/dev/null; then \
		if ! grep -q '# shemacs-scm install marker' "$(HOME)/.bashrc" 2>/dev/null; then \
			echo '' >> "$(HOME)/.bashrc"; \
			echo '# shemacs-scm install marker' >> "$(HOME)/.bashrc"; \
		fi; \
		echo '[[ -f "$$HOME/.em.scm.sh" ]] && source "$$HOME/.em.scm.sh"' >> "$(HOME)/.bashrc"; \
		echo "Added Scheme source line to ~/.bashrc"; \
	else \
		echo "~/.bashrc already sources ~/.em.scm.sh"; \
	fi
	@echo "Installed Scheme backend. Reload ~/.bashrc to use Scheme em() in bash."

uninstall: ## Remove shemacs from home directory
	@rm -f "$(HOME)/.em.sh" "$(HOME)/.em.zsh"
	@rm -f "$(HOME)/.em.scm.sh" "$(HOME)/.em.scm" "$(HOME)/.em.scm.cache"
	@[ -f "$(HOME)/.bashrc" ] && sed -i '' '/# shemacs install marker/d; /# shemacs-scm install marker/d; /# em - bad emacs/d; /# em - shemacs/d; /source.*\.em\.sh/d; /sourceif.*\.em\.sh/d; /\[.*\.em\.sh.*\] && source/d; /source.*\.em\.scm\.sh/d; /sourceif.*\.em\.scm\.sh/d; /\[.*\.em\.scm\.sh.*\] && source/d' "$(HOME)/.bashrc" 2>/dev/null || \
		sed -i '/# shemacs install marker/d; /# shemacs-scm install marker/d; /# em - bad emacs/d; /# em - shemacs/d; /source.*\.em\.sh/d; /sourceif.*\.em\.sh/d; /\[.*\.em\.sh.*\] && source/d; /source.*\.em\.scm\.sh/d; /sourceif.*\.em\.scm\.sh/d; /\[.*\.em\.scm\.sh.*\] && source/d' "$(HOME)/.bashrc" 2>/dev/null || true
	@[ -f "$(HOME)/.zshrc" ] && sed -i '' '/# shemacs install marker/d; /# shemacs-scm install marker/d; /# em - bad emacs/d; /# em - shemacs/d; /source.*\.em\.zsh/d; /sourceif.*\.em\.zsh/d; /\[.*\.em\.zsh.*\] && source/d' "$(HOME)/.zshrc" 2>/dev/null || \
		sed -i '/# shemacs install marker/d; /# shemacs-scm install marker/d; /# em - bad emacs/d; /# em - shemacs/d; /source.*\.em\.zsh/d; /sourceif.*\.em\.zsh/d; /\[.*\.em\.zsh.*\] && source/d' "$(HOME)/.zshrc" 2>/dev/null || true
	@echo "Uninstalled shemacs."

uninstall-scm: ## Remove shemacs Scheme backend from home directory
	@rm -f "$(HOME)/.em.scm.sh" "$(HOME)/.em.scm" "$(HOME)/.em.scm.cache"
	@[ -f "$(HOME)/.bashrc" ] && sed -i '' '/# shemacs-scm install marker/d; /source.*\.em\.scm\.sh/d; /sourceif.*\.em\.scm\.sh/d; /\[.*\.em\.scm\.sh.*\] && source/d' "$(HOME)/.bashrc" 2>/dev/null || \
		sed -i '/# shemacs-scm install marker/d; /source.*\.em\.scm\.sh/d; /sourceif.*\.em\.scm\.sh/d; /\[.*\.em\.scm\.sh.*\] && source/d' "$(HOME)/.bashrc" 2>/dev/null || true
	@echo "Uninstalled shemacs Scheme backend."

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
