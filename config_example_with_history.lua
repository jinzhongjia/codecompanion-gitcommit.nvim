-- Example configuration showing how to use the new commit history feature

require("codecompanion").setup({
  adapters = {
    openai = function()
      return require("codecompanion.adapters").extend("openai", {
        env = {
          api_key = "your_api_key_here",
        },
      })
    end,
  },
  extensions = {
    -- GitCommit extension with history context enabled
    gitcommit = {
      callback = "codecompanion._extensions.gitcommit",
      opts = {
        -- Core configuration
        adapter = "openai",
        model = "gpt-4-turbo-preview",
        languages = { "English", "Chinese" },

        -- NEW: History commit context configuration
        use_commit_history = true, -- Enable using commit history as context
        commit_history_count = 15, -- Use 15 recent commits for context (default: 10)

        -- Existing configuration options
        buffer = {
          enabled = true,
          keymap = "<leader>gc",
          auto_generate = true,
          auto_generate_delay = 200,
          skip_auto_generate_on_amend = true,
        },

        exclude_files = {
          "*.pb.go",
          "*.min.js",
          "package-lock.json",
          "yarn.lock",
          "*.log",
          "dist/*",
          "build/*",
          "node_modules/*",
        },

        add_git_tool = true,
        enable_git_read = true,
        enable_git_edit = true,
        enable_git_bot = true,
        git_tool_auto_submit_success = true,
      },
    },
  },
})

-- Alternative configuration with history disabled
-- gitcommit = {
--   callback = "codecompanion._extensions.gitcommit",
--   opts = {
--     use_commit_history = false,  -- Disable history context
--     -- ... other options
--   }
-- }
