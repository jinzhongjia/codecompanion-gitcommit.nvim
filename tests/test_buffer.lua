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

T["_insert_commit_message"] = new_set()

T["_insert_commit_message"]["replaces existing message and keeps comments"] = function()
  local result = child.lua([[
    package.preload["codecompanion._extensions.gitcommit.generator"] = function()
      return {}
    end
    local Buffer = require("codecompanion._extensions.gitcommit.buffer")
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(bufnr)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
      "old subject",
      "old body",
      "# comment",
      "# more",
    })
    Buffer._insert_commit_message(bufnr, "feat: new")
    return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  ]])
  h.eq({ "feat: new", "", "# comment", "# more" }, result)
end

T["_insert_commit_message"]["handles verbose separator"] = function()
  local result = child.lua([[
    package.preload["codecompanion._extensions.gitcommit.generator"] = function()
      return {}
    end
    local Buffer = require("codecompanion._extensions.gitcommit.buffer")
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(bufnr)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
      "old subject",
      "# ------------------------ >8 ------------------------",
      "# diff",
    })
    Buffer._insert_commit_message(bufnr, "fix: bug")
    return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  ]])
  h.eq({ "fix: bug", "", "# ------------------------ >8 ------------------------", "# diff" }, result)
end

T["_insert_commit_message"]["adds blank line when missing"] = function()
  local result = child.lua([[
    package.preload["codecompanion._extensions.gitcommit.generator"] = function()
      return {}
    end
    local Buffer = require("codecompanion._extensions.gitcommit.buffer")
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(bufnr)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "# comment" })
    Buffer._insert_commit_message(bufnr, "chore: update")
    return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  ]])
  h.eq({ "chore: update", "", "# comment" }, result)
end

T["_insert_commit_message"]["skips cursor move when buffer hidden"] = function()
  local result = child.lua([[
    package.preload["codecompanion._extensions.gitcommit.generator"] = function()
      return {}
    end
    local Buffer = require("codecompanion._extensions.gitcommit.buffer")
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(bufnr)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "# comment" })

    local called = 0
    local orig_bufwinid = vim.fn.bufwinid
    local orig_set_cursor = vim.api.nvim_win_set_cursor
    vim.fn.bufwinid = function() return -1 end
    vim.api.nvim_win_set_cursor = function()
      called = called + 1
    end

    Buffer._insert_commit_message(bufnr, "feat: hidden")

    vim.fn.bufwinid = orig_bufwinid
    vim.api.nvim_win_set_cursor = orig_set_cursor
    return called
  ]])
  h.eq(0, result)
end

T["auto_generate"] = new_set()

T["auto_generate"]["skips when amending"] = function()
  local result = child.lua([[
    package.preload["codecompanion._extensions.gitcommit.generator"] = function()
      return {}
    end
    local Buffer = require("codecompanion._extensions.gitcommit.buffer")
    local Git = require("codecompanion._extensions.gitcommit.git")

    local autocmds = {}
    vim.api.nvim_create_autocmd = function(event, opts)
      table.insert(autocmds, { event = event, opts = opts })
    end

    vim.defer_fn = function(fn, _delay)
      fn()
      return { stop = function() end }
    end

    Git.is_amending = function() return true end

    local called = 0
    Buffer._generate_and_insert_commit_message = function()
      called = called + 1
    end

    Buffer.setup({ auto_generate = true, auto_generate_delay = 0, window_stability_delay = 0 })

    local bufnr = vim.api.nvim_create_buf(false, true)
    local filetype_cb
    for _, item in ipairs(autocmds) do
      if item.event == "FileType" then
        filetype_cb = item.opts.callback
      end
    end

    filetype_cb({ buf = bufnr })

    for _, item in ipairs(autocmds) do
      if item.event == "WinEnter" then
        item.opts.callback({ buf = bufnr })
      end
    end

    return called
  ]])
  h.eq(0, result)
end

T["auto_generate"]["skips when buffer has message"] = function()
  local result = child.lua([[
    package.preload["codecompanion._extensions.gitcommit.generator"] = function()
      return {}
    end
    local Buffer = require("codecompanion._extensions.gitcommit.buffer")
    local Git = require("codecompanion._extensions.gitcommit.git")

    local autocmds = {}
    vim.api.nvim_create_autocmd = function(event, opts)
      table.insert(autocmds, { event = event, opts = opts })
    end

    vim.defer_fn = function(fn, _delay)
      fn()
      return { stop = function() end }
    end

    Git.is_amending = function() return false end

    local called = 0
    Buffer._generate_and_insert_commit_message = function()
      called = called + 1
    end

    Buffer.setup({ auto_generate = true, auto_generate_delay = 0, window_stability_delay = 0 })

    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "existing subject", "# comment" })

    local filetype_cb
    for _, item in ipairs(autocmds) do
      if item.event == "FileType" then
        filetype_cb = item.opts.callback
      end
    end

    filetype_cb({ buf = bufnr })

    for _, item in ipairs(autocmds) do
      if item.event == "WinEnter" then
        item.opts.callback({ buf = bufnr })
      end
    end

    return called
  ]])
  h.eq(0, result)
end

