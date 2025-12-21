local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool
local validation = require("codecompanion._extensions.gitcommit.tools.validation")

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
            "conflict_status",
            "conflict_show",
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

GitRead.system_prompt = [[# Git Read Tool (`git_read`)

## CONTEXT
- You have access to a read-only Git tool running within CodeCompanion, in Neovim.
- Use this tool to examine repository status, history, branches, and configurations.
- All operations are non-destructive and safe to execute.

## OBJECTIVE
- Follow the tool's schema strictly.
- Use the appropriate operation for the task.
- Provide clear and accurate Git information to the user.

## AVAILABLE OPERATIONS
| Operation | Description | Required Args |
|-----------|-------------|---------------|
| `status` | Show repository status | - |
| `log` | Show commit history | count?, format? |
| `diff` | Show file differences | staged?, file_path? |
| `branch` | List branches | remote_only? |
| `remotes` | Show remote repositories | - |
| `show` | Show commit details | commit_hash? |
| `blame` | Show file blame info | file_path (required) |
| `stash_list` | List stashes | - |
| `diff_commits` | Compare commits | commit1 (required), commit2? |
| `contributors` | Show contributors | count? |
| `search_commits` | Search commit messages | pattern (required) |
| `tags` | List all tags | - |
| `generate_release_notes` | Generate release notes | from_tag?, to_tag? |
| `conflict_status` | List files with conflicts | - |
| `conflict_show` | Show conflict markers in file | file_path (required) |
| `gitignore_get` | Get .gitignore content | - |
| `gitignore_check` | Check if file is ignored | gitignore_file (required) |
| `help` | Show help information | - |

## RESPONSE
- Only invoke this tool when examining Git repository state.
- Choose the most appropriate operation for the user's request.
- For operations requiring file paths, use relative paths from the repository root.]]

local TOOL_NAME = "gitRead"
local VALID_OPERATIONS = {
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
  "conflict_status",
  "conflict_show",
  "help",
  "gitignore_get",
  "gitignore_check",
}
local VALID_LOG_FORMATS = { "oneline", "short", "medium", "full", "fuller" }
local VALID_RELEASE_FORMATS = { "markdown", "plain", "json" }

