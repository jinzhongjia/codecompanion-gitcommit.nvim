# CodeCompanion Git Commit Extension

A CodeCompanion extension that generates AI-powered git commit messages following the Conventional Commits specification.

## Features

- 🤖 AI-powered commit message generation using CodeCompanion's LLM adapters
- 📋 Interactive UI with copy and commit options
- ✅ Conventional Commits specification compliance
- 🔍 Automatic git repository detection
- 📝 Support for both user commands and slash commands
- ⌨️ Smart keymap integration for gitcommit buffers

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
        languages = { "English", "Chinese", "Japanese" }, -- Optional: list of languages for commit messages
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

-- Generate commit message
gitcommit.generate(function(result, error)
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
├── init.lua        # Main extension entry point
├── git.lua         # Git operations (repository detection, diff, commit)
├── generator.lua   # LLM integration for commit message generation
├── ui.lua          # Floating window UI and interactions
└── buffer.lua      # GitCommit buffer keymap integration
```

## Module Overview

### `git.lua`
Handles all git-related operations:
- Repository detection
- Staged changes retrieval
- Commit execution

### `generator.lua`
Manages LLM interaction:
- Prompt creation for commit message generation
- API communication with CodeCompanion adapters
- Response handling

### `ui.lua`
Provides interactive user interface:
- Floating window display
- Keyboard shortcuts
- Copy to clipboard functionality

### `buffer.lua`
Handles gitcommit buffer integration:
- Automatic keymap setup for gitcommit filetype
- Smart commit message insertion
- Buffer content management

### `init.lua`
Main extension coordinator:
- Module integration
- Command registration
- Extension exports

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
   - `s` - Submit (commit changes)
   - `Enter` - Copy and close
   - `q/Esc` - Close without action

### GitCommit Buffer Workflow
1. Stage your changes with `git add`
2. Run `git commit` to open the commit buffer
3. Press `<leader>gc` in normal mode to generate commit message
4. The AI-generated message will be inserted into the buffer
5. Edit if needed and save to complete the commit

## Configuration

The extension accepts the following options:

```lua
opts = {
  add_slash_command = true, -- Add /gitcommit slash command to chat buffer
  adapter = "openai",      -- LLM adapter to use (default: codecompanion chat adapter)
  model = "gpt-4",         -- Model to use (default: codecompanion chat model)
  languages = { "English", "Chinese", "Japanese" }, -- Languages for commit messages
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
A list of languages that can be used for generating commit messages. When specified, the extension will prompt you to select a language before generating the commit message. If not provided, commit messages will be generated in English by default.
#### `buffer.enabled` (boolean, default: `true`)
Controls whether gitcommit buffer keymap integration is enabled.

#### `buffer.keymap` (string, default: `"<leader>gc"`)
The keymap used in gitcommit buffers to trigger commit message generation.

## Contributing

Feel free to submit issues and enhancement requests!