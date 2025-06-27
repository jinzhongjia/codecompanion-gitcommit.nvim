# CodeCompanion Git Commit Extension

### `tools/git.lua`

Core git operations engine:

- Safe git command execution with error handling
- Repository validation and detection
- Git status, log, diff, and branch operations
- File staging/unstaging and blame information
- Stash management and commit operations
- Branch creation, checkout, and management
- Repository insights (contributors, remotes, commit search)
- Reset operations with safety checks

### `tools/git_bot.lua`

CodeCompanion chat tool integration:

- OpenAI-compatible function calling schema
- Natural language interface for git operations
- Comprehensive parameter validation and handling
- Formatted output for chat buffer display
- Approval system for destructive operations
- Error handling and user feedback
- Integration with CodeCompanion's agent system
A CodeCompanion extension that generates AI-powered git commit messages following the Conventional Commits specification.

## Features

### Core Features
- 🤖 AI-powered commit message generation using CodeCompanion's LLM adapters
- 📋 Interactive UI with copy to clipboard and yank register options
- ✅ Conventional Commits specification compliance
- 🔍 Automatic git repository detection
- 📝 Support for both user commands and slash commands
- ⌨️ Smart keymap integration for gitcommit buffers
- 🌍 Multi-language support for commit messages
- 🔄 Support for both regular commits and `git commit --amend`
- 📁 File filtering support with glob patterns to exclude files from diff analysis

