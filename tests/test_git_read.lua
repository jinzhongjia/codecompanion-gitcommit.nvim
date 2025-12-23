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
    local GitRead = require("codecompanion._extensions.gitcommit.tools.git_read")
    return GitRead.name
  ]])
  h.eq("git_read", name)
end

T["schema"]["has function type and strict mode"] = function()
  local result = child.lua([[
    local GitRead = require("codecompanion._extensions.gitcommit.tools.git_read")
    return {
      type = GitRead.schema.type,
      func_name = GitRead.schema["function"].name,
      strict = GitRead.schema["function"].strict,
    }
  ]])
  h.eq("function", result.type)
  h.eq("git_read", result.func_name)
  h.eq(true, result.strict)
end

T["schema"]["contains valid operations enum"] = function()
  local result = child.lua([[
    local GitRead = require("codecompanion._extensions.gitcommit.tools.git_read")
    local enum = GitRead.schema["function"].parameters.properties.operation.enum
    local has_status = vim.tbl_contains(enum, "status")
    local has_log = vim.tbl_contains(enum, "log")
    local has_help = vim.tbl_contains(enum, "help")
    return {
      count = #enum,
      has_required = has_status and has_log and has_help,
      is_non_empty = #enum > 0,
    }
  ]])
  h.eq(true, result.has_required)
  h.eq(true, result.is_non_empty)
  h.eq(true, result.count >= 15)
end

T["cmds"] = new_set()

T["cmds"]["returns error for nil args"] = function()
  local result = child.lua([[
    local GitRead = require("codecompanion._extensions.gitcommit.tools.git_read")
    local cmd_fn = GitRead.cmds[1]
    local result = cmd_fn({}, nil, nil)
    return {
      status = result.status,
      has_msg = result.data.output:find("Invalid arguments") ~= nil,
    }
  ]])
  h.eq("error", result.status)
  h.eq(true, result.has_msg)
end

T["cmds"]["returns error for invalid operation"] = function()
  local result = child.lua([[
    local GitRead = require("codecompanion._extensions.gitcommit.tools.git_read")
    local cmd_fn = GitRead.cmds[1]
    local result = cmd_fn({}, { operation = "invalid_op" }, nil)
    return {
      status = result.status,
      has_msg = result.data.output:find("operation must be one of") ~= nil,
    }
  ]])
  h.eq("error", result.status)
  h.eq(true, result.has_msg)
end

T["cmds"]["returns error for missing operation"] = function()
  local result = child.lua([[
    local GitRead = require("codecompanion._extensions.gitcommit.tools.git_read")
    local cmd_fn = GitRead.cmds[1]
    local result = cmd_fn({}, {}, nil)
    return {
      status = result.status,
      has_msg = result.data.output:find("operation is required") ~= nil,
    }
  ]])
  h.eq("error", result.status)
  h.eq(true, result.has_msg)
end

T["cmds"]["help operation returns success"] = function()
  local result = child.lua([[
    local GitRead = require("codecompanion._extensions.gitcommit.tools.git_read")
    local cmd_fn = GitRead.cmds[1]
    local result = cmd_fn({}, { operation = "help" }, nil)
    return {
      status = result.status,
      has_status = result.data:find("status") ~= nil,
    }
  ]])
  h.eq("success", result.status)
  h.eq(true, result.has_status)
end

T["cmds"]["blame requires file_path"] = function()
  local result = child.lua([[
    local GitRead = require("codecompanion._extensions.gitcommit.tools.git_read")
    local cmd_fn = GitRead.cmds[1]
    local result = cmd_fn({}, { operation = "blame" }, nil)
    return {
      status = result.status,
      has_msg = result.data.output:find("file_path is required") ~= nil,
    }
  ]])
  h.eq("error", result.status)
  h.eq(true, result.has_msg)
end

T["cmds"]["diff_commits requires commit1"] = function()
  local result = child.lua([[
    local GitRead = require("codecompanion._extensions.gitcommit.tools.git_read")
    local cmd_fn = GitRead.cmds[1]
    local result = cmd_fn({}, { operation = "diff_commits" }, nil)
    return {
      status = result.status,
      has_msg = result.data.output:find("commit1 is required") ~= nil,
    }
  ]])
  h.eq("error", result.status)
  h.eq(true, result.has_msg)
end

T["cmds"]["validates log count range"] = function()
  local result = child.lua([[
    local GitRead = require("codecompanion._extensions.gitcommit.tools.git_read")
    local cmd_fn = GitRead.cmds[1]
    local result = cmd_fn({}, { operation = "log", count = 10000 }, nil)
    return {
      status = result.status,
      has_msg = result.data.output:find("count must be at most 1000") ~= nil,
    }
  ]])
  h.eq("error", result.status)
  h.eq(true, result.has_msg)
end

T["cmds"]["validates log format enum"] = function()
  local result = child.lua([[
    local GitRead = require("codecompanion._extensions.gitcommit.tools.git_read")
    local cmd_fn = GitRead.cmds[1]
    local result = cmd_fn({}, { operation = "log", format = "invalid" }, nil)
    return {
      status = result.status,
      has_msg = result.data.output:find("format must be one of") ~= nil,
    }
  ]])
  h.eq("error", result.status)
  h.eq(true, result.has_msg)
end

T["opts"] = new_set()

T["opts"]["does not require approval"] = function()
  local result = child.lua([[
    local GitRead = require("codecompanion._extensions.gitcommit.tools.git_read")
    return {
      v18 = GitRead.opts.require_approval_before({}, {}),
      v17 = GitRead.opts.requires_approval({}, {}),
    }
  ]])
  h.eq(false, result.v18)
  h.eq(false, result.v17)
end

return T
