class_name RunController
extends Node

signal run_finished(result: RunResult)

var arena: Arena
var completed_waves := 0
var miniboss_kills := 0
var final_boss_kill := false


func setup(new_arena: Arena) -> void:
	arena = new_arena


func record_wave_completed(index: int) -> void:
	completed_waves = maxi(completed_waves, index)


func record_miniboss_defeated() -> void:
	miniboss_kills += 1


func record_final_boss_defeated() -> void:
	final_boss_kill = true


func build_result(victory: bool) -> RunResult:
	var result := RunResult.new()
	result.ensure_run_id()
	result.character_id = arena.selected_character_id
	result.victory = victory
	result.elapsed_seconds = arena.elapsed
	result.completed_waves = completed_waves
	result.miniboss_kills = miniboss_kills
	result.final_boss_kill = final_boss_kill
	result.kills = arena.kills
	result.player_level = arena.player_level
	result.evolved_skill_ids.assign(arena.skill_controller.inventory.evolved_ids.values())
	return result
