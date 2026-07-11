class_name WaveDirector
extends Node

signal wave_started(index: int, definition: WaveDefinition)
signal wave_progress_changed(index: int, remaining: float)
signal wave_completed(index: int)
signal rest_started(next_index: int, duration: float)
signal all_waves_completed

enum State { PREPARING, ACTIVE, WAITING_FOR_BOSS_DEATH, RESTING, COMPLETED }

var waves: Array[WaveDefinition] = []
var state := State.PREPARING
var current_index := 0
var current_wave: WaveDefinition
var elapsed_in_state := 0.0
var duration_scale := 1.0
var boss_instance_id := 0


func setup(definitions: Array[WaveDefinition]) -> void:
	waves = definitions.duplicate()
	waves.sort_custom(func(a: WaveDefinition, b: WaveDefinition) -> bool: return a.index < b.index)
	state = State.PREPARING
	current_index = 0
	elapsed_in_state = 0.0


func start() -> void:
	if state == State.PREPARING:
		_start_wave(1)


func process(delta: float) -> void:
	if state == State.PREPARING or state == State.COMPLETED:
		return
	elapsed_in_state += delta
	if state == State.ACTIVE:
		var duration := current_wave.target_duration * duration_scale
		wave_progress_changed.emit(current_wave.index, maxf(duration - elapsed_in_state, 0.0))
		if elapsed_in_state >= duration:
			_complete_current_wave()
	elif state == State.RESTING:
		if elapsed_in_state >= current_wave.rest_duration * duration_scale:
			_start_wave(current_wave.index + 1)


func register_boss(instance_id: int) -> void:
	boss_instance_id = instance_id


func notify_boss_defeated(instance_id: int) -> bool:
	if state != State.WAITING_FOR_BOSS_DEATH or instance_id != boss_instance_id:
		return false
	boss_instance_id = 0
	_complete_current_wave()
	return true


func force_complete_current_wave_for_tests() -> Error:
	if not OS.is_debug_build() or current_wave == null:
		return ERR_UNAUTHORIZED
	_complete_current_wave()
	return OK


func _start_wave(index: int) -> void:
	if index > waves.size():
		state = State.COMPLETED
		all_waves_completed.emit()
		return
	current_index = index
	current_wave = waves[index - 1]
	elapsed_in_state = 0.0
	state = State.WAITING_FOR_BOSS_DEATH if current_wave.kind != WaveDefinition.WaveKind.NORMAL else State.ACTIVE
	wave_started.emit(index, current_wave)


func _complete_current_wave() -> void:
	if current_wave == null or state == State.COMPLETED:
		return
	var completed_index := current_wave.index
	wave_completed.emit(completed_index)
	if current_wave.kind == WaveDefinition.WaveKind.FINAL_BOSS:
		state = State.COMPLETED
		all_waves_completed.emit()
		return
	state = State.RESTING
	elapsed_in_state = 0.0
	rest_started.emit(completed_index + 1, current_wave.rest_duration * duration_scale)
