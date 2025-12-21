local M = {}

M.style_guides = {
  detailed = [[You are creating comprehensive release notes for developers.
Write thorough explanations of changes with technical context.
Include migration guides for breaking changes and code examples where helpful.
Credit contributors and explain the "why" behind significant changes.]],

  concise = [[You are creating brief, scannable release notes.
Use one-line bullet points. Focus only on user-facing changes.
Skip internal refactoring and minor fixes unless significant.
Readers should understand key changes in under 30 seconds.]],

  changelog = [[You are creating a CHANGELOG following Keep a Changelog format.
Group by: Added, Changed, Fixed, Deprecated, Removed, Security.
Use technical language. Include commit hashes in parentheses.
Only include sections that have content.]],

  marketing = [[You are creating user-friendly release notes for end users.
Focus on benefits, not implementation. Use non-technical language.
Make it engaging - highlight how changes improve user experience.
Skip internal changes that don't affect users.]],
}

M.base_instructions = [[
CRITICAL RULES:
- Only include sections that have actual content - skip empty categories entirely
- Do NOT use placeholder text like "[description here]" - write real content or omit
- Adapt structure to fit the actual changes - small releases need simple notes
- Group related commits together when they serve the same purpose
- For trivial releases (1-3 small commits), keep notes proportionally brief

WRITING GUIDELINES:
- Lead with the most impactful changes
- Explain "why" changes matter, not just "what" changed
- Convert commit messages into user-friendly descriptions
- Merge similar commits into single entries when appropriate
]]

local function format_commit(commit)
  local parts = { string.format("- %s", commit.subject) }
  if commit.author then
    table.insert(parts, string.format(" (@%s)", commit.author))
  end
  if commit.body and #commit.body > 0 then
    table.insert(parts, string.format("\n  > %s", commit.body:gsub("\n", "\n  > ")))
  end
  return table.concat(parts)
end

local function format_category(name, commits)
  if #commits == 0 then
    return nil
  end
  local lines = { string.format("\n### %s", name) }
  for _, commit in ipairs(commits) do
    table.insert(lines, format_commit(commit))
  end
  return table.concat(lines, "\n")
end

function M.analyze_commits(commits)
  local analysis = {
    features = {},
    fixes = {},
    breaking_changes = {},
    performance = {},
    documentation = {},
    refactoring = {},
    tests = {},
    chore = {},
    other = {},
    contributors = {},
  }

  for _, commit in ipairs(commits) do
    analysis.contributors[commit.author] = (analysis.contributors[commit.author] or 0) + 1

    local is_breaking = commit.subject:match("!:") or commit.subject:upper():match("BREAKING")

    if is_breaking then
      table.insert(analysis.breaking_changes, commit)
    elseif commit.type == "feat" or commit.type == "feature" then
      table.insert(analysis.features, commit)
    elseif commit.type == "fix" or commit.type == "bugfix" then
      table.insert(analysis.fixes, commit)
    elseif commit.type == "perf" then
      table.insert(analysis.performance, commit)
    elseif commit.type == "docs" or commit.type == "doc" then
      table.insert(analysis.documentation, commit)
    elseif commit.type == "refactor" then
      table.insert(analysis.refactoring, commit)
    elseif commit.type == "test" or commit.type == "tests" then
      table.insert(analysis.tests, commit)
    elseif commit.type == "chore" or commit.type == "build" or commit.type == "ci" then
      table.insert(analysis.chore, commit)
    else
      table.insert(analysis.other, commit)
    end
  end

  return analysis
end

function M.create_smart_prompt(commits, style, version_info)
  local analysis = M.analyze_commits(commits)
  local guide = M.style_guides[style] or M.style_guides.detailed

  local parts = {}

  table.insert(parts, guide)
  table.insert(parts, "\n\n")
  table.insert(parts, M.base_instructions)
  table.insert(parts, "\n\n---\n\n")

  table.insert(parts, "## Release Context\n")
  table.insert(parts, string.format("From: %s → To: %s\n", version_info.from, version_info.to))
  table.insert(parts, string.format("Date: %s\n", os.date("%Y-%m-%d")))
  table.insert(parts, string.format("Total commits: %d\n", #commits))

  local contributor_names = {}
  for name, count in pairs(analysis.contributors) do
    table.insert(contributor_names, string.format("%s (%d)", name, count))
  end
  if #contributor_names > 0 then
    table.insert(parts, string.format("Contributors: %s\n", table.concat(contributor_names, ", ")))
  end

  table.insert(parts, "\n---\n\n## Commits by Category\n")

  local categories = {
    { "⚠️ Breaking Changes", analysis.breaking_changes },
    { "Features", analysis.features },
    { "Bug Fixes", analysis.fixes },
    { "Performance", analysis.performance },
    { "Refactoring", analysis.refactoring },
    { "Documentation", analysis.documentation },
    { "Tests", analysis.tests },
    { "Chore/Build/CI", analysis.chore },
    { "Other", analysis.other },
  }

  local has_content = false
  for _, cat in ipairs(categories) do
    local section = format_category(cat[1], cat[2])
    if section then
      table.insert(parts, section)
      has_content = true
    end
  end

  if not has_content then
    table.insert(parts, "\n(No categorized commits found)\n")
  end

  table.insert(parts, "\n\n---\n\n")
  table.insert(parts, "Generate release notes based on the commits above. ")
  table.insert(parts, "Adapt the structure and length to match the actual content.")

  return table.concat(parts)
end

return M
