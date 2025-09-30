local Langs = require("codecompanion._extensions.gitcommit.langs")
local Git = require("codecompanion._extensions.gitcommit.git")
local Generator = require("codecompanion._extensions.gitcommit.generator")

---@class CodeCompanion.GitCommit.Buffer
local Buffer = {}

local default_config = {
  enabled = true,
  keymap = "<leader>gc",
  auto_generate = false,
  auto_generate_delay = 100, -- Default delay in ms
  window_stability_delay = 300, -- Extra delay for window stability in ms
  skip_auto_generate_on_amend = true, -- Skip auto-generation during git commit --amend
}

---@type table Current configuration
local config = {}

---Setup buffer keymaps for gitcommit filetype
---@param opts? CodeCompanion.GitCommit.ExtensionOpts.Buffer Config options
function Buffer.setup(opts)
  config = vim.tbl_deep_extend("force", default_config, opts or {})

  if not config.enabled then
    return
  end

  -- Create autocommand for gitcommit
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "gitcommit",
    callback = function(event)
      Buffer._setup_gitcommit_keymap(event.buf)

      if config.auto_generate then
        -- Auto-generation with stable timing detection for different Git tools
        local auto_generate_attempted = false
        local pending_timer = nil

        local function should_attempt_auto_generate(bufnr)
          -- Don't attempt if we already successfully generated for this buffer
          if auto_generate_attempted then
            return false
          end

          -- Ensure buffer is valid
          if not vim.api.nvim_buf_is_valid(bufnr) then
            return false
          end

          local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

          -- Find the verbose diff separator line (git commit --verbose adds this)
          -- Format: "# ------------------------ >8 ------------------------"
          local verbose_separator_line = nil
          for i, line in ipairs(lines) do
            if line:match("^#.*%-%-%-+%s*>8%s*%-%-%-+") then
              verbose_separator_line = i
              break
            end
          end

          -- Check if buffer already has commit message
          -- Only check lines before the verbose separator (if present)
          local check_end = verbose_separator_line or #lines
          local has_message = false
          for i = 1, check_end do
            local line = lines[i]
            if not line:match("^%s*#") and vim.trim(line) ~= "" then
              has_message = true
              break
            end
          end

          -- Skip if buffer already has content
          if has_message then
            return false
          end

          -- Skip auto-generation during git amend operation
          local should_skip_amend = config.skip_auto_generate_on_amend and Git.is_amending()
          if should_skip_amend then
            return false
          end

          return true
        end

        local function schedule_auto_generate(bufnr)
          -- Cancel any pending timer to avoid multiple generations
          if pending_timer then
            pending_timer:stop()
            pending_timer = nil
          end

          -- Schedule generation with extended delay for stability
          pending_timer = vim.defer_fn(function()
            pending_timer = nil
            if should_attempt_auto_generate(bufnr) then
              auto_generate_attempted = true
              Buffer._generate_and_insert_commit_message(bufnr)
            end
          end, config.auto_generate_delay + config.window_stability_delay) -- Extra delay for window stability
        end

        -- Shared callback function for autocommands to reduce duplication
        local autocmd_callback = function(args)
          schedule_auto_generate(args.buf)
        end

        -- Multiple event triggers to ensure compatibility with different Git tools
        local autocmd_opts = {
          buffer = event.buf,
          desc = "Auto-generate GitCommit message",
          callback = autocmd_callback,
        }

        -- Primary trigger: WinEnter (works with most tools)
        vim.api.nvim_create_autocmd("WinEnter", autocmd_opts)

        -- Secondary trigger: BufWinEnter (works with Fugitive)
        vim.api.nvim_create_autocmd("BufWinEnter", autocmd_opts)

        -- Tertiary trigger: CursorMoved (fallback, with debouncing)
        vim.api.nvim_create_autocmd("CursorMoved", autocmd_opts)

        -- Cleanup timer when buffer is deleted or unloaded
        vim.api.nvim_create_autocmd(
          { "BufDelete", "BufUnload" },
          vim.tbl_extend("force", autocmd_opts, {
            callback = function()
              if pending_timer then
                pending_timer:stop()
                pending_timer = nil
              end
            end,
          })
        )
      end
    end,
    desc = "Setup GitCommit AI assistant",
  })
