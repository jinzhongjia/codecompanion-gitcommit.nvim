local H = {}

H.eq = MiniTest.expect.equality
H.not_eq = MiniTest.expect.no_equality

H.expect_match = MiniTest.new_expectation("string matching", function(pattern, str)
  return str:find(pattern, 1, true) ~= nil
end, function(pattern, str)
  return string.format("Pattern: %s\nObserved string: %s", vim.inspect(pattern), str)
end)

H.expect_array_contains = MiniTest.new_expectation("array contains element", function(element, arr)
  if type(arr) ~= "table" then
    return false
  end
  for _, v in ipairs(arr) do
    if v == element then
      return true
    end
  end
  return false
end, function(element, arr)
  return string.format("Element: %s\nArray: %s", vim.inspect(element), vim.inspect(arr))
end)

H.child_start = function(child)
  child.restart({ "-u", "tests/minimal_init.lua" })
end

return H
