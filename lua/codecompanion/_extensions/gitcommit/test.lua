-- Simple test script for CodeCompanion Git Commit Extension
-- Run with: :luafile lua/codecompanion/_extensions/gitcommit/test.lua

local function test_git_module()
	print("Testing Git module...")

	local Git = require("codecompanion._extensions.gitcommit.git")

	-- Test repository detection
	local is_repo = Git.is_repository()
	print("Is git repository:", is_repo)

	if is_repo then
		-- Test staged diff
		local diff = Git.get_staged_diff()
		if diff then
			print("Staged changes found (length):", string.len(diff))
		else
			print("No staged changes found")
		end
	end
end

local function test_generator_module()
	print("\nTesting Generator module...")

	local Generator = require("codecompanion._extensions.gitcommit.generator")

	-- Test with sample diff (only if CodeCompanion is available)
	local ok, _ = pcall(require, "codecompanion")
	if ok then
		local sample_diff = [[
diff --git a/test.lua b/test.lua
new file mode 100644
index 0000000..1234567
--- /dev/null
+++ b/test.lua
@@ -0,0 +1,3 @@
+-- Test file
+local function hello()
+  print("Hello, world!")
+end
]]

		print("Testing with sample diff...")
		Generator.generate_commit_message(sample_diff, function(result, error)
			if error then
				print("Generator error:", error)
			else
				print("Generated message:", result or "nil")
			end
		end)
	else
		print("CodeCompanion not available, skipping generator test")
	end
end

local function test_main_module()
	print("\nTesting main module...")

	local M = require("codecompanion._extensions.gitcommit")

	-- Test exported functions
	print("Module loaded successfully")
	print("Exports available:")
	for key, _ in pairs(M.exports or {}) do
		print("  -", key)
	end
end

local function run_tests()
	print("=== CodeCompanion Git Commit Extension Tests ===\n")

	local success, error = pcall(function()
		test_git_module()
		test_generator_module()
		test_main_module()
	end)

	if success then
		print("\n✅ All tests completed")
	else
		print("\n❌ Test error:", error)
	end

	print("\n=== Tests End ===")
end

-- Run tests
run_tests()

return {
	run_tests = run_tests,
	test_git_module = test_git_module,
	test_generator_module = test_generator_module,
	test_main_module = test_main_module,
}