T["auto_generate"]["triggers on empty buffer"] = function()
  local result = child.lua([[
    package.preload["codecompanion._extensions.gitcommit.generator"] = function()
      return {}
    end
    local Buffer = require("codecompanion._extensions.gitcommit.buffer")
    local Git = require("codecompanion._extensions.gitcommit.git")

    local autocmds = {}
    vim.api.nvim_create_autocmd = function(event, opts)
      table.insert(autocmds, { event = event, opts = opts })
    end

    vim.defer_fn = function(fn, _delay)
      fn()
      return { stop = function() end }
    end

    Git.is_amending = function() return false end

    local called = 0
    Buffer._generate_and_insert_commit_message = function()
      called = called + 1
    end

    Buffer.setup({ auto_generate = true, auto_generate_delay = 0, window_stability_delay = 0 })

    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "# comment" })

    local filetype_cb
    for _, item in ipairs(autocmds) do
      if item.event == "FileType" then
        filetype_cb = item.opts.callback
      end
    end

    filetype_cb({ buf = bufnr })

    for _, item in ipairs(autocmds) do
      if item.event == "WinEnter" then
        item.opts.callback({ buf = bufnr })
      end
    end

    return called
  ]])
  h.eq(1, result)
end

T["auto_generate"]["ignores verbose diff separator"] = function()
  local result = child.lua([[
    package.preload["codecompanion._extensions.gitcommit.generator"] = function()
      return {}
    end
    local Buffer = require("codecompanion._extensions.gitcommit.buffer")
    local Git = require("codecompanion._extensions.gitcommit.git")

    local autocmds = {}
    vim.api.nvim_create_autocmd = function(event, opts)
      table.insert(autocmds, { event = event, opts = opts })
    end

    vim.defer_fn = function(fn, _delay)
      fn()
      return { stop = function() end }
    end

    Git.is_amending = function() return false end

    local called = 0
    Buffer._generate_and_insert_commit_message = function()
      called = called + 1
    end

    Buffer.setup({ auto_generate = true, auto_generate_delay = 0, window_stability_delay = 0 })

    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
      "# ------------------------ >8 ------------------------",
      "# diff",
    })

    local filetype_cb
    for _, item in ipairs(autocmds) do
      if item.event == "FileType" then
        filetype_cb = item.opts.callback
      end
    end

    filetype_cb({ buf = bufnr })

    for _, item in ipairs(autocmds) do
      if item.event == "WinEnter" then
        item.opts.callback({ buf = bufnr })
      end
    end

    return called
  ]])
  h.eq(1, result)
end

T["auto_generate"]["debounces repeated triggers"] = function()
  local result = child.lua([[
    package.preload["codecompanion._extensions.gitcommit.generator"] = function()
      return {}
    end
    local Buffer = require("codecompanion._extensions.gitcommit.buffer")
    local Git = require("codecompanion._extensions.gitcommit.git")

    local autocmds = {}
    vim.api.nvim_create_autocmd = function(event, opts)
      table.insert(autocmds, { event = event, opts = opts })
    end

    vim.defer_fn = function(fn, _delay)
      fn()
      return { stop = function() end }
    end

    Git.is_amending = function() return false end

    local called = 0
    Buffer._generate_and_insert_commit_message = function()
      called = called + 1
    end

    Buffer.setup({ auto_generate = true, auto_generate_delay = 0, window_stability_delay = 0 })

    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "# comment" })

    local filetype_cb
    for _, item in ipairs(autocmds) do
      if item.event == "FileType" then
        filetype_cb = item.opts.callback
      end
    end

    filetype_cb({ buf = bufnr })

    for _, item in ipairs(autocmds) do
      if item.event == "WinEnter" then
        item.opts.callback({ buf = bufnr })
        item.opts.callback({ buf = bufnr })
      end
    end

    return called
  ]])
  h.eq(1, result)
end

T["auto_generate"]["cleans up pending timer on buffer unload"] = function()
  local result = child.lua([[
    package.preload["codecompanion._extensions.gitcommit.generator"] = function()
      return {}
    end
    local Buffer = require("codecompanion._extensions.gitcommit.buffer")
    local Git = require("codecompanion._extensions.gitcommit.git")

    local autocmds = {}
    vim.api.nvim_create_autocmd = function(event, opts)
      table.insert(autocmds, { event = event, opts = opts })
    end

    local stopped = 0
    vim.defer_fn = function(_fn, _delay)
      return {
        stop = function()
          stopped = stopped + 1
        end,
      }
    end

    Git.is_amending = function() return false end

    Buffer.setup({ auto_generate = true, auto_generate_delay = 0, window_stability_delay = 0 })

    local bufnr = vim.api.nvim_create_buf(false, true)
    local filetype_cb
    for _, item in ipairs(autocmds) do
      if item.event == "FileType" then
        filetype_cb = item.opts.callback
      end
    end

    filetype_cb({ buf = bufnr })

    for _, item in ipairs(autocmds) do
      if item.event == "WinEnter" then
        item.opts.callback({ buf = bufnr })
      end
    end

    for _, item in ipairs(autocmds) do
      if item.event == "BufDelete" then
        item.opts.callback({ buf = bufnr })
      elseif type(item.event) == "table" then
        for _, event in ipairs(item.event) do
          if event == "BufDelete" then
            item.opts.callback({ buf = bufnr })
            break
          end
        end
      end
    end

    return stopped
  ]])
  h.eq(1, result)
end

return T
