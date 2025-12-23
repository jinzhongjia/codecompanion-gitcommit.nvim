local prompts = require("codecompanion._extensions.gitcommit.prompts.release_notes")
local git_utils = require("codecompanion._extensions.gitcommit.git_utils")
local Command = require("codecompanion._extensions.gitcommit.tools.command")
local normalize_output = require("codecompanion._extensions.gitcommit.tools.output").normalize_output

local CommandExecutor = Command.CommandExecutor
local shell_quote = git_utils.shell_quote

---@class CodeCompanion.GitCommit.Tools.AIReleaseNotes: CodeCompanion.Tools.Tool
local AIReleaseNotes = {}

AIReleaseNotes.name = "ai_release_notes"

AIReleaseNotes.schema = {
  type = "function",
  ["function"] = {
    name = "ai_release_notes",
    description = "Generate AI-powered release notes by analyzing commit history and changes",
    parameters = {
      type = "object",
      properties = {
        from_tag = {
          type = { "string", "null" },
          description = "Starting tag/version (if not provided, uses second latest tag)",
        },
        to_tag = {
          type = { "string", "null" },
          description = "Ending tag/version (if not provided, uses latest tag or HEAD)",
        },
        style = {
          type = { "string", "null" },
          enum = { "detailed", "concise", "changelog", "marketing" },
          description = "Style of release notes to generate. Default: detailed",
        },
      },
      required = { "from_tag", "to_tag", "style" },
      additionalProperties = false,
    },
    strict = true,
  },
}

AIReleaseNotes.system_prompt = [[Generate comprehensive release notes by analyzing git commit history.

You will:
1. Analyze commit messages and diffs to understand changes
2. Group related changes logically
3. Write clear, user-friendly descriptions
4. Highlight breaking changes, new features, and important fixes
5. Credit contributors appropriately

Output styles:
- detailed: Comprehensive notes with technical details
- concise: Brief summary of key changes
- changelog: Developer-focused changelog format
- marketing: User-friendly marketing release notes]]

---@param from_ref string Starting reference (tag or commit hash)
---@param to_ref string Ending reference (tag or commit hash or HEAD)
---@return table|nil, string|nil Commits array and error message
local function get_detailed_commits(from_ref, to_ref)
  -- Git range A..B = commits reachable from B but not from A
  -- This correctly excludes from_ref itself and includes up to to_ref
  local range = from_ref .. ".." .. (to_ref or "HEAD")

  local escaped_range = vim.fn.shellescape(range)

  local separator = "---COMMIT_SEPARATOR---"
  local format_str = shell_quote("%H||%s||%an||%b" .. separator)
  local commit_cmd = string.format("git log --pretty=format:%s %s", format_str, escaped_range)

  local success, output = CommandExecutor.run(commit_cmd)
  if not success then
    return nil, "Failed to get commit history"
  end

  -- Handle empty output
  if not output or vim.trim(output) == "" then
    return {}, nil
  end

  local commits = {}
  -- Split by separator to get individual commits
  local commit_entries = vim.split(output, separator, { plain = true })

  for _, entry in ipairs(commit_entries) do
    if entry and vim.trim(entry) ~= "" then
      -- Find first non-empty line with commit info
      local lines = vim.split(entry, "\n")
      local commit_line = nil
      local body_start_idx = 1

      -- Find line with commit info (has || separators)
      for i, line in ipairs(lines) do
        if line:match("||") then
          commit_line = line
          body_start_idx = i + 1
          break
        end
      end

      if commit_line then
        local parts = vim.split(commit_line, "||", { plain = true })

        if #parts >= 3 then
          local hash = vim.trim(parts[1] or "")
          local subject = vim.trim(parts[2] or "")
          local author = vim.trim(parts[3] or "")

          local body = nil
          local body_lines = {}

          if #parts > 3 and vim.trim(parts[4]) ~= "" then
            table.insert(body_lines, vim.trim(parts[4]))
          end

          for i = body_start_idx, #lines do
            local line = vim.trim(lines[i])
            if line ~= "" then
              table.insert(body_lines, line)
            end
          end

          if #body_lines > 0 then
            body = table.concat(body_lines, "\n")
          end

          local commit_type = subject:match("^(%w+)%b():") or subject:match("^(%w+):")

          table.insert(commits, {
            hash = hash,
            subject = subject,
            body = body,
            author = author,
            type = commit_type,
          })
        end
      end
    end
  end

  return commits, nil
end

AIReleaseNotes.cmds = {
  function(_, args)
    local from_tag = args.from_tag
    local to_tag = args.to_tag
    local style = args.style or "detailed"

    -- Get tags if not specified
    if not to_tag or not from_tag then
      -- Try to get tags sorted by version
      local success, tags_output = CommandExecutor.run("git tag --sort=-version:refname")
      if success and tags_output and vim.trim(tags_output) ~= "" then
        local tags = {}
        for tag in tags_output:gmatch("[^\r\n]+") do
          local trimmed = vim.trim(tag)
          if trimmed ~= "" then
            table.insert(tags, trimmed)
          end
        end

        -- Set to_tag if not specified
        if not to_tag then
          if #tags > 0 then
            to_tag = tags[1] -- Use latest tag
          else
            to_tag = "HEAD" -- No tags, use HEAD
          end
        end

        -- Set from_tag if not specified
        if not from_tag then
          if #tags > 1 then
            from_tag = tags[2] -- Use previous tag
          elseif #tags == 1 then
            -- Only one tag, get first commit as starting point
            local first_commit_cmd = "git rev-list --max-parents=0 HEAD"
            local fc_success, first_commit_output = CommandExecutor.run(first_commit_cmd)
            if fc_success and first_commit_output and vim.trim(first_commit_output) ~= "" then
              from_tag = vim.trim(first_commit_output):sub(1, 8)
            else
              -- Fallback to 10 commits ago
              from_tag = "HEAD~10"
            end
          else
            -- No tags at all, use HEAD~10 as a reasonable default
            from_tag = "HEAD~10"
          end
        end
      else
        -- No tags or git command failed
        if not to_tag then
          to_tag = "HEAD"
        end
        if not from_tag then
          from_tag = "HEAD~10" -- Default to last 10 commits
        end
      end
    end

    -- Get detailed commit history
    local commits, error_msg = get_detailed_commits(from_tag, to_tag)
    if not commits then
      return { status = "error", data = error_msg }
    end

    if #commits == 0 then
      local msg = string.format("No commits found between %s and %s", from_tag, to_tag)
      return { status = "success", data = msg }
    end

    local prompt = prompts.create_smart_prompt(commits, style, { from = from_tag, to = to_tag })

    return { status = "success", data = prompt }
  end,
}

AIReleaseNotes.handlers = {
  on_exit = function(self, tools) end,
}

AIReleaseNotes.output = {
  success = function(self, tools, cmd, stdout)
    local chat = tools.chat
    local output = normalize_output(stdout)
    local user_msg = "Release notes generated"
    chat:add_tool_output(self, output, user_msg)
  end,
  error = function(self, tools, cmd, stderr, stdout)
    local chat = tools.chat
    local errors = normalize_output(stderr, "Unknown error")
    local user_msg = "Release notes generation failed"
    chat:add_tool_output(self, errors, user_msg)
  end,
}

AIReleaseNotes.opts = {
  require_approval_before = function(self, tools)
    return false
  end,
  requires_approval = function(self, tools)
    return false
  end,
}

return AIReleaseNotes
