extends SceneTree

const SUITE_DIRECTORY := "res://tests/suites"
const TEST_CONTEXT_SCRIPT := preload("res://tests/framework/test_context.gd")

var context: RefCounted = TEST_CONTEXT_SCRIPT.new()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var requested_suite := _requested_suite()
	var suite_paths := _discover_suite_paths()
	if suite_paths.is_empty():
		context.fail("没有在 %s 中发现测试套件" % SUITE_DIRECTORY)

	var executed := 0
	for suite_path in suite_paths:
		var suite_script := load(suite_path) as Script
		if suite_script == null:
			context.fail("无法加载测试套件：%s" % suite_path)
			continue
		var suite: RefCounted = suite_script.new() as RefCounted
		if suite == null or not suite.has_method("run"):
			context.fail("测试套件缺少 run 方法：%s" % suite_path)
			continue
		var suite_name := StringName(suite.get("suite_name"))
		if suite_name.is_empty():
			context.fail("测试套件缺少 suite_name：%s" % suite_path)
			continue
		if not requested_suite.is_empty() and suite_name != requested_suite:
			continue
		executed += 1
		context.begin_suite(suite_name)
		await suite.run(self, context)
		context.end_suite()

	if executed == 0:
		context.fail("没有执行匹配的测试套件：%s" % requested_suite)
	context.print_summary()
	quit(context.exit_code())


func _discover_suite_paths() -> PackedStringArray:
	var result := PackedStringArray()
	for file_name in DirAccess.get_files_at(SUITE_DIRECTORY):
		if file_name.begins_with("test_") and file_name.ends_with(".gd"):
			result.append(SUITE_DIRECTORY.path_join(file_name))
	result.sort()
	return result


func _requested_suite() -> StringName:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--suite="):
			return StringName(argument.trim_prefix("--suite=").strip_edges())
	return &""
