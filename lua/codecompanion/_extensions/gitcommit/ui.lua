---@class CodeCompanion.GitCommit.UI
local UI = {}

---Copy text to system clipboard
---@param text string The text to copy
local function copy_to_clipboard(text)
  vim.fn.setreg("+", text)
  if vim.fn.has("clipboard") == 1 then
    vim.fn.setreg("*", text)
  end
end

---Show commit message in a floating window with interactive options
---@param message string The commit message to display
---@param on_commit fun(message: string): boolean Callback for commit action
function UI.show_commit_message(message, on_commit)
  -- Prepare window content
  local content = UI._prepare_content(message)

  -- Calculate window dimensions
  local width, height = UI._calculate_dimensions(content)

  -- Create buffer and window
  local buf = vim.api.nvim_create_buf(false, true)
  local win = UI._create_window(buf, width, height)

  -- Set buffer content and options
  UI._setup_buffer(buf, content)

  -- Set up keymaps
  UI._setup_keymaps(buf, win, message, on_commit)
end

---Prepare content for the floating window
---@param message string The commit message
---@return table content The formatted content lines
function UI._prepare_content(message)
  local content = {
    "# Generated Commit Message",
    "",
    "```",
  }

  -- Add commit message lines
  local message_lines = vim.split(message, "\n")
  for _, line in ipairs(message_lines) do
    table.insert(content, line)
  end

  table.insert(content, "```")
  table.insert(content, "")
  table.insert(content, "---")
  table.insert(content, "")
  table.insert(content, "## Actions")
  table.insert(content, "")
  table.insert(content, "- **[c]** Copy to clipboard")
  table.insert(content, "- **[s]** Submit (commit changes)")
  table.insert(content, "- **[Enter]** Copy and close")
  table.insert(content, "- **[q/Esc]** Close")

  return content
end

---Calculate window dimensions based on content
---@param content table The content lines
---@return number width, number height The calculated dimensions
function UI._calculate_dimensions(content)
  local max_line_length = 0
  for _, line in ipairs(content) do
    max_line_length = math.max(max_line_length, vim.fn.strdisplaywidth(line))
  end

  local width = math.max(50, math.min(120, max_line_length + 6))
  local height = math.min(math.floor(vim.o.lines * 0.8), #content + 4)

  return width, height
end

---Create floating window
---@param buf number The buffer number
---@param width number Window width
---@param height number Window height
---@return number win The window handle
function UI._create_window(buf, width, height)
  return vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    style = "minimal",
    border = "rounded",
    title = " 🚀 Git Commit Assistant ",
    title_pos = "center",
  })
end

---Setup buffer content and options
---@param buf number The buffer number
---@param content table The content lines
function UI._setup_buffer(buf, content)
  -- Set content
  vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

  -- Set buffer options
  vim.api.nvim_set_option_value("filetype", "markdown", { buf = buf })
  vim.api.nvim_set_option_value("syntax", "on", { buf = buf })
end

---Setup keymaps for the floating window
---@param buf number The buffer number
---@param win number The window handle
---@param message string The commit message
---@param on_commit fun(message: string): boolean Callback for commit action
function UI._setup_keymaps(buf, win, message, on_commit)
  local opts = { buffer = buf, nowait = true, silent = true }

  -- Close window keymaps
  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(win, true)
  end, opts)

  vim.keymap.set("n", "<Esc>", function()
    vim.api.nvim_win_close(win, true)
  end, opts)

  -- Copy to clipboard
  vim.keymap.set("n", "c", function()
    copy_to_clipboard(message)
    vim.notify("📋 Commit message copied to clipboard", vim.log.levels.INFO)
  end, opts)

  -- Submit commit
  vim.keymap.set("n", "s", function()
    local success = on_commit(message)
    if success then
      vim.api.nvim_win_close(win, true)
    end
  end, opts)

  -- Copy and close
  vim.keymap.set("n", "<CR>", function()
    copy_to_clipboard(message)
    vim.notify("📋 Commit message copied to clipboard", vim.log.levels.INFO)
    vim.api.nvim_win_close(win, true)
  end, opts)
end

return UI
