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

T["gitignore"] = new_set()

T["gitignore"]["reads existing .gitignore"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    local CommandExecutor = Command.CommandExecutor
    local CommandBuilder = Command.CommandBuilder
    local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool

    local dir = vim.fn.tempname()
    vim.fn.mkdir(dir, "p")
    local sep = package.config:sub(1, 1)
    local path = dir .. sep .. ".gitignore"
    local fd = vim.uv.fs_open(path, "w", 420)
    vim.uv.fs_write(fd, "node_modules\n", 0)
    vim.uv.fs_close(fd)

    CommandExecutor.run = function(cmd)
      if vim.deep_equal(cmd, CommandBuilder.repo_root()) then
        return true, dir
      end
      return false, "unexpected"
    end

    local success, output = GitTool.get_gitignore()
    return { success = success, output = output }
  ]])
  h.eq(true, result.success)
  h.expect_match("node_modules", result.output)
end

T["gitignore"]["handles missing .gitignore"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    local CommandExecutor = Command.CommandExecutor
    local CommandBuilder = Command.CommandBuilder
    local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool

    local dir = vim.fn.tempname()
    vim.fn.mkdir(dir, "p")

    CommandExecutor.run = function(cmd)
      if vim.deep_equal(cmd, CommandBuilder.repo_root()) then
        return true, dir
      end
      return false, "unexpected"
    end

    local success, output = GitTool.get_gitignore()
    return { success = success, output = output }
  ]])
  h.eq(true, result.success)
  h.eq("", result.output)
end

T["gitignore"]["adds and removes rules"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    local CommandExecutor = Command.CommandExecutor
    local CommandBuilder = Command.CommandBuilder
    local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool

    local dir = vim.fn.tempname()
    vim.fn.mkdir(dir, "p")
    local sep = package.config:sub(1, 1)
    local path = dir .. sep .. ".gitignore"
    local fd = vim.uv.fs_open(path, "w", 420)
    vim.uv.fs_write(fd, "node_modules\n", 0)
    vim.uv.fs_close(fd)

    CommandExecutor.run = function(cmd)
      if vim.deep_equal(cmd, CommandBuilder.repo_root()) then
        return true, dir
      end
      return false, "unexpected"
    end

    local add_ok, add_msg = GitTool.add_gitignore_rule({ "node_modules", "dist/" })
    local remove_ok, remove_msg = GitTool.remove_gitignore_rule("dist/")

    local fd2 = vim.uv.fs_open(path, "r", 438)
    local data = vim.uv.fs_read(fd2, vim.uv.fs_stat(path).size, 0)
    vim.uv.fs_close(fd2)

    return {
      add_ok = add_ok,
      add_msg = add_msg,
      remove_ok = remove_ok,
      remove_msg = remove_msg,
      content = data,
    }
  ]])
  h.eq(true, result.add_ok)
  h.expect_match("dist/", result.add_msg)
  h.eq(true, result.remove_ok)
  h.expect_match("dist/", result.remove_msg)
  h.expect_match("node_modules", result.content)
  h.eq(nil, result.content:match("dist/"))
end

T["is_ignored"] = new_set()

T["is_ignored"]["returns success when ignored"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    local CommandExecutor = Command.CommandExecutor
    local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool

    CommandExecutor.run_array = function(_cmd)
      return true, "ignored.txt"
    end

    local success, output = GitTool.is_ignored("ignored.txt")
    return { success = success, output = output }
  ]])
  h.eq(true, result.success)
  h.expect_match("ignored.txt", result.output)
end

T["is_ignored"]["returns error when not ignored"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    local CommandExecutor = Command.CommandExecutor
    local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool

    CommandExecutor.run_array = function(_cmd)
      return false, "not ignored"
    end

    local success, output = GitTool.is_ignored("file.txt")
    return { success = success, output = output }
  ]])
  h.eq(false, result.success)
  h.expect_match("not ignored", result.output)
end

T["conflicts"] = new_set()

