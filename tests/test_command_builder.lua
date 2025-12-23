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

local function has_element(tbl, element)
  for _, v in ipairs(tbl) do
    if v == element then
      return true
    end
  end
  return false
end

local function has_element_containing(tbl, pattern)
  for _, v in ipairs(tbl) do
    if type(v) == "string" and v:find(pattern) then
      return true
    end
  end
  return false
end

T["status"] = new_set()

T["status"]["returns correct command"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.status()
  ]])
  h.eq({ "git", "status", "--porcelain" }, result)
end

T["log"] = new_set()

T["log"]["returns default command"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.log()
  ]])
  h.eq({ "git", "log", "-10", "--oneline" }, result)
end

T["log"]["respects count parameter"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.log(5)
  ]])
  h.eq({ "git", "log", "-5", "--oneline" }, result)
end

T["log"]["respects format parameter"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.log(10, "short")
  ]])
  h.eq({ "git", "log", "-10", "--pretty=short" }, result)
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
  h.eq({ "git", "log", "-1", "--oneline" }, formats.oneline)
  h.eq({ "git", "log", "-1", "--pretty=short" }, formats.short)
  h.eq({ "git", "log", "-1", "--pretty=medium" }, formats.medium)
  h.eq({ "git", "log", "-1", "--pretty=full" }, formats.full)
  h.eq({ "git", "log", "-1", "--pretty=fuller" }, formats.fuller)
end

T["diff"] = new_set()

T["diff"]["returns basic command"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.diff()
  ]])
  h.eq({ "git", "diff" }, result)
end

T["diff"]["adds cached flag for staged"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.diff(true)
  ]])
  h.eq({ "git", "diff", "--cached" }, result)
end

T["diff"]["adds file path"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.diff(false, "test.lua")
  ]])
  h.eq({ "git", "diff", "--", "test.lua" }, result)
end

T["diff"]["adds both staged and file"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.diff(true, "test.lua")
  ]])
  h.eq({ "git", "diff", "--cached", "--", "test.lua" }, result)
end

T["branch"] = new_set()

T["branch"]["current_branch returns correct command"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.current_branch()
  ]])
  h.eq({ "git", "branch", "--show-current" }, result)
end

T["branch"]["branches returns all branches by default"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.branches()
  ]])
  h.eq({ "git", "branch", "-a" }, result)
end

T["branch"]["branches returns remote only when specified"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.branches(true)
  ]])
  h.eq({ "git", "branch", "-r" }, result)
end

T["stage"] = new_set()

T["stage"]["handles single file as string"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.stage("test.lua")
  ]])
  h.eq({ "git", "add", "--", "test.lua" }, result)
end

T["stage"]["handles multiple files"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.stage({"a.lua", "b.lua"})
  ]])
  h.eq({ "git", "add", "--", "a.lua", "b.lua" }, result)
end

T["unstage"] = new_set()

T["unstage"]["returns correct command"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.unstage("test.lua")
  ]])
  h.eq({ "git", "reset", "HEAD", "--", "test.lua" }, result)
end

T["commit"] = new_set()

T["commit"]["returns basic commit command"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.commit("test message")
  ]])
  h.eq({ "git", "commit", "-m", "test message" }, result)
end

T["commit"]["adds amend flag"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.commit("test message", true)
  ]])
  h.eq({ "git", "commit", "--amend", "-m", "test message" }, result)
end

T["create_branch"] = new_set()

T["create_branch"]["creates and checks out by default"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.create_branch("feature/test")
  ]])
  h.eq({ "git", "checkout", "-b", "feature/test" }, result)
end

T["create_branch"]["creates without checkout when specified"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.create_branch("feature/test", false)
  ]])
  h.eq({ "git", "branch", "feature/test" }, result)
end

T["checkout"] = new_set()

T["checkout"]["returns correct command"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.checkout("main")
  ]])
  h.eq({ "git", "checkout", "main" }, result)
end

T["remotes"] = new_set()

