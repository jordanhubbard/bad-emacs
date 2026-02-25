SHELL := /bin/bash
PREFIX ?= $(HOME)/.local/bin
BASHRC ?= $(HOME)/.bashrc
SCRIPT := bademacs

.PHONY: install uninstall check

install:
	@mkdir -p "$(PREFIX)"
	@cp "$(SCRIPT)" "$(PREFIX)/$(SCRIPT)"
	@chmod +x "$(PREFIX)/$(SCRIPT)"
	@if ! grep -q 'source.*bademacs' "$(BASHRC)" 2>/dev/null; then \
		echo '' >> "$(BASHRC)"; \
		echo '# bademacs - shell-based emacs clone' >> "$(BASHRC)"; \
		echo 'source "$(PREFIX)/$(SCRIPT)"' >> "$(BASHRC)"; \
		echo "Added source line to $(BASHRC)"; \
	else \
		echo "$(BASHRC) already sources bademacs"; \
	fi
	@echo "Installed. Open a new shell or: source $(BASHRC)"

uninstall:
	@rm -f "$(PREFIX)/$(SCRIPT)"
	@if [ -f "$(BASHRC)" ]; then \
		sed -i '/# bademacs/d; /source.*bademacs/d' "$(BASHRC)"; \
		echo "Removed from $(BASHRC)"; \
	fi
	@echo "Uninstalled."

check:
	@bash -n "$(SCRIPT)" && echo "Syntax OK"
