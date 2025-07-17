# CodeCompanion GitCommit Extension

A Neovim plugin extension for CodeCompanion that generates AI-powered Git commit messages following the Conventional Commits specification, with comprehensive Git workflow integration.

## ✨ Features

- 🤖 **AI Commit Generation** - Generate Conventional Commits compliant messages using CodeCompanion's LLM adapters
- 🛠️ **Git Tool Integration** - Execute Git operations through `@git_read` (15 read operations) and `@git_edit` (16 write operations) tools in chat
- 🤖 **Git Assistant** - Intelligent Git workflow assistance via `@git_bot` combining read/write operations
- 🌍 **Multi-language Support** - Generate commit messages in multiple languages
- 📝 **Smart Buffer Integration** - Auto-generate commit messages in gitcommit buffers with configurable keymaps
- 📋 **File Filtering** - Support glob patterns to exclude files from diff analysis
- 📚 **Commit History Context** - Use recent commit history to maintain consistent styling and patterns
- 🔌 **Programmatic API** - Full API for external integrations and custom workflows
- ⚡ **Async Operations** - Non-blocking Git operations with proper error handling

## 📦 Installation

Add this extension to your CodeCompanion configuration:

```lua
require("codecompanion").setup({
  extensions = {
    gitcommit = {
      callback = "codecompanion._extensions.gitcommit",
      opts = {
        -- Basic configuration
        adapter = "openai",                       -- LLM adapter
        model = "gpt-4",                         -- Model name
        languages = { "English", "Chinese", "Japanese", "French" }, -- Supported languages
        
        -- File filtering (optional)
        exclude_files = { 
          "*.pb.go", "*.min.js", "*.min.css", "package-lock.json",
          "yarn.lock", "*.log", "dist/*", "build/*", ".next/*",
          "node_modules/*", "vendor/*"
        },
        
        -- Buffer integration
        buffer = {
          enabled = true,                  -- Enable gitcommit buffer keymaps
          keymap = "<leader>gc",           -- Keymap for generating commit messages
          auto_generate = true,            -- Auto-generate on buffer enter
          auto_generate_delay = 200,       -- Auto-generation delay (ms)
          skip_auto_generate_on_amend = true, -- Skip auto-generation during git commit --amend
        },
        
        -- Feature toggles
        add_slash_command = true,          -- Add /gitcommit slash command
        add_git_tool = true,              -- Add @git_read and @git_edit tools
        enable_git_read = true,           -- Enable read-only Git operations
        enable_git_edit = true,           -- Enable write-access Git operations  
        enable_git_bot = true,            -- Enable @git_bot tool group (requires both read/write enabled)
        add_git_commands = true,          -- Add :CodeCompanionGitCommit commands
        git_tool_auto_submit_errors = false,    -- Auto-submit errors to LLM
        git_tool_auto_submit_success = true,    -- Auto-submit success to LLM
        gitcommit_select_count = 100,     -- Number of commits shown in /gitcommit
        
        -- Commit history context (optional)
        use_commit_history = true,         -- Enable commit history context
        commit_history_count = 10,         -- Number of recent commits for context
      }
    }
  }
})
```

## 🚀 Usage

### Commands

| Command | Description |
|---------|-------------|
| `:CodeCompanionGitCommit` | Generate Git commit message |
| `:CCGitCommit` | Generate Git commit message (short alias) |

### Git Tool Operations

Use Git tools in CodeCompanion chat:

#### 📖 Read-only Operations (`@git_read`)

```
@git_read status                              # Show repository status
@git_read log --count 5                       # Show last 5 commits
@git_read diff --staged                       # Show staged changes
@git_read branch                              # List all branches
@git_read contributors --count 10             # Show top 10 contributors
@git_read tags                                # List all tags
@git_read gitignore_get                       # Get .gitignore content
@git_read gitignore_check --gitignore_file "file.txt"  # Check if file is ignored
@git_read show --commit_hash "abc123"         # Show commit details
@git_read blame --file_path "src/main.lua"   # Show file blame information
@git_read search_commits --pattern "fix:"    # Search commits containing "fix:"
@git_read stash_list                          # List all stashes
@git_read diff_commits --commit1 "abc123" --commit2 "def456"  # Compare two commits
@git_read remotes                             # Show remote repositories
@git_read help                                # Show help information
```

#### ✏️ Write Operations (`@git_edit`)

