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

T["status"] = new_set()

T["status"]["returns correct command"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.status()
  ]])
  h.eq("git status --porcelain", result)
end

T["log"] = new_set()

T["log"]["returns default command"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.log()
  ]])
  h.eq("git log -10 --oneline", result)
end

T["log"]["respects count parameter"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.log(5)
  ]])
  h.eq("git log -5 --oneline", result)
end

T["log"]["respects format parameter"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.log(10, "short")
  ]])
  h.eq("git log -10 --pretty=short", result)
end

T["log"]["handles all format types"] = function()
  local formats = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    local CB = Command.CommandBuilder
    return {
      oneline = CB.log(1, "oneline"),
      short = CB.log(1, "short"),
      medium = CB.log(1, "medium"),
      full = CB.log(1, "full"),
      fuller = CB.log(1, "fuller"),
    }
  ]])
  h.eq("git log -1 --oneline", formats.oneline)
  h.eq("git log -1 --pretty=short", formats.short)
  h.eq("git log -1 --pretty=medium", formats.medium)
  h.eq("git log -1 --pretty=full", formats.full)
  h.eq("git log -1 --pretty=fuller", formats.fuller)
end

T["diff"] = new_set()

T["diff"]["returns basic command"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.diff()
  ]])
  h.eq("git diff", result)
end

T["diff"]["adds cached flag for staged"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.diff(true)
  ]])
  h.eq("git diff --cached", result)
end

T["diff"]["adds file path"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.diff(false, "test.lua")
  ]])
  h.eq(true, result:find("%-%-") ~= nil)
  h.eq(true, result:find("test.lua") ~= nil)
end

T["diff"]["adds both staged and file"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.diff(true, "test.lua")
  ]])
  h.eq(true, result:find("--cached") ~= nil)
  h.eq(true, result:find("%-%-") ~= nil)
  h.eq(true, result:find("test.lua") ~= nil)
end

T["branch"] = new_set()

T["branch"]["current_branch returns correct command"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.current_branch()
  ]])
  h.eq("git branch --show-current", result)
end

T["branch"]["branches returns all branches by default"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.branches()
  ]])
  h.eq("git branch -a", result)
end

T["branch"]["branches returns remote only when specified"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.branches(true)
  ]])
  h.eq("git branch -r", result)
end

T["stage"] = new_set()

T["stage"]["handles single file as string"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.stage("test.lua")
  ]])
  h.eq(true, result:find("git add") ~= nil)
  h.eq(true, result:find("%-%-") ~= nil)
  h.eq(true, result:find("test.lua") ~= nil)
end

T["stage"]["handles multiple files"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.stage({"a.lua", "b.lua"})
  ]])
  h.eq(true, result:find("git add") ~= nil)
  h.eq(true, result:find("%-%-") ~= nil)
  h.eq(true, result:find("a.lua") ~= nil)
  h.eq(true, result:find("b.lua") ~= nil)
end

T["unstage"] = new_set()

T["unstage"]["returns correct command"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.unstage("test.lua")
  ]])
  h.eq(true, result:find("git reset HEAD") ~= nil)
  h.eq(true, result:find("%-%-") ~= nil)
  h.eq(true, result:find("test.lua") ~= nil)
end

T["commit"] = new_set()

T["commit"]["returns basic commit command"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.commit("test message")
  ]])
  h.eq(true, result:find("git commit") ~= nil)
  h.eq(true, result:find("-m") ~= nil)
  h.eq(true, result:find("test message") ~= nil)
end

T["commit"]["adds amend flag"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.commit("test message", true)
  ]])
  h.eq(true, result:find("--amend") ~= nil)
end

T["create_branch"] = new_set()

T["create_branch"]["creates and checks out by default"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.create_branch("feature/test")
  ]])
  h.eq(true, result:find("git checkout %-b") ~= nil)
  h.eq(true, result:find("feature") ~= nil)
end

T["create_branch"]["creates without checkout when specified"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.create_branch("feature/test", false)
  ]])
  h.eq(true, result:find("git branch ") ~= nil)
  h.eq(true, result:find("feature/test") ~= nil)
