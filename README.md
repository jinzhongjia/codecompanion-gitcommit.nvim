# CodeCompanion Git Commit Extension

A CodeCompanion extension that generates AI-powered git commit messages following the Conventional Commits specification.

## Features

- 🤖 AI-powered commit message generation using CodeCompanion's LLM adapters
- 📋 Interactive UI with copy to clipboard and yank register options
- ✅ Conventional Commits specification compliance
- 🔍 Automatic git repository detection
- 📝 Support for both user commands and slash commands
- ⌨️ Smart keymap integration for gitcommit buffers
- 🌍 Multi-language support for commit messages
- 🔄 Support for both regular commits and `git commit --amend`
- 📁 File filtering support with glob patterns to exclude files from diff analysis

## Installation

### As a CodeCompanion Extension

Add this to your CodeCompanion configuration:

```lua
require("codecompanion").setup({
  extensions = {
    gitcommit = {
      callback = "codecompanion._extensions.gitcommit",
      opts = {
        add_slash_command = true, -- Optional: adds /gitcommit slash command
        adapter = "openai",        -- Optional: specify LLM adapter (defaults to codecompanion chat adapter)
        model = "gpt-4",          -- Optional: specify model (defaults to codecompanion chat model)
        languages = { "English", "简体中文", "日本語", "Français", "Español" }, -- Optional: list of languages for commit messages
        exclude_files = { "*.pb.go", "*.min.js", "package-lock.json" }, -- Optional: exclude files from diff analysis
        buffer = {
          enabled = true,        -- Enable gitcommit buffer keymaps
          keymap = "<leader>gc", -- Keymap for generating commit message in gitcommit buffer
        }
      }
    }
  }
})
```

## Usage

### User Commands

- `:CodeCompanionGitCommit` - Generate git commit message
- `:CCGitCommit` - Short alias for the above command

### GitCommit Buffer Integration

When you run `git commit` or open a gitcommit buffer:
1. Press `<leader>gc` (or your configured keymap) in normal mode
2. The extension will automatically generate a commit message based on staged changes
3. The generated message will be inserted directly into the commit buffer

### Slash Command (if enabled)

In a CodeCompanion chat buffer, use `/gitcommit` to generate a commit message.

### Programmatic Usage

```lua
local gitcommit = require("codecompanion").extensions.gitcommit

-- Generate commit message with language selection
gitcommit.generate("English", function(result, error)
  if error then
    print("Error:", error)
  else
    print("Generated:", result)
  end
end)

-- Generate commit message without language (uses default)
gitcommit.generate(nil, function(result, error)
  if error then
    print("Error:", error)
  else
    print("Generated:", result)
  end
end)

-- Check if in git repository
local is_git_repo = gitcommit.is_git_repo()

-- Get staged diff
local diff = gitcommit.get_staged_diff()

-- Commit changes
local success = gitcommit.commit_changes("feat: add new feature")

-- Get buffer configuration
local buffer_config = gitcommit.get_buffer_config()
```

## File Structure

```
lua/codecompanion/_extensions/gitcommit/
├── init.lua        # Main extension entry point and command registration
├── git.lua         # Git operations (repository detection, diff, commit, amend support)
├── generator.lua   # LLM integration for commit message generation
├── ui.lua          # Floating window UI and interactions
├── buffer.lua      # GitCommit buffer keymap integration
├── langs.lua       # Language selection functionality
└── types.lua       # Type definitions and TypeScript-style annotations
```

## Module Overview

### `git.lua`
Handles all git-related operations:

- Repository detection with filesystem and git command fallback
- Staged changes retrieval and contextual diff generation
- File filtering support with glob patterns to exclude files from analysis
- Support for both regular commits and `git commit --amend`
- Commit execution with proper error handling

### `generator.lua`
Manages LLM interaction:

- Prompt creation for commit message generation with language support
- API communication with CodeCompanion adapters
- Response handling and error management
- Adapter and model configuration

### `ui.lua`
Provides interactive user interface:

- Floating window display with markdown formatting
- Interactive keyboard shortcuts (`c`, `y`, `s`, `Enter`, `q/Esc`)
- Copy to clipboard and yank register functionality
- Responsive window sizing

### `buffer.lua`
Handles gitcommit buffer integration:

- Automatic keymap setup for gitcommit filetype
- Smart commit message insertion at correct position
- Buffer content management and validation
- Language selection integration

### `langs.lua`
Manages language selection:

