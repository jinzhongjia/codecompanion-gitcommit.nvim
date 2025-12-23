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

T["schema"] = new_set()

T["schema"]["has correct name"] = function()
  local name = child.lua([[
    local AIReleaseNotes = require("codecompanion._extensions.gitcommit.tools.ai_release_notes")
    return AIReleaseNotes.name
  ]])
  h.eq("ai_release_notes", name)
end

T["schema"]["has function type"] = function()
  local result = child.lua([[
    local AIReleaseNotes = require("codecompanion._extensions.gitcommit.tools.ai_release_notes")
    return AIReleaseNotes.schema.type
  ]])
  h.eq("function", result)
end

T["schema"]["has strict mode enabled"] = function()
  local result = child.lua([[
    local AIReleaseNotes = require("codecompanion._extensions.gitcommit.tools.ai_release_notes")
    return AIReleaseNotes.schema["function"].strict
  ]])
  h.eq(true, result)
end

T["schema"]["has correct function name"] = function()
  local result = child.lua([[
    local AIReleaseNotes = require("codecompanion._extensions.gitcommit.tools.ai_release_notes")
    return AIReleaseNotes.schema["function"].name
  ]])
  h.eq("ai_release_notes", result)
end

T["schema"]["has description"] = function()
  local result = child.lua([[
    local AIReleaseNotes = require("codecompanion._extensions.gitcommit.tools.ai_release_notes")
    return AIReleaseNotes.schema["function"].description ~= nil
  ]])
  h.eq(true, result)
end

T["schema"]["parameters has object type"] = function()
  local result = child.lua([[
    local AIReleaseNotes = require("codecompanion._extensions.gitcommit.tools.ai_release_notes")
    return AIReleaseNotes.schema["function"].parameters.type
  ]])
  h.eq("object", result)
end

T["schema"]["has from_tag property with nullable type"] = function()
  local result = child.lua([[
    local AIReleaseNotes = require("codecompanion._extensions.gitcommit.tools.ai_release_notes")
    local props = AIReleaseNotes.schema["function"].parameters.properties
    local t = props.from_tag.type
    return props.from_tag ~= nil and type(t) == "table" and vim.tbl_contains(t, "null")
  ]])
  h.eq(true, result)
end

T["schema"]["has to_tag property with nullable type"] = function()
  local result = child.lua([[
    local AIReleaseNotes = require("codecompanion._extensions.gitcommit.tools.ai_release_notes")
    local props = AIReleaseNotes.schema["function"].parameters.properties
    local t = props.to_tag.type
    return props.to_tag ~= nil and type(t) == "table" and vim.tbl_contains(t, "null")
  ]])
  h.eq(true, result)
end

T["schema"]["has style property with nullable type and enum"] = function()
  local result = child.lua([[
    local AIReleaseNotes = require("codecompanion._extensions.gitcommit.tools.ai_release_notes")
    local props = AIReleaseNotes.schema["function"].parameters.properties
    local t = props.style.type
    return props.style ~= nil and type(t) == "table" and vim.tbl_contains(t, "null") and props.style.enum ~= nil
  ]])
  h.eq(true, result)
end

T["schema"]["style enum has all valid values"] = function()
  local result = child.lua([[
    local AIReleaseNotes = require("codecompanion._extensions.gitcommit.tools.ai_release_notes")
    local style_prop = AIReleaseNotes.schema["function"].parameters.properties.style
    local enum = style_prop.enum
    local expected = { "detailed", "concise", "changelog", "marketing" }
    if #enum ~= #expected then return false end
    for i, v in ipairs(expected) do
      if enum[i] ~= v then return false end
    end
    return true
  ]])
  h.eq(true, result)
end

T["schema"]["disallows additional properties"] = function()
  local result = child.lua([[
    local AIReleaseNotes = require("codecompanion._extensions.gitcommit.tools.ai_release_notes")
    return AIReleaseNotes.schema["function"].parameters.additionalProperties
  ]])
  h.eq(false, result)
end

T["system_prompt"] = new_set()

T["system_prompt"]["exists and is string"] = function()
  local result = child.lua([[
    local AIReleaseNotes = require("codecompanion._extensions.gitcommit.tools.ai_release_notes")
    return type(AIReleaseNotes.system_prompt) == "string"
  ]])
  h.eq(true, result)
end

T["system_prompt"]["mentions output styles"] = function()
  local result = child.lua([[
    local AIReleaseNotes = require("codecompanion._extensions.gitcommit.tools.ai_release_notes")
    local prompt = AIReleaseNotes.system_prompt
    return prompt:find("detailed") ~= nil
      and prompt:find("concise") ~= nil
      and prompt:find("changelog") ~= nil
      and prompt:find("marketing") ~= nil
  ]])
  h.eq(true, result)
end

T["handlers"] = new_set()

T["handlers"]["has on_exit handler"] = function()
  local result = child.lua([[
    local AIReleaseNotes = require("codecompanion._extensions.gitcommit.tools.ai_release_notes")
    return AIReleaseNotes.handlers ~= nil and AIReleaseNotes.handlers.on_exit ~= nil
  ]])
  h.eq(true, result)
end

T["output"] = new_set()

T["output"]["has required fields"] = function()
  local result = child.lua([[
    local AIReleaseNotes = require("codecompanion._extensions.gitcommit.tools.ai_release_notes")
    local output = AIReleaseNotes.output
    return output ~= nil
      and output.success ~= nil
      and output.error ~= nil
  ]])
  h.eq(true, result)
end

T["opts"] = new_set()

T["opts"]["requires approval"] = function()
  local result = child.lua([[
    local AIReleaseNotes = require("codecompanion._extensions.gitcommit.tools.ai_release_notes")
    local opts = AIReleaseNotes.opts
    return opts ~= nil and (opts.require_approval_before ~= nil or opts.requires_approval ~= nil)
  ]])
  h.eq(true, result)
end

return T