```
@git_edit stage --files ["src/main.lua", "README.md"]
@git_edit unstage --files ["src/main.lua"]
@git_edit commit --commit_message "feat: add new feature"
@git_edit commit                              # Auto-generate AI commit message
@git_edit create_branch --branch_name "feature/new-ui" --checkout true
@git_edit checkout --target "main"
@git_edit stash --message "Work in progress" --include_untracked true
@git_edit apply_stash --stash_ref "stash@{0}"
@git_edit reset --commit_hash "abc123" --mode "soft"
@git_edit gitignore_add --gitignore_rules ["*.log", "temp/*"]
@git_edit gitignore_remove --gitignore_rule "*.tmp"
@git_edit push --remote "origin" --branch "main" --set_upstream true
@git_edit cherry_pick --cherry_pick_commit_hash "abc123"
@git_edit revert --revert_commit_hash "abc123"
@git_edit create_tag --tag_name "v1.0.0" --tag_message "Release v1.0.0"
@git_edit delete_tag --tag_name "v0.9.0"
@git_edit merge --branch "feature/new-ui"
```

#### 🤖 Git Assistant (`@git_bot`)

Use a comprehensive Git assistant that combines read and write operations:

```
@git_bot Please help me create a new branch and push the current changes
@git_bot Analyze recent commit history and summarize main changes
@git_bot Help me organize the current workspace status
```

### Basic Usage

**1. Generate commit message:**
```
:CodeCompanionGitCommit
```

**2. GitCommit buffer integration:**
- Run `git commit` to open commit buffer
- Press `<leader>gc` to generate message (or auto-generates if enabled)
- Edit and save to complete commit

**3. Chat-based Git workflow:**
```
@git_read status                              # Check repository status
@git_edit stage --files ["file1.txt", "file2.txt"]  # Stage files
/gitcommit                                    # Generate commit message in chat
@git_edit commit --commit_message "feat: add new feature"  # Commit
@git_edit push --remote "origin" --branch "main"     # Push changes
```

## ⚙️ Configuration Options

<details>
<summary>Complete configuration options</summary>

```lua
opts = {
  adapter = "openai",                         -- LLM adapter
  model = "gpt-4",                           -- Model name
  languages = { "English", "Chinese", "Japanese", "French" }, -- Supported languages list
  exclude_files = {                          -- Excluded file patterns
    "*.pb.go", "*.min.js", "*.min.css",
    "package-lock.json", "yarn.lock", "*.log",
    "dist/*", "build/*", ".next/*",
    "node_modules/*", "vendor/*"
  },
  add_slash_command = true,                  -- Add /gitcommit command
  add_git_tool = true,                      -- Add Git tools
  enable_git_read = true,                   -- Enable read-only Git operations
  enable_git_edit = true,                   -- Enable write-access Git operations
  enable_git_bot = true,                    -- Enable Git bot (requires both read/write enabled)
  add_git_commands = true,                  -- Add Git commands
  gitcommit_select_count = 100,             -- Commits shown in /gitcommit
  git_tool_auto_submit_errors = false,      -- Auto-submit errors to LLM
  git_tool_auto_submit_success = true,      -- Auto-submit success to LLM
  use_commit_history = true,                -- Enable commit history context
  commit_history_count = 10,                -- Number of recent commits for context
  buffer = {
    enabled = true,                         -- Enable buffer integration
    keymap = "<leader>gc",                 -- Keymap
    auto_generate = true,                  -- Auto-generate
    auto_generate_delay = 200,             -- Generation delay (ms)
    skip_auto_generate_on_amend = true,    -- Skip auto-generation during amend
  }
}
```

</details>

## 🔌 Programmatic API

The extension provides a comprehensive API for external integrations:

```lua
local gitcommit = require("codecompanion._extensions.gitcommit")

-- Generate commit message programmatically
gitcommit.exports.generate("English", function(result, error)
  if result then
    print("Generated:", result)
  else
    print("Error:", error)
  end
end)

-- Check if in git repository
if gitcommit.exports.is_git_repo() then
  print("In git repository")
end

-- Get git status
local status = gitcommit.exports.git_tool.status()
print("Git status:", status)

-- Stage files
gitcommit.exports.git_tool.stage({"file1.txt", "file2.txt"})

-- Create and checkout branch
gitcommit.exports.git_tool.create_branch("feature/new-feature", true)
```

## 📚 Documentation

For detailed documentation, see: `:help codecompanion-gitcommit`

## 🔒 Safety Features

- **Read-only operations** (`@git_read`) require no confirmation
- **Modifying operations** (`@git_edit`) require user confirmation
- **Repository validation** ensures operations in valid Git repositories
- **Comprehensive error handling** with helpful error messages

## 📄 License

MIT License
