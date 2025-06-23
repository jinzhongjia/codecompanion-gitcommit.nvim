-- CodeCompanion GitCommit Extension Configuration Example
-- This file demonstrates how to configure the enhanced GitCommit extension with git tools

return {
  -- Basic configuration
  adapter = "anthropic", -- or "openai", "copilot", etc.
  model = "claude-3-5-sonnet-20241022",

  -- Languages for commit message generation
  languages = { "English", "中文", "日本語", "Français" },

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
    enabled = true,
    keymap = "<leader>gc",
    auto_generate = true,
    auto_generate_delay = 200,
  },

  -- Enable slash command in chat buffer
  add_slash_command = true,

  -- Git tool configuration (NEW)
  add_git_tool = true, -- Add @git_bot tool to CodeCompanion
  add_git_commands = true, -- Add :CodeCompanionGit commands
  git_tool_auto_submit_errors = false, -- Don't auto-submit errors to LLM
  git_tool_auto_submit_success = false, -- Don't auto-submit success to LLM
}