### Git Tool Features
- 🛠️ **@git_read tool** - Read-only Git operations through CodeCompanion chat (status, log, diff, etc.)
- ✍️ **@git_edit tool** - Write-access Git operations through CodeCompanion chat (stage, unstage, branch creation, etc.)
- 📊 **Git status and branch management** - Check status, create/switch branches
- 🔍 **Advanced Git operations** - Diff, log, blame, stash operations  
- 👥 **Repository insights** - Contributors, commit search, remote info
- 🔒 **Safe operations** - Automatic approval requirements for destructive operations
- 💬 **Natural language interface** - Control Git through conversation
- 📝 **Comprehensive Git workflow** - From status check to commit in one chat

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
        languages = { "English", "Chinese", "Japanese", "French", "Spanish" }, -- Optional: list of languages for commit messages
        exclude_files = { "*.pb.go", "*.min.js", "package-lock.json" }, -- Optional: exclude files from diff analysis
        add_git_tool = true,       -- Optional: add @git_read and @git_edit tools to CodeCompanion (default: true)
        add_git_commands = true,   -- Optional: add :CodeCompanionGit commands (default: true)
        gitcommit_select_count = 100, -- Optional: number of recent commits for /gitcommit slash command (default: 100)
        buffer = {
          enabled = true,        -- Enable gitcommit buffer keymaps
          keymap = "<leader>gc", -- Keymap for generating commit message in gitcommit buffer
          auto_generate = true,  -- Automatically generate message on entering gitcommit buffer
          auto_generate_delay = 100, -- Delay in ms before auto-generating
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
- `:CodeCompanionGit` - Open CodeCompanion chat with git assistant
- `:CCGit` - Short alias for git assistant
### Git Tool Operations

#### Interactive Git Assistant

Use `:CodeCompanionGit` or `:CCGit` to open a CodeCompanion chat buffer. You can then use `@git_read` for read-only operations or `@git_edit` for operations that modify the repository.

#### Chat Integration

In any CodeCompanion chat buffer, use `@git_read` or `@git_edit` to perform Git operations:

```
@git_read help                    # Show available read-only operations
@git_read status                  # Show git status
@git_read log --count 5           # Show last 5 commits
@git_read diff --staged           # Show staged changes
@git_read branch                  # List all branches

@git_edit help                    # Show available write-access operations
@git_edit create_branch --branch_name feature/new-ui
@git_edit stage --files ["src/main.lua", "README.md"]
@git_edit stash --message "Work in progress"
```

#### Git Tool Commands Reference

**@git_read: Read-only Git Operations**

**Repository Status & Info**
- `@git_read status` - Show repository status
- `@git_read log [--count N] [--format FORMAT]` - Show commit history
- `@git_read branch [--remote_only]` - List branches
- `@git_read remotes` - Show remote repositories
- `@git_read contributors [--count N]` - Show top contributors
- `@git_read show [--commit_hash HASH]` - Show commit details
- `@git_read diff_commits --commit1 HASH1 [--commit2 HASH2] [--file_path PATH]` - Compare commits
- `@git_read search_commits --pattern "PATTERN" [--count N]` - Search commits
- `@git_read stash_list` - List all stashes
- `@git_read blame --file_path PATH [--line_start N] [--line_end N]` - Show blame info
- `@git_read gitignore_get` - View current .gitignore content
- `@git_read gitignore_check --gitignore_file "FILE"` - Check if file is ignored

**@git_edit: Write-access Git Operations**

**File Operations**
- `@git_edit stage --files ["file1", "file2"]` - Stage files
- `@git_edit unstage --files ["file1", "file2"]` - Unstage files

**Branch Management**
- `@git_edit create_branch --branch_name NAME [--checkout BOOL]` - Create new branch
- `@git_edit checkout --target BRANCH_OR_COMMIT` - Switch branch/commit

**Stash Operations**
- `@git_edit stash [--message "MSG"] [--include_untracked]` - Stash changes
- `@git_edit apply_stash [--stash_ref "stash@{0}"]` - Apply stash

**Advanced Operations** (require approval)
- `@git_edit reset --commit_hash HASH [--mode soft|mixed|hard]` - Reset to commit

**GitIgnore Management**
- `@git_edit gitignore_add --gitignore_rule "RULE"` - Add rule to .gitignore
- `@git_edit gitignore_add --gitignore_rules ["rule1", "rule2"]` - Add multiple rules
• `@git_edit gitignore_remove --gitignore_rule "RULE"` - Remove rule from .gitignore
• `@git_edit push [--remote REMOTE] [--branch BRANCH] [--force BOOL]` - Push changes to a remote repository.
  WARNING: `force` push is dangerous and can overwrite remote history. Use with extreme caution.
• `@git_edit rebase [--onto ONTO] [--base BASE] [--interactive BOOL]` - Rebase current branch onto another.
  WARNING: `interactive` rebase opens an editor and is not suitable for automated environments. It can also rewrite history.
• `@git_edit cherry_pick --cherry_pick_commit_hash HASH` - Apply the changes introduced by some existing commits.
• `@git_edit revert --revert_commit_hash HASH` - Revert a commit.

#### Safety Features

The git tools include automatic safety features:
- **Read-only operations** (via `@git_read`) do not require approval.
- **Modifying operations** (via `@git_edit`) require user confirmation.
- **Repository validation** ensures you're in a valid Git repository.
- **Comprehensive error handling** with helpful error messages.

#### Example Workflows

**Code Review Workflow:**
```
@git_read status
@git_read diff --staged
/gitcommit  # Generate commit message
```

**Branch Management:**
```
@git_read branch
@git_edit create_branch --branch_name feature/new-ui
# ... make changes ...
@git_edit stage --files ["src/ui.lua"]
@git_read status
```

**Investigation Workflow:**
```
@git_read log --count 10
@git_read show --commit_hash abc123
@git_read blame --file_path src/main.lua --line_start 50 --line_end 60
```

**GitIgnore Management Workflow:**
```
@git_read gitignore_get                              # View current .gitignore
@git_edit gitignore_add --gitignore_rule "*.log"     # Add single rule
@git_edit gitignore_add --gitignore_rules ["dist/", "build/", "*.tmp"] # Add multiple rules
@git_read gitignore_check --gitignore_file "temp.log" # Check if file is ignored
@git_edit gitignore_remove --gitignore_rule "*.log"  # Remove rule
```

### GitCommit Buffer Integration

When you run `git commit` or open a gitcommit buffer:

1.  If `buffer.auto_generate` is `true`, the commit message will be generated and inserted automatically.
2.  If `buffer.auto_generate` is `false` (default), press `<leader>gc` (or your configured keymap) in normal mode to trigger generation.
3.  The generated message will be inserted directly into the commit buffer.

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

-- Git Tool API
-- Basic operations
local success, output = gitcommit.git_tool.status()
local success, branches = gitcommit.git_tool.branches()
local success, log = gitcommit.git_tool.log(5, "oneline")

-- File operations
local success, diff = gitcommit.git_tool.diff(true) -- staged diff
local success, diff_file = gitcommit.git_tool.diff(false, "src/main.lua") -- specific file
gitcommit.git_tool.stage({"src/main.lua", "README.md"})
gitcommit.git_tool.unstage({"src/main.lua"})

-- Branch operations
local success, current = gitcommit.git_tool.current_branch()
gitcommit.git_tool.create_branch("feature/new-feature", true) -- create and checkout
gitcommit.git_tool.checkout("main")

-- Repository info
local success, remotes = gitcommit.git_tool.remotes()
local success, contributors = gitcommit.git_tool.contributors(10)
local success, commit_info = gitcommit.git_tool.show("HEAD")

-- Blame and history
local success, blame = gitcommit.git_tool.blame("src/main.lua", 10, 20)
local success, commits = gitcommit.git_tool.search_commits("fix bug", 5)
local success, comparison = gitcommit.git_tool.diff_commits("HEAD~1", "HEAD", "src/main.lua")

-- Stash operations
gitcommit.git_tool.stash("Work in progress", true) -- include untracked
local success, stashes = gitcommit.git_tool.stash_list()
gitcommit.git_tool.apply_stash("stash@{0}")

-- Advanced operations (use with caution)
gitcommit.git_tool.reset("HEAD~1", "soft")
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
├── types.lua       # Type definitions and TypeScript-style annotations
└── tools/          # Git tool implementations
    ├── git.lua     # Core git operations and command execution
    ├── git_read.lua # CodeCompanion chat tool for read-only Git operations
    └── git_edit.lua # CodeCompanion chat tool for write-access Git operations
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
- Git tool integration and command setup

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
3. If `auto_generate` is enabled, the message appears automatically. Otherwise, press `<leader>gc` in normal mode to generate it.
4. The AI-generated message will be inserted into the buffer.
5. Edit if needed and save to complete the commit.

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
  languages = { "English", "Chinese", "Japanese", "French", "Spanish" }, -- Languages for commit messages
  exclude_files = { "*.pb.go", "*.min.js", "package-lock.json" }, -- File patterns to exclude from diff analysis
  add_git_tool = true,     -- Add @git_bot tool to CodeCompanion (default: true)
  add_git_commands = true, -- Add :CodeCompanionGit commands (default: true)
  git_tool_auto_submit_errors = false,  -- Auto-submit git tool errors to LLM (default: false)
  git_tool_auto_submit_success = false, -- Auto-submit git tool success to LLM (default: false)
  gitcommit_select_count = 100, -- Number of recent commits for /gitcommit slash command (default: 100)
  buffer = {
    enabled = true,        -- Enable gitcommit buffer keymaps (default: true)
    keymap = "<leader>gc", -- Keymap for generating commit message (default: "<leader>gc")
    auto_generate = false, -- Automatically generate message on entering gitcommit buffer (default: false)
    auto_generate_delay = 100, -- Delay in ms before auto-generating (default: 100)
  }
}
```

### Configuration Options

#### `add_slash_command` (boolean, default: `false`)

When enabled, adds `/gitcommit` slash command to CodeCompanion chat buffers.

#### `add_git_tool` (boolean, default: `true`)

When enabled, adds the `@git_read` and `@git_edit` tools to CodeCompanion chat buffers. This allows you to perform Git operations through natural language in chat.

#### `add_git_commands` (boolean, default: `true`)

When enabled, adds `:CodeCompanionGit` and `:CCGit` commands that open a chat buffer for Git assistance.

#### `git_tool_auto_submit_errors` (boolean, default: `false`)

When enabled, automatically submits git tool error messages back to the LLM for analysis and suggestions.

#### `git_tool_auto_submit_success` (boolean, default: `false`)

When enabled, automatically submits git tool success messages back to the LLM to continue the workflow.

#### `gitcommit_select_count` (number, default: `100`)

Number of recent commits to show when using the `/gitcommit` slash command. This controls how many commits are available for selection in the interactive commit selector.
#### `adapter` (string, optional)

The LLM adapter to use for generating commit messages. If not specified, defaults to the adapter configured for CodeCompanion's chat strategy.

#### `model` (string, optional)

The specific model to use with the adapter. If not specified, defaults to the model configured for CodeCompanion's chat strategy.

#### `languages` (table, optional)

A list of languages that can be used for generating commit messages. When specified, the extension will prompt you to select a language before generating the commit message. If not provided or empty, commit messages will be generated in English by default.

Example:

```lua
languages = { "English", "Chinese", "Japanese", "French", "Spanish" }
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

#### `buffer.auto_generate` (boolean, default: `false`)

When `true`, automatically generates a commit message upon entering a `gitcommit` buffer, but only if the buffer does not already contain a message (to avoid overwriting during an amend).

#### `buffer.auto_generate_delay` (number, default: `100`)

The delay in milliseconds before the automatic generation is triggered. This helps prevent race conditions with other plugins (like `neogit`) that manage UI elements. You can increase this value if you still experience issues.

## Contributing

Feel free to submit issues and enhancement requests!
