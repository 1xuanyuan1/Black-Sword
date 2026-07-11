class_name FrameworkTestSuite
extends RefCounted

const TEST_CONTEXT_SCRIPT := preload("res://tests/framework/test_context.gd")

var suite_name: StringName = &"framework"


func run(tree: SceneTree, context: RefCounted) -> void:
	var suite_files := DirAccess.get_files_at("res://tests/suites")
	context.check("test_baseline.gd" in suite_files, "测试运行器可以发现 baseline 套件")
	context.check("test_framework.gd" in suite_files, "测试运行器可以发现 framework 套件")

	var probe: RefCounted = TEST_CONTEXT_SCRIPT.new()
	context.check(probe.exit_code() == 0, "没有失败时测试进程返回成功退出码")
	probe.failures.append("expected probe failure")
	context.check(probe.exit_code() == 1, "存在失败时测试进程返回非零退出码")

	await tree.create_timer(0.01).timeout
	context.check(true, "测试套件支持异步等待场景计时器")
