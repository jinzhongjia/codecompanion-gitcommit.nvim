local h = require("tests.helpers")
local new_set = MiniTest.new_set

local child = MiniTest.new_child_neovim()

local T = new_set({
  hooks = {
    pre_case = function()
      h.child_start(child)
    end,
    post_once = child.stop,
  },
})

-- =============================================================================
-- style_guides
-- =============================================================================

T["style_guides"] = new_set()

T["style_guides"]["has detailed style"] = function()
  local result = child.lua([[
    local ReleaseNotes = require("codecompanion._extensions.gitcommit.prompts.release_notes")
    return ReleaseNotes.style_guides.detailed ~= nil
  ]])
  h.eq(true, result)
end

T["style_guides"]["has concise style"] = function()
  local result = child.lua([[
    local ReleaseNotes = require("codecompanion._extensions.gitcommit.prompts.release_notes")
    return ReleaseNotes.style_guides.concise ~= nil
  ]])
  h.eq(true, result)
end

T["style_guides"]["has changelog style"] = function()
  local result = child.lua([[
    local ReleaseNotes = require("codecompanion._extensions.gitcommit.prompts.release_notes")
    return ReleaseNotes.style_guides.changelog ~= nil
  ]])
  h.eq(true, result)
end

T["style_guides"]["has marketing style"] = function()
  local result = child.lua([[
    local ReleaseNotes = require("codecompanion._extensions.gitcommit.prompts.release_notes")
    return ReleaseNotes.style_guides.marketing ~= nil
  ]])
  h.eq(true, result)
end

T["style_guides"]["detailed style mentions technical"] = function()
  local result = child.lua([[
    local ReleaseNotes = require("codecompanion._extensions.gitcommit.prompts.release_notes")
    return ReleaseNotes.style_guides.detailed:find("technical") ~= nil
  ]])
  h.eq(true, result)
end

T["style_guides"]["concise style mentions brief"] = function()
  local result = child.lua([[
    local ReleaseNotes = require("codecompanion._extensions.gitcommit.prompts.release_notes")
    return ReleaseNotes.style_guides.concise:find("brief") ~= nil
  ]])
  h.eq(true, result)
end

-- =============================================================================
-- base_instructions
-- =============================================================================

T["base_instructions"] = new_set()

T["base_instructions"]["exists and is not empty"] = function()
  local result = child.lua([[
    local ReleaseNotes = require("codecompanion._extensions.gitcommit.prompts.release_notes")
    return ReleaseNotes.base_instructions ~= nil and #ReleaseNotes.base_instructions > 0
  ]])
  h.eq(true, result)
end

T["base_instructions"]["contains critical rules"] = function()
  local result = child.lua([[
    local ReleaseNotes = require("codecompanion._extensions.gitcommit.prompts.release_notes")
    return ReleaseNotes.base_instructions:find("CRITICAL") ~= nil
  ]])
  h.eq(true, result)
end

-- =============================================================================
-- analyze_commits
-- =============================================================================

T["analyze_commits"] = new_set()

T["analyze_commits"]["returns table with expected categories"] = function()
  local result = child.lua([[
    local ReleaseNotes = require("codecompanion._extensions.gitcommit.prompts.release_notes")
    local analysis = ReleaseNotes.analyze_commits({})
    return {
      has_features = analysis.features ~= nil,
      has_fixes = analysis.fixes ~= nil,
      has_breaking = analysis.breaking_changes ~= nil,
      has_performance = analysis.performance ~= nil,
      has_documentation = analysis.documentation ~= nil,
      has_refactoring = analysis.refactoring ~= nil,
      has_tests = analysis.tests ~= nil,
      has_chore = analysis.chore ~= nil,
      has_other = analysis.other ~= nil,
      has_contributors = analysis.contributors ~= nil,
    }
  ]])
  h.eq(true, result.has_features)
  h.eq(true, result.has_fixes)
  h.eq(true, result.has_breaking)
  h.eq(true, result.has_performance)
  h.eq(true, result.has_documentation)
  h.eq(true, result.has_refactoring)
  h.eq(true, result.has_tests)
  h.eq(true, result.has_chore)
  h.eq(true, result.has_other)
  h.eq(true, result.has_contributors)
end

T["analyze_commits"]["categorizes feat commits"] = function()
  local result = child.lua([[
    local ReleaseNotes = require("codecompanion._extensions.gitcommit.prompts.release_notes")
    local commits = {
      { subject = "feat: add new feature", type = "feat", author = "user1" },
    }
    local analysis = ReleaseNotes.analyze_commits(commits)
    return #analysis.features
  ]])
  h.eq(1, result)
end

T["analyze_commits"]["categorizes fix commits"] = function()
  local result = child.lua([[
    local ReleaseNotes = require("codecompanion._extensions.gitcommit.prompts.release_notes")
    local commits = {
      { subject = "fix: resolve bug", type = "fix", author = "user1" },
    }
    local analysis = ReleaseNotes.analyze_commits(commits)
    return #analysis.fixes
  ]])
  h.eq(1, result)
end

T["analyze_commits"]["categorizes breaking changes with exclamation mark"] = function()
  local result = child.lua([[
    local ReleaseNotes = require("codecompanion._extensions.gitcommit.prompts.release_notes")
    local commits = {
      { subject = "feat!: breaking change", type = "feat", author = "user1" },
    }
    local analysis = ReleaseNotes.analyze_commits(commits)
    return #analysis.breaking_changes
  ]])
  h.eq(1, result)
end

T["analyze_commits"]["categorizes breaking changes with scope and exclamation"] = function()
  local result = child.lua([[
    local ReleaseNotes = require("codecompanion._extensions.gitcommit.prompts.release_notes")
    local commits = {
      { subject = "feat(api)!: breaking api change", type = "feat", author = "user1" },
    }
    local analysis = ReleaseNotes.analyze_commits(commits)
    return #analysis.breaking_changes
  ]])
  h.eq(1, result)
end

T["analyze_commits"]["categorizes breaking changes with BREAKING keyword"] = function()
  local result = child.lua([[
    local ReleaseNotes = require("codecompanion._extensions.gitcommit.prompts.release_notes")
    local commits = {
      { subject = "feat: BREAKING CHANGE in api", type = "feat", author = "user1" },
    }
    local analysis = ReleaseNotes.analyze_commits(commits)
    return #analysis.breaking_changes
  ]])
  h.eq(1, result)
end

T["analyze_commits"]["categorizes perf commits"] = function()
  local result = child.lua([[
    local ReleaseNotes = require("codecompanion._extensions.gitcommit.prompts.release_notes")
    local commits = {
      { subject = "perf: improve speed", type = "perf", author = "user1" },
    }
    local analysis = ReleaseNotes.analyze_commits(commits)
    return #analysis.performance
  ]])
  h.eq(1, result)
end

T["analyze_commits"]["categorizes docs commits"] = function()
  local result = child.lua([[
    local ReleaseNotes = require("codecompanion._extensions.gitcommit.prompts.release_notes")
    local commits = {
      { subject = "docs: update readme", type = "docs", author = "user1" },
    }
    local analysis = ReleaseNotes.analyze_commits(commits)
    return #analysis.documentation
  ]])
  h.eq(1, result)
end

T["analyze_commits"]["categorizes refactor commits"] = function()
  local result = child.lua([[
    local ReleaseNotes = require("codecompanion._extensions.gitcommit.prompts.release_notes")
    local commits = {
      { subject = "refactor: clean up code", type = "refactor", author = "user1" },
    }
    local analysis = ReleaseNotes.analyze_commits(commits)
    return #analysis.refactoring
  ]])
  h.eq(1, result)
end

T["analyze_commits"]["categorizes test commits"] = function()
  local result = child.lua([[
    local ReleaseNotes = require("codecompanion._extensions.gitcommit.prompts.release_notes")
    local commits = {
      { subject = "test: add unit tests", type = "test", author = "user1" },
    }
    local analysis = ReleaseNotes.analyze_commits(commits)
    return #analysis.tests
  ]])
  h.eq(1, result)
end

T["analyze_commits"]["categorizes chore commits"] = function()
  local result = child.lua([[
    local ReleaseNotes = require("codecompanion._extensions.gitcommit.prompts.release_notes")
    local commits = {
      { subject = "chore: update deps", type = "chore", author = "user1" },
    }
    local analysis = ReleaseNotes.analyze_commits(commits)
    return #analysis.chore
  ]])
  h.eq(1, result)
end

T["analyze_commits"]["categorizes build commits as chore"] = function()
  local result = child.lua([[
    local ReleaseNotes = require("codecompanion._extensions.gitcommit.prompts.release_notes")
    local commits = {
      { subject = "build: update config", type = "build", author = "user1" },
    }
    local analysis = ReleaseNotes.analyze_commits(commits)
    return #analysis.chore
  ]])
  h.eq(1, result)
end

T["analyze_commits"]["categorizes ci commits as chore"] = function()
  local result = child.lua([[
    local ReleaseNotes = require("codecompanion._extensions.gitcommit.prompts.release_notes")
    local commits = {
      { subject = "ci: add workflow", type = "ci", author = "user1" },
    }
    local analysis = ReleaseNotes.analyze_commits(commits)
    return #analysis.chore
  ]])
  h.eq(1, result)
end

T["analyze_commits"]["categorizes unknown type as other"] = function()
  local result = child.lua([[
    local ReleaseNotes = require("codecompanion._extensions.gitcommit.prompts.release_notes")
    local commits = {
      { subject = "misc: random change", type = "misc", author = "user1" },
    }
    local analysis = ReleaseNotes.analyze_commits(commits)
    return #analysis.other
  ]])
  h.eq(1, result)
end

T["analyze_commits"]["tracks contributors"] = function()
  local result = child.lua([[
    local ReleaseNotes = require("codecompanion._extensions.gitcommit.prompts.release_notes")
    local commits = {
      { subject = "feat: feature 1", type = "feat", author = "alice" },
      { subject = "fix: fix 1", type = "fix", author = "bob" },
      { subject = "feat: feature 2", type = "feat", author = "alice" },
    }
    local analysis = ReleaseNotes.analyze_commits(commits)
    return {
      alice_count = analysis.contributors["alice"],
      bob_count = analysis.contributors["bob"],
    }
  ]])
  h.eq(2, result.alice_count)
  h.eq(1, result.bob_count)
end

T["analyze_commits"]["handles multiple commit types"] = function()
  local result = child.lua([[
    local ReleaseNotes = require("codecompanion._extensions.gitcommit.prompts.release_notes")
    local commits = {
      { subject = "feat: new feature", type = "feat", author = "user1" },
      { subject = "fix: bug fix", type = "fix", author = "user2" },
      { subject = "docs: update docs", type = "docs", author = "user1" },
      { subject = "test: add tests", type = "test", author = "user3" },
    }
    local analysis = ReleaseNotes.analyze_commits(commits)
    return {
      features = #analysis.features,
      fixes = #analysis.fixes,
      docs = #analysis.documentation,
      tests = #analysis.tests,
    }
  ]])
  h.eq(1, result.features)
  h.eq(1, result.fixes)
  h.eq(1, result.docs)
  h.eq(1, result.tests)
end

-- =============================================================================
-- create_smart_prompt
-- =============================================================================

T["create_smart_prompt"] = new_set()

T["create_smart_prompt"]["returns string"] = function()
  local result = child.lua([[
    local ReleaseNotes = require("codecompanion._extensions.gitcommit.prompts.release_notes")
    local commits = {
      { subject = "feat: new feature", type = "feat", author = "user1" },
    }
    local prompt = ReleaseNotes.create_smart_prompt(commits, "detailed", { from = "v1.0", to = "v1.1" })
    return type(prompt)
  ]])
  h.eq("string", result)
end

T["create_smart_prompt"]["includes version info"] = function()
  local result = child.lua([[
    local ReleaseNotes = require("codecompanion._extensions.gitcommit.prompts.release_notes")
    local commits = {
      { subject = "feat: new feature", type = "feat", author = "user1" },
    }
    local prompt = ReleaseNotes.create_smart_prompt(commits, "detailed", { from = "v1.0.0", to = "v2.0.0" })
    return {
      has_from = prompt:find("v1.0.0") ~= nil,
      has_to = prompt:find("v2.0.0") ~= nil,
    }
  ]])
  h.eq(true, result.has_from)
  h.eq(true, result.has_to)
