SHELL      := /bin/bash
SRCDIR     := $(abspath .)
BUMP       ?= patch

.DEFAULT_GOAL := help

.PHONY: install install-scm uninstall uninstall-scm check test release help

help: ## Show available make targets
	@awk 'BEGIN {FS = ":.*##"}; /^[a-zA-Z_-]+:.*##/ { printf "  %-20s %s\n", $$1, $$2 }' \
	  $(MAKEFILE_LIST)

install: ## Install em.sh and em.zsh to home directory
	@echo "Installing shemacs to home directory..."
	@cp "$(SRCDIR)/em.sh" "$(HOME)/.em.sh"
	@cp "$(SRCDIR)/em.zsh" "$(HOME)/.em.zsh"
	@echo "Installed ~/.em.sh and ~/.em.zsh"
	@if ! grep -q '# shemacs install marker' "$(HOME)/.bashrc" 2>/dev/null; then \
		if ! grep -q '# sheme install marker' "$(HOME)/.bashrc" 2>/dev/null; then \
			echo "WARNING: sheme is not installed in ~/.bashrc. Install sheme first for full functionality."; \
		fi; \
		echo '' >> "$(HOME)/.bashrc"; \
		echo '# shemacs install marker' >> "$(HOME)/.bashrc"; \
		echo '[[ -f "$$HOME/.em.sh" ]] && source "$$HOME/.em.sh"' >> "$(HOME)/.bashrc"; \
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

install-scm: install ## Install Scheme-powered em (requires sheme)
	@echo ""
	@echo "Installing Scheme-powered em (requires sheme: https://github.com/jordanhubbard/sheme)..."
	@cp "$(SRCDIR)/em.scm.sh" "$(HOME)/.em.scm.sh"
	@cp "$(SRCDIR)/em.scm" "$(HOME)/.em.scm"
	@rm -f "$(HOME)/.em.scm.cache"
	@echo "Installed ~/.em.scm.sh and ~/.em.scm"
	@if ! grep -q '# shemacs-scm install marker' "$(HOME)/.bashrc" 2>/dev/null; then \
		if ! grep -q '# sheme install marker' "$(HOME)/.bashrc" 2>/dev/null; then \
			echo "WARNING: sheme is not installed in ~/.bashrc. sheme is required for the Scheme backend."; \
		fi; \
		echo '' >> "$(HOME)/.bashrc"; \
		echo '# shemacs-scm install marker' >> "$(HOME)/.bashrc"; \
		echo '[[ -f "$$HOME/.em.scm.sh" ]] && source "$$HOME/.em.scm.sh"' >> "$(HOME)/.bashrc"; \
		echo "Added source line to ~/.bashrc"; \
	else \
		echo "~/.bashrc already has shemacs-scm installed"; \
	fi
	@echo "Source ~/.em.scm.sh (instead of ~/.em.sh) to use the Scheme backend."

uninstall: ## Remove shemacs from home directory
	@rm -f "$(HOME)/.em.sh" "$(HOME)/.em.zsh"
	@[ -f "$(HOME)/.bashrc" ] && sed -i '' '/# shemacs install marker/d; /# em - bad emacs/d; /# em - shemacs/d; /source.*\.em\.sh/d; /sourceif.*\.em\.sh/d; /\[.*\.em\.sh.*\] && source/d' "$(HOME)/.bashrc" 2>/dev/null || \
		sed -i '/# shemacs install marker/d; /# em - bad emacs/d; /# em - shemacs/d; /source.*\.em\.sh/d; /sourceif.*\.em\.sh/d; /\[.*\.em\.sh.*\] && source/d' "$(HOME)/.bashrc" 2>/dev/null || true
	@[ -f "$(HOME)/.zshrc" ] && sed -i '' '/# shemacs install marker/d; /# em - bad emacs/d; /# em - shemacs/d; /source.*\.em\.zsh/d; /sourceif.*\.em\.zsh/d; /\[.*\.em\.zsh.*\] && source/d' "$(HOME)/.zshrc" 2>/dev/null || \
		sed -i '/# shemacs install marker/d; /# em - bad emacs/d; /# em - shemacs/d; /source.*\.em\.zsh/d; /sourceif.*\.em\.zsh/d; /\[.*\.em\.zsh.*\] && source/d' "$(HOME)/.zshrc" 2>/dev/null || true
	@echo "Uninstalled shemacs."

uninstall-scm: ## Remove Scheme-powered em from home directory
	@rm -f "$(HOME)/.em.scm.sh" "$(HOME)/.em.scm" "$(HOME)/.em.scm.cache"
	@[ -f "$(HOME)/.bashrc" ] && sed -i '' '/# shemacs-scm install marker/d; /# em - shemacs Scheme/d; /source.*\.em\.scm\.sh/d; /sourceif.*\.em\.scm\.sh/d; /\[.*\.em\.scm\.sh.*\] && source/d' "$(HOME)/.bashrc" 2>/dev/null || \
		sed -i '/# shemacs-scm install marker/d; /# em - shemacs Scheme/d; /source.*\.em\.scm\.sh/d; /sourceif.*\.em\.scm\.sh/d; /\[.*\.em\.scm\.sh.*\] && source/d' "$(HOME)/.bashrc" 2>/dev/null || true
	@echo "Uninstalled Scheme-backed em."

check: ## Validate shell syntax without running tests
	@echo "Checking bash version..."
	@bash -n em.sh && echo "  em.sh:      Syntax OK"
	@echo "Checking zsh version..."
	@zsh -n em.zsh && echo "  em.zsh:     Syntax OK"
	@echo "Checking Scheme launcher..."
	@bash -n em.scm.sh && echo "  em.scm.sh:  Syntax OK"

test: check ## Run full integration test suite (requires expect)
	@./tests/run_tests.sh

release: ## Create a release: make release BUMP=patch|minor|major
	@bash scripts/release.sh $(BUMP)
