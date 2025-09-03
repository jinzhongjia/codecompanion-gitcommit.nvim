local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool

---@class CodeCompanion.GitCommit.Tools.GitRead
local GitRead = {}

GitRead.name = "git_read"
GitRead.description = "Tool for read-only Git operations like status, log, diff, etc."

GitRead.schema = {
  type = "function",
  ["function"] = {
    name = "git_read",
    description = "Execute various read-only Git operations.",
    parameters = {
      type = "object",
      properties = {
        operation = {
          type = "string",
          enum = {
            "status",
            "log",
            "diff",
            "branch",
            "remotes",
            "show",
            "blame",
            "stash_list",
            "diff_commits",
            "contributors",
            "search_commits",
            "tags",
            "generate_release_notes",
            "help",
            "gitignore_get",
            "gitignore_check",
          },
          description = "The read-only Git operation to perform.",
        },
        args = {
          type = "object",
          properties = {
            count = {
              type = "integer",
              description = "Number of items to show (for log, contributors, etc.)",
            },
            format = {
              type = "string",
              description = "Format for log output (oneline, short, medium, full, fuller)",
            },
            staged = {
              type = "boolean",
              description = "Whether to show staged changes for diff",
            },
            file_path = {
              type = "string",
              description = "Path to a specific file",
            },
            remote_only = {
              type = "boolean",
              description = "Show only remote branches",
            },
            commit_hash = {
              type = "string",
              description = "Commit hash or reference",
            },
            line_start = {
              type = "integer",
              description = "Start line number for blame",
            },
            line_end = {
              type = "integer",
              description = "End line number for blame",
            },
            commit1 = {
              type = "string",
              description = "First commit for diff",
            },
            commit2 = {
              type = "string",
              description = "Second commit for diff",
            },
            pattern = {
              type = "string",
              description = "Search pattern for commits",
            },
            gitignore_file = {
              type = "string",
              description = "File to check if ignored",
            },
            from_tag = {
              type = "string",
              description = "Starting tag for release notes generation (if not provided, uses second latest tag)",
            },
            to_tag = {
              type = "string",
              description = "Ending tag for release notes generation (if not provided, uses latest tag)",
            },
            release_format = {
              type = "string",
              description = "Format for release notes (markdown, plain, json)",
              default = "markdown",
            },
          },
          additionalProperties = false,
        },
      },
      required = { "operation" },
      additionalProperties = false,
    },
    strict = true,
  },
}

GitRead.system_prompt = [[Execute read-only Git repository operations

When to use:
• When examining repository status and history
• When analyzing code changes and diffs
• When investigating commit patterns and contributors
• When checking branch states and configurations

Best practices:
• Must verify Git repository before operations
• Use specific operation parameters for targeted results
• Avoid operations that modify repository state
• Ensure operation args match expected parameters

Available operations: status, log, diff, branch, remotes, show, blame, stash_list, diff_commits, contributors, search_commits, tags, generate_release_notes, gitignore_get, gitignore_check, help]]

