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
        -- Auto-generation triggers once when entering gitcommit window
        -- Avoids race conditions with plugins like neogit
        -- Skip auto-generation during git amend to preserve user intent
        vim.api.nvim_create_autocmd("WinEnter", {
          buffer = event.buf,
          once = true,
          callback = function(args)
            -- Defer execution to ensure other plugins finish UI setup
            vim.defer_fn(function()
              if not vim.api.nvim_buf_is_valid(args.buf) then
                return
              end

              -- Check if buffer already has commit message
              local lines = vim.api.nvim_buf_get_lines(args.buf, 0, -1, false)
              local has_message = false
              for _, line in ipairs(lines) do
                if not line:match("^%s*#") and vim.trim(line) ~= "" then
                  has_message = true
                  break
                end
              end

              -- Skip auto-generation if:
              -- 1. Buffer already has commit message
              -- 2. In git amend operation (user may want to keep existing message)
              local should_skip_amend = config.skip_auto_generate_on_amend and Git.is_amending()
              if not has_message and not should_skip_amend then
                Buffer._generate_and_insert_commit_message(args.buf)
              end
            end, config.auto_generate_delay)
          end,
          desc = "Auto-generate GitCommit message",
        })
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

---Insert commit message into gitcommit buffer
---@param bufnr number Buffer number
---@param message string Commit message to insert
function Buffer._insert_commit_message(bufnr, message)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    vim.notify("Buffer is no longer valid", vim.log.levels.ERROR)
    return
  end

  -- Get current buffer content
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  -- Find first line that doesn't start with # (comment)
  -- This is where we'll insert commit message
  local insert_line = 0
  for i, line in ipairs(lines) do
    if not line:match("^%s*#") and vim.trim(line) == "" then
      insert_line = i - 1
      break
    elseif not line:match("^%s*#") and vim.trim(line) ~= "" then
      -- Found non-comment, non-empty line, insert before
      insert_line = i - 1
      break
    end
  end

  -- Split message into lines
  local message_lines = vim.split(message, "\n")

  -- Remove existing commit message if present
  local first_comment_line = nil
  for i, line in ipairs(lines) do
    if line:match("^%s*#") then
      first_comment_line = i - 1
      break
    end
  end

  if first_comment_line then
    -- Remove non-comment lines before first comment
    local non_comment_lines = {}
    for i = 1, first_comment_line do
      if not lines[i]:match("^%s*#") and vim.trim(lines[i]) ~= "" then
        -- This is non-comment line, might be existing commit message
      else
        table.insert(non_comment_lines, lines[i])
      end
    end

    -- Clear buffer and insert new content
    vim.api.nvim_buf_set_lines(bufnr, 0, first_comment_line, false, {})
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