T["conflicts"]["cherry_pick reports conflict"] = function()
  local result = child.lua([[
    local Git = require("codecompanion._extensions.gitcommit.git")
    local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool
    Git.is_repository = function() return true end

    local orig_system = vim.fn.system
    vim.fn.system = function(_cmd)
      local fail_cmd = (vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1)
        and "cmd /c exit 1"
        or "false"
      orig_system(fail_cmd)
      return "CONFLICT (content): conflict"
    end

    local success, output = GitTool.cherry_pick("abc123")
    return { success = success, output = output }
  ]])
  h.eq(false, result.success)
  h.expect_match("Cherry-pick conflict detected", result.output)
end

T["conflicts"]["merge reports conflict"] = function()
  local result = child.lua([[
    local Git = require("codecompanion._extensions.gitcommit.git")
    local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool
    Git.is_repository = function() return true end

    local orig_system = vim.fn.system
    vim.fn.system = function(_cmd)
      local fail_cmd = (vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1)
        and "cmd /c exit 1"
        or "false"
      orig_system(fail_cmd)
      return "CONFLICT (content): conflict"
    end

    local success, output = GitTool.merge("feature/test")
    return { success = success, output = output }
  ]])
  h.eq(false, result.success)
  h.expect_match("Merge conflict detected", result.output)
end

T["conflicts"]["rebase reports conflict"] = function()
  local result = child.lua([[
    local Git = require("codecompanion._extensions.gitcommit.git")
    local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool
    Git.is_repository = function() return true end

    local orig_system = vim.fn.system
    vim.fn.system = function(_cmd)
      local fail_cmd = (vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1)
        and "cmd /c exit 1"
        or "false"
      orig_system(fail_cmd)
      return "CONFLICT (content): conflict"
    end

    local success, output = GitTool.rebase(nil, "develop")
    return { success = success, output = output }
  ]])
  h.eq(false, result.success)
  h.expect_match("Rebase conflict detected", result.output)
end

T["conflicts"]["conflict status reports none"] = function()
  local result = child.lua([[
    local Git = require("codecompanion._extensions.gitcommit.git")
    local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool
    Git.is_repository = function() return true end

    local orig_system = vim.fn.system
    vim.fn.system = function(_cmd)
      local ok_cmd = (vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1)
        and "cmd /c echo."
        or "printf ''"
      return orig_system(ok_cmd)
    end

    local success, output = GitTool.get_conflict_status()
    return { success = success, output = output }
  ]])
  h.eq(true, result.success)
  h.eq("No conflicts found", result.output)
end

T["conflicts"]["conflict status returns conflicted files"] = function()
  local result = child.lua([[
    local Git = require("codecompanion._extensions.gitcommit.git")
    local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool
    Git.is_repository = function() return true end

    local orig_system = vim.fn.system
    vim.fn.system = function(_cmd)
      local ok_cmd = (vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1)
        and "cmd /c echo file1 & echo file2"
        or "printf 'file1\nfile2\n'"
      return orig_system(ok_cmd)
    end

    local success, output = GitTool.get_conflict_status()
    return { success = success, output = output }
  ]])
  h.eq(true, result.success)
  h.expect_match("file1", result.output)
  h.expect_match("file2", result.output)
end

T["conflicts"]["show_conflict finds markers"] = function()
  local result = child.lua([[
    local Git = require("codecompanion._extensions.gitcommit.git")
    local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool
    Git.is_repository = function() return true end

    local path = vim.fn.tempname()
    local fd = vim.uv.fs_open(path, "w", 420)
    local content = table.concat({
      "<<<<<<< HEAD",
      "ours",
      "=======",
      "theirs",
      ">>>>>>> branch",
    }, "\n")
    vim.uv.fs_write(fd, content, 0)
    vim.uv.fs_close(fd)

    local success, output = GitTool.show_conflict(path)
    return { success = success, output = output }
  ]])
  h.eq(true, result.success)
  h.expect_match("<<<<<<<", result.output)
  h.expect_match(">>>>>>>", result.output)
end