GitRead.cmds = {
  function(self, args, _input)
    local operation = args.operation
    local op_args = args.args or {}

    if operation == "help" then
      local help_text = [[Available read-only Git operations:
• status: Show repository status
• log: Show commit history
• diff: Show file differences
• branch: List branches
• remotes: Show remote repositories
• show: Show commit details
• blame: Show file blame info
• stash_list: List stashes
• diff_commits: Compare commits
• contributors: Show contributors
• search_commits: Search commit messages
• tags: List all tags
• generate_release_notes: Generate release notes between tags
• gitignore_get: Get .gitignore content
• gitignore_check: Check if a file is ignored]]
      return { status = "success", data = help_text }
    end

    local success, output

    -- Safely execute operations through pcall to ensure there's always a response
    local ok, result = pcall(function()
      if operation == "status" then
        success, output = GitTool.get_status()
      elseif operation == "log" then
        success, output = GitTool.get_log(op_args.count, op_args.format)
      elseif operation == "diff" then
        success, output = GitTool.get_diff(op_args.staged, op_args.file_path)
      elseif operation == "branch" then
        success, output = GitTool.get_branches(op_args.remote_only)
      elseif operation == "remotes" then
        success, output = GitTool.get_remotes()
      elseif operation == "show" then
        success, output = GitTool.show_commit(op_args.commit_hash)
      elseif operation == "blame" then
        if not op_args.file_path or op_args.file_path == "" then
          return { status = "error", data = "File path is required for blame" }
        end
        success, output = GitTool.get_blame(op_args.file_path, op_args.line_start, op_args.line_end)
      elseif operation == "stash_list" then
        success, output = GitTool.list_stashes()
      elseif operation == "diff_commits" then
        if not op_args.commit1 or op_args.commit1 == "" then
          return { status = "error", data = "First commit is required for comparison" }
        end
        success, output = GitTool.diff_commits(op_args.commit1, op_args.commit2, op_args.file_path)
      elseif operation == "contributors" then
        success, output = GitTool.get_contributors(op_args.count)
      elseif operation == "search_commits" then
        if not op_args.pattern or op_args.pattern == "" then
          return { status = "error", data = "Search pattern is required" }
        end
        success, output = GitTool.search_commits(op_args.pattern, op_args.count)
      elseif operation == "tags" then
        success, output = GitTool.get_tags()
      elseif operation == "generate_release_notes" then
        success, output = GitTool.generate_release_notes(op_args.from_tag, op_args.to_tag, op_args.release_format)
      elseif operation == "gitignore_get" then
        success, output = GitTool.get_gitignore()
      elseif operation == "gitignore_check" then
        if not op_args.gitignore_file or op_args.gitignore_file == "" then
          return { status = "error", data = "No file specified for .gitignore check" }
        end
        success, output = GitTool.is_ignored(op_args.gitignore_file)
      else
        return { status = "error", data = "Unknown Git read operation: " .. operation }
      end

      return { success = success, output = output }
    end)

    -- Handle unexpected execution errors
    if not ok then
      local error_msg = "Git read operation failed unexpectedly: " .. tostring(result)
      return { status = "error", data = error_msg }
    end

    -- Check if this is an early return (validation error)
    if result.status then
      return result
    end

    local success, output = result.success, result.output

    -- Return consistent format
    if success then
      return { status = "success", data = output }
    else
      return { status = "error", data = output or "Git read operation failed" }
    end
  end,
}

GitRead.handlers = {
  setup = function(_self, _agent)
    return true
  end,
  on_exit = function(_self, _agent) end,
}

GitRead.output = {
  success = function(self, agent, _cmd, stdout)
    local chat = agent.chat
    local operation = self.args.operation
    local output = stdout[1] or ""

    -- Prepare messages for LLM and user
    local llm_msg, user_msg

    if output and vim.trim(output) ~= "" then
      -- For LLM: raw output is often better for processing
      llm_msg = output

      -- For user: formatted for readability
      if output:find("\n") then
        user_msg = string.format("Git %s output:\n```\n%s\n```", operation, output)
      else
        user_msg = string.format("Git %s: %s", operation, output)
      end
    else
      -- Empty output messages
      local empty_messages = {
        status = "No changes found",
        diff = "No differences found",
        stash_list = "No stashes found",
        tags = "No tags found",
        branch = "No branches found",
        remotes = "No remotes configured",
      }
      local empty_msg = empty_messages[operation] or string.format("No output from git %s", operation)
      llm_msg = empty_msg
      user_msg = string.format("Git %s completed: %s", operation, empty_msg)
    end

    -- Use standard add_tool_output format
    -- First param: for LLM (not shown to user), Second param: for user (shown in chat)
    return chat:add_tool_output(self, llm_msg, user_msg)
  end,

  error = function(self, agent, _cmd, stderr, stdout)
    local chat = agent.chat
    local operation = self.args.operation
    local error_msg = stderr[1] or stdout[1] or "Unknown error"

    -- For LLM: raw error message
    local llm_msg = string.format("Git %s operation failed: %s", operation, error_msg)

    -- For user: more friendly error message
    local user_msg = string.format("❌ Git %s failed: %s", operation, error_msg)

    -- Send both messages
    return chat:add_tool_output(self, llm_msg, user_msg)
  end,
}

GitRead.opts = {
  requires_approval = false, -- Read operations don't need approval
}

return GitRead
