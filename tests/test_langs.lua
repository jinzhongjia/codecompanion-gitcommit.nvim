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

T["setup"] = new_set()

T["setup"]["accepts valid array of languages"] = function()
  local result = child.lua([[
    local Langs = require("codecompanion._extensions.gitcommit.langs")
    Langs.setup({ "English", "Chinese", "Japanese" })
    return true
  ]])
  h.eq(true, result)
end

T["setup"]["accepts empty array"] = function()
  local result = child.lua([[
    local Langs = require("codecompanion._extensions.gitcommit.langs")
    Langs.setup({})
    return true
  ]])
  h.eq(true, result)
end

T["setup"]["accepts single language"] = function()
  local result = child.lua([[
    local Langs = require("codecompanion._extensions.gitcommit.langs")
    Langs.setup({ "English" })
    return true
  ]])
  h.eq(true, result)
end

T["setup"]["throws error for non-table input"] = function()
  local result = child.lua([[
    local Langs = require("codecompanion._extensions.gitcommit.langs")
    local ok, err = pcall(function()
      Langs.setup("not a table")
    end)
    return not ok and err:find("must be a array") ~= nil
  ]])
  h.eq(true, result)
end

T["setup"]["throws error for number input"] = function()
  local result = child.lua([[
    local Langs = require("codecompanion._extensions.gitcommit.langs")
    local ok, err = pcall(function()
      Langs.setup(123)
    end)
    return not ok and err:find("must be a array") ~= nil
  ]])
  h.eq(true, result)
end

T["setup"]["accepts nil and defaults to empty"] = function()
  local result = child.lua([[
    local Langs = require("codecompanion._extensions.gitcommit.langs")
    Langs.setup(nil)
    return true
  ]])
  h.eq(true, result)
end

T["select_lang"] = new_set()

T["select_lang"]["returns nil when no languages configured"] = function()
  local result = child.lua([[
    local Langs = require("codecompanion._extensions.gitcommit.langs")
    Langs.setup({})
    local selected = nil
    Langs.select_lang(function(choice)
      selected = choice
    end)
    return selected
  ]])
  h.eq(vim.NIL, result)
end

T["select_lang"]["returns single language directly without prompt"] = function()
  local result = child.lua([[
    local Langs = require("codecompanion._extensions.gitcommit.langs")
    Langs.setup({ "English" })
    local selected = nil
    Langs.select_lang(function(choice)
      selected = choice
    end)
    return selected
  ]])
  h.eq("English", result)
end

T["select_lang"]["returns nil when setup with nil"] = function()
  local result = child.lua([[
    local Langs = require("codecompanion._extensions.gitcommit.langs")
    Langs.setup(nil)
    local selected = nil
    Langs.select_lang(function(choice)
      selected = choice
    end)
    return selected
  ]])
  h.eq(vim.NIL, result)
end

return T
