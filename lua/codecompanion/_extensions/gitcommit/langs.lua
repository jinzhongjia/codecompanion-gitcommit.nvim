local M = {}

--- @type string[]?
local _langs = nil

function M.setup(langs)
  _langs = langs or {}
  if type(_langs) ~= "table" then
    error("langs must be a array of language names")
  end
end

--- @param callback fun(choice: string|nil) Callback function to handle the selected language
function M.select_lang(callback)
  if not _langs or #_langs == 0 then
    callback(nil)
    return
  end

  -- If only one language is configured, use it directly
  if #_langs == 1 then
    callback(_langs[1])
    return
  end

  vim.ui.select(_langs, {
    prompt = "Select language:",
    format_item = function(item)
      return item
    end,
  }, function(choice)
    callback(choice)
  end)
end

return M
