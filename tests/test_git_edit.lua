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
    local GitEdit = require("codecompanion._extensions.gitcommit.tools.git_edit")
    return GitEdit.name
  ]])
  h.eq("git_edit", name)
end

T["schema"]["has function type and strict mode"] = function()
  local result = child.lua([[
    local GitEdit = require("codecompanion._extensions.gitcommit.tools.git_edit")
    return {
      type = GitEdit.schema.type,
      func_name = GitEdit.schema["function"].name,
      strict = GitEdit.schema["function"].strict,
    }
  ]])
  h.eq("function", result.type)
  h.eq("git_edit", result.func_name)
  h.eq(true, result.strict)
end

T["schema"]["contains valid operations enum"] = function()
  local result = child.lua([[
    local GitEdit = require("codecompanion._extensions.gitcommit.tools.git_edit")
    local enum = GitEdit.schema["function"].parameters.properties.operation.enum
    local has_stage = vim.tbl_contains(enum, "stage")
    local has_commit = vim.tbl_contains(enum, "commit")
    local has_help = vim.tbl_contains(enum, "help")
    return {
      count = #enum,
      has_required = has_stage and has_commit and has_help,
      is_non_empty = #enum > 0,
    }
  ]])
  h.eq(true, result.has_required)
  h.eq(true, result.is_non_empty)
  h.eq(true, result.count >= 20)
end

T["cmds"] = new_set()

T["cmds"]["returns error for nil args"] = function()
  local result = child.lua([[
    local GitEdit = require("codecompanion._extensions.gitcommit.tools.git_edit")
    local cmd_fn = GitEdit.cmds[1]
    local result = cmd_fn({}, nil, nil, function() end)
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
    local GitEdit = require("codecompanion._extensions.gitcommit.tools.git_edit")
    local cmd_fn = GitEdit.cmds[1]
    local result = cmd_fn({}, { operation = "invalid_op" }, nil, function() end)
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
    local GitEdit = require("codecompanion._extensions.gitcommit.tools.git_edit")
    local cmd_fn = GitEdit.cmds[1]
    local result = cmd_fn({}, {}, nil, function() end)
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
    local GitEdit = require("codecompanion._extensions.gitcommit.tools.git_edit")
    local cmd_fn = GitEdit.cmds[1]
    local result = cmd_fn({}, { operation = "help" }, nil, function() end)
    return {
      status = result.status,
      has_stage = result.data:find("stage") ~= nil,
    }
  ]])
  h.eq("success", result.status)
  h.eq(true, result.has_stage)
end

T["cmds"]["stage requires files array"] = function()
  local result = child.lua([[
    local GitEdit = require("codecompanion._extensions.gitcommit.tools.git_edit")
    local cmd_fn = GitEdit.cmds[1]
    local result = cmd_fn({}, { operation = "stage" }, nil, function() end)
    return {
      status = result.status,
      has_msg = result.data.output:find("files is required") ~= nil,
    }
  ]])
  h.eq("error", result.status)
  h.eq(true, result.has_msg)
end

T["cmds"]["stage requires non-empty files array"] = function()
  local result = child.lua([[
    local GitEdit = require("codecompanion._extensions.gitcommit.tools.git_edit")
    local cmd_fn = GitEdit.cmds[1]
    local result = cmd_fn({}, { operation = "stage", files = {} }, nil, function() end)
    return {
      status = result.status,
      has_msg = result.data.output:find("files cannot be empty") ~= nil,
    }
  ]])
  h.eq("error", result.status)
  h.eq(true, result.has_msg)
end

T["cmds"]["create_branch requires branch_name"] = function()
  local result = child.lua([[
    local GitEdit = require("codecompanion._extensions.gitcommit.tools.git_edit")
    local cmd_fn = GitEdit.cmds[1]
    local result = cmd_fn({}, { operation = "create_branch" }, nil, function() end)
    return {
      status = result.status,
      has_msg = result.data.output:find("branch_name is required") ~= nil,
    }
  ]])
  h.eq("error", result.status)
  h.eq(true, result.has_msg)
end

T["cmds"]["checkout requires target"] = function()
  local result = child.lua([[
    local GitEdit = require("codecompanion._extensions.gitcommit.tools.git_edit")
    local cmd_fn = GitEdit.cmds[1]
    local result = cmd_fn({}, { operation = "checkout" }, nil, function() end)
    return {
      status = result.status,
      has_msg = result.data.output:find("target is required") ~= nil,
    }
  ]])
  h.eq("error", result.status)
  h.eq(true, result.has_msg)
end

T["cmds"]["reset requires commit_hash"] = function()
  local result = child.lua([[
    local GitEdit = require("codecompanion._extensions.gitcommit.tools.git_edit")
    local cmd_fn = GitEdit.cmds[1]
    local result = cmd_fn({}, { operation = "reset" }, nil, function() end)
    return {
      status = result.status,
      has_msg = result.data.output:find("commit_hash is required") ~= nil,
    }
  ]])
  h.eq("error", result.status)
  h.eq(true, result.has_msg)
end

T["cmds"]["reset validates mode enum"] = function()
  local result = child.lua([[
    local GitEdit = require("codecompanion._extensions.gitcommit.tools.git_edit")
    local cmd_fn = GitEdit.cmds[1]
    local result = cmd_fn({}, {
      operation = "reset",
      commit_hash = "abc123",
      mode = "invalid",
    }, nil, function() end)
    return {
      status = result.status,
      has_msg = result.data.output:find("mode must be one of") ~= nil,
    }
  ]])
  h.eq("error", result.status)
  h.eq(true, result.has_msg)
end

T["cmds"]["merge requires branch"] = function()
  local result = child.lua([[
    local GitEdit = require("codecompanion._extensions.gitcommit.tools.git_edit")
    local cmd_fn = GitEdit.cmds[1]
    local result = cmd_fn({}, { operation = "merge" }, nil, function() end)
    return {
      status = result.status,
      has_msg = result.data.output:find("branch is required") ~= nil,
    }
  ]])
  h.eq("error", result.status)
  h.eq(true, result.has_msg)
end

T["cmds"]["rebase requires base"] = function()
  local result = child.lua([[
    local GitEdit = require("codecompanion._extensions.gitcommit.tools.git_edit")
    local cmd_fn = GitEdit.cmds[1]
    local result = cmd_fn({}, { operation = "rebase" }, nil, function() end)
    return {
      status = result.status,
      has_msg = result.data.output:find("base is required") ~= nil,
    }
  ]])
  h.eq("error", result.status)
  h.eq(true, result.has_msg)
end

T["cmds"]["gitignore_add requires rules"] = function()
  local result = child.lua([[
    local GitEdit = require("codecompanion._extensions.gitcommit.tools.git_edit")
    local cmd_fn = GitEdit.cmds[1]
    local result = cmd_fn({}, { operation = "gitignore_add" }, nil, function() end)
    return {
      status = result.status,
      has_msg = result.data.output:find("gitignore_rules or gitignore_rule is required") ~= nil,
    }
  ]])
  h.eq("error", result.status)
  h.eq(true, result.has_msg)
end

T["opts"] = new_set()

T["opts"]["requires approval for write operations"] = function()
  local result = child.lua([[
    local GitEdit = require("codecompanion._extensions.gitcommit.tools.git_edit")
    return {
      v18 = GitEdit.opts.require_approval_before({}, {}),
      v17 = GitEdit.opts.requires_approval({}, {}),
    }
  ]])
  h.eq(true, result.v18)
  h.eq(true, result.v17)
end

return T