GitRead.cmds = {
  function(self, args, _input)
    if args == nil or type(args) ~= "table" then
      return validation.format_error(TOOL_NAME, "Invalid arguments: expected object")
    end

    local operation = args.operation
    local err = validation.require_enum(operation, "operation", VALID_OPERATIONS, TOOL_NAME)
    if err then
      return err
    end

    local op_args = args.args
    if op_args ~= nil and type(op_args) ~= "table" then
      return validation.format_error(TOOL_NAME, "args must be an object")
    end
    op_args = op_args or {}

    if operation == "help" then
      local help_text =
        "\\\nAvailable read-only Git operations:\n• status: Show repository status\n• log: Show commit history\n• diff: Show file differences\n• branch: List branches\n• remotes: Show remote repositories\n• show: Show commit details\n• blame: Show file blame info\n• stash_list: List stashes\n• diff_commits: Compare commits\n• contributors: Show contributors\n• search_commits: Search commit messages\n• tags: List all tags\n• generate_release_notes: Generate release notes between tags\n• conflict_status: List files with merge conflicts\n• conflict_show: Show conflict markers in a file\n• gitignore_get: Get .gitignore content\n• gitignore_check: Check if a file is ignored\n      "
      return { status = "success", data = help_text }
    end

    local success, output, user_msg, llm_msg
    local param_err

    local ok, result = pcall(function()
      if operation == "status" then
        success, output, user_msg, llm_msg = GitTool.get_status()
      elseif operation == "log" then
        param_err = validation.first_error({
          validation.optional_integer(op_args.count, "count", TOOL_NAME, 1, 1000),
          op_args.format and validation.require_enum(op_args.format, "format", VALID_LOG_FORMATS, TOOL_NAME) or nil,
        })
        if param_err then
          return param_err
        end
        success, output, user_msg, llm_msg = GitTool.get_log(op_args.count, op_args.format)
      elseif operation == "diff" then
        param_err = validation.first_error({
          validation.optional_boolean(op_args.staged, "staged", TOOL_NAME),
          validation.optional_string(op_args.file_path, "file_path", TOOL_NAME),
        })
        if param_err then
          return param_err
        end
        success, output, user_msg, llm_msg = GitTool.get_diff(op_args.staged, op_args.file_path)
      elseif operation == "branch" then
        param_err = validation.optional_boolean(op_args.remote_only, "remote_only", TOOL_NAME)
        if param_err then
          return param_err
        end
        success, output, user_msg, llm_msg = GitTool.get_branches(op_args.remote_only)
      elseif operation == "remotes" then
        success, output, user_msg, llm_msg = GitTool.get_remotes()
      elseif operation == "show" then
        param_err = validation.optional_string(op_args.commit_hash, "commit_hash", TOOL_NAME)
        if param_err then
          return param_err
        end
        success, output, user_msg, llm_msg = GitTool.show_commit(op_args.commit_hash)
      elseif operation == "blame" then
        param_err = validation.first_error({
          validation.require_string(op_args.file_path, "file_path", TOOL_NAME),
          validation.optional_integer(op_args.line_start, "line_start", TOOL_NAME, 1),
          validation.optional_integer(op_args.line_end, "line_end", TOOL_NAME, 1),
        })
        if param_err then
          return param_err
        end
        success, output, user_msg, llm_msg = GitTool.get_blame(op_args.file_path, op_args.line_start, op_args.line_end)
      elseif operation == "stash_list" then
        success, output, user_msg, llm_msg = GitTool.list_stashes()
      elseif operation == "diff_commits" then
        param_err = validation.first_error({
          validation.require_string(op_args.commit1, "commit1", TOOL_NAME),
          validation.optional_string(op_args.commit2, "commit2", TOOL_NAME),
          validation.optional_string(op_args.file_path, "file_path", TOOL_NAME),
        })
        if param_err then
          return param_err
        end
        success, output, user_msg, llm_msg = GitTool.diff_commits(op_args.commit1, op_args.commit2, op_args.file_path)
      elseif operation == "contributors" then
        param_err = validation.optional_integer(op_args.count, "count", TOOL_NAME, 1, 1000)
        if param_err then
          return param_err
        end
        success, output, user_msg, llm_msg = GitTool.get_contributors(op_args.count)
      elseif operation == "search_commits" then
        param_err = validation.first_error({
          validation.require_string(op_args.pattern, "pattern", TOOL_NAME),
          validation.optional_integer(op_args.count, "count", TOOL_NAME, 1, 1000),
        })
        if param_err then
          return param_err
        end
        success, output, user_msg, llm_msg = GitTool.search_commits(op_args.pattern, op_args.count)
      elseif operation == "tags" then
        success, output, user_msg, llm_msg = GitTool.get_tags()
      elseif operation == "generate_release_notes" then
        param_err = validation.first_error({
          validation.optional_string(op_args.from_tag, "from_tag", TOOL_NAME),
          validation.optional_string(op_args.to_tag, "to_tag", TOOL_NAME),
          op_args.release_format
              and validation.require_enum(op_args.release_format, "release_format", VALID_RELEASE_FORMATS, TOOL_NAME)
            or nil,
        })
        if param_err then
          return param_err
        end
        success, output, user_msg, llm_msg =
          GitTool.generate_release_notes(op_args.from_tag, op_args.to_tag, op_args.release_format)
      elseif operation == "conflict_status" then
        success, output, user_msg, llm_msg = GitTool.get_conflict_status()
      elseif operation == "conflict_show" then
        param_err = validation.require_string(op_args.file_path, "file_path", TOOL_NAME)
        if param_err then
          return param_err
        end
        success, output, user_msg, llm_msg = GitTool.show_conflict(op_args.file_path)
      elseif operation == "gitignore_get" then
        success, output, user_msg, llm_msg = GitTool.get_gitignore()
      elseif operation == "gitignore_check" then
        param_err = validation.require_string(op_args.gitignore_file, "gitignore_file", TOOL_NAME)
        if param_err then
          return param_err
        end
        success, output, user_msg, llm_msg = GitTool.is_ignored(op_args.gitignore_file)
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
  prompt = function(self, _tools)
    local operation = self.args and self.args.operation or "unknown"
    return string.format("Execute git %s?", operation)
  end,

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

  rejected = function(self, tools, _cmd, _opts)
    local chat = tools.chat
    local operation = self.args and self.args.operation or "unknown"
    local message = string.format("User rejected the git %s operation", operation)
    return chat:add_tool_output(self, message, message)
  end,
}

GitRead.opts = {
  -- v18+ uses require_approval_before
  require_approval_before = function(_self, _agent)
    return false
  end,
  -- COMPAT(v17): Remove when dropping v17 support
  requires_approval = function(_self, _agent)
    return false
  end,
}

return GitRead