T["remotes"]["returns correct command"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.remotes()
  ]])
  h.eq({ "git", "remote", "-v" }, result)
end

T["show"] = new_set()

T["show"]["defaults to HEAD"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.show()
  ]])
  h.eq({ "git", "show", "HEAD" }, result)
end

T["show"]["accepts commit hash"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.show("abc123")
  ]])
  h.eq({ "git", "show", "abc123" }, result)
end

T["blame"] = new_set()

T["blame"]["returns basic command"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.blame("test.lua")
  ]])
  h.eq({ "git", "blame", "--", "test.lua" }, result)
end

T["blame"]["adds line range"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.blame("test.lua", 10, 20)
  ]])
  h.eq({ "git", "blame", "-L", "10,20", "--", "test.lua" }, result)
end

T["blame"]["adds line start with default range"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.blame("test.lua", 10)
  ]])
  h.eq({ "git", "blame", "-L", "10,+10", "--", "test.lua" }, result)
end

T["stash"] = new_set()

T["stash"]["returns basic command"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.stash()
  ]])
  h.eq({ "git", "stash" }, result)
end

T["stash"]["adds untracked flag"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.stash(nil, true)
  ]])
  h.eq({ "git", "stash", "-u" }, result)
end

T["stash"]["adds message"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.stash("WIP", false)
  ]])
  h.eq({ "git", "stash", "-m", "WIP" }, result)
end

T["stash_list"] = new_set()

T["stash_list"]["returns correct command"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.stash_list()
  ]])
  h.eq({ "git", "stash", "list" }, result)
end

T["stash_apply"] = new_set()

T["stash_apply"]["defaults to stash@{0}"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.stash_apply()
  ]])
  h.eq({ "git", "stash", "apply", "stash@{0}" }, result)
end

T["stash_apply"]["accepts custom ref"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.stash_apply("stash@{2}")
  ]])
  h.eq({ "git", "stash", "apply", "stash@{2}" }, result)
end

T["reset"] = new_set()

T["reset"]["defaults to mixed mode"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.reset("HEAD~1")
  ]])
  h.eq({ "git", "reset", "--mixed", "HEAD~1" }, result)
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
  h.eq({ "git", "reset", "--soft", "HEAD~1" }, modes.soft)
  h.eq({ "git", "reset", "--mixed", "HEAD~1" }, modes.mixed)
  h.eq({ "git", "reset", "--hard", "HEAD~1" }, modes.hard)
end

T["diff_commits"] = new_set()

T["diff_commits"]["compares two commits"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.diff_commits("abc123", "def456")
  ]])
  h.eq({ "git", "diff", "abc123", "def456" }, result)
end

T["diff_commits"]["defaults second commit to HEAD"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.diff_commits("abc123")
  ]])
  h.eq({ "git", "diff", "abc123", "HEAD" }, result)
end

T["diff_commits"]["adds file path"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.diff_commits("abc123", "def456", "test.lua")
  ]])
  h.eq({ "git", "diff", "abc123", "def456", "--", "test.lua" }, result)
end

T["push"] = new_set()

T["push"]["returns basic command"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.push()
  ]])
  h.eq({ "git", "push" }, result)
end

T["push"]["adds remote and branch"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.push("origin", "main")
  ]])
  h.eq({ "git", "push", "origin", "main" }, result)
end

T["push"]["adds force flag"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.push("origin", "main", true)
  ]])
  h.eq({ "git", "push", "--force", "origin", "main" }, result)
end

T["push"]["adds set-upstream flag"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.push("origin", "main", false, true)
  ]])
  h.eq({ "git", "push", "--set-upstream", "origin", "main" }, result)
end

T["push"]["handles tags flag"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.push(nil, nil, false, false, true)
  ]])
  h.eq({ "git", "push", "origin", "--tags" }, result)
end

T["push"]["handles single tag"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.push(nil, nil, false, false, false, "v1.0.0")
  ]])
  h.eq({ "git", "push", "origin", "v1.0.0" }, result)
end

