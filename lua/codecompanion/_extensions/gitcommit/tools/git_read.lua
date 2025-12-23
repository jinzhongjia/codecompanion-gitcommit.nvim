local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool
local validation = require("codecompanion._extensions.gitcommit.tools.validation")
local output_utils = require("codecompanion._extensions.gitcommit.tools.output")
local normalize_output = output_utils.normalize_output
local normalize_args = output_utils.normalize_args

---@class CodeCompanion.GitCommit.Tools.GitRead: CodeCompanion.Tools.Tool
local GitRead = {}

GitRead.name = "git_read"

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
local TOOL_NAME = "gitRead"

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
          enum = VALID_OPERATIONS,
          description = "The read-only Git operation to perform.",
        },
        count = {
          type = { "integer", "null" },
          description = "Number of items to show (for log, contributors, etc.)",
        },
        format = {
          type = { "string", "null" },
          description = "Format for log output (oneline, short, medium, full, fuller)",
        },
        staged = {
          type = { "boolean", "null" },
          description = "Whether to show staged changes for diff",
        },
        file_path = {
          type = { "string", "null" },
          description = "Path to a specific file",
        },
        remote_only = {
          type = { "boolean", "null" },
          description = "Show only remote branches",
        },
        commit_hash = {
          type = { "string", "null" },
          description = "Commit hash or reference",
        },
        line_start = {
          type = { "integer", "null" },
          description = "Start line number for blame",
        },
        line_end = {
          type = { "integer", "null" },
          description = "End line number for blame",
        },
        commit1 = {
          type = { "string", "null" },
          description = "First commit for diff_commits",
        },
        commit2 = {
          type = { "string", "null" },
          description = "Second commit for diff_commits",
        },
        pattern = {
          type = { "string", "null" },
          description = "Search pattern for commits",
        },
        gitignore_file = {
          type = { "string", "null" },
          description = "File to check if ignored",
        },
        from_tag = {
          type = { "string", "null" },
          description = "Starting tag for release notes generation (if not provided, uses second latest tag)",
        },
        to_tag = {
          type = { "string", "null" },
          description = "Ending tag for release notes generation (if not provided, uses latest tag)",
        },
        release_format = {
          type = { "string", "null" },
          description = "Format for release notes (markdown, plain, json). Default: markdown",
        },
      },
      required = {
        "operation",
        "count",
        "format",
        "staged",
        "file_path",
        "remote_only",
        "commit_hash",
        "line_start",
        "line_end",
        "commit1",
        "commit2",
        "pattern",
        "gitignore_file",
        "from_tag",
        "to_tag",
        "release_format",
      },
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
- All parameters are passed at the top level (not nested in args).
- Pass null for unused optional parameters.

## AVAILABLE OPERATIONS
| Operation | Description | Parameters |
|-----------|-------------|------------|
| `status` | Show repository status | (none) |
| `log` | Show commit history | count?, format? |
| `diff` | Show file differences | staged?, file_path? |
| `branch` | List branches | remote_only? |
| `remotes` | Show remote repositories | (none) |
| `show` | Show commit details | commit_hash? |
| `blame` | Show file blame info | file_path (required), line_start?, line_end? |
| `stash_list` | List stashes | (none) |
| `diff_commits` | Compare commits | commit1 (required), commit2?, file_path? |
| `contributors` | Show contributors | count? |
| `search_commits` | Search commit messages | pattern (required), count? |
| `tags` | List all tags | (none) |
| `generate_release_notes` | Generate release notes | from_tag?, to_tag?, release_format? |
| `conflict_status` | List files with conflicts | (none) |
| `conflict_show` | Show conflict markers in file | file_path (required) |
| `gitignore_get` | Get .gitignore content | (none) |
| `gitignore_check` | Check if file is ignored | gitignore_file (required) |
| `help` | Show help information | (none) |

## EXAMPLE CALLS
- Status: `{ "operation": "status", "count": null, "format": null, ... }`
- Log: `{ "operation": "log", "count": 5, "format": "oneline", ... }`
- Diff: `{ "operation": "diff", "staged": true, ... }`
- Blame: `{ "operation": "blame", "file_path": "src/main.lua", ... }`

## RESPONSE
- Only invoke this tool when examining Git repository state.
- Choose the most appropriate operation for the user's request.
- For operations requiring file paths, use relative paths from the repository root.]]

