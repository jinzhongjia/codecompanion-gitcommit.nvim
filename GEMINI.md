# Project Overview: CodeCompanion Git Commit Extension

This project is a CodeCompanion extension designed to generate AI-powered Git commit messages following the Conventional Commits specification. It integrates powerful Git tools for enhanced workflow.

## Key Features:

- **AI Commit Generation**: Generates Conventional Commits compliant messages using CodeCompanion's LLM adapters.
- **Git Tool Integration**: Allows execution of Git operations via `@git_read` (read-only) and `@git_edit` (write) tools within chat.
- **Multi-language Support**: Supports generating commit messages in multiple languages (e.g., English, Chinese).
- **Smart Buffer Integration**: Auto-generates commit messages in gitcommit buffers.
- **File Filtering**: Supports glob patterns to exclude generated files from analysis.
- **Natural Language Interface**: Enables controlling Git workflows through conversational commands.

## Development Principles

- **No Plenary**: The use of the `plenary.nvim` library is prohibited. Instead, leverage Neovim's built-in `vim.uv` library for I/O and other system-level operations.
- **Asynchronous by Default**: For any operation that could be time-consuming (e.g., network requests, file system operations), always prefer an asynchronous implementation to avoid blocking the main thread.
- **Comprehensive Feedback**: Regardless of the outcome, every asynchronous operation must report its result (both success and failure) back to the language model. This ensures the LLM is always aware of the state of the tool.

## Installation:

Add this extension to your CodeCompanion configuration in `init.lua` or similar:

```lua
require("codecompanion").setup({
  extensions = {
    gitcommit = {
      callback = "codecompanion._extensions.gitcommit",
      opts = {
        adapter = "openai",
        model = "gpt-4",
        languages = { "English", "Chinese" },
        exclude_files = { "*.pb.go", "*.min.js", "package-lock.json", "dist/*", "build/*", "node_modules/*" },
        buffer = {
          enabled = true,
          keymap = "<leader>gc",
          auto_generate = true,
          auto_generate_delay = 100,
        },
        add_slash_command = true,
        add_git_tool = true,
        add_git_commands = true,
      }
    }
  }
})
```

## Usage:

### Commands:

- `:CodeCompanionGitCommit` or `:CCGitCommit`: Generate Git commit message.
- `:CodeCompanionGit` or `:CCGit`: Open Git assistant chat.

### Git Tool Operations in Chat:

- **Read-only (`@git_read`)**: e.g., `@git_read status`, `@git_read log --count 5`
- **Write (`@git_edit`)**: e.g., `@git_edit stage --files ["src/main.lua", "README.md"]`, `@git_edit create_branch --branch_name "feature/new-ui"`

### Workflow Examples:

- **Quick commit**: Check status, stage files, then generate commit message.
- **Branch management**: List branches, create new branch, make changes, stage files, then generate commit message.

## Configuration Options:

Key configurable options include LLM adapter and model, supported languages, file exclusion patterns, buffer integration settings (enable, keymap, auto-generate), and toggles for slash commands, Git tools, and Git commands.

## Safety Features:

- Read-only operations (`@git_read`) require no confirmation.
- Modifying operations (`@git_edit`) require user confirmation.
- Repository validation ensures operations in valid Git repositories.
- Comprehensive error handling.

## License:

MIT License