class_name RunResult
extends RefCounted

var run_id := ""
var character_id: StringName = &"black_sword"
var victory := false
var elapsed_seconds := 0.0
var completed_waves := 0
var miniboss_kills := 0
var final_boss_kill := false
var kills := 0
var player_level := 1
var evolved_skill_ids: Array[StringName] = []
var story_events: Array[StringName] = []
var earned_night_embers := 0
var submitted := false


func calculate_night_embers() -> int:
	return maxi(completed_waves, 0) * 20 \
		+ maxi(miniboss_kills, 0) * 40 \
		+ (120 if final_boss_kill else 0) \
		+ mini(100, floori(float(maxi(kills, 0)) / 20.0) * 5) \
		+ (100 if victory else 0)


func ensure_run_id() -> String:
	if run_id.is_empty():
		run_id = "%d-%d-%d" % [Time.get_unix_time_from_system(), Time.get_ticks_usec(), randi()]
	return run_id
