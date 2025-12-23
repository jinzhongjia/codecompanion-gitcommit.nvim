local M = {}

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
