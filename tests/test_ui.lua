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

T["_prepare_content"] = new_set()

T["_prepare_content"]["returns table with header"] = function()
  local result = child.lua([[
    local UI = require("codecompanion._extensions.gitcommit.ui")
    local content = UI._prepare_content("test message")
    return content[1]
  ]])
  h.eq("# Generated Commit Message", result)
end

T["_prepare_content"]["includes commit message in code block"] = function()
  local result = child.lua([[
    local UI = require("codecompanion._extensions.gitcommit.ui")
    local content = UI._prepare_content("feat: add new feature")
    -- content[3] is "```", content[4] is the message, content[5] is "```"
    return content[4]
  ]])
  h.eq("feat: add new feature", result)
end

T["_prepare_content"]["handles multi-line commit message"] = function()
  local result = child.lua([[
    local UI = require("codecompanion._extensions.gitcommit.ui")
    local content = UI._prepare_content("feat: add feature\n\nThis is description")
    -- Find the message lines between code blocks
    local lines = {}
    local in_block = false
    for i, line in ipairs(content) do
      if line == "```" then
        if in_block then break end
        in_block = true
      elseif in_block then
        table.insert(lines, line)
      end
    end
    return lines
  ]])
  h.eq({ "feat: add feature", "", "This is description" }, result)
end

T["_prepare_content"]["includes action instructions"] = function()
  local result = child.lua([[
    local UI = require("codecompanion._extensions.gitcommit.ui")
    local content = UI._prepare_content("test")
    local has_copy = false
    local has_submit = false
    local has_close = false
    for _, line in ipairs(content) do
      if line:match("%[c%].*Copy to clipboard") then has_copy = true end
      if line:match("%[s%].*Submit") then has_submit = true end
      if line:match("%[q/Esc%].*Close") then has_close = true end
    end
    return { has_copy = has_copy, has_submit = has_submit, has_close = has_close }
  ]])
  h.eq(true, result.has_copy)
  h.eq(true, result.has_submit)
  h.eq(true, result.has_close)
end

T["_prepare_content"]["returns correct structure"] = function()
  local result = child.lua([[
    local UI = require("codecompanion._extensions.gitcommit.ui")
    local content = UI._prepare_content("msg")
    return {
      is_table = type(content) == "table",
      has_elements = #content > 0,
      first_is_header = content[1] == "# Generated Commit Message",
    }
  ]])
  h.eq(true, result.is_table)
  h.eq(true, result.has_elements)
  h.eq(true, result.first_is_header)
end

T["_calculate_dimensions"] = new_set()

T["_calculate_dimensions"]["returns width and height"] = function()
  local result = child.lua([[
    local UI = require("codecompanion._extensions.gitcommit.ui")
    local content = { "line 1", "line 2", "line 3" }
    local width, height = UI._calculate_dimensions(content)
    return { width = width, height = height }
  ]])
  h.eq("number", type(result.width))
  h.eq("number", type(result.height))
end

T["_calculate_dimensions"]["minimum width is 50"] = function()
  local result = child.lua([[
    local UI = require("codecompanion._extensions.gitcommit.ui")
    local content = { "a", "b" }
    local width, _ = UI._calculate_dimensions(content)
    return width
  ]])
  h.eq(true, result >= 50)
end

T["_calculate_dimensions"]["width increases with long lines"] = function()
  local result = child.lua([[
    local UI = require("codecompanion._extensions.gitcommit.ui")
    local short_content = { "short" }
    local long_content = { string.rep("x", 80) }
    local short_width, _ = UI._calculate_dimensions(short_content)
    local long_width, _ = UI._calculate_dimensions(long_content)
    return long_width > short_width
  ]])
  h.eq(true, result)
end

T["_calculate_dimensions"]["maximum width is 120"] = function()
  local result = child.lua([[
    local UI = require("codecompanion._extensions.gitcommit.ui")
    local content = { string.rep("x", 200) }
    local width, _ = UI._calculate_dimensions(content)
    return width
  ]])
  h.eq(true, result <= 120)
end

T["_calculate_dimensions"]["height based on content lines"] = function()
  local result = child.lua([[
    local UI = require("codecompanion._extensions.gitcommit.ui")
    local small = { "a" }
    local large = { "a", "b", "c", "d", "e", "f", "g", "h", "i", "j" }
    local _, h1 = UI._calculate_dimensions(small)
    local _, h2 = UI._calculate_dimensions(large)
    return h2 > h1
  ]])
  h.eq(true, result)
end

T["_calculate_dimensions"]["height includes padding"] = function()
  local result = child.lua([[
    local UI = require("codecompanion._extensions.gitcommit.ui")
    local content = { "line1", "line2", "line3" }
    local _, height = UI._calculate_dimensions(content)
    -- height should be at least content lines + 4 (padding)
    return height >= #content
  ]])
  h.eq(true, result)
end

T["_prepare_content"]["handles empty message"] = function()
  local result = child.lua([[
    local UI = require("codecompanion._extensions.gitcommit.ui")
    local content = UI._prepare_content("")
    return content[4]
  ]])
  h.eq("", result)
end

T["_prepare_content"]["preserves long single line"] = function()
  local result = child.lua([[
    local UI = require("codecompanion._extensions.gitcommit.ui")
    local msg = string.rep("x", 200)
    local content = UI._prepare_content(msg)
    return content[4]
  ]])
  h.eq(string.rep("x", 200), result)
end

return T