T["conflicts"]["show_conflict reports no markers"] = function()
  local result = child.lua([[
    local Git = require("codecompanion._extensions.gitcommit.git")
    local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool
    Git.is_repository = function() return true end

    local path = vim.fn.tempname()
    local fd = vim.uv.fs_open(path, "w", 420)
    vim.uv.fs_write(fd, "clean file", 0)
    vim.uv.fs_close(fd)

    local success, output = GitTool.show_conflict(path)
    return { success = success, output = output }
  ]])
  h.eq(true, result.success)
  h.expect_match("No conflict markers found", result.output)
end

T["conflicts"]["conflict status reports failure"] = function()
  local result = child.lua([[
    local Git = require("codecompanion._extensions.gitcommit.git")
    local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool
    Git.is_repository = function() return true end

    local orig_system = vim.fn.system
    vim.fn.system = function(_cmd)
      local fail_cmd = (vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1)
        and "cmd /c exit /b 1"
        or "false"
      return orig_system(fail_cmd)
    end

    local success, output = GitTool.get_conflict_status()
    return { success = success, output = output }
  ]])
  h.eq(false, result.success)
  h.expect_match("Failed to get conflict status", result.output)
end

T["conflicts"]["show_conflict reports missing file"] = function()
  local result = child.lua([[
    local Git = require("codecompanion._extensions.gitcommit.git")
    local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool
    Git.is_repository = function() return true end

    local path = vim.fn.tempname()
    local success, output = GitTool.show_conflict(path)
    return { success = success, output = output }
  ]])
  h.eq(false, result.success)
  h.expect_match("File not found", result.output)
end

T["param_validation"] = new_set()

T["param_validation"]["create_tag requires tag_name"] = function()
  local result = child.lua([[
    local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool
    local success, output = GitTool.create_tag(nil)
    return { success = success, output = output }
  ]])
  h.eq(false, result.success)
  h.expect_match("Tag name is required", result.output)
end

T["param_validation"]["delete_tag requires tag_name"] = function()
  local result = child.lua([[
    local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool
    local success, output = GitTool.delete_tag(nil)
    return { success = success, output = output }
  ]])
  h.eq(false, result.success)
  h.expect_match("Tag name is required for deletion", result.output)
end

T["param_validation"]["add_remote requires name and url"] = function()
  local result = child.lua([[
    local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool
    local success1, output1 = GitTool.add_remote(nil, "http://example.com")
    local success2, output2 = GitTool.add_remote("origin", nil)
    return {
      success1 = success1,
      output1 = output1,
      success2 = success2,
      output2 = output2,
    }
  ]])
  h.eq(false, result.success1)
  h.expect_match("Remote name is required", result.output1)
  h.eq(false, result.success2)
  h.expect_match("Remote URL is required", result.output2)
end

T["param_validation"]["rename_remote requires names"] = function()
  local result = child.lua([[
    local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool
    local success1, output1 = GitTool.rename_remote(nil, "new")
    local success2, output2 = GitTool.rename_remote("old", nil)
    return {
      success1 = success1,
      output1 = output1,
      success2 = success2,
      output2 = output2,
    }
  ]])
  h.eq(false, result.success1)
  h.expect_match("Current remote name is required", result.output1)
  h.eq(false, result.success2)
  h.expect_match("New remote name is required", result.output2)
end

T["param_validation"]["set_remote_url requires name and url"] = function()
  local result = child.lua([[
    local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool
    local success1, output1 = GitTool.set_remote_url(nil, "http://example.com")
    local success2, output2 = GitTool.set_remote_url("origin", nil)
    return {
      success1 = success1,
      output1 = output1,
      success2 = success2,
      output2 = output2,
    }
  ]])
  h.eq(false, result.success1)
  h.expect_match("Remote name is required", result.output1)
  h.eq(false, result.success2)
  h.expect_match("Remote URL is required", result.output2)
end

T["write_ops"] = new_set()

T["write_ops"]["commit requires message"] = function()
  local result = child.lua([[
    local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool
    local success, output = GitTool.commit("")
    return { success = success, output = output }
  ]])
  h.eq(false, result.success)
  h.expect_match("Commit message is required", result.output)