end

---Setup keymap for gitcommit buffer
---@param bufnr number Buffer number
function Buffer._setup_gitcommit_keymap(bufnr)
  -- Only set keymap if buffer is valid
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  -- Set buffer-local keymap
  vim.keymap.set("n", config.keymap, function()
    Buffer._generate_and_insert_commit_message(bufnr)
  end, {
    buffer = bufnr,
    desc = "Generate AI commit message",
    silent = true,
  })
end

---Generate commit message and insert into gitcommit buffer
---@param bufnr number Buffer number
function Buffer._generate_and_insert_commit_message(bufnr)
  -- Check git repository
  if not Git.is_repository() then
    vim.notify("Not in a git repository", vim.log.levels.ERROR)
    return
  end

  -- Get changes for commit
  local diff, context = Git.get_contextual_diff()
  if not diff then
    local msg
    if context == "no_changes" then
      msg = Git.is_amending() and "No changes to amend" or "No staged changes found. Please stage your changes first."
    else
      msg = "Failed to get git changes, context=" .. tostring(context)
    end
    vim.notify(msg, vim.log.levels.ERROR)
    return
  end

  Langs.select_lang(function(lang)
    -- Check if user cancelled language selection
    if lang == nil then
      return
    end

    vim.notify("Generating commit message...", vim.log.levels.INFO)

    -- Get commit history for context
    local commit_history = nil
    local git_config = Git.get_config and Git.get_config() or {}
    if git_config.use_commit_history then
      commit_history = Git.get_commit_history(git_config.commit_history_count)
    end

    -- Generate commit message
    Generator.generate_commit_message(diff, lang, commit_history, function(result, error)
      if error then
        vim.notify("Failed to generate commit message: " .. error, vim.log.levels.ERROR)
        return
      end

      if result then
        Buffer._insert_commit_message(bufnr, result)
      else
        vim.notify("Failed to generate commit message", vim.log.levels.ERROR)
      end
    end)
  end)
end

function Buffer._insert_commit_message(bufnr, message)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    vim.notify("Buffer is no longer valid", vim.log.levels.ERROR)
    return
  end

  -- Get current buffer content
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  -- Find verbose diff separator (git commit --verbose)
  local verbose_separator_line = nil
  for i, line in ipairs(lines) do
    if line:match("^#.*%-%-%-+%s*>8%s*%-%-%-+") then
      verbose_separator_line = i
      break
    end
  end

  -- Find first comment line (or verbose separator if present)
  -- This is where we'll insert commit message
  local first_comment_line = nil
  local check_end = verbose_separator_line or #lines
  for i = 1, check_end do
    local line = lines[i]
    if line:match("^%s*#") then
      first_comment_line = i
      break
    end
  end

  -- Split message into lines
  local message_lines = vim.split(message, "\n")

  if first_comment_line then
    -- Remove any existing commit message (non-comment lines before first comment)
    vim.api.nvim_buf_set_lines(bufnr, 0, first_comment_line - 1, false, {})
  end

  -- Insert new commit message at beginning
  vim.api.nvim_buf_set_lines(bufnr, 0, 0, false, message_lines)

  -- Add empty line after commit message if needed
  if #message_lines > 0 and message_lines[#message_lines] ~= "" then
    vim.api.nvim_buf_set_lines(bufnr, #message_lines, #message_lines, false, { "" })
  end

  -- Move cursor to beginning of commit message
  vim.api.nvim_win_set_cursor(0, { 1, 0 })

  vim.notify("Commit message generated and inserted!", vim.log.levels.INFO)
end

---Get current configuration
---@return table config Current configuration
function Buffer.get_config()
  return vim.deepcopy(config)
end

return Buffer
