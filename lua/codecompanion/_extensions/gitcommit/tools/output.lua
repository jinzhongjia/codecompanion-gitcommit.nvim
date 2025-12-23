local M = {}

---Convert vim.NIL to nil for a single value
---@param value any
---@return any
local function nil_or_value(value)
  if value == vim.NIL then
    return nil
  end
  return value
end

---Normalize args table by converting vim.NIL values to nil
---This is needed because JSON null becomes vim.NIL in Neovim,
---but vim.NIL is truthy in Lua conditionals (it's userdata, not nil)
---@param args table The args table to normalize
---@return table The normalized args table
function M.normalize_args(args)
  if args == nil or type(args) ~= "table" then
    return args
  end
  local normalized = {}
  for k, v in pairs(args) do
    normalized[k] = nil_or_value(v)
  end
  return normalized
end

---@param out any
---@param fallback? string
---@return string
function M.normalize_output(out, fallback)
  if out == nil then
    return fallback or ""
  end
  if type(out) == "string" then
    return out
  end
  if type(out) ~= "table" then
    return tostring(out)
  end
  if vim.tbl_islist(out) then
    local lines = {}
    local has_nested = false
    for _, v in ipairs(out) do
      if type(v) == "table" then
        has_nested = true
        break
      end
    end
    if has_nested then
      for _, v in ipairs(out) do
        if type(v) == "table" then
          for _, line in ipairs(v) do
            if line ~= nil and line ~= "" then
              table.insert(lines, tostring(line))
            end
          end
        elseif v ~= nil and v ~= "" then
          table.insert(lines, tostring(v))
        end
      end
    else
      for _, v in ipairs(out) do
        if v ~= nil and v ~= "" then
          table.insert(lines, tostring(v))
        end
      end
    end
    if #lines == 0 then
      return fallback or ""
    end
    return table.concat(lines, "\n")
  end
  if type(out.data) == "string" then
    return out.data
  end
  if type(out.stdout) == "string" then
    return out.stdout
  end
  if type(out.stderr) == "string" then
    return out.stderr
  end
  return fallback or tostring(out)
end

return M
