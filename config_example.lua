-- CodeCompanion GitCommit Extension Configuration Example
-- This file demonstrates how to configure the GitCommit extension with git tools

return {
  -- Basic configuration
  adapter = "anthropic", -- or "openai", "copilot", etc.
  model = "claude-3-5-sonnet-20241022",

  -- Languages for commit message generation
  languages = { "English", "Chinese", "Japanese", "French" },

  -- Files to exclude from git diff (supports glob patterns)
  exclude_files = {
    "*.pb.go", -- Protocol buffer files
    "*.min.js", -- Minified JavaScript
    "*.min.css", -- Minified CSS
    "package-lock.json", -- NPM lock files
    "yarn.lock", -- Yarn lock files
    "*.log", -- Log files
    "dist/*", -- Distribution directories
    "build/*", -- Build directories
    ".next/*", -- Next.js build
    "node_modules/*", -- Node modules
    "vendor/*", -- Vendor directories
  },

  -- Buffer configuration
  buffer = {
    enabled = true, -- Enable buffer integration
    keymap = "<leader>gc", -- Keymap
    auto_generate = true, -- Auto-generate
    auto_generate_delay = 200, -- Auto-generation delay (ms)
    skip_auto_generate_on_amend = true, -- Skip auto-generation during git commit --amend
  },

  -- Feature toggles
  add_slash_command = true, -- Enable slash command in chat buffer
  add_git_tool = true, -- Add @{git_read} and @{git_edit} tools to CodeCompanion
  enable_git_read = true, -- Enable read-only Git operations
  enable_git_edit = true, -- Enable write-access Git operations
  enable_git_bot = true, -- Enable @{git_bot} tool group (requires both read/write enabled)
  add_git_commands = true, -- Add :CodeCompanionGitCommit commands

  -- Git tool configuration
  git_tool_auto_submit_errors = false, -- Don't auto-submit errors to LLM
  git_tool_auto_submit_success = true, -- Auto-submit success to LLM
  gitcommit_select_count = 100, -- Number of recent commits for /gitcommit slash command
}
