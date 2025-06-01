# CodeCompanion Git Commit Extension

A CodeCompanion extension that generates AI-powered git commit messages following the Conventional Commits specification.

## Features

- 🤖 AI-powered commit message generation using CodeCompanion's LLM adapters
- 📋 Interactive UI with copy and commit options
- ✅ Conventional Commits specification compliance
- 🔍 Automatic git repository detection
- 📝 Support for both user commands and slash commands

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
      }
    }
  }
})
```

## Usage

### User Commands

- `:CodeCompanionGitCommit` - Generate git commit message
- `:CCGitCommit` - Short alias for the above command

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
```

## File Structure

```
lua/codecompanion/_extensions/gitcommit/
├── init.lua        # Main extension entry point
├── git.lua         # Git operations (repository detection, diff, commit)
├── generator.lua   # LLM integration for commit message generation
└── ui.lua          # Floating window UI and interactions
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

1. Stage your changes with `git add`
2. Run `:CodeCompanionGitCommit`
3. Review the generated commit message in the floating window
4. Choose an action:
   - `c` - Copy to clipboard
   - `s` - Submit (commit changes)
   - `Enter` - Copy and close
   - `q/Esc` - Close without action

## Configuration

The extension accepts the following options:

```lua
opts = {
  add_slash_command = true, -- Add /gitcommit slash command to chat buffer
}
```

## Contributing

Feel free to submit issues and enhancement requests!