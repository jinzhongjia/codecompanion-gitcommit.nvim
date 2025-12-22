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

T["clean_commit_message"] = new_set()

T["clean_commit_message"]["returns trimmed message"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    return GitUtils.clean_commit_message("  feat: add feature  ")
  ]])
  h.eq("feat: add feature", result)
end

T["clean_commit_message"]["removes markdown code block"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    return GitUtils.clean_commit_message("```\nfeat: add feature\n```")
  ]])
  h.eq("feat: add feature", result)
end

T["clean_commit_message"]["removes markdown code block with language identifier"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    return GitUtils.clean_commit_message("```text\nfeat: add feature\n```")
  ]])
  h.eq("feat: add feature", result)
end

T["clean_commit_message"]["removes quadruple backtick code blocks"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    return GitUtils.clean_commit_message("````\nfeat: add feature\n````")
  ]])
  h.eq("feat: add feature", result)
end

T["clean_commit_message"]["handles multiline commit message"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    local input = "```\nfeat: add feature\n\nThis is the body.\n```"
    return GitUtils.clean_commit_message(input)
  ]])
  h.eq("feat: add feature\n\nThis is the body.", result)
end

T["clean_commit_message"]["preserves message without code blocks"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    return GitUtils.clean_commit_message("feat: simple message")
  ]])
  h.eq("feat: simple message", result)
end

T["clean_commit_message"]["handles empty string"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    return GitUtils.clean_commit_message("")
  ]])
  h.eq("", result)
end

T["clean_commit_message"]["handles only whitespace"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    return GitUtils.clean_commit_message("   \n   ")
  ]])
  h.eq("", result)
end

T["clean_commit_message"]["handles code block with only backticks"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    return GitUtils.clean_commit_message("```\n```")
  ]])
  h.eq("", result)
end

T["clean_commit_message"]["does not remove inline backticks"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    return GitUtils.clean_commit_message("feat: add `config` option")
  ]])
  h.eq("feat: add `config` option", result)
end

T["build_commit_prompt"] = new_set()

T["build_commit_prompt"]["returns string"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    local prompt = GitUtils.build_commit_prompt("diff content", "English", nil)
    return type(prompt) == "string"
  ]])
  h.eq(true, result)
end

T["build_commit_prompt"]["includes diff content"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    local prompt = GitUtils.build_commit_prompt("my-unique-diff-content", "English", nil)
    return prompt:find("my%-unique%-diff%-content") ~= nil
  ]])
  h.eq(true, result)
end

T["build_commit_prompt"]["includes language"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    local prompt = GitUtils.build_commit_prompt("diff", "Japanese", nil)
    return prompt:find("Japanese") ~= nil
  ]])
  h.eq(true, result)
end

T["build_commit_prompt"]["includes commit history when provided"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    local history = { "feat: first commit", "fix: second commit" }
    local prompt = GitUtils.build_commit_prompt("diff", "English", history)
    return prompt:find("RECENT COMMIT HISTORY") ~= nil
  ]])
  h.eq(true, result)
end

T["build_commit_prompt"]["includes all history entries"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    local history = { "feat: first commit", "fix: second commit" }
    local prompt = GitUtils.build_commit_prompt("diff", "English", history)
    return prompt:find("feat: first commit") ~= nil and prompt:find("fix: second commit") ~= nil
  ]])
  h.eq(true, result)
end

T["build_commit_prompt"]["excludes history section when nil"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    local prompt = GitUtils.build_commit_prompt("diff", "English", nil)
    return prompt:find("RECENT COMMIT HISTORY") == nil
  ]])
  h.eq(true, result)
end

T["build_commit_prompt"]["excludes history section when empty"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    local prompt = GitUtils.build_commit_prompt("diff", "English", {})
    return prompt:find("RECENT COMMIT HISTORY") == nil
  ]])
  h.eq(true, result)
end

T["build_commit_prompt"]["mentions conventional commit types"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    local prompt = GitUtils.build_commit_prompt("diff", "English", nil)
    return prompt:find("feat") ~= nil and prompt:find("fix") ~= nil and prompt:find("refactor") ~= nil
  ]])
  h.eq(true, result)
end

T["build_commit_prompt"]["includes formatting rules"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    local prompt = GitUtils.build_commit_prompt("diff", "English", nil)
    return prompt:find("50 char") ~= nil or prompt:find("72 char") ~= nil
  ]])
  h.eq(true, result)
end

T["build_commit_prompt"]["defaults to English when lang is nil"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    local prompt = GitUtils.build_commit_prompt("diff", nil, nil)
    return prompt:find("English") ~= nil
  ]])
  h.eq(true, result)
end

return T
