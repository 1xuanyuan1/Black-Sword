class_name TestContext
extends RefCounted

var total_checks := 0
var passed_checks := 0
var failures: PackedStringArray = []
var current_suite: StringName = &""
var _suite_start_checks := 0
var _suite_start_failures := 0


func begin_suite(suite_name: StringName) -> void:
	current_suite = suite_name
	_suite_start_checks = total_checks
	_suite_start_failures = failures.size()
	print("\n[SUITE] %s" % current_suite)


func end_suite() -> void:
	var checks := total_checks - _suite_start_checks
	var failed := failures.size() - _suite_start_failures
	print("[SUITE DONE] %s: %d checks, %d failed" % [current_suite, checks, failed])
	current_suite = &""


func check(condition: bool, message: String) -> void:
	total_checks += 1
	var prefix := "[%s] " % current_suite if not current_suite.is_empty() else ""
	if condition:
		passed_checks += 1
		print("[PASS] " + prefix + message)
		return
	failures.append(prefix + message)
	printerr("[FAIL] " + prefix + message)


func fail(message: String) -> void:
	check(false, message)


func exit_code() -> int:
	return 0 if failures.is_empty() else 1


func print_summary() -> void:
	if failures.is_empty():
		print("\nALL TESTS PASSED (%d checks)" % total_checks)
		return
	printerr("\n%d TESTS FAILED (%d/%d checks passed)" % [failures.size(), passed_checks, total_checks])
	for failure in failures:
		printerr("  - " + failure)