end

T["write_ops"]["commit fails when not in repo"] = function()
  local result = child.lua([[
    local Git = require("codecompanion._extensions.gitcommit.git")
    local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool
    Git.is_repository = function() return false end
    local success, output = GitTool.commit("feat: test")
    return { success = success, output = output }
  ]])
  h.eq(false, result.success)
  h.expect_match("Not in a git repository", result.output)
end

T["write_ops"]["push_async reports not in repo"] = function()
  local result = child.lua([[
    local Git = require("codecompanion._extensions.gitcommit.git")
    local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool
    Git.is_repository = function() return false end
    local payload = nil
    GitTool.push_async("origin", "main", false, false, false, nil, function(res)
      payload = res
    end)
    return payload
  ]])
  h.eq("error", result.status)
  h.expect_match("Not in a git repository", result.data)
end

T["write_ops"]["merge_continue reports conflicts"] = function()
  local result = child.lua([[
    local Git = require("codecompanion._extensions.gitcommit.git")
    local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool
    Git.is_repository = function() return true end

    local orig_system = vim.fn.system
    vim.fn.system = function(_cmd)
      local fail_cmd = (vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1)
        and "cmd /c exit /b 1"
        or "false"
      orig_system(fail_cmd)
      return "CONFLICT (content)"
    end

    local success, output = GitTool.merge_continue()
    return { success = success, output = output }
  ]])
  h.eq(false, result.success)
  h.expect_match("Conflicts still exist", result.output)
end

T["write_ops"]["merge_abort reports no merge"] = function()
  local result = child.lua([[
    local Git = require("codecompanion._extensions.gitcommit.git")
    local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool
    Git.is_repository = function() return true end

    local orig_system = vim.fn.system
    vim.fn.system = function(_cmd)
      local fail_cmd = (vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1)
        and "cmd /c exit /b 1"
        or "false"
      orig_system(fail_cmd)
      return "not merging"
    end

    local success, output = GitTool.merge_abort()
    return { success = success, output = output }
  ]])
  h.eq(false, result.success)
  h.expect_match("No merge in progress", result.output)
end

T["write_ops"]["cherry_pick_continue reports conflicts"] = function()
  local result = child.lua([[
    local Git = require("codecompanion._extensions.gitcommit.git")
    local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool
    Git.is_repository = function() return true end

    local orig_system = vim.fn.system
    vim.fn.system = function(_cmd)
      local fail_cmd = (vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1)
        and "cmd /c exit /b 1"
        or "false"
      orig_system(fail_cmd)
      return "CONFLICT (content)"
    end

    local success, output = GitTool.cherry_pick_continue()
    return { success = success, output = output }
  ]])
  h.eq(false, result.success)
  h.expect_match("Conflicts still exist", result.output)
end

T["write_ops"]["cherry_pick_abort reports none in progress"] = function()
  local result = child.lua([[
    local Git = require("codecompanion._extensions.gitcommit.git")
    local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool
    Git.is_repository = function() return true end

    local orig_system = vim.fn.system
    vim.fn.system = function(_cmd)
      local fail_cmd = (vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1)
        and "cmd /c exit /b 1"
        or "false"
      orig_system(fail_cmd)
      return "no cherry-pick in progress"
    end

    local success, output = GitTool.cherry_pick_abort()
    return { success = success, output = output }
  ]])
  h.eq(false, result.success)
  h.expect_match("No cherry-pick in progress", result.output)
end

T["write_ops"]["merge_continue succeeds"] = function()
  local result = child.lua([[
    local Git = require("codecompanion._extensions.gitcommit.git")
    local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool
    Git.is_repository = function() return true end

    local orig_system = vim.fn.system
    vim.fn.system = function(_cmd)
      local ok_cmd = (vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1)
        and "cmd /c exit /b 0"
        or "true"
      return orig_system(ok_cmd)
    end

    local success, output = GitTool.merge_continue()
    return { success = success, output = output }
  ]])
  h.eq(true, result.success)
end

