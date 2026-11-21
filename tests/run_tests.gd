extends SceneTree
## Headless test runner. Exit code 0 = all green, 1 = failures.
##   godot --headless --path . --script res://tests/run_tests.gd [-- test_name ...]

const SUITES := [
	"res://tests/test_power_grid.gd",
	"res://tests/test_inventory.gd",
	"res://tests/test_save.gd",
	"res://tests/test_world.gd",
	"res://tests/test_drone.gd",
	"res://tests/test_walkthrough.gd",
]


func _init() -> void:
	await process_frame
	var total := 0
	var failed := 0
	var only := OS.get_cmdline_user_args()
	for path in SUITES:
		print("\n", path.get_file())
		var suite: TestCase = load(path).new()
		suite.tree = self
		for method in suite.get_method_list():
			var name: String = method["name"]
			if not name.begins_with("test_") or (not only.is_empty() and not only.has(name)):
				continue
			total += 1
			suite.failures.clear()
			await Callable(suite, name).call()
			await suite.cleanup()
			if suite.failures.is_empty():
				print("  PASS  ", name)
			else:
				failed += 1
				print("  FAIL  ", name)
				for f in suite.failures:
					print("        - ", f)
	print("\n%d tests, %d passed, %d failed" % [total, total - failed, failed])
	quit(1 if failed > 0 else 0)