T["cherry_pick"] = new_set()

T["cherry_pick"]["returns correct command"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.cherry_pick("abc123")
  ]])
  h.eq({ "git", "cherry-pick", "--no-edit", "abc123" }, result)
end

T["cherry_pick_abort"] = new_set()

T["cherry_pick_abort"]["returns correct command"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.cherry_pick_abort()
  ]])
  h.eq({ "git", "cherry-pick", "--abort" }, result)
end

T["cherry_pick_continue"] = new_set()

T["cherry_pick_continue"]["returns correct command"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.cherry_pick_continue()
  ]])
  h.eq({ "git", "cherry-pick", "--continue" }, result)
end

T["cherry_pick_skip"] = new_set()

T["cherry_pick_skip"]["returns correct command"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.cherry_pick_skip()
  ]])
  h.eq({ "git", "cherry-pick", "--skip" }, result)
end

T["revert"] = new_set()

T["revert"]["returns correct command"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.revert("abc123")
  ]])
  h.eq({ "git", "revert", "--no-edit", "abc123" }, result)
end

T["tags"] = new_set()

T["tags"]["returns correct command"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.tags()
  ]])
  h.eq({ "git", "tag" }, result)
end

T["tags_sorted"] = new_set()

T["tags_sorted"]["returns correct command"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.tags_sorted()
  ]])
  h.eq({ "git", "tag", "--sort=-version:refname" }, result)
end

T["create_tag"] = new_set()

T["create_tag"]["creates lightweight tag"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.create_tag("v1.0.0")
  ]])
  h.eq({ "git", "tag", "v1.0.0" }, result)
end

T["create_tag"]["creates annotated tag"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.create_tag("v1.0.0", "Release 1.0")
  ]])
  h.eq({ "git", "tag", "-a", "v1.0.0", "-m", "Release 1.0" }, result)
end

T["create_tag"]["tags specific commit"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.create_tag("v1.0.0", nil, "abc123")
  ]])
  h.eq({ "git", "tag", "v1.0.0", "abc123" }, result)
end

T["delete_tag"] = new_set()

T["delete_tag"]["deletes local tag"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.delete_tag("v1.0.0")
  ]])
  h.eq({ "git", "tag", "-d", "v1.0.0" }, result)
end

T["delete_tag"]["deletes remote tag"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.delete_tag("v1.0.0", "origin")
  ]])
  h.eq({ "git", "push", "--delete", "origin", "v1.0.0" }, result)
end

T["merge"] = new_set()

T["merge"]["returns correct command"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.merge("feature/test")
  ]])
  h.eq({ "git", "merge", "feature/test", "--no-edit" }, result)
end

T["merge_abort"] = new_set()

T["merge_abort"]["returns correct command"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.merge_abort()
  ]])
  h.eq({ "git", "merge", "--abort" }, result)
end

T["merge_continue"] = new_set()

T["merge_continue"]["returns correct command"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.merge_continue()
  ]])
  h.eq({ "git", "merge", "--continue" }, result)
end

T["conflict_status"] = new_set()

T["conflict_status"]["returns correct command"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.conflict_status()
  ]])
  h.eq({ "git", "diff", "--name-only", "--diff-filter=U" }, result)
end

T["contributors"] = new_set()

T["contributors"]["returns correct command"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.contributors()
  ]])
  h.eq({ "git", "shortlog", "-sn" }, result)
end

T["search_commits"] = new_set()

T["search_commits"]["returns correct command"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.search_commits("fix")
  ]])
  h.eq({ "git", "log", "--grep=fix", "--oneline", "-20" }, result)
end

T["search_commits"]["respects count parameter"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.search_commits("feat", 10)
  ]])
  h.eq({ "git", "log", "--grep=feat", "--oneline", "-10" }, result)
end

T["remote_operations"] = new_set()

T["remote_operations"]["add_remote"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.add_remote("upstream", "https://github.com/test/repo.git")
  ]])
  h.eq({ "git", "remote", "add", "upstream", "https://github.com/test/repo.git" }, result)
