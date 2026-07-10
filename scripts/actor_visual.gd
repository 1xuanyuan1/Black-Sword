class_name ActorVisual
extends Node2D

signal death_animation_finished

const OCAD_WALK_DOWN := [
	Rect2(126, 0, 21, 42), Rect2(147, 0, 21, 42), Rect2(168, 0, 21, 42),
	Rect2(189, 0, 21, 42), Rect2(210, 0, 21, 42), Rect2(231, 0, 21, 42),
]
const OCAD_WALK_UP := [
	Rect2(126, 42, 21, 42), Rect2(147, 42, 21, 42), Rect2(168, 42, 21, 42),
	Rect2(189, 42, 21, 42), Rect2(210, 42, 21, 42), Rect2(231, 42, 21, 42),
]
const OCAD_WALK_SIDE := [
	Rect2(0, 84, 21, 42), Rect2(21, 84, 21, 42), Rect2(42, 84, 21, 42),
	Rect2(63, 84, 21, 42), Rect2(84, 84, 21, 42), Rect2(105, 84, 21, 42),
]
const OCAD_ATTACK_SIDE := [
	Rect2(0, 168, 42, 42), Rect2(42, 168, 42, 42), Rect2(84, 168, 42, 42),
	Rect2(126, 168, 42, 42), Rect2(168, 168, 42, 42), Rect2(210, 168, 42, 42),
]
const OCAD_IDLE_DOWN := Rect2(189, 126, 21, 42)
const OCAD_IDLE_SIDE := Rect2(210, 126, 21, 42)
const OCAD_IDLE_UP := Rect2(231, 126, 21, 42)
const OCAD_HURT := Rect2(168, 126, 21, 42)
const OCAD_DEATH := Rect2(189, 210, 63, 42)

@onready var sprite: Sprite2D = $CharacterSprite
var visual_kind: StringName = &"character"
var facing := Vector2.DOWN
var state: StringName = &"idle"
var animation_time := 0.0
var state_timer := 0.0
var attack_animation_duration := 0.22
var dead := false
var base_scale := 3.5
var attack_variant := 0


func setup(texture: Texture2D, kind: StringName, scale_factor: float, tint: Color = Color.WHITE) -> void:
	visual_kind = kind
	base_scale = scale_factor
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = true
	sprite.modulate = tint
	sprite.region_enabled = false
	sprite.flip_h = false
	if kind == &"hero_actual":
		sprite.hframes = 6
		sprite.vframes = 9
	elif kind == &"ocad_character":
		sprite.hframes = 1
		sprite.vframes = 1
		sprite.region_enabled = true
		sprite.region_rect = OCAD_IDLE_DOWN
	elif kind == &"character":
		sprite.hframes = 4
		sprite.vframes = 7
	else:
		sprite.hframes = 4
		sprite.vframes = 4
	sprite.scale = Vector2.ONE * base_scale
	z_index = 5


func _process(delta: float) -> void:
	animation_time += delta
	if state_timer > 0.0:
		state_timer -= delta
		if state_timer <= 0.0 and not dead:
			state = &"idle"
	_update_frame()


func set_motion(direction: Vector2, moving: bool) -> void:
	if dead:
		return
	if direction.length_squared() > 0.01:
		facing = direction.normalized()
	if state not in [&"attack", &"hurt"]:
		state = &"move" if moving else &"idle"


func play_attack(duration: float = 0.22) -> void:
	if dead:
		return
	state = &"attack"
	animation_time = 0.0
	attack_variant = 1 - attack_variant
	attack_animation_duration = maxf(duration, 0.30) if visual_kind == &"ocad_character" else maxf(duration, 0.001)
	state_timer = attack_animation_duration
	if visual_kind == &"ocad_character":
		sprite.scale = Vector2.ONE * base_scale
		return
	var tween := create_tween()
	tween.tween_property(sprite, "scale", Vector2(base_scale * 1.12, base_scale * 0.92), attack_animation_duration * 0.45)
	tween.tween_property(sprite, "scale", Vector2.ONE * base_scale, attack_animation_duration * 0.55)