T["write_ops"]["cherry_pick_continue succeeds"] = function()
  local result = child.lua([[
    local Git = require("codecompanion._extensions.gitcommit.git")
    local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool
    Git.is_repository = function() return true end

    local orig_system = vim.fn.system
    vim.fn.system = function(_cmd)
      local ok_cmd = (vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1)
        and "cmd /c exit /b 0"
        or "true"
      return orig_system(ok_cmd)
    end

    local success, output = GitTool.cherry_pick_continue()
    return { success = success, output = output }
  ]])
  h.eq(true, result.success)
end

T["conflicts"]["conflict status formats user message"] = function()
  local result = child.lua([[
    local Git = require("codecompanion._extensions.gitcommit.git")
    local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool
    Git.is_repository = function() return true end

    local orig_system = vim.fn.system
    vim.fn.system = function(_cmd)
      local ok_cmd = (vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1)
        and "cmd /c echo file1"
        or "printf 'file1\n'"
      return orig_system(ok_cmd)
    end

    local success, output, user_msg, llm_msg = GitTool.get_conflict_status()
    return { success = success, output = output, user_msg = user_msg, llm_msg = llm_msg }
  ]])
  h.eq(true, result.success)
  h.expect_match("file1", result.user_msg)
  h.expect_match("<gitConflictStatus>", result.llm_msg)
end

T["write_ops"]["commit uses executor when in repo"] = function()
  local result = child.lua([[
    local Git = require("codecompanion._extensions.gitcommit.git")
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    local CommandExecutor = Command.CommandExecutor
    local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool

    Git.is_repository = function() return true end
    CommandExecutor.run = function(cmd)
      return true, cmd
    end

    local success, output = GitTool.commit("feat: test", false)
    return { success = success, output = output }
  ]])
  h.eq(true, result.success)
  h.expect_array_contains("git", result.output)
  h.expect_array_contains("commit", result.output)
end

T["write_ops"]["push delegates to executor"] = function()
  local result = child.lua([[
    local Git = require("codecompanion._extensions.gitcommit.git")
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    local CommandExecutor = Command.CommandExecutor
    local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool

    Git.is_repository = function() return true end
    CommandExecutor.run = function(cmd)
      return true, cmd
    end

    local success, output = GitTool.push("origin", "main", false, false, false, nil)
    return { success = success, output = output }
  ]])
  h.eq(true, result.success)
  h.expect_array_contains("git", result.output)
  h.expect_array_contains("push", result.output)
end

T["write_ops"]["fetch delegates to executor"] = function()
  local result = child.lua([[
    local Git = require("codecompanion._extensions.gitcommit.git")
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    local CommandExecutor = Command.CommandExecutor
    local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool

    Git.is_repository = function() return true end
    CommandExecutor.run = function(cmd)
      return true, cmd
    end

    local success, output = GitTool.fetch("origin", "main", false)
    return { success = success, output = output }
  ]])
  h.eq(true, result.success)
  h.expect_array_contains("git", result.output)
  h.expect_array_contains("fetch", result.output)
end

T["write_ops"]["pull delegates to executor"] = function()
  local result = child.lua([[
    local Git = require("codecompanion._extensions.gitcommit.git")
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    local CommandExecutor = Command.CommandExecutor
    local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool

    Git.is_repository = function() return true end
    CommandExecutor.run = function(cmd)
      return true, cmd
    end

    local success, output = GitTool.pull("origin", "main", false)
    return { success = success, output = output }
  ]])
  h.eq(true, result.success)
  h.expect_array_contains("git", result.output)
  h.expect_array_contains("pull", result.output)
end

T["write_ops"]["stash delegates to executor"] = function()
  local result = child.lua([[
    local Git = require("codecompanion._extensions.gitcommit.git")
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    local CommandExecutor = Command.CommandExecutor
    local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool

    Git.is_repository = function() return true end
    CommandExecutor.run = function(cmd)
      return true, cmd
    end

    local success, output = GitTool.stash("msg", true)
    return { success = success, output = output }
  ]])
  h.eq(true, result.success)
  h.expect_array_contains("git", result.output)
  h.expect_array_contains("stash", result.output)