end

T["remote_operations"]["remove_remote"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.remove_remote("upstream")
  ]])
  h.eq({ "git", "remote", "remove", "upstream" }, result)
end

T["remote_operations"]["rename_remote"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.rename_remote("origin", "upstream")
  ]])
  h.eq({ "git", "remote", "rename", "origin", "upstream" }, result)
end

T["remote_operations"]["set_remote_url"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.set_remote_url("origin", "https://new-url.git")
  ]])
  h.eq({ "git", "remote", "set-url", "origin", "https://new-url.git" }, result)
end

T["fetch"] = new_set()

T["fetch"]["fetches all by default"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.fetch()
  ]])
  h.eq({ "git", "fetch", "--all" }, result)
end

T["fetch"]["fetches specific remote"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.fetch("origin")
  ]])
  h.eq({ "git", "fetch", "origin" }, result)
end

T["fetch"]["adds prune flag"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.fetch(nil, nil, true)
  ]])
  h.eq({ "git", "fetch", "--prune", "--all" }, result)
end

T["fetch"]["fetches remote with branch"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.fetch("origin", "main")
  ]])
  h.eq({ "git", "fetch", "origin", "main" }, result)
end

T["pull"] = new_set()

T["pull"]["returns basic command"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.pull()
  ]])
  h.eq({ "git", "pull" }, result)
end

T["pull"]["adds remote and branch"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.pull("origin", "main")
  ]])
  h.eq({ "git", "pull", "origin", "main" }, result)
end

T["pull"]["adds rebase flag"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.pull("origin", "main", true)
  ]])
  h.eq({ "git", "pull", "--rebase", "origin", "main" }, result)
end

T["utility"] = new_set()

T["utility"]["is_inside_work_tree"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.is_inside_work_tree()
  ]])
  h.eq({ "git", "rev-parse", "--is-inside-work-tree" }, result)
end

T["utility"]["verify_head"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.verify_head()
  ]])
  h.eq({ "git", "rev-parse", "--verify", "HEAD" }, result)
end

T["utility"]["git_dir"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.git_dir()
  ]])
  h.eq({ "git", "rev-parse", "--git-dir" }, result)
end

T["utility"]["repo_root"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.repo_root()
  ]])
  h.eq({ "git", "rev-parse", "--show-toplevel" }, result)
end

T["utility"]["check_ignore returns array"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.check_ignore("test.lua")
  ]])
  h.eq({ "git", "check-ignore", "--", "test.lua" }, result)
end

T["rebase"] = new_set()

T["rebase"]["returns basic command"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.rebase()
  ]])
  h.eq({ "git", "rebase" }, result)
end

T["rebase"]["adds onto flag"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.rebase("main")
  ]])
  h.eq({ "git", "rebase", "--onto", "main" }, result)
end

T["rebase"]["adds interactive flag"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.rebase(nil, nil, true)
  ]])
  h.eq({ "git", "rebase", "--interactive" }, result)
end

T["rebase"]["adds base branch"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.rebase(nil, "develop")
  ]])
  h.eq({ "git", "rebase", "develop" }, result)
end

T["rebase_abort"] = new_set()

T["rebase_abort"]["returns correct command"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.rebase_abort()
  ]])
  h.eq({ "git", "rebase", "--abort" }, result)
end

T["rebase_continue"] = new_set()

T["rebase_continue"]["returns correct command"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.rebase_continue()
  ]])
  h.eq({ "git", "rebase", "--continue" }, result)
end

T["release_notes_log"] = new_set()

T["release_notes_log"]["returns correct command"] = function()
  local result = child.lua([[
    local Command = require("codecompanion._extensions.gitcommit.tools.command")
    return Command.CommandBuilder.release_notes_log("v1.0.0", "v1.1.0")
  ]])
  h.eq(result[1], "git")
  h.eq(result[2], "log")
  h.eq(result[4], "--date=short")
  h.eq(result[5], "v1.0.0..v1.1.0")
end

return T