end

T["create_smart_prompt"]["includes commit count"] = function()
  local result = child.lua([[
    local ReleaseNotes = require("codecompanion._extensions.gitcommit.prompts.release_notes")
    local commits = {
      { subject = "feat: feature 1", type = "feat", author = "user1" },
      { subject = "feat: feature 2", type = "feat", author = "user2" },
      { subject = "fix: fix 1", type = "fix", author = "user1" },
    }
    local prompt = ReleaseNotes.create_smart_prompt(commits, "detailed", { from = "v1.0", to = "v1.1" })
    return prompt:find("Total commits: 3") ~= nil
  ]])
  h.eq(true, result)
end

T["create_smart_prompt"]["includes style guide for detailed"] = function()
  local result = child.lua([[
    local ReleaseNotes = require("codecompanion._extensions.gitcommit.prompts.release_notes")
    local commits = {
      { subject = "feat: new feature", type = "feat", author = "user1" },
    }
    local prompt = ReleaseNotes.create_smart_prompt(commits, "detailed", { from = "v1.0", to = "v1.1" })
    return prompt:find("comprehensive") ~= nil
  ]])
  h.eq(true, result)
end

T["create_smart_prompt"]["includes style guide for concise"] = function()
  local result = child.lua([[
    local ReleaseNotes = require("codecompanion._extensions.gitcommit.prompts.release_notes")
    local commits = {
      { subject = "feat: new feature", type = "feat", author = "user1" },
    }
    local prompt = ReleaseNotes.create_smart_prompt(commits, "concise", { from = "v1.0", to = "v1.1" })
    return prompt:find("brief") ~= nil
  ]])
  h.eq(true, result)
end

T["create_smart_prompt"]["includes style guide for changelog"] = function()
  local result = child.lua([[
    local ReleaseNotes = require("codecompanion._extensions.gitcommit.prompts.release_notes")
    local commits = {
      { subject = "feat: new feature", type = "feat", author = "user1" },
    }
    local prompt = ReleaseNotes.create_smart_prompt(commits, "changelog", { from = "v1.0", to = "v1.1" })
    return prompt:find("CHANGELOG") ~= nil
  ]])
  h.eq(true, result)
end

T["create_smart_prompt"]["includes style guide for marketing"] = function()
  local result = child.lua([[
    local ReleaseNotes = require("codecompanion._extensions.gitcommit.prompts.release_notes")
    local commits = {
      { subject = "feat: new feature", type = "feat", author = "user1" },
    }
    local prompt = ReleaseNotes.create_smart_prompt(commits, "marketing", { from = "v1.0", to = "v1.1" })
    return prompt:find("user%-friendly") ~= nil
  ]])
  h.eq(true, result)
end

T["create_smart_prompt"]["falls back to detailed for unknown style"] = function()
  local result = child.lua([[
    local ReleaseNotes = require("codecompanion._extensions.gitcommit.prompts.release_notes")
    local commits = {
      { subject = "feat: new feature", type = "feat", author = "user1" },
    }
    local prompt = ReleaseNotes.create_smart_prompt(commits, "unknown_style", { from = "v1.0", to = "v1.1" })
    return prompt:find("comprehensive") ~= nil
  ]])
  h.eq(true, result)
end

T["create_smart_prompt"]["includes contributors"] = function()
  local result = child.lua([[
    local ReleaseNotes = require("codecompanion._extensions.gitcommit.prompts.release_notes")
    local commits = {
      { subject = "feat: feature 1", type = "feat", author = "alice" },
      { subject = "fix: fix 1", type = "fix", author = "bob" },
    }
    local prompt = ReleaseNotes.create_smart_prompt(commits, "detailed", { from = "v1.0", to = "v1.1" })
    return {
      has_alice = prompt:find("alice") ~= nil,
      has_bob = prompt:find("bob") ~= nil,
    }
  ]])
  h.eq(true, result.has_alice)
  h.eq(true, result.has_bob)
end

