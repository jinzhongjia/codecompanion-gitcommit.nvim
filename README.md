# CodeCompanion GitCommit Extension

A Neovim plugin extension for CodeCompanion that generates AI-powered Git commit messages following the Conventional Commits specification, with comprehensive Git workflow integration.

## ✨ Features

- 🤖 **AI Commit Generation** - Generate Conventional Commits compliant messages using CodeCompanion's LLM adapters
- 🛠️ **Git Tool Integration** - Execute Git operations through `@git_read` (15 operations) and `@git_edit` (16 operations) tools in chat
- 🤖 **Git Assistant** - Intelligent Git workflow assistance via `@git_bot` combining read/write operations
- 🌍 **Multi-language Support** - Generate commit messages in multiple languages
- 📝 **Smart Buffer Integration** - Auto-generate commit messages in gitcommit buffers with configurable keymaps
- 📋 **File Filtering** - Support glob patterns to exclude files from diff analysis
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
          enabled = true,                -- Enable gitcommit buffer keymaps
          keymap = "<leader>gc",         -- Keymap for generating commit messages
          auto_generate = true,          -- Auto-generate on buffer enter
          auto_generate_delay = 200,     -- Auto-generation delay (ms)
        },
        
        -- Feature toggles
        add_slash_command = true,        -- Add /gitcommit slash command
        add_git_tool = true,            -- Add @git_read and @git_edit tools
        enable_git_read = true,         -- Enable read-only Git operations
        enable_git_edit = true,         -- Enable write-access Git operations  
        enable_git_bot = true,          -- Enable @git_bot tool group (requires both read/write enabled)
        add_git_commands = true,        -- Add :CodeCompanionGitCommit commands
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
@git_read status                    # Show repository status
@git_read log --count 5             # Show last 5 commits
@git_read diff --staged             # Show staged changes
@git_read branch                    # List all branches
@git_read contributors --count 10   # Show top 10 contributors
@git_read tags                      # List all tags
@git_read gitignore_get             # Get .gitignore content
```

#### ✏️ Write Operations (`@git_edit`)

```
@git_edit stage --files ["src/main.lua", "README.md"]
@git_edit create_branch --branch_name "feature/new-ui"
@git_edit stash --message "Work in progress"
@git_edit checkout --target "main"
@git_edit commit --commit_message "feat: add new feature"
@git_edit push --remote "origin" --branch "main"
```

#### 🤖 Git Bot (`@git_bot`)

Use a comprehensive Git assistant that combines read and write operations:

```
@git_bot Please help me create a new branch and push the current changes
@git_bot Analyze recent commit history and summarize main changes
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
@git_read status                    # Check repository status
@git_edit stage --files ["file1.txt", "file2.txt"]  # Stage files
/gitcommit                          # Generate commit message in chat
@git_edit commit --commit_message "feat: add new feature"  # Commit
@git_edit push --remote "origin" --branch "main"    # Push changes
```

## ⚙️ Configuration Options

<details>
<summary>Complete configuration options</summary>

```lua
opts = {
  adapter = "openai",                           -- LLM adapter
  model = "gpt-4",                             -- Model name
  languages = { "English", "Chinese", "Japanese", "French" }, -- Supported languages list
  exclude_files = {                            -- Excluded file patterns
    "*.pb.go", "*.min.js", "*.min.css",
    "package-lock.json", "yarn.lock", "*.log",
    "dist/*", "build/*", ".next/*",
    "node_modules/*", "vendor/*"
  },
  add_slash_command = true,                    -- Add /gitcommit command
  add_git_tool = true,                        -- Add Git tools
  enable_git_read = true,                     -- Enable read-only Git operations
  enable_git_edit = true,                     -- Enable write-access Git operations
  enable_git_bot = true,                      -- Enable Git bot (requires both read/write enabled)
  add_git_commands = true,                    -- Add Git commands
  gitcommit_select_count = 100,               -- Commits shown in /gitcommit
  git_tool_auto_submit_errors = false,       -- Auto-submit errors to LLM
  git_tool_auto_submit_success = false,      -- Auto-submit success to LLM
  buffer = {
    enabled = true,                           -- Enable buffer integration
    keymap = "<leader>gc",                   -- Keymap
    auto_generate = true,                    -- Auto-generate
    auto_generate_delay = 200,              -- Generation delay (ms)
  }
}
```

</details>

## 📚 Documentation

For detailed documentation, see: `:help codecompanion-gitcommit`

## 🔒 Safety Features

- **Read-only operations** (`@git_read`) require no confirmation
- **Modifying operations** (`@git_edit`) require user confirmation
- **Repository validation** ensures operations in valid Git repositories
- **Comprehensive error handling** with helpful error messages

## 📄 License

MIT License
