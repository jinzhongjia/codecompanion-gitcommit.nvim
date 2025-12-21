local prompts = require("codecompanion._extensions.gitcommit.prompts.release_notes")

---@class CodeCompanion.GitCommit.Tools.AIReleaseNotes
local AIReleaseNotes = {}

AIReleaseNotes.name = "ai_release_notes"
AIReleaseNotes.description = "Generate comprehensive release notes using AI analysis of commit history"

AIReleaseNotes.schema = {
  type = "function",
  ["function"] = {
    name = "ai_release_notes",
    description = "Generate AI-powered release notes by analyzing commit history and changes",
    parameters = {
      type = "object",
      properties = {
        from_tag = {
          type = "string",
          description = "Starting tag/version (if not provided, uses second latest tag)",
        },
        to_tag = {
          type = "string",
          description = "Ending tag/version (if not provided, uses latest tag or HEAD)",
        },
        style = {
          type = "string",
          enum = { "detailed", "concise", "changelog", "marketing" },
          description = "Style of release notes to generate",
        },
      },
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

-- Helper function to get commit details with diffs
local function get_detailed_commits(from_ref, to_ref)
  -- Git range A..B = commits reachable from B but not from A
  -- This correctly excludes from_ref itself and includes up to to_ref
  local range = from_ref .. ".." .. (to_ref or "HEAD")

  local escaped_range = vim.fn.shellescape(range)

  local separator = "---COMMIT_SEPARATOR---"
  local commit_cmd = string.format(
    "git log --pretty=format:'%%H||%%s||%%an||%%b%s' %s",
    separator,
    escaped_range
  )

  local success, output = pcall(vim.fn.system, commit_cmd)
  if not success or vim.v.shell_error ~= 0 then
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
      -- Find the first non-empty line with commit info
      local lines = vim.split(entry, "\n")
      local commit_line = nil
      local body_start_idx = 1

      -- Find the line with the commit info (has || separators)
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
      local success, tags_output = pcall(vim.fn.system, "git tag --sort=-version:refname")
      if success and vim.v.shell_error == 0 and tags_output and vim.trim(tags_output) ~= "" then
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
            local fc_success, first_commit_output = pcall(vim.fn.system, first_commit_cmd)
            if fc_success and vim.v.shell_error == 0 then
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
      return {
        status = "error",
        data = {
          output = error_msg,
          user_msg = "✗ " .. error_msg,
          llm_msg = "<aiReleaseNotes>fail: " .. error_msg .. "</aiReleaseNotes>",
        },
      }
    end

    if #commits == 0 then
      local msg = string.format("No commits found between %s and %s", from_tag, to_tag)
      return {
        status = "success",
        data = {
          output = msg,
          user_msg = "ℹ " .. msg,
          llm_msg = "<aiReleaseNotes>success: " .. msg .. "</aiReleaseNotes>",
        },
      }
    end

    local prompt = prompts.create_smart_prompt(commits, style, { from = from_tag, to = to_tag })

    local user_msg = string.format(
      "📝 Generating %s release notes: %s → %s (%d commits)",
      style,
      from_tag,
      to_tag,
      #commits
    )

    local llm_msg = string.format("<aiReleaseNotes>\n%s\n</aiReleaseNotes>", prompt)

    return {
      status = "success",
      data = {
        output = prompt,
        user_msg = user_msg,
        llm_msg = llm_msg,
      },
    }
  end,
}

AIReleaseNotes.handlers = {
  setup = function(_self, _agent)
    return true
  end,
  on_exit = function(_self, _agent) end,
}

AIReleaseNotes.output = {
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
    local llm_msg = data and data.llm_msg or (type(data) == "string" and data or "AI release notes generation failed")
    local user_msg = data and data.user_msg or "AI release notes generation failed"
    return chat:add_tool_output(self, llm_msg, user_msg)
  end,
}

AIReleaseNotes.opts = {
  -- v18+ uses require_approval_before
  require_approval_before = function(_self, _agent)
    return false
  end,
  -- COMPAT(v17): Remove when dropping v17 support
  requires_approval = function(_self, _agent)
    return false
  end,
}

return AIReleaseNotes