func play_hurt() -> void:
	if dead:
		return
	state = &"hurt"
	animation_time = 0.0
	state_timer = 0.2
	sprite.modulate = Color("fff1f1")
	var tween := create_tween()
	tween.tween_property(sprite, "position", Vector2(5.0, 0.0), 0.045)
	tween.tween_property(sprite, "position", Vector2(-4.0, 0.0), 0.045)
	tween.tween_property(sprite, "position", Vector2.ZERO, 0.06)
	tween.tween_callback(func() -> void: if is_instance_valid(sprite): sprite.modulate = Color.WHITE)


func play_death() -> void:
	if dead:
		return
	dead = true
	state = &"death"
	animation_time = 0.0
	_update_frame()
	var tween := create_tween()
	tween.tween_property(sprite, "rotation", 0.38, 0.22).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property(sprite, "scale", Vector2(base_scale * 1.08, base_scale * 0.72), 0.22)
	tween.tween_interval(0.32)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.32)
	tween.parallel().tween_property(sprite, "position:y", 8.0, 0.32)
	tween.tween_callback(func() -> void: death_animation_finished.emit())


func _update_frame() -> void:
	if sprite.texture == null:
		return
	if visual_kind == &"ocad_character":
		_update_ocad_frame()
		return
	var direction_frame := _direction_frame(facing)
	if visual_kind == &"hero_actual":
		sprite.frame_coords.x = int(animation_time * (9.0 if state == &"move" else 7.0)) % 6
		match state:
			&"move": sprite.frame_coords.y = _hero_direction_row(facing)
			&"attack": sprite.frame_coords.y = 5 + attack_variant
			&"hurt": sprite.frame_coords.y = 7
			&"death": sprite.frame_coords.y = 8
			_: sprite.frame_coords.y = 0
	elif visual_kind == &"character":
		sprite.frame_coords.x = direction_frame
		match state:
			&"move": sprite.frame_coords.y = int(animation_time * 8.0) % 4
			&"attack": sprite.frame_coords.y = 4
			&"death":
				sprite.frame_coords.x = 0
				sprite.frame_coords.y = 6
			_: sprite.frame_coords.y = 0
	else:
		sprite.frame_coords.x = direction_frame
		sprite.frame_coords.y = int(animation_time * (9.0 if state == &"move" else 5.0)) % 4


func _update_ocad_frame() -> void:
	sprite.flip_h = false
	match state:
		&"move":
			var frames: Array
			if absf(facing.x) > absf(facing.y):
				frames = OCAD_WALK_SIDE
				sprite.flip_h = facing.x > 0.0
			elif facing.y < 0.0:
				frames = OCAD_WALK_UP
			else:
				frames = OCAD_WALK_DOWN
			var frame_index: int = int(animation_time * 10.0) % frames.size()
			var walk_region: Rect2 = frames[frame_index]
			sprite.region_rect = walk_region
		&"attack":
			var attack_index: int = ocad_attack_frame_index()
			sprite.region_rect = OCAD_ATTACK_SIDE[attack_index]
			sprite.flip_h = facing.x > 0.0
		&"hurt":
			sprite.region_rect = OCAD_HURT
		&"death":
			sprite.region_rect = OCAD_DEATH
		_:
			if absf(facing.x) > absf(facing.y):
				sprite.region_rect = OCAD_IDLE_SIDE
				sprite.flip_h = facing.x > 0.0
			elif facing.y < 0.0:
				sprite.region_rect = OCAD_IDLE_UP
			else:
				sprite.region_rect = OCAD_IDLE_DOWN


func ocad_attack_frame_index() -> int:
	var normalized_time: float = animation_time / maxf(attack_animation_duration, 0.001)
	return clampi(int(normalized_time * float(OCAD_ATTACK_SIDE.size())), 0, OCAD_ATTACK_SIDE.size() - 1)


func _hero_direction_row(direction: Vector2) -> int:
	if absf(direction.x) > absf(direction.y):
		return 4 if direction.x > 0.0 else 3
	return 1 if direction.y > 0.0 else 2


func _direction_frame(direction: Vector2) -> int:
	if absf(direction.x) > absf(direction.y):
		return 3 if direction.x > 0.0 else 2
	return 0 if direction.y > 0.0 else 1