end

T["checkout"] = new_set()

T["checkout"]["returns correct command"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.checkout("main")
  ]])
  h.eq(true, result:find("git checkout") ~= nil)
  h.eq(true, result:find("main") ~= nil)
end

T["remotes"] = new_set()

T["remotes"]["returns correct command"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.remotes()
  ]])
  h.eq("git remote -v", result)
end

T["show"] = new_set()

T["show"]["defaults to HEAD"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.show()
  ]])
  h.eq(true, result:find("git show") ~= nil)
  h.eq(true, result:find("HEAD") ~= nil)
end

T["show"]["accepts commit hash"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.show("abc123")
  ]])
  h.eq(true, result:find("abc123") ~= nil)
end

T["blame"] = new_set()

T["blame"]["returns basic command"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.blame("test.lua")
  ]])
  h.eq(true, result:find("git blame") ~= nil)
  h.eq(true, result:find("%-%-") ~= nil)
  h.eq(true, result:find("test.lua") ~= nil)
end

T["blame"]["adds line range"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.blame("test.lua", 10, 20)
  ]])
  h.eq(true, result:find("-L") ~= nil)
  h.eq(true, result:find("10,20") ~= nil)
  h.eq(true, result:find("%-%-") ~= nil)
end

T["blame"]["adds line start with default range"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.blame("test.lua", 10)
  ]])
  h.eq(true, result:find("%-L") ~= nil)
  h.eq(true, result:find("10,%+10") ~= nil)
end

T["stash"] = new_set()

T["stash"]["returns basic command"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.stash()
  ]])
  h.eq("git stash", result)
end

T["stash"]["adds untracked flag"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.stash(nil, true)
  ]])
  h.eq(true, result:find("-u") ~= nil)
end

T["stash"]["adds message"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.stash("WIP", false)
  ]])
  h.eq(true, result:find("-m") ~= nil)
  h.eq(true, result:find("WIP") ~= nil)
end

T["stash_list"] = new_set()

T["stash_list"]["returns correct command"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.stash_list()
  ]])
  h.eq("git stash list", result)
end

T["stash_apply"] = new_set()

T["stash_apply"]["defaults to stash@{0}"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.stash_apply()
  ]])
  h.eq(true, result:find("git stash apply") ~= nil)
  h.eq(true, result:find("stash@{0}") ~= nil)
end

T["stash_apply"]["accepts custom ref"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.stash_apply("stash@{2}")
  ]])
  h.eq(true, result:find("stash@{2}") ~= nil)
end

T["reset"] = new_set()

T["reset"]["defaults to mixed mode"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.reset("HEAD~1")
  ]])
  h.eq(true, result:find("git reset") ~= nil)
  h.eq(true, result:find("--mixed") ~= nil)
  h.eq(true, result:find("HEAD~1") ~= nil)
end

T["reset"]["handles all modes"] = function()
  local modes = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    local CB = Command.CommandBuilder
    return {
      soft = CB.reset("HEAD~1", "soft"),
      mixed = CB.reset("HEAD~1", "mixed"),
      hard = CB.reset("HEAD~1", "hard"),
    }
  ]])
  h.eq(true, modes.soft:find("--soft") ~= nil)
  h.eq(true, modes.mixed:find("--mixed") ~= nil)
  h.eq(true, modes.hard:find("--hard") ~= nil)
end

T["diff_commits"] = new_set()

T["diff_commits"]["compares two commits"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.diff_commits("abc123", "def456")
  ]])
  h.eq(true, result:find("git diff") ~= nil)
  h.eq(true, result:find("abc123") ~= nil)
  h.eq(true, result:find("def456") ~= nil)
end

T["diff_commits"]["defaults second commit to HEAD"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.diff_commits("abc123")
  ]])
  h.eq(true, result:find("HEAD") ~= nil)
end

T["diff_commits"]["adds file path"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.diff_commits("abc123", "def456", "test.lua")
  ]])
  h.eq(true, result:find("--") ~= nil)
  h.eq(true, result:find("test.lua") ~= nil)