- Multi-language support configuration
- Interactive language selection UI
- Language preference handling

### `types.lua`
Provides type definitions:

- TypeScript-style type annotations for Lua
- Interface definitions for all modules
- Configuration option types

### `init.lua`
Main extension coordinator:

- Module integration and dependency management
- Command registration (`:CodeCompanionGitCommit`, `:CCGitCommit`)
- Slash command integration
- Extension exports for programmatic usage

## Requirements

- Neovim with CodeCompanion plugin installed
- Git repository with staged changes
- Configured LLM adapter in CodeCompanion

## Workflow

### Traditional Workflow
1. Stage your changes with `git add`
2. Run `:CodeCompanionGitCommit`
3. Review the generated commit message in the floating window
4. Choose an action:
   - `c` - Copy to clipboard
   - `y` - Copy to yank register
   - `s` - Submit (commit changes)
   - `Enter` - Copy and close
   - `q/Esc` - Close without action

### Interactive Keymaps

When the floating window is displayed with the generated commit message, the following keymaps are available:

- **`c`** - Copy the commit message to the system clipboard (`+` register)
- **`y`** - Copy the commit message to Vim's default yank register (`"` register)
- **`s`** - Submit the commit message immediately (executes `git commit`)
- **`Enter`** - Copy to clipboard and close the floating window
- **`q` or `Esc`** - Close the floating window without taking any action

### GitCommit Buffer Workflow
1. Stage your changes with `git add`
2. Run `git commit` to open the commit buffer
3. Press `<leader>gc` in normal mode to generate commit message
4. The AI-generated message will be inserted into the buffer
5. Edit if needed and save to complete the commit

### Amend Workflow
1. Make additional changes to your files
2. Stage changes with `git add` (optional, for new changes)
3. Run `git commit --amend` to open the amend buffer
4. Press `<leader>gc` in normal mode to generate an updated commit message
5. The extension will analyze the full commit changes and generate an appropriate message
6. Edit if needed and save to complete the amend

## Configuration

The extension accepts the following options:

```lua
opts = {
  add_slash_command = true, -- Add /gitcommit slash command to chat buffer
  adapter = "openai",      -- LLM adapter to use (default: codecompanion chat adapter)
  model = "gpt-4",         -- Model to use (default: codecompanion chat model)
  languages = { "English", "简体中文", "日本語", "Français", "Español" }, -- Languages for commit messages
  exclude_files = { "*.pb.go", "*.min.js", "package-lock.json" }, -- File patterns to exclude from diff analysis
  buffer = {
    enabled = true,        -- Enable gitcommit buffer keymaps (default: true)
    keymap = "<leader>gc", -- Keymap for generating commit message (default: "<leader>gc")
  }
}
```

### Configuration Options

#### `add_slash_command` (boolean, default: `false`)
When enabled, adds `/gitcommit` slash command to CodeCompanion chat buffers.

#### `adapter` (string, optional)
The LLM adapter to use for generating commit messages. If not specified, defaults to the adapter configured for CodeCompanion's chat strategy.

#### `model` (string, optional)
The specific model to use with the adapter. If not specified, defaults to the model configured for CodeCompanion's chat strategy.

#### `languages` (table, optional)
A list of languages that can be used for generating commit messages. When specified, the extension will prompt you to select a language before generating the commit message. If not provided or empty, commit messages will be generated in English by default.

Example:

```lua
languages = { "English", "简体中文", "日本語", "Français", "Español" }
```

#### `exclude_files` (table, optional)
A list of file patterns to exclude from git diff analysis when generating commit messages. Supports glob patterns using `*` and `?` wildcards. This is useful for excluding generated files, minified files, or large files that don't need AI analysis.

Examples:

```lua
exclude_files = { 
  "*.pb.go",           -- Protocol buffer generated files
  "*.min.js",          -- Minified JavaScript files
  "package-lock.json", -- NPM lock file
  "yarn.lock",         -- Yarn lock file
  "*.generated.ts",    -- Generated TypeScript files
  "dist/*",            -- Distribution directory
  "build/*"            -- Build directory
}
```

#### `buffer.enabled` (boolean, default: `true`)
Controls whether gitcommit buffer keymap integration is enabled.

#### `buffer.keymap` (string, default: `"<leader>gc"`)
The keymap used in gitcommit buffers to trigger commit message generation.

## Contributing

Feel free to submit issues and enhancement requests!