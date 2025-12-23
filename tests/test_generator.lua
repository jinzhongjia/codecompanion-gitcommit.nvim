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
    return prompt:find("BEGIN HISTORY") ~= nil
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
    return prompt:find("BEGIN HISTORY") == nil
  ]])
  h.eq(true, result)
end

T["build_commit_prompt"]["excludes history section when empty"] = function()
  local result = child.lua([[
    local GitUtils = require("codecompanion._extensions.gitcommit.git_utils")
    local prompt = GitUtils.build_commit_prompt("diff", "English", {})
    return prompt:find("BEGIN HISTORY") == nil
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

T["generate_commit_message"] = new_set()

T["generate_commit_message"]["returns error when adapter cannot resolve"] = function()
  local result = child.lua([[
    package.preload["codecompanion.adapters"] = function()
      return { resolve = function() return nil end }
    end
    package.preload["codecompanion.schema"] = function()
      return { get_default = function() return {} end }
    end
    package.preload["codecompanion.http"] = function()
      return { new = function() return {} end }
    end

    local Generator = require("codecompanion._extensions.gitcommit.generator")
    Generator.setup("missing", nil)
    local out, err
    Generator.generate_commit_message("diff", "English", nil, function(result, error)
      out = result
      err = error
    end)
    local function norm(value)
      return value == nil and vim.NIL or value
    end
    return { out = norm(out), err = norm(err) }
  ]])
  h.eq(vim.NIL, result.out)
  h.expect_match("Failed to resolve adapter", result.err)
end

T["generate_commit_message"]["returns error for unsupported adapter type"] = function()
  local result = child.lua([[
    package.preload["codecompanion.adapters"] = function()
      return { resolve = function() return { type = "unknown" } end }
    end
    package.preload["codecompanion.schema"] = function()
      return { get_default = function() return {} end }
    end
    package.preload["codecompanion.http"] = function()
      return { new = function() return {} end }
    end

    local Generator = require("codecompanion._extensions.gitcommit.generator")
    local out, err
    Generator.generate_commit_message("diff", "English", nil, function(result, error)
      out = result
      err = error
    end)
    local function norm(value)
      return value == nil and vim.NIL or value
    end
    return { out = norm(out), err = norm(err) }
  ]])
  h.eq(vim.NIL, result.out)
  h.expect_match("Invalid or unsupported adapter type", result.err)
end

T["generate_commit_message"]["cleans streamed HTTP output"] = function()
  local result = child.lua([[
    package.preload["codecompanion.adapters"] = function()
      return {
        resolve = function()
          return {
            type = "http",
            name = "test",
            formatted_name = "Test",
            schema = { model = { default = "model" } },
            map_schema_to_params = function(self) return self end,
            map_roles = function(_, messages) return messages end,
          }
        end,
        call_handler = function(_, _, chunk)
          return { status = "success", output = { content = chunk } }
        end,
      }
    end
    package.preload["codecompanion.schema"] = function()
      return { get_default = function() return {} end }
    end
    package.preload["codecompanion.http"] = function()
      return {
        new = function()
          return {
            send = function(_, _, opts)
              opts.on_chunk("```")
              opts.on_chunk("\nfeat: add feature\n")
              opts.on_chunk("```")
              opts.on_done()
            end,
          }
        end,
      }
    end

    local Generator = require("codecompanion._extensions.gitcommit.generator")
    local out, err
    Generator.generate_commit_message("diff", "English", nil, function(result, error)
      out = result
      err = error
    end)
    local function norm(value)
      return value == nil and vim.NIL or value
    end
    return { out = norm(out), err = norm(err) }
  ]])
  h.eq("feat: add feature", result.out)
  h.eq(vim.NIL, result.err)
end

T["generate_commit_message"]["returns error when ACP returns empty response"] = function()
  local result = child.lua([[
    package.preload["codecompanion.adapters"] = function()
      return { resolve = function() return { type = "acp", name = "acp" } end }
    end
    package.preload["codecompanion.schema"] = function()
      return { get_default = function() return {} end }
    end
    package.preload["codecompanion.acp"] = function()
      return {
        new = function()
          local client = {}
          function client:connect_and_initialize() return true end
          function client:session_prompt(_) return self end
          function client:with_options(_) return self end
          function client:on_message_chunk(fn) self._on_chunk = fn; return self end
          function client:on_complete(fn) self._on_complete = fn; return self end
          function client:on_error(fn) self._on_error = fn; return self end
          function client:send()
            if self._on_complete then
              self._on_complete("stop")
            end
          end
          function client:disconnect() _G._acp_disconnected = true end
          return client
        end,
      }
    end

    local Generator = require("codecompanion._extensions.gitcommit.generator")
    local out, err
    Generator.generate_commit_message("diff", "English", nil, function(result, error)
      out = result
      err = error
    end)
    local function norm(value)
      return value == nil and vim.NIL or value
    end
    return { out = norm(out), err = norm(err), disconnected = _G._acp_disconnected }
  ]])
  h.eq(vim.NIL, result.out)
  h.expect_match("ACP returned empty response", result.err)
  h.eq(true, result.disconnected)
end

T["generate_commit_message"]["returns ACP content and disconnects"] = function()
  local result = child.lua([[
    package.preload["codecompanion.adapters"] = function()
      return { resolve = function() return { type = "acp", name = "acp" } end }
    end
    package.preload["codecompanion.schema"] = function()
      return { get_default = function() return {} end }
    end
    package.preload["codecompanion.acp"] = function()
      return {
        new = function()
          local client = {}
          function client:connect_and_initialize() return true end
          function client:session_prompt(_) return self end
          function client:with_options(_) return self end
          function client:on_message_chunk(fn) self._on_chunk = fn; return self end
          function client:on_complete(fn) self._on_complete = fn; return self end
          function client:on_error(fn) self._on_error = fn; return self end
          function client:send()
            if self._on_chunk then
              self._on_chunk("feat: acp")
            end
            if self._on_complete then
              self._on_complete("stop")
            end
          end
          function client:disconnect() _G._acp_disconnected = true end
          return client
        end,
      }
    end

    local Generator = require("codecompanion._extensions.gitcommit.generator")
    local out, err
    Generator.generate_commit_message("diff", "English", nil, function(result, error)
      out = result
      err = error
    end)
    local function norm(value)
      return value == nil and vim.NIL or value
    end
    return { out = norm(out), err = norm(err), disconnected = _G._acp_disconnected }
  ]])
  h.eq("feat: acp", result.out)
  h.eq(vim.NIL, result.err)
  h.eq(true, result.disconnected)
end

return T
