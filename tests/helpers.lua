local H = {}

H.eq = MiniTest.expect.equality
H.not_eq = MiniTest.expect.no_equality

H.expect_match = MiniTest.new_expectation("string matching", function(pattern, str)
  return str:find(pattern, 1, true) ~= nil -- plain text match
end, function(pattern, str)
  return string.format("Pattern: %s\nObserved string: %s", vim.inspect(pattern), str)
end)

H.child_start = function(child)
  child.restart({ "-u", "tests/minimal_init.lua" })
end

return H
