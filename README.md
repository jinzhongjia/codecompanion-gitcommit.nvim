# CodeCompanion Git Commit Extension

A CodeCompanion extension that generates AI-powered git commit messages following the Conventional Commits specification, with powerful Git tool integration.

## ✨ Features

- 🤖 **AI Commit Generation** - Generate Conventional Commits compliant messages using CodeCompanion's LLM adapters
- 🛠️ **Git Tool Integration** - Execute Git operations through `@git_read` and `@git_edit` tools in chat
- 🌍 **Multi-language Support** - Generate commit messages in multiple languages
- 📝 **Smart Buffer Integration** - Auto-generate commit messages in gitcommit buffers
- 📋 **File Filtering** - Support glob patterns to exclude generated files from analysis
- 💬 **Natural Language Interface** - Control Git workflows through conversation

## 📦 Installation

Add this extension to your CodeCompanion configuration:

```lua
require("codecompanion").setup({
  extensions = {
    gitcommit = {
      callback = "codecompanion._extensions.gitcommit",
      opts = {
        -- Basic configuration
        adapter = "openai",                    -- LLM adapter
        model = "gpt-4",                      -- Model name
        languages = { "English", "Chinese" }, -- Supported languages
        
        -- File filtering (optional)
        exclude_files = { 
          "*.pb.go", "*.min.js", "package-lock.json",
          "dist/*", "build/*", "node_modules/*"
        },
        
        -- Buffer integration
        buffer = {
          enabled = true,              -- Enable gitcommit buffer keymaps
          keymap = "<leader>gc",       -- Keymap for generating commit messages
          auto_generate = true,        -- Auto-generate on buffer enter
          auto_generate_delay = 100,   -- Auto-generation delay (ms)
        },
        
        -- Feature toggles
        add_slash_command = true,      -- Add /gitcommit slash command
        add_git_tool = true,          -- Add @git_read and @git_edit tools, and @git_bot tool group
        add_git_commands = true,      -- Add :CodeCompanionGit commands
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
| `:CodeCompanionGit` | Open Git assistant chat |
| `:CCGit` | Open Git assistant chat (short alias) |

### Git Tool Operations

Use Git tools in CodeCompanion chat:

#### 📖 Read-only Operations (`@git_read`)

```
@git_read status                    # Show repository status
@git_read log --count 5             # Show last 5 commits
@git_read diff --staged             # Show staged changes
@git_read branch                    # List all branches
@git_read contributors --count 10   # Show top 10 contributors
```

#### ✏️ Write Operations (`@git_edit`)

```
@git_edit stage --files ["src/main.lua", "README.md"]
@git_edit create_branch --branch_name "feature/new-ui"
@git_edit stash --message "Work in progress"
@git_edit checkout --target "main"
```

### Workflow Examples

**Quick commit workflow:**
```
@git_read status           # Check status
@git_edit stage --files [...]  # Stage files
:CodeCompanionGitCommit    # Generate commit message
```

**Branch management:**
```
@git_read branch
@git_edit create_branch --branch_name "feature/awesome"
# ... make changes ...
@git_edit stage --files [...]
/gitcommit                 # Generate commit message in chat
```

## ⚙️ Configuration Options

<details>
<summary>Complete configuration options</summary>

```lua
opts = {
  adapter = "openai",                           -- LLM adapter
  model = "gpt-4",                             -- Model name
  languages = { "English", "Chinese" },        -- Supported languages list
  exclude_files = { "*.min.js", "dist/*" },   -- Excluded file patterns
  add_slash_command = true,                    -- Add /gitcommit command
  add_git_tool = true,                        -- Add Git tools
  add_git_commands = true,                    -- Add Git commands
  gitcommit_select_count = 100,               -- Commits shown in /gitcommit
  git_tool_auto_submit_errors = false,       -- Auto-submit errors to LLM
  git_tool_auto_submit_success = false,      -- Auto-submit success to LLM
  buffer = {
    enabled = true,                           -- Enable buffer integration
    keymap = "<leader>gc",                   -- Keymap
    auto_generate = true,                    -- Auto-generate
    auto_generate_delay = 100,              -- Generation delay
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