GitRead.cmds = {
  function(self, args, _input)
    if args == nil or type(args) ~= "table" then
      return validation.format_error(TOOL_NAME, "Invalid arguments: expected object")
    end

    args = normalize_args(args) -- JSON null → vim.NIL (truthy) → nil

    local operation = args.operation
    local err = validation.require_enum(operation, "operation", VALID_OPERATIONS, TOOL_NAME)
    if err then
      return err
    end

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
          validation.optional_integer(args.count, "count", TOOL_NAME, 1, 1000),
          args.format and validation.require_enum(args.format, "format", VALID_LOG_FORMATS, TOOL_NAME) or nil,
        })
        if param_err then
          return param_err
        end
        success, output, user_msg, llm_msg = GitTool.get_log(args.count, args.format)
      elseif operation == "diff" then
        param_err = validation.first_error({
          validation.optional_boolean(args.staged, "staged", TOOL_NAME),
          validation.optional_string(args.file_path, "file_path", TOOL_NAME),
        })
        if param_err then
          return param_err
        end
        success, output, user_msg, llm_msg = GitTool.get_diff(args.staged, args.file_path)
      elseif operation == "branch" then
        param_err = validation.optional_boolean(args.remote_only, "remote_only", TOOL_NAME)
        if param_err then
          return param_err
        end
        success, output, user_msg, llm_msg = GitTool.get_branches(args.remote_only)
      elseif operation == "remotes" then
        success, output, user_msg, llm_msg = GitTool.get_remotes()
      elseif operation == "show" then
        param_err = validation.optional_string(args.commit_hash, "commit_hash", TOOL_NAME)
        if param_err then
          return param_err
        end
        success, output, user_msg, llm_msg = GitTool.show_commit(args.commit_hash)
      elseif operation == "blame" then
        param_err = validation.first_error({
          validation.require_string(args.file_path, "file_path", TOOL_NAME),
          validation.optional_integer(args.line_start, "line_start", TOOL_NAME, 1),
          validation.optional_integer(args.line_end, "line_end", TOOL_NAME, 1),
        })
        if param_err then
          return param_err
        end
        success, output, user_msg, llm_msg = GitTool.get_blame(args.file_path, args.line_start, args.line_end)
      elseif operation == "stash_list" then
        success, output, user_msg, llm_msg = GitTool.list_stashes()
      elseif operation == "diff_commits" then
        param_err = validation.first_error({
          validation.require_string(args.commit1, "commit1", TOOL_NAME),
          validation.optional_string(args.commit2, "commit2", TOOL_NAME),
          validation.optional_string(args.file_path, "file_path", TOOL_NAME),
        })
        if param_err then
          return param_err
        end
        success, output, user_msg, llm_msg = GitTool.diff_commits(args.commit1, args.commit2, args.file_path)
      elseif operation == "contributors" then
        param_err = validation.optional_integer(args.count, "count", TOOL_NAME, 1, 1000)
        if param_err then
          return param_err
        end
        success, output, user_msg, llm_msg = GitTool.get_contributors(args.count)
      elseif operation == "search_commits" then
        param_err = validation.first_error({
          validation.require_string(args.pattern, "pattern", TOOL_NAME),
          validation.optional_integer(args.count, "count", TOOL_NAME, 1, 1000),
        })
        if param_err then
          return param_err
        end
        success, output, user_msg, llm_msg = GitTool.search_commits(args.pattern, args.count)
      elseif operation == "tags" then
        success, output, user_msg, llm_msg = GitTool.get_tags()
      elseif operation == "generate_release_notes" then
        param_err = validation.first_error({
          validation.optional_string(args.from_tag, "from_tag", TOOL_NAME),
          validation.optional_string(args.to_tag, "to_tag", TOOL_NAME),
          args.release_format
              and validation.require_enum(args.release_format, "release_format", VALID_RELEASE_FORMATS, TOOL_NAME)
            or nil,
        })
        if param_err then
          return param_err
        end
        success, output, user_msg, llm_msg =
          GitTool.generate_release_notes(args.from_tag, args.to_tag, args.release_format)
      elseif operation == "conflict_status" then
        success, output, user_msg, llm_msg = GitTool.get_conflict_status()
      elseif operation == "conflict_show" then
        param_err = validation.require_string(args.file_path, "file_path", TOOL_NAME)
        if param_err then
          return param_err
        end
        success, output, user_msg, llm_msg = GitTool.show_conflict(args.file_path)
      elseif operation == "gitignore_get" then
        success, output, user_msg, llm_msg = GitTool.get_gitignore()
      elseif operation == "gitignore_check" then
        param_err = validation.require_string(args.gitignore_file, "gitignore_file", TOOL_NAME)
        if param_err then
          return param_err
        end
        success, output, user_msg, llm_msg = GitTool.is_ignored(args.gitignore_file)
      end

      return { success = success, output = output, user_msg = user_msg, llm_msg = llm_msg }
    end)

    if not ok then
      local error_msg = "Git read operation failed unexpectedly: " .. tostring(result)
      return { status = "error", data = error_msg }
    end

    if result.status then
      return result
    end

    local op_success, output = result.success, result.output

    if op_success then
      return { status = "success", data = output or "Operation completed" }
    else
      return { status = "error", data = output or "Git read operation failed" }
    end
  end,
}

GitRead.handlers = {
  on_exit = function(self, tools) end,
}

GitRead.output = {
  prompt = function(self, tools)
    local operation = self.args and self.args.operation or "unknown"
    return string.format("Execute git %s?", operation)
  end,

  success = function(self, tools, cmd, stdout)
    local chat = tools.chat
    local operation = self.args and self.args.operation or "unknown"
    local output = normalize_output(stdout)
    local user_msg = string.format("Git %s completed", operation)
    chat:add_tool_output(self, output, user_msg)
  end,

  error = function(self, tools, cmd, stderr, stdout)
    local chat = tools.chat
    local operation = self.args and self.args.operation or "unknown"
    local errors = normalize_output(stderr, "Unknown error")
    local user_msg = string.format("Git %s failed", operation)
    chat:add_tool_output(self, errors, user_msg)
  end,

  rejected = function(self, tools, cmd, opts)
    local operation = self.args and self.args.operation or "unknown"
    local message = string.format("User rejected the git %s operation", operation)
    opts = vim.tbl_extend("force", { message = message }, opts or {})
    local ok, helpers = pcall(require, "codecompanion.interactions.chat.tools.builtin.helpers")
    if ok and helpers and helpers.rejected then
      helpers.rejected(self, tools, cmd, opts)
    else
      tools.chat:add_tool_output(self, message)
    end
  end,
}

GitRead.opts = {
  require_approval_before = function(self, tools)
    return false
  end,
  requires_approval = function(self, tools)
    return false
  end,
}

return GitRead
