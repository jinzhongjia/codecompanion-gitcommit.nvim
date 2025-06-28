local Langs = require("codecompanion._extensions.gitcommit.langs")
local Git = require("codecompanion._extensions.gitcommit.git")
local Generator = require("codecompanion._extensions.gitcommit.generator")

---@class CodeCompanion.GitCommit.Buffer
local Buffer = {}

---@type CodeCompanion.GitCommit.ExtensionOpts.Buffer Default configuration
local default_config = {
  enabled = true,
  keymap = "<leader>gc",
  auto_generate = false,
  auto_generate_delay = 100, -- Default delay in ms
}

---@type table Current configuration
local config = {}

---Setup buffer keymaps for gitcommit filetype
---@param opts? CodeCompanion.GitCommit.ExtensionOpts.Buffer Configuration options
function Buffer.setup(opts)
  config = vim.tbl_deep_extend("force", default_config, opts or {})

  if not config.enabled then
    return
  end

  -- Create autocommand for gitcommit filetype
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "gitcommit",
    callback = function(event)
      Buffer._setup_gitcommit_keymap(event.buf)

      if config.auto_generate then
        -- This autocommand will trigger once when the user enters the gitcommit window.
        -- This avoids race conditions with plugins like neogit that manage multiple windows.
        vim.api.nvim_create_autocmd("WinEnter", {
          buffer = event.buf,
          once = true,
          callback = function(args)
            -- Defer the execution to ensure other plugins (like neogit) have finished their UI setup.
            vim.defer_fn(function()
              if not vim.api.nvim_buf_is_valid(args.buf) then
                return
              end

              -- Check if buffer already has a commit message (e.g., during amend)
              local lines = vim.api.nvim_buf_get_lines(args.buf, 0, -1, false)
              local has_message = false
              for _, line in ipairs(lines) do
                if not line:match("^%s*#") and vim.trim(line) ~= "" then
                  has_message = true
                  break
                end
              end

              if not has_message then
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

---Setup keymap for specific gitcommit buffer
---@param bufnr number Buffer number
function Buffer._setup_gitcommit_keymap(bufnr)
  -- Only set keymap if buffer is modifiable and in gitcommit filetype
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
  vim.notify("Generating commit message...", vim.log.levels.INFO)

  -- Check if we're in a git repository
  if not Git.is_repository() then
    vim.notify("Not in a git repository", vim.log.levels.ERROR)
    return
  end

  -- Get relevant changes (staged or amend)
  local diff, context = Git.get_contextual_diff()
  if not diff then
    local msg = context == "no_changes"
        and (Git.is_amending() and "No changes to amend" or "No staged changes found. Please stage your changes first.")
      or "Failed to get git changes"
    vim.notify(msg, vim.log.levels.ERROR)
    return
  end

  Langs.select_lang(function(lang)
    -- Generate commit message using LLM
    Generator.generate_commit_message(diff, lang, function(result, error)
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

  -- Find the first line that doesn't start with # (comment)
  -- This is where we'll insert the commit message
  local insert_line = 0
  for i, line in ipairs(lines) do
    if not line:match("^%s*#") and vim.trim(line) == "" then
      insert_line = i - 1
      break
    elseif not line:match("^%s*#") and vim.trim(line) ~= "" then
      -- Found non-comment, non-empty line, insert before it
      insert_line = i - 1
      break
    end
  end

  -- Split message into lines
  local message_lines = vim.split(message, "\n")

  -- Remove existing commit message if present (before first comment line)
  local first_comment_line = nil
  for i, line in ipairs(lines) do
    if line:match("^%s*#") then
      first_comment_line = i - 1
      break
    end
  end

  if first_comment_line then
    -- Remove non-comment lines before the first comment
    local non_comment_lines = {}
    for i = 1, first_comment_line do
      if not lines[i]:match("^%s*#") and vim.trim(lines[i]) ~= "" then
        -- This is a non-comment line, it might be an existing commit message
      else
        table.insert(non_comment_lines, lines[i])
      end
    end

    -- Clear the buffer and insert new content
    vim.api.nvim_buf_set_lines(bufnr, 0, first_comment_line, false, {})
  end

  -- Insert the new commit message at the beginning
  vim.api.nvim_buf_set_lines(bufnr, 0, 0, false, message_lines)

  -- Add an empty line after the commit message if it doesn't end with one
  if #message_lines > 0 and message_lines[#message_lines] ~= "" then
    vim.api.nvim_buf_set_lines(bufnr, #message_lines, #message_lines, false, { "" })
  end

  -- Move cursor to the beginning of the commit message
  vim.api.nvim_win_set_cursor(0, { 1, 0 })

  vim.notify("Commit message generated and inserted!", vim.log.levels.INFO)
end

---Get current configuration
---@return table config Current configuration
function Buffer.get_config()
  return vim.deepcopy(config)
end

return Buffer
