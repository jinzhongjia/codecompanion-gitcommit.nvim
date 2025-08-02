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

-- Helper function to validate required parameters
local function validate_required_param(param_name, param_value, error_msg)
  if not param_value or param_value == "" then
    return {
      status = "error",
      data = {
        output = error_msg or (param_name .. " is required"),
        user_msg = error_msg or (param_name .. " is required"),
        llm_msg = "<gitReadTool>fail: " .. (error_msg or (param_name .. " is required")) .. "</gitReadTool>",
      },
    }
  end
  return nil
end

GitRead.cmds = {
  function(self, args, _input)
    local operation = args.operation
    local op_args = args.args or {}

    if operation == "help" then
      local help_text =
        "\\\nAvailable read-only Git operations:\n• status: Show repository status\n• log: Show commit history\n• diff: Show file differences\n• branch: List branches\n• remotes: Show remote repositories\n• show: Show commit details\n• blame: Show file blame info\n• stash_list: List stashes\n• diff_commits: Compare commits\n• contributors: Show contributors\n• search_commits: Search commit messages\n• tags: List all tags\n• generate_release_notes: Generate release notes between tags\n• gitignore_get: Get .gitignore content\n• gitignore_check: Check if a file is ignored\n      "
      return { status = "success", data = help_text }
    end

    local success, output, user_msg, llm_msg

    -- Safely execute operations through pcall to ensure there's always a response
    local ok, result = pcall(function()
      if operation == "status" then
        success, output, user_msg, llm_msg = GitTool.get_status()
      elseif operation == "log" then
        success, output, user_msg, llm_msg = GitTool.get_log(op_args.count, op_args.format)
      elseif operation == "diff" then
        success, output, user_msg, llm_msg = GitTool.get_diff(op_args.staged, op_args.file_path)
      elseif operation == "branch" then
        success, output, user_msg, llm_msg = GitTool.get_branches(op_args.remote_only)
      elseif operation == "remotes" then
        success, output, user_msg, llm_msg = GitTool.get_remotes()
      elseif operation == "show" then
        success, output, user_msg, llm_msg = GitTool.show_commit(op_args.commit_hash)
      elseif operation == "blame" then
        local validation_error =
          validate_required_param("file_path", op_args.file_path, "File path is required for blame")
        if validation_error then
          return validation_error
        end
        success, output, user_msg, llm_msg = GitTool.get_blame(op_args.file_path, op_args.line_start, op_args.line_end)
      elseif operation == "stash_list" then
        success, output, user_msg, llm_msg = GitTool.list_stashes()
      elseif operation == "diff_commits" then
        local validation_error =
          validate_required_param("commit1", op_args.commit1, "First commit is required for comparison")
        if validation_error then
          return validation_error
        end
        success, output, user_msg, llm_msg = GitTool.diff_commits(op_args.commit1, op_args.commit2, op_args.file_path)
      elseif operation == "contributors" then
        success, output, user_msg, llm_msg = GitTool.get_contributors(op_args.count)
      elseif operation == "search_commits" then
        local validation_error = validate_required_param("pattern", op_args.pattern, "Search pattern is required")
        if validation_error then
          return validation_error
        end
        success, output, user_msg, llm_msg = GitTool.search_commits(op_args.pattern, op_args.count)
      elseif operation == "tags" then
        success, output, user_msg, llm_msg = GitTool.get_tags()
      elseif operation == "generate_release_notes" then
        success, output, user_msg, llm_msg =
          GitTool.generate_release_notes(op_args.from_tag, op_args.to_tag, op_args.release_format)
      elseif operation == "gitignore_get" then
        success, output, user_msg, llm_msg = GitTool.get_gitignore()
      elseif operation == "gitignore_check" then
        local validation_error =
          validate_required_param("gitignore_file", op_args.gitignore_file, "No file specified for .gitignore check")
        if validation_error then
          return validation_error
        end
        success, output, user_msg, llm_msg = GitTool.is_ignored(op_args.gitignore_file)
      else
        return {
          status = "error",
          data = {
            output = "Unknown Git read operation: " .. operation,
            user_msg = "Unknown Git read operation: " .. operation,
            llm_msg = "<gitReadTool>fail: Unknown Git read operation: " .. operation .. "</gitReadTool>",
          },
        }
      end

      return { success = success, output = output, user_msg = user_msg, llm_msg = llm_msg }
    end)

    -- Handle unexpected execution errors
    if not ok then
      local error_msg = "Git read operation failed unexpectedly: " .. tostring(result)
      return {
        status = "error",
        data = {
          output = error_msg,
          user_msg = error_msg,
          llm_msg = "<gitReadTool>fail: " .. error_msg .. "</gitReadTool>",
        },
      }
    end

    local success, output, user_msg, llm_msg = result.success, result.output, result.user_msg, result.llm_msg

    -- Ensure proper response format even if operation fails
    if success then
      return { status = "success", data = { output = output, user_msg = user_msg, llm_msg = llm_msg } }
    else
      -- Ensure consistent error message format
      local formatted_output = {
        output = output or "Git read operation failed",
        user_msg = user_msg or "Git read operation failed",
        llm_msg = llm_msg or "<gitReadTool>fail: Git read operation failed</gitReadTool>",
      }
      return { status = "error", data = formatted_output }
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
    local data = stdout[1]
    local llm_msg = data and data.llm_msg or data.output
    local user_msg = data and data.user_msg or data.output
    return chat:add_tool_output(self, llm_msg, user_msg)
  end,
  error = function(self, agent, _cmd, stderr, stdout)
    local chat = agent.chat
    local data = stderr[1] or stdout[1]
    local llm_msg = data and data.llm_msg or (type(data) == "string" and data or "Git read operation failed")
    local user_msg = data and data.user_msg or "Git read operation failed"
    return chat:add_tool_output(self, llm_msg, user_msg)
  end,
}

GitRead.opts = {
  requires_approval = function(_self, _agent)
    return false
  end,
}

return GitRead