end

T["push"] = new_set()

T["push"]["returns basic command"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.push()
  ]])
  h.eq("git push", result)
end

T["push"]["adds remote and branch"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.push("origin", "main")
  ]])
  h.eq(true, result:find("origin") ~= nil)
  h.eq(true, result:find("main") ~= nil)
end

T["push"]["adds force flag"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.push("origin", "main", true)
  ]])
  h.eq(true, result:find("--force") ~= nil)
end

T["push"]["adds set-upstream flag"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.push("origin", "main", false, true)
  ]])
  h.eq(true, result:find("%-%-set%-upstream") ~= nil)
end

T["push"]["handles tags flag"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.push(nil, nil, false, false, true)
  ]])
  h.eq(true, result:find("--tags") ~= nil)
  h.eq(true, result:find("origin") ~= nil)
end

T["push"]["handles single tag"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.push(nil, nil, false, false, false, "v1.0.0")
  ]])
  h.eq(true, result:find("v1.0.0") ~= nil)
  h.eq(true, result:find("origin") ~= nil)
end

T["push_array"] = new_set()

T["push_array"]["returns array format"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    local cmd = Command.CommandBuilder.push_array("origin", "main")
    return type(cmd) == "table" and cmd[1] == "git" and cmd[2] == "push"
  ]])
  h.eq(true, result)
end

T["cherry_pick"] = new_set()

T["cherry_pick"]["returns correct command"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.cherry_pick("abc123")
  ]])
  h.eq(true, result:find("git cherry%-pick") ~= nil)
  h.eq(true, result:find("%-%-no%-edit") ~= nil)
  h.eq(true, result:find("abc123") ~= nil)
end

T["cherry_pick_abort"] = new_set()

T["cherry_pick_abort"]["returns correct command"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.cherry_pick_abort()
  ]])
  h.eq("git cherry-pick --abort", result)
end

T["cherry_pick_continue"] = new_set()

T["cherry_pick_continue"]["returns correct command"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.cherry_pick_continue()
  ]])
  h.eq("git cherry-pick --continue", result)
end

T["cherry_pick_skip"] = new_set()

T["cherry_pick_skip"]["returns correct command"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.cherry_pick_skip()
  ]])
  h.eq("git cherry-pick --skip", result)
end

T["revert"] = new_set()

T["revert"]["returns correct command"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.revert("abc123")
  ]])
  h.eq(true, result:find("git revert") ~= nil)
  h.eq(true, result:find("%-%-no%-edit") ~= nil)
  h.eq(true, result:find("abc123") ~= nil)
end

T["tags"] = new_set()

T["tags"]["returns correct command"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.tags()
  ]])
  h.eq("git tag", result)
end

T["tags_sorted"] = new_set()

T["tags_sorted"]["returns correct command"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.tags_sorted()
  ]])
  h.eq("git tag --sort=-version:refname", result)
end

T["create_tag"] = new_set()

T["create_tag"]["creates lightweight tag"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.create_tag("v1.0.0")
  ]])
  h.eq(true, result:find("git tag") ~= nil)
  h.eq(true, result:find("v1.0.0") ~= nil)
end

T["create_tag"]["creates annotated tag"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.create_tag("v1.0.0", "Release 1.0")
  ]])
  h.eq(true, result:find("-a") ~= nil)
  h.eq(true, result:find("-m") ~= nil)
  h.eq(true, result:find("Release 1.0") ~= nil)
end

T["create_tag"]["tags specific commit"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.create_tag("v1.0.0", nil, "abc123")
  ]])
  h.eq(true, result:find("abc123") ~= nil)
end

T["delete_tag"] = new_set()

T["delete_tag"]["deletes local tag"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.delete_tag("v1.0.0")
  ]])
  h.eq(true, result:find("git tag %-d") ~= nil)
  h.eq(true, result:find("v1%.0%.0") ~= nil)
end

T["delete_tag"]["deletes remote tag"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.delete_tag("v1.0.0", "origin")
  ]])
  h.eq(true, result:find("git push %-%-delete") ~= nil)
  h.eq(true, result:find("origin") ~= nil)
