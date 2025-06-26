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
              description = "Format for log output (oneline, short, full, etc.)",
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

GitRead.system_prompt =
  "## Git Read Tool (`git_read`)\n- You have access to a read-only Git tool.\n- You can perform operations like status, diff, log, and branch listing.\n- Always check if you're in a Git repository before performing operations.\n- Use this tool to gather information about the repository state.\n\n## AVAILABLE OPERATIONS\n- `status`: Show repository status\n- `log`: Show commit history (args: count, format)\n- `diff`: Show differences (args: staged, file_path)\n- `branch`: List branches (args: remote_only)\n- `remotes`: Show remote repositories\n- `show`: Show commit details (args: commit_hash)\n- `blame`: Show file blame information (args: file_path, line_start, line_end)\n- `stash_list`: List stashes\n- `diff_commits`: Compare commits (args: commit1, commit2, file_path)\n- `contributors`: Show top contributors (args: count)\n- `search_commits`: Search commits by message (args: pattern, count)\n- `gitignore_get`: Get the content of the .gitignore file\n- `gitignore_check`: Check if a file is ignored by .gitignore\n- `help`: Show available read operations\n"

GitRead.cmds = {
  function(self, args, input)
    local operation = args.operation
    local op_args = args.args or {}

    if operation == "help" then
      local help_text =
        "\\\nAvailable read-only Git operations:\n• status: Show repository status\n• log: Show commit history\n• diff: Show file differences\n• branch: List branches\n• remotes: Show remote repositories\n• show: Show commit details\n• blame: Show file blame info\n• stash_list: List stashes\n• diff_commits: Compare commits\n• contributors: Show contributors\n• search_commits: Search commit messages\n• gitignore_get: Get .gitignore content\n• gitignore_check: Check if a file is ignored\n      "
      return { status = "success", data = help_text }
    end

    local success, output

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
      if not op_args.file_path then
        return { status = "error", data = "File path is required for blame" }
      end
      success, output = GitTool.get_blame(op_args.file_path, op_args.line_start, op_args.line_end)
    elseif operation == "stash_list" then
      success, output = GitTool.list_stashes()
    elseif operation == "diff_commits" then
      if not op_args.commit1 then
        return { status = "error", data = "First commit is required for comparison" }
      end
      success, output = GitTool.diff_commits(op_args.commit1, op_args.commit2, op_args.file_path)
    elseif operation == "contributors" then
      success, output = GitTool.get_contributors(op_args.count)
    elseif operation == "search_commits" then
      if not op_args.pattern then
        return { status = "error", data = "Search pattern is required" }
      end
      success, output = GitTool.search_commits(op_args.pattern, op_args.count)
    elseif operation == "gitignore_get" then
      success, output = GitTool.get_gitignore()
    elseif operation == "gitignore_check" then
      local file = op_args.gitignore_file
      if not file then
        return { status = "error", data = "No file specified for .gitignore check" }
      end
      success, output = GitTool.is_ignored(file)
    else
      return { status = "error", data = "Unknown Git read operation: " .. operation }
    end

    if success then
      return { status = "success", data = output }
    else
      return { status = "error", data = output }
    end
  end,
}

GitRead.handlers = {
  setup = function(self, agent)
    return true
  end,
  on_exit = function(self, agent) end,
}

GitRead.output = {
  success = function(self, agent, cmd, stdout)
    local chat = agent.chat
    local operation = self.args.operation
    local user_msg = string.format("Git operation [%s] completed", operation)
    return chat:add_tool_output(self, stdout[1], user_msg)
  end,
  error = function(self, agent, cmd, stderr, stdout)
    local chat = agent.chat
    local error_msg = stderr[1] or "Git read operation failed"
    local user_msg = "Git read operation failed"
    return chat:add_tool_output(self, error_msg, user_msg)
  end,
}

GitRead.opts = {
  requires_approval = function(self, agent)
    return false
  end,
}

return GitRead