end

T["write_ops"]["reset delegates to executor"] = function()
  local result = child.lua([[
    local Git = require("codecompanion._extensions.gitcommit.git")
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    local CommandExecutor = Command.CommandExecutor
    local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool

    Git.is_repository = function() return true end
    CommandExecutor.run = function(cmd)
      return true, cmd
    end

    local success, output = GitTool.reset("abc123", "soft")
    return { success = success, output = output }
  ]])
  h.eq(true, result.success)
  h.expect_array_contains("git", result.output)
  h.expect_array_contains("reset", result.output)
end

T["write_ops"]["rebase delegates to executor"] = function()
  local result = child.lua([[
    local Git = require("codecompanion._extensions.gitcommit.git")
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    local CommandExecutor = Command.CommandExecutor
    local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool

    Git.is_repository = function() return true end
    CommandExecutor.run = function(cmd)
      return true, cmd
    end

    local success, output = GitTool.rebase("main", "HEAD~2", true)
    return { success = success, output = output }
  ]])
  h.eq(true, result.success)
  h.expect_array_contains("git", result.output)
  h.expect_array_contains("rebase", result.output)
end

T["read_ops"] = new_set()

T["read_ops"]["get_log formats success output"] = function()
  local result = child.lua([[
    local Git = require("codecompanion._extensions.gitcommit.git")
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    local CommandExecutor = Command.CommandExecutor
    local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool

    Git.is_repository = function() return true end
    CommandExecutor.run = function(_cmd)
      return true, "commit1\ncommit2\n"
    end

    local success, output, user_msg, llm_msg = GitTool.get_log(2, "oneline")
    return { success = success, output = output, user_msg = user_msg, llm_msg = llm_msg }
  ]])
  h.eq(true, result.success)
  h.expect_match("commit1", result.user_msg)
  h.expect_match("<gitLogTool>success:", result.llm_msg)
end

T["read_ops"]["get_log formats empty output"] = function()
  local result = child.lua([[
    local Git = require("codecompanion._extensions.gitcommit.git")
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    local CommandExecutor = Command.CommandExecutor
    local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool

    Git.is_repository = function() return true end
    CommandExecutor.run = function(_cmd)
      return true, ""
    end

    local success, output, user_msg, llm_msg = GitTool.get_log(2, "oneline")
    return { success = success, output = output, user_msg = user_msg, llm_msg = llm_msg }
  ]])
  h.eq(true, result.success)
  h.expect_match("no commits found", result.user_msg)
  h.expect_match("<gitLogTool>success:", result.llm_msg)
end

T["read_ops"]["get_diff formats error output"] = function()
  local result = child.lua([[
    local Git = require("codecompanion._extensions.gitcommit.git")
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    local CommandExecutor = Command.CommandExecutor
    local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool

    Git.is_repository = function() return true end
    CommandExecutor.run = function(_cmd)
      return false, "diff failed"
    end

    local success, output, user_msg, llm_msg = GitTool.get_diff(true, nil)
    return { success = success, output = output, user_msg = user_msg, llm_msg = llm_msg }
  ]])
  h.eq(false, result.success)
  h.expect_match("diff failed", result.user_msg)
  h.expect_match("<gitDiffTool>fail:", result.llm_msg)
end

T["read_ops"]["show_commit formats output"] = function()
  local result = child.lua([[
    local Git = require("codecompanion._extensions.gitcommit.git")
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    local CommandExecutor = Command.CommandExecutor
    local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool

    Git.is_repository = function() return true end
    CommandExecutor.run = function(_cmd)
      return true, "commit detail"
    end

    local success, output, user_msg, llm_msg = GitTool.show_commit("abc123")
    return { success = success, output = output, user_msg = user_msg, llm_msg = llm_msg }
  ]])
  h.eq(true, result.success)
  h.expect_match("commit detail", result.user_msg)
  h.expect_match("<gitShowTool>success:", result.llm_msg)
end

