local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool
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
        include_stats = {
          type = "boolean",
          description = "Include statistics about changes",
        },
        group_by_type = {
          type = "boolean",
          description = "Group commits by conventional commit types",
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
  -- Get commit log with full details
  local range = from_ref .. ".." .. to_ref
  local escaped_range = vim.fn.shellescape(range)

  -- Get commits with more details
  local commit_cmd =
    string.format("git log --pretty=format:'%%H|%%s|%%b|%%an|%%ae|%%ad' --date=short %s", escaped_range)

  local success, output = pcall(vim.fn.system, commit_cmd)
  if not success or vim.v.shell_error ~= 0 then
    return nil, "Failed to get commit history"
  end

  local commits = {}
  for line in output:gmatch("[^\r\n]+") do
    local parts = vim.split(line, "|")
    if #parts >= 6 then
      local hash = parts[1]
      local subject = parts[2]
      local body = parts[3] ~= "" and parts[3] or nil

      -- Get diff stats for this commit
      local diff_cmd = string.format("git diff --stat %s~1 %s", hash, hash)
      local _, diff_stats = pcall(vim.fn.system, diff_cmd)

      -- Parse conventional commit type
      local commit_type, scope = subject:match("^(%w+)%((.-)%):")
      if not commit_type then
        commit_type = subject:match("^(%w+):")
      end

      table.insert(commits, {
        hash = hash,
        subject = subject,
        body = body,
        author = parts[4],
        email = parts[5],
        date = parts[6],
        type = commit_type,
        scope = scope,
        diff_stats = vim.v.shell_error == 0 and diff_stats or nil,
      })
    end
  end

  return commits, nil
end

-- Generate AI prompt for release notes
local function create_release_notes_prompt(commits, from_tag, to_tag, style, include_stats)
  local prompt_parts = {
    string.format(
      "Generate release notes for version %s (from %s) based on these commits:\n\n",
      to_tag or "HEAD",
      from_tag or "previous version"
    ),
  }

  -- Add commit information
  table.insert(prompt_parts, "COMMIT HISTORY:\n")
  table.insert(prompt_parts, "================\n\n")

  for _, commit in ipairs(commits) do
    table.insert(prompt_parts, string.format("Commit: %s\n", commit.hash:sub(1, 8)))
    table.insert(prompt_parts, string.format("Type: %s\n", commit.type or "other"))
    if commit.scope then
      table.insert(prompt_parts, string.format("Scope: %s\n", commit.scope))
    end
    table.insert(prompt_parts, string.format("Subject: %s\n", commit.subject))
    if commit.body then
      table.insert(prompt_parts, string.format("Body: %s\n", commit.body))
    end
    table.insert(prompt_parts, string.format("Author: %s\n", commit.author))
    table.insert(prompt_parts, string.format("Date: %s\n", commit.date))

    if commit.diff_stats and include_stats then
      table.insert(prompt_parts, "Changes:\n")
      table.insert(prompt_parts, commit.diff_stats)
    end
    table.insert(prompt_parts, "\n---\n\n")
  end

  -- Add style-specific instructions
  local style_instructions = {
    detailed = [[Create comprehensive release notes with:
- Detailed explanation of each feature and fix
- Technical details where relevant
- Migration guides for breaking changes
- Full contributor acknowledgments]],

    concise = [[Create brief release notes with:
- One-line summaries of key changes
- Only the most important features and fixes
- Minimal technical details]],

    changelog = [[Create a developer-focused changelog with:
- Conventional commit grouping (Features, Fixes, Breaking Changes, etc.)
- Technical descriptions
- Links to commits (use short hash)
- Clear upgrade instructions]],

    marketing = [[Create user-friendly marketing release notes with:
- Exciting descriptions of new features
- Benefits to users clearly explained
- Non-technical language
- Emphasis on improvements and value]],
  }

  table.insert(prompt_parts, "\nRELEASE NOTES REQUIREMENTS:\n")
  table.insert(prompt_parts, "============================\n")
  table.insert(prompt_parts, style_instructions[style] or style_instructions.detailed)
  table.insert(prompt_parts, "\n\n")

  -- Add statistics if requested
  if include_stats then
    local stats = {
      total = #commits,
      features = 0,
      fixes = 0,
      breaking = 0,
      contributors = {},
    }

    for _, commit in ipairs(commits) do
      if commit.type == "feat" then
        stats.features = stats.features + 1
      elseif commit.type == "fix" then
        stats.fixes = stats.fixes + 1
      elseif commit.type == "!" or commit.subject:match("BREAKING") then
        stats.breaking = stats.breaking + 1
      end
      stats.contributors[commit.author] = true
    end

    local contributor_count = 0
    for _ in pairs(stats.contributors) do
      contributor_count = contributor_count + 1
    end

    table.insert(prompt_parts, "STATISTICS:\n")
    table.insert(prompt_parts, string.format("- Total commits: %d\n", stats.total))
    table.insert(prompt_parts, string.format("- New features: %d\n", stats.features))
    table.insert(prompt_parts, string.format("- Bug fixes: %d\n", stats.fixes))
    table.insert(prompt_parts, string.format("- Breaking changes: %d\n", stats.breaking))
    table.insert(prompt_parts, string.format("- Contributors: %d\n", contributor_count))
    table.insert(prompt_parts, "\n")
  end

  table.insert(
    prompt_parts,
    [[
Please generate well-formatted release notes based on the above information.
Focus on clarity, completeness, and making the changes understandable to the target audience.
Group related changes together and highlight the most important updates.
]]
  )

  return table.concat(prompt_parts)
end

AIReleaseNotes.cmds = {
  function(self, args, chat)
    local from_tag = args.from_tag
    local to_tag = args.to_tag
    local style = args.style or "detailed"
    local include_stats = args.include_stats ~= false
    local group_by_type = args.group_by_type ~= false

    -- Get tags if not specified
    if not to_tag or not from_tag then
      local success, tags_output = pcall(vim.fn.system, "git tag --sort=-version:refname")
      if success and vim.v.shell_error == 0 then
        local tags = {}
        for tag in tags_output:gmatch("[^\r\n]+") do
          if tag ~= "" then
            table.insert(tags, tag)
          end
        end

        if not to_tag then
          to_tag = tags[1] or "HEAD"
        end
        if not from_tag and #tags > 1 then
          from_tag = tags[2]
        elseif not from_tag then
          -- Get the first commit if no previous tag
          local first_commit = vim.fn.system("git rev-list --max-parents=0 HEAD"):gsub("\n", "")
          from_tag = first_commit:sub(1, 8)
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

    -- Use the smart prompt generator
    local version_info = {
      from = from_tag,
      to = to_tag,
    }

    -- Use the new template system if available, fallback to old method
    local prompt
    if group_by_type and prompts.create_smart_prompt then
      prompt = prompts.create_smart_prompt(commits, style, version_info)
    else
      prompt = create_release_notes_prompt(commits, from_tag, to_tag, style, include_stats)
    end

    -- Return the prompt for the AI to process
    local user_msg = string.format(
      "🤖 Analyzing %d commits between %s and %s to generate %s release notes...\n\nPlease analyze the following commit history and generate release notes:\n\n%s",
      #commits,
      from_tag,
      to_tag,
      style,
      prompt
    )

    local llm_msg = string.format(
      "<aiReleaseNotes>analyze: %s to %s (%d commits)\n%s</aiReleaseNotes>",
      from_tag,
      to_tag,
      #commits,
      prompt
    )

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
  requires_approval = function(_self, _agent)
    return false
  end,
}

return AIReleaseNotes
