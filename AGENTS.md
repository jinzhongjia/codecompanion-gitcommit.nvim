# AGENTS.md - AI Agent Guidelines for codecompanion-gitcommit.nvim

> Guidelines for AI agents (Claude, GPT, Copilot, etc.) working with this codebase.

## Project Overview

**codecompanion-gitcommit.nvim** is a Neovim plugin extension for [CodeCompanion](https://github.com/olimorris/codecompanion.nvim) that provides:
- AI-powered Git commit message generation following Conventional Commits
- Comprehensive Git workflow tools (`@{git_read}`, `@{git_edit}`, `@{git_bot}`)
- AI-powered release notes generation
- Multi-language support for commit messages
- Smart buffer integration for gitcommit filetype

### Compatibility
- Requires CodeCompanion **v18.0+**
- Lua 5.1+ / LuaJIT
- Neovim 0.9+
- Multi-platform (Linux, macOS, WSL, Native Windows)

---

## Architecture

```
codecompanion-gitcommit.nvim/
├── lua/codecompanion/_extensions/gitcommit/
│   ├── init.lua           # Main entry point, extension setup, exports
│   ├── config.lua         # Default configuration options
│   ├── git.lua            # Core Git operations (diff, commit, repository detection)
│   ├── generator.lua      # LLM-based commit message generation
│   ├── buffer.lua         # Gitcommit buffer integration & auto-generation
│   ├── ui.lua             # Floating window UI for commit message display
│   ├── langs.lua          # Multi-language support for commit messages
│   ├── types.lua          # Type definitions (LuaLS annotations)
│   ├── prompts/
│   │   └── release_notes.lua  # Prompts for AI release notes generation
│   └── tools/
│       ├── git.lua            # GitTool class - low-level git operations
│       ├── git_read.lua       # Read-only git operations tool schema
│       ├── git_edit.lua       # Write-access git operations tool schema
│       ├── ai_release_notes.lua # AI-powered release notes tool
│       └── validation.lua     # Parameter validation utilities
├── doc/
│   └── codecompanion-gitcommit.txt  # Vim help documentation
├── scripts/
│   └── download_codecompanion.ps1   # Development script
└── .github/workflows/
    └── stylua-check.yml     # CI for code formatting
```

### Module Dependency Graph

```
init.lua (entry point)
    ├── config.lua
    ├── git.lua ──────────────────┐
    ├── generator.lua             │
    ├── buffer.lua ───────────────┼── git.lua (core)
    ├── ui.lua                    │
    ├── langs.lua                 │
    └── tools/                    │
        ├── git.lua ──────────────┘
        ├── git_read.lua ─────────┬── tools/git.lua
        ├── git_edit.lua ─────────┤
        ├── ai_release_notes.lua ─┴── prompts/release_notes.lua
        └── validation.lua
```

---

## Key Components

### 1. Extension Entry Point (`init.lua`)

The main module that:
- Sets up the extension with CodeCompanion
- Registers tools (`git_read`, `git_edit`, `ai_release_notes`) and tool groups (`git_bot`)
- Creates Vim commands (`:CodeCompanionGitCommit`, `:CCGitCommit`)
- Adds slash commands (`/gitcommit`)
- Exposes programmatic API via `exports`

**Chat Config Access:**
```lua
-- v18+ uses interactions
if codecompanion_config.interactions and codecompanion_config.interactions.chat then
  return codecompanion_config.interactions.chat
end
```

### 2. Git Core Module (`git.lua`)

Handles:
- Repository detection (`is_repository()`)
- Diff retrieval with file filtering (`get_staged_diff()`, `get_contextual_diff()`)
- Amend detection (`is_amending()`)
- Commit history retrieval (`get_commit_history()`)
- Glob pattern matching for file exclusion

**Important:** This module maintains its own `config` state set via `Git.setup()`.

### 3. Generator (`generator.lua`)

LLM integration for commit message generation:
- Supports both HTTP and ACP (Anthropic Claude Protocol) adapters
- Handles streaming responses
- Cleans markdown code blocks from LLM output
- Creates structured prompts with commit history context

### 4. Tools System (`tools/`)

CodeCompanion tool implementations following the tool schema pattern:

| Tool | File | Purpose |
|------|------|---------|
| `git_read` | `git_read.lua` | 16 read-only operations (status, log, diff, etc.) |
| `git_edit` | `git_edit.lua` | 20 write operations (stage, commit, push, etc.) |

| `ai_release_notes` | `ai_release_notes.lua` | AI-powered release notes from commit history |

**Tool Schema Structure:**
```lua
Tool.schema = {
  type = "function",
  ["function"] = {
    name = "tool_name",
    parameters = { ... },
    strict = true,  -- Enforce strict parameter validation
  },
}
Tool.system_prompt = [[...]]  -- LLM context
Tool.cmds = { function(self, args) ... end }  -- Execution
Tool.handlers = { setup, on_exit }
Tool.output = { prompt, success, error, rejected }
Tool.opts = { require_approval_before }  -- Tool options
```

### 5. Validation (`tools/validation.lua`)

Centralized parameter validation with consistent error formatting:
- `require_string()`, `optional_string()`
- `require_array()`, `optional_integer()`, `optional_boolean()`
- `require_enum()`, `first_error()`

---

## Coding Conventions

### Style
- **Formatter:** StyLua (config in `stylua.toml`)
- **Line width:** 120 characters
- **Indentation:** 2 spaces
- **Quotes:** Double quotes for strings

### Naming
- Modules: `PascalCase` for classes (`GitTool`, `Generator`)
- Functions: `snake_case` (`get_staged_diff`, `format_git_response`)
- Private functions: Prefix with `_` (`Git._filter_diff`, `Buffer._setup_gitcommit_keymap`)
- Constants: `UPPER_SNAKE_CASE` (`TOOL_NAME`, `VALID_OPERATIONS`)

### Type Annotations
Use LuaLS (lua-language-server) annotations:
```lua
---@class ClassName
---@field field_name type Description

---@param param_name type Description
---@return type description
function Module.function_name(param_name)
```

### Error Handling Pattern
```lua
local ok, result = pcall(function()
  -- risky operation
end)
if not ok then
  return false, "Error: " .. tostring(result)
end
return result
```

### Git Command Execution Pattern
```lua
local success, output = pcall(vim.fn.system, cmd)
if not success or vim.v.shell_error ~= 0 then
  return false, output or "Command failed"
end
return true, output
```

---

## Requirements

This extension requires CodeCompanion **v18.0+**. The codebase uses:
- `interactions.chat` for chat configuration
- `require_approval_before` for tool approval

**Tool Options Pattern:**
```lua
Tool.opts = {
  require_approval_before = function(_self, _tools) return true end,
}
```

---

## Adding New Features

### Adding a New Git Read Operation

1. Add operation to `VALID_OPERATIONS` in `git_read.lua`
2. Add to schema `enum` array
3. Add to `system_prompt` documentation table
4. Implement handler in `GitTool` (`tools/git.lua`)
5. Add case in `GitRead.cmds` function
6. Add to help text

### Adding a New Git Edit Operation

Same pattern as read operations, but in `git_edit.lua`. Remember:
- Edit operations require approval (`require_approval_before = true`)
- Add appropriate parameter validation
- Handle async operations if needed (see `push_async`)

### Adding a New Tool

1. Create `tools/new_tool.lua` following existing pattern
2. Register in `init.lua` → `setup_tools()`
3. Add schema, system_prompt, cmds, handlers, output, opts
4. Add to tool group if needed (`git_bot`)

---

## Testing & Development

### Available Mise Tasks
```bash
mise run deps       # Install test dependencies (mini.nvim)
mise run test       # Run all unit tests
mise run test:file file=tests/test_validation.lua  # Run specific test file
mise run lint       # Check code formatting with stylua
mise run fmt        # Format code with stylua
mise run doc        # Download latest CodeCompanion documentation
```

### Running Style Checks
```bash
stylua --check .    # Check formatting (used in CI)
stylua .            # Auto-fix formatting
# Or via mise:
mise run lint       # Check formatting
mise run fmt        # Auto-fix formatting
```

### Development Setup
The extension must be loaded through CodeCompanion:
```lua
require("codecompanion").setup({
  extensions = {
    gitcommit = {
      callback = "codecompanion._extensions.gitcommit",
      opts = { ... }
    }
  }
})
```

### Debugging Tips
- Use `vim.notify()` for user-facing messages
- Use `vim.inspect()` for debugging complex data structures
- Check `vim.v.shell_error` after shell commands
- Use `pcall()` to catch Lua errors gracefully

---

## Common Patterns

### Formatted Tool Response
```lua
local function format_git_response(tool_name, success, output, empty_msg)
  local user_msg, llm_msg
  local tag = "git" .. tool_name:gsub("^%l", string.upper) .. "Tool"
  
  if success then
    user_msg = string.format("✓ Git %s:\n```\n%s\n```", tool_name, output)
    llm_msg = string.format("<%s>success:\n%s</%s>", tag, output, tag)
  else
    user_msg = string.format("✗ Git %s failed: %s", tool_name, output)
    llm_msg = string.format("<%s>fail: %s</%s>", tag, output, tag)
  end
  return user_msg, llm_msg
end
```

### Async Git Operations
```lua
vim.fn.jobstart(cmd, {
  on_stdout = function(_, data) ... end,
  on_stderr = function(_, data) ... end,
  on_exit = function(_, code)
    if code == 0 then
      callback({ status = "success", data = output })
    else
      callback({ status = "error", data = error_output })
    end
  end,
})
```

### Buffer Content Manipulation
```lua
local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
vim.api.nvim_buf_set_lines(bufnr, start, end_, false, new_lines)
vim.api.nvim_win_set_cursor(0, { row, col })
```

---

## Security Considerations

- **Read operations** (`git_read`): No approval required
- **Write operations** (`git_edit`): Require user approval
- **Force push**: Extra warning, explicitly dangerous
- **Input escaping**: Always use `vim.fn.shellescape()` for shell commands
- **Path validation**: Validate file paths before operations

---

## API Reference

### Programmatic Exports

```lua
local gitcommit = require("codecompanion._extensions.gitcommit")

-- Generate commit message
gitcommit.exports.generate("English", function(result, error) end)

-- Check repository status
gitcommit.exports.is_git_repo()

-- Git operations
gitcommit.exports.git_tool.status()
gitcommit.exports.git_tool.stage({"file.lua"})
gitcommit.exports.git_tool.generate_release_notes("v1.0", "v1.1", "markdown")
```

---

## Notes for AI Agents

1. **Always run `stylua --check .`** after making changes to ensure StyLua compliance
2. **Always run `stylua .`** after modifying code to auto-format
3. **Use v18+ patterns** when modifying tool options (use `require_approval_before`)
4. **Use validation.lua** for all parameter validation in tools
5. **Follow existing patterns** - this codebase is consistent; match the style
6. **Test with actual CodeCompanion** - the extension requires the parent plugin
7. **Error messages should be user-friendly** - use icons (✓, ✗, ℹ) for visual feedback
8 **Document new features** in both code (annotations) and help file
9. **Update this file (AGENTS.md)** with any new patterns or guidelines you introduce