end

T["merge"] = new_set()

T["merge"]["returns correct command"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.merge("feature/test")
  ]])
  h.eq(true, result:find("git merge") ~= nil)
  h.eq(true, result:find("%-%-no%-edit") ~= nil)
  h.eq(true, result:find("feature") ~= nil)
end

T["merge_abort"] = new_set()

T["merge_abort"]["returns correct command"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.merge_abort()
  ]])
  h.eq("git merge --abort", result)
end

T["merge_continue"] = new_set()

T["merge_continue"]["returns correct command"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.merge_continue()
  ]])
  h.eq("git merge --continue", result)
end

T["conflict_status"] = new_set()

T["conflict_status"]["returns correct command"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.conflict_status()
  ]])
  h.eq("git diff --name-only --diff-filter=U", result)
end

T["remote_operations"] = new_set()

T["remote_operations"]["add_remote"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.add_remote("upstream", "https://github.com/test/repo.git")
  ]])
  h.eq(true, result:find("git remote add") ~= nil)
  h.eq(true, result:find("upstream") ~= nil)
end

T["remote_operations"]["remove_remote"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.remove_remote("upstream")
  ]])
  h.eq(true, result:find("git remote remove") ~= nil)
  h.eq(true, result:find("upstream") ~= nil)
end

T["remote_operations"]["rename_remote"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.rename_remote("origin", "upstream")
  ]])
  h.eq(true, result:find("git remote rename") ~= nil)
end

T["remote_operations"]["set_remote_url"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.set_remote_url("origin", "https://new-url.git")
  ]])
  h.eq(true, result:find("git remote set%-url") ~= nil)
end

T["fetch"] = new_set()

T["fetch"]["fetches all by default"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.fetch()
  ]])
  h.eq(true, result:find("git fetch") ~= nil)
  h.eq(true, result:find("--all") ~= nil)
end

T["fetch"]["fetches specific remote"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.fetch("origin")
  ]])
  h.eq(true, result:find("origin") ~= nil)
end

T["fetch"]["adds prune flag"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.fetch(nil, nil, true)
  ]])
  h.eq(true, result:find("--prune") ~= nil)
end

T["pull"] = new_set()

T["pull"]["returns basic command"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.pull()
  ]])
  h.eq("git pull", result)
end

T["pull"]["adds remote and branch"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.pull("origin", "main")
  ]])
  h.eq(true, result:find("origin") ~= nil)
  h.eq(true, result:find("main") ~= nil)
end

T["pull"]["adds rebase flag"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.pull("origin", "main", true)
  ]])
  h.eq(true, result:find("--rebase") ~= nil)
end

T["utility"] = new_set()

T["utility"]["is_inside_work_tree"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.is_inside_work_tree()
  ]])
  h.eq(true, result:find("git rev%-parse %-%-is%-inside%-work%-tree") ~= nil)
end

T["utility"]["git_dir"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.git_dir()
  ]])
  h.eq("git rev-parse --git-dir", result)
end

T["utility"]["repo_root"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.repo_root()
  ]])
  h.eq("git rev-parse --show-toplevel", result)
end

T["utility"]["check_ignore returns array"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    local cmd = Command.CommandBuilder.check_ignore("test.lua")
    return type(cmd) == "table"
      and cmd[1] == "git"
      and cmd[2] == "check-ignore"
      and cmd[3] == "--"
      and cmd[4] == "test.lua"
  ]])
  h.eq(true, result)
end

T["rebase"] = new_set()

T["rebase"]["returns basic command"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.rebase()
  ]])
  h.eq("git rebase", result)
end

T["rebase"]["adds onto flag"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.rebase("main")
  ]])
  h.eq(true, result:find("--onto") ~= nil)
  h.eq(true, result:find("main") ~= nil)
end

T["rebase"]["adds interactive flag"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.rebase(nil, nil, true)
  ]])
  h.eq(true, result:find("--interactive") ~= nil)
end

return T
