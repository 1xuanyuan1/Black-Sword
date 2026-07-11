class_name SpawnDirector
extends Node

var arena: Arena
var current_wave: WaveDefinition
var spawn_timer := 0.0
var reinforcements_enabled := false
var rng := RandomNumberGenerator.new()
var qa_auto_defeat_bosses := false


func setup(new_arena: Arena) -> void:
	arena = new_arena
	rng.randomize()


func begin_wave(definition: WaveDefinition) -> void:
	current_wave = definition
	spawn_timer = 0.05
	reinforcements_enabled = true
	if definition.kind == WaveDefinition.WaveKind.MINIBOSS:
		arena.spawn_miniboss(definition.boss_id)
	elif definition.kind == WaveDefinition.WaveKind.FINAL_BOSS:
		arena._start_boss()


func complete_wave() -> void:
	reinforcements_enabled = false


func process(delta: float) -> void:
	if current_wave == null or not reinforcements_enabled or not arena.run_active:
		return
	if qa_auto_defeat_bosses and current_wave.kind != WaveDefinition.WaveKind.NORMAL and arena.wave_director.elapsed_in_state >= 0.8:
		if is_instance_valid(arena.miniboss):
			arena.miniboss.take_damage(DamageEvent.create(999999.0, arena.player))
		elif is_instance_valid(arena.boss):
			arena.boss.take_damage(DamageEvent.create(999999.0, arena.player))
		return
	if current_wave.kind != WaveDefinition.WaveKind.NORMAL and arena.wave_director.elapsed_in_state >= 90.0 * arena.wave_director.duration_scale:
		reinforcements_enabled = false
		return
	spawn_timer -= delta
	if spawn_timer > 0.0 or arena.active_enemy_count() >= current_wave.enemy_cap:
		return
	spawn_timer = current_wave.spawn_interval * arena.wave_director.duration_scale * rng.randf_range(0.82, 1.16)
	var id := arena.weighted_enemy(current_wave.enemy_weights)
	var elite_affix: StringName = &""
	if rng.randf() < current_wave.elite_chance:
		elite_affix = &"swift" if rng.randf() < 0.45 else &"blood"
	arena.spawn_enemy(id, arena.spawn_position_around_player(), elite_affix)
