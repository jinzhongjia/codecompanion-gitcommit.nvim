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

T["run"] = new_set()

T["run"]["returns success on ok command"] = function()
  local result = child.lua([[
    local CommandExecutor = require("codecompanion._extensions.gitcommit.tools.command").CommandExecutor
    local cmd = (vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1) and "cmd /c echo ok" or "printf 'ok'"
    local success, output = CommandExecutor.run(cmd)
    return { success = success, output = output }
  ]])
  h.eq(true, result.success)
  h.expect_match("ok", result.output)
end

T["run"]["does not treat fatal output as error with zero exit"] = function()
  local result = child.lua([[
    local CommandExecutor = require("codecompanion._extensions.gitcommit.tools.command").CommandExecutor
    local cmd = (vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1)
      and "cmd /c echo fatal: boom"
      or "printf 'fatal: boom'"
    local success, output = CommandExecutor.run(cmd)
    return { success = success, output = output }
  ]])
  h.eq(true, result.success)
  h.expect_match("fatal:", result.output)
end

T["run"]["returns error on non-zero exit"] = function()
  local result = child.lua([[
    local CommandExecutor = require("codecompanion._extensions.gitcommit.tools.command").CommandExecutor
    local cmd = (vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1) and "cmd /c exit /b 1" or "false"
    local success, output = CommandExecutor.run(cmd)
    return { success = success, output = output }
  ]])
  h.eq(false, result.success)
end

T["run_array"] = new_set()

T["run_array"]["returns success for array command"] = function()
  local result = child.lua([[
    local CommandExecutor = require("codecompanion._extensions.gitcommit.tools.command").CommandExecutor
    local cmd = (vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1)
      and { "cmd", "/c", "echo ok" }
      or { "sh", "-c", "printf 'ok'" }
    local success, output = CommandExecutor.run_array(cmd)
    return { success = success, output = output }
  ]])
  h.eq(true, result.success)
  h.expect_match("ok", result.output)
end

T["run_async"] = new_set()

T["run_async"]["aggregates stdout on success"] = function()
  local result = child.lua([[
    local CommandExecutor = require("codecompanion._extensions.gitcommit.tools.command").CommandExecutor
    local orig = vim.fn.jobstart
    vim.fn.jobstart = function(_cmd, opts)
      opts.on_stdout(nil, { "line1", "line2" })
      opts.on_stderr(nil, {})
      opts.on_exit(nil, 0)
      return 1
    end

    local out = nil
    CommandExecutor.run_async({ "git", "status" }, function(result)
      out = result
    end)
    vim.fn.jobstart = orig
    return out
  ]])
  h.eq("success", result.status)
  h.eq("line1\nline2", result.data)
end

T["run_async"]["aggregates stderr on error"] = function()
  local result = child.lua([[
    local CommandExecutor = require("codecompanion._extensions.gitcommit.tools.command").CommandExecutor
    local orig = vim.fn.jobstart
    vim.fn.jobstart = function(_cmd, opts)
      opts.on_stdout(nil, {})
      opts.on_stderr(nil, { "err1", "err2" })
      opts.on_exit(nil, 1)
      return 1
    end

    local out = nil
    CommandExecutor.run_async({ "git", "status" }, function(result)
      out = result
    end)
    vim.fn.jobstart = orig
    return out
  ]])
  h.eq("error", result.status)
  h.eq("err1\nerr2", result.data)
end

return T