T["create_smart_prompt"]["includes Features section for feat commits"] = function()
  local result = child.lua([[
    local ReleaseNotes = require("codecompanion._extensions.gitcommit.prompts.release_notes")
    local commits = {
      { subject = "feat: new feature", type = "feat", author = "user1" },
    }
    local prompt = ReleaseNotes.create_smart_prompt(commits, "detailed", { from = "v1.0", to = "v1.1" })
    return prompt:find("### Features") ~= nil
  ]])
  h.eq(true, result)
end

T["create_smart_prompt"]["includes Bug Fixes section for fix commits"] = function()
  local result = child.lua([[
    local ReleaseNotes = require("codecompanion._extensions.gitcommit.prompts.release_notes")
    local commits = {
      { subject = "fix: bug fix", type = "fix", author = "user1" },
    }
    local prompt = ReleaseNotes.create_smart_prompt(commits, "detailed", { from = "v1.0", to = "v1.1" })
    return prompt:find("### Bug Fixes") ~= nil
  ]])
  h.eq(true, result)
end

T["create_smart_prompt"]["includes Breaking Changes section"] = function()
  local result = child.lua([[
    local ReleaseNotes = require("codecompanion._extensions.gitcommit.prompts.release_notes")
    local commits = {
      { subject = "feat!: breaking change", type = "feat", author = "user1" },
    }
    local prompt = ReleaseNotes.create_smart_prompt(commits, "detailed", { from = "v1.0", to = "v1.1" })
    return prompt:find("Breaking Changes") ~= nil
  ]])
  h.eq(true, result)
end

T["create_smart_prompt"]["includes commit hash for detailed style"] = function()
  local result = child.lua([[
    local ReleaseNotes = require("codecompanion._extensions.gitcommit.prompts.release_notes")
    local commits = {
      { subject = "feat: new feature", type = "feat", author = "user1", hash = "abc1234567890" },
    }
    local prompt = ReleaseNotes.create_smart_prompt(commits, "detailed", { from = "v1.0", to = "v1.1" })
    return prompt:find("abc1234") ~= nil
  ]])
  h.eq(true, result)
end

T["create_smart_prompt"]["includes commit hash for changelog style"] = function()
  local result = child.lua([[
    local ReleaseNotes = require("codecompanion._extensions.gitcommit.prompts.release_notes")
    local commits = {
      { subject = "feat: new feature", type = "feat", author = "user1", hash = "def5678901234" },
    }
    local prompt = ReleaseNotes.create_smart_prompt(commits, "changelog", { from = "v1.0", to = "v1.1" })
    return prompt:find("def5678") ~= nil
  ]])
  h.eq(true, result)
end

T["create_smart_prompt"]["excludes commit hash for concise style"] = function()
  local result = child.lua([[
    local ReleaseNotes = require("codecompanion._extensions.gitcommit.prompts.release_notes")
    local commits = {
      { subject = "feat: new feature", type = "feat", author = "user1", hash = "xyz9876543210" },
    }
    local prompt = ReleaseNotes.create_smart_prompt(commits, "concise", { from = "v1.0", to = "v1.1" })
    return prompt:find("xyz9876") == nil
  ]])
  h.eq(true, result)
end

T["create_smart_prompt"]["handles empty commits"] = function()
  local result = child.lua([[
    local ReleaseNotes = require("codecompanion._extensions.gitcommit.prompts.release_notes")
    local commits = {}
    local prompt = ReleaseNotes.create_smart_prompt(commits, "detailed", { from = "v1.0", to = "v1.1" })
    return {
      is_string = type(prompt) == "string",
      has_no_categorized = prompt:find("No categorized commits") ~= nil,
    }
  ]])
  h.eq(true, result.is_string)
  h.eq(true, result.has_no_categorized)
end

T["create_smart_prompt"]["includes markdown code block instruction"] = function()
  local result = child.lua([[
    local ReleaseNotes = require("codecompanion._extensions.gitcommit.prompts.release_notes")
    local commits = {
      { subject = "feat: new feature", type = "feat", author = "user1" },
    }
    local prompt = ReleaseNotes.create_smart_prompt(commits, "detailed", { from = "v1.0", to = "v1.1" })
    return prompt:find("```markdown") ~= nil
  ]])
  h.eq(true, result)
end

return T