T["read_ops"]["get_status handles empty output"] = function()
  local result = child.lua([[
    local Git = require("codecompanion._extensions.gitcommit.git")
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    local CommandExecutor = Command.CommandExecutor
    local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool

    Git.is_repository = function() return true end
    CommandExecutor.run = function(_cmd)
      return true, ""
    end

    local success, output, user_msg, llm_msg = GitTool.get_status()
    return { success = success, output = output, user_msg = user_msg, llm_msg = llm_msg }
  ]])
  h.eq(true, result.success)
  h.expect_match("no changes found", result.user_msg)
  h.expect_match("<gitStatusTool>success:", result.llm_msg)
end

T["read_ops"]["get_tags handles empty output"] = function()
  local result = child.lua([[
    local Git = require("codecompanion._extensions.gitcommit.git")
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    local CommandExecutor = Command.CommandExecutor
    local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool

    Git.is_repository = function() return true end
    CommandExecutor.run = function(_cmd)
      return true, ""
    end

    local success, output, user_msg, llm_msg = GitTool.get_tags()
    return { success = success, output = output, user_msg = user_msg, llm_msg = llm_msg }
  ]])
  h.eq(true, result.success)
  h.expect_match("No tag data available", result.user_msg)
  h.expect_match("<gitTagTool>success:", result.llm_msg)
end

T["release_notes"] = new_set()

T["release_notes"]["returns error when no tags"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    local CommandExecutor = Command.CommandExecutor
    local CommandBuilder = Command.CommandBuilder
    local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool

    CommandExecutor.run = function(cmd)
      if vim.deep_equal(cmd, CommandBuilder.tags_sorted()) then
        return true, ""
      end
      return false, "unexpected"
    end

    local success, output = GitTool.generate_release_notes(nil, nil, "markdown")
    return { success = success, output = output }
  ]])
  h.eq(false, result.success)
  h.expect_match("No tags found", result.output)
end

T["release_notes"]["defaults tags and builds markdown"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    local CommandExecutor = Command.CommandExecutor
    local CommandBuilder = Command.CommandBuilder
    local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool

    CommandExecutor.run = function(cmd)
      if vim.deep_equal(cmd, CommandBuilder.tags_sorted()) then
        return true, "v2.0\nv1.0\n"
      end
      if vim.deep_equal(cmd, CommandBuilder.release_notes_log("v1.0", "v2.0")) then
        local line1 = table.concat({ "abc123", "feat: add api", "me", "2024-01-01" }, "\x01")
        local line2 = table.concat({ "def456", "fix: repair bug", "you", "2024-01-02" }, "\x01")
        return true, line1 .. "\n" .. line2
      end
      return false, "unexpected"
    end

    local success, output = GitTool.generate_release_notes(nil, nil, "markdown")
    return { success = success, output = output }
  ]])
  h.eq(true, result.success)
  h.expect_match("Release Notes: v1.0", result.output)
  h.expect_match("feat: add api", result.output)
  h.expect_match("fix: repair bug", result.output)
end

T["release_notes"]["returns json output"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    local CommandExecutor = Command.CommandExecutor
    local CommandBuilder = Command.CommandBuilder
    local GitTool = require("codecompanion._extensions.gitcommit.tools.git").GitTool

    CommandExecutor.run = function(cmd)
      if vim.deep_equal(cmd, CommandBuilder.tags_sorted()) then
        return true, "v2.0\nv1.0\n"
      end
      if vim.deep_equal(cmd, CommandBuilder.release_notes_log("v1.0", "v2.0")) then
        local line1 = table.concat({ "abc123", "feat: add api", "me", "2024-01-01" }, "\x01")
        return true, line1
      end
      return false, "unexpected"
    end

    local success, output = GitTool.generate_release_notes(nil, nil, "json")
    local decoded = vim.fn.json_decode(output)
    return { success = success, decoded = decoded }
  ]])
  h.eq(true, result.success)
  h.eq("v1.0", result.decoded.from_tag)
  h.eq("v2.0", result.decoded.to_tag)
  h.eq(1, result.decoded.total_commits)
end

return T
