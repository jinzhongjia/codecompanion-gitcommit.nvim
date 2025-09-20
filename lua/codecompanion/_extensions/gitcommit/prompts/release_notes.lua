local M = {}

-- Prompt templates for different release note styles
M.templates = {
  detailed = {
    intro = [[You are an expert technical writer creating comprehensive release notes.
Analyze the provided git commit history and create detailed release notes that:
- Explain each change thoroughly with context
- Include technical implementation details
- Provide migration guides for breaking changes
- Credit all contributors appropriately
- Add helpful examples where relevant]],

    format = [[
# Release {version}

## 🎯 Overview
[Provide a compelling summary of this release's purpose and main achievements]

## ✨ What's New

### Features
[List and explain new features with examples]

### Improvements
[Detail enhancements to existing functionality]

## 🐛 Bug Fixes
[Describe fixed issues and their impact]

## 💔 Breaking Changes
[List breaking changes with migration instructions]

## 🔧 Technical Details
[Include implementation notes for developers]

## 📊 Statistics
- Total commits: {commit_count}
- Contributors: {contributor_count}
- Files changed: {files_changed}

## 👥 Contributors
[List contributors with their contributions]

## 📝 Full Changelog
[Link or reference to complete commit list]
]],
  },

  concise = {
    intro = [[Create brief, scannable release notes focusing on user impact.
Summarize changes in one-line bullet points, highlighting only the most important updates.]],

    format = [[
# Version {version}

## Key Changes
- [Major feature or change 1]
- [Major feature or change 2]
- [Important bug fix]

## Quick Stats
- {commit_count} commits from {contributor_count} contributors
]],
  },

  changelog = {
    intro = [[Generate a developer-focused CHANGELOG following Keep a Changelog format.
Group changes by type (Added, Changed, Fixed, Deprecated, Removed, Security).
Use technical language and include commit references.]],

    format = [[
## [{version}] - {date}

### Added
- New features and additions

### Changed
- Changes in existing functionality

### Fixed
- Bug fixes

### Deprecated
- Soon-to-be removed features

### Removed
- Removed features

### Security
- Security fixes and improvements

[{version}]: {compare_url}
]],
  },

  marketing = {
    intro = [[Write engaging, user-friendly release notes for a general audience.
Focus on benefits and value, using non-technical language.
Make it exciting and highlight how these changes improve the user experience.]],

    format = [[
# 🎉 {product_name} {version} is Here!

## What's New

### 🌟 Headline Feature
[Exciting description of the main feature and its benefits]

### ✨ More Improvements You'll Love
[User-friendly descriptions of other enhancements]

## 🐛 Squashed Bugs
[Light-hearted mentions of fixed issues]

## 🙏 Thank You
Special thanks to our amazing contributors who made this release possible!

[Call-to-action: Update now, try it out, etc.]
]],
  },
}

-- Helper function to analyze commits for smart categorization
function M.analyze_commits(commits)
  local analysis = {
    features = {},
    fixes = {},
    breaking_changes = {},
    performance = {},
    documentation = {},
    refactoring = {},
    tests = {},
    other = {},
    contributors = {},
    stats = {
      total = #commits,
      by_type = {},
    },
  }

  for _, commit in ipairs(commits) do
    -- Track contributors
    analysis.contributors[commit.author] = (analysis.contributors[commit.author] or 0) + 1

    -- Categorize by conventional commit type
    local category = "other"
    local is_breaking = commit.subject:match("!") or commit.subject:match("BREAKING")

    if is_breaking then
      table.insert(analysis.breaking_changes, commit)
      category = "breaking"
    elseif commit.type == "feat" or commit.type == "feature" then
      table.insert(analysis.features, commit)
      category = "features"
    elseif commit.type == "fix" or commit.type == "bugfix" then
      table.insert(analysis.fixes, commit)
      category = "fixes"
    elseif commit.type == "perf" then
      table.insert(analysis.performance, commit)
      category = "performance"
    elseif commit.type == "docs" then
      table.insert(analysis.documentation, commit)
      category = "documentation"
    elseif commit.type == "refactor" then
      table.insert(analysis.refactoring, commit)
      category = "refactoring"
    elseif commit.type == "test" or commit.type == "tests" then
      table.insert(analysis.tests, commit)
      category = "tests"
    else
      table.insert(analysis.other, commit)
    end

    -- Track stats by type
    analysis.stats.by_type[category] = (analysis.stats.by_type[category] or 0) + 1
  end

  return analysis
end

-- Generate context-aware prompts based on commit analysis
function M.create_smart_prompt(commits, style, version_info)
  local analysis = M.analyze_commits(commits)
  local template = M.templates[style] or M.templates.detailed

  local prompt_parts = {
    template.intro,
    "\n\n",
    "VERSION INFORMATION:\n",
    string.format("- Previous version: %s\n", version_info.from),
    string.format("- New version: %s\n", version_info.to),
    string.format("- Release date: %s\n", os.date("%Y-%m-%d")),
    "\n",
  }

  -- Add commit analysis summary
  table.insert(prompt_parts, "COMMIT ANALYSIS:\n")
  table.insert(prompt_parts, string.format("- Total commits: %d\n", analysis.stats.total))

  if #analysis.features > 0 then
    table.insert(prompt_parts, string.format("- New features: %d\n", #analysis.features))
  end
  if #analysis.fixes > 0 then
    table.insert(prompt_parts, string.format("- Bug fixes: %d\n", #analysis.fixes))
  end
  if #analysis.breaking_changes > 0 then
    table.insert(
      prompt_parts,
      string.format("- BREAKING CHANGES: %d (requires careful documentation)\n", #analysis.breaking_changes)
    )
  end

  local contributor_count = 0
  for _ in pairs(analysis.contributors) do
    contributor_count = contributor_count + 1
  end
  table.insert(prompt_parts, string.format("- Contributors: %d\n\n", contributor_count))

  -- Add categorized commits
  if #analysis.breaking_changes > 0 then
    table.insert(prompt_parts, "⚠️ BREAKING CHANGES:\n")
    for _, commit in ipairs(analysis.breaking_changes) do
      table.insert(prompt_parts, string.format("- %s (by %s)\n", commit.subject, commit.author))
      if commit.body then
        table.insert(prompt_parts, string.format("  Details: %s\n", commit.body))
      end
    end
    table.insert(prompt_parts, "\n")
  end

  if #analysis.features > 0 then
    table.insert(prompt_parts, "NEW FEATURES:\n")
    for _, commit in ipairs(analysis.features) do
      table.insert(prompt_parts, string.format("- %s\n", commit.subject))
    end
    table.insert(prompt_parts, "\n")
  end

  if #analysis.fixes > 0 then
    table.insert(prompt_parts, "BUG FIXES:\n")
    for _, commit in ipairs(analysis.fixes) do
      table.insert(prompt_parts, string.format("- %s\n", commit.subject))
    end
    table.insert(prompt_parts, "\n")
  end

  -- Add other categories if present
  if #analysis.performance > 0 then
    table.insert(prompt_parts, "PERFORMANCE IMPROVEMENTS:\n")
    for _, commit in ipairs(analysis.performance) do
      table.insert(prompt_parts, string.format("- %s\n", commit.subject))
    end
    table.insert(prompt_parts, "\n")
  end

  -- Add format template
  table.insert(prompt_parts, "\nDESIRED OUTPUT FORMAT:\n")
  table.insert(prompt_parts, template.format)
  table.insert(prompt_parts, "\n\nPlease generate the release notes following the above format and guidelines.")

  return table.concat(prompt_parts)
end

return M
