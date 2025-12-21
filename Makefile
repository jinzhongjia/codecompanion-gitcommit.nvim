.PHONY: doc test test-file lint fmt deps

OS := $(shell uname -s 2>/dev/null || echo Windows_NT)

NVIM ?= nvim

deps:
	@mkdir -p deps
	@test -d deps/mini.nvim || git clone --depth 1 https://github.com/echasnovski/mini.nvim deps/mini.nvim

test: deps
	@$(NVIM) --headless -u tests/minimal_init.lua -c "lua MiniTest.run()"

test-file: deps
	@$(NVIM) --headless -u tests/minimal_init.lua -c "lua MiniTest.run_file('$(FILE)')"

lint:
	@stylua --check .

fmt:
	@stylua .

# Default output path for the downloaded doc
DOC_OUT := codecompanion.txt

# Windows (PowerShell 7) target
ifeq ($(OS),Windows_NT)
# Prefer pwsh if available, fallback to powershell
POWERSHELL := $(if $(shell where pwsh 2> NUL),pwsh,powershell)

doc:
	$(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/download_codecompanion.ps1 -OutFile $(DOC_OUT)

else
# Non-Windows target uses curl or wget
CURL := $(shell command -v curl 2>/dev/null)
WGET := $(shell command -v wget 2>/dev/null)
URL := https://github.com/olimorris/codecompanion.nvim/raw/refs/heads/main/doc/codecompanion.txt

doc:
ifeq ($(CURL),)
ifeq ($(WGET),)
	@echo "Error: need curl or wget to download on non-Windows" && exit 1
else
	@$(WGET) -O $(DOC_OUT) $(URL)
endif
else
	@$(CURL) -fsSL -o $(DOC_OUT) $(URL)
endif
endif
