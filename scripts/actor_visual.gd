class_name ActorVisual
extends Node2D

signal death_animation_finished

var sprite := Sprite2D.new()
var visual_kind: StringName = &"character"
var facing := Vector2.DOWN
var state: StringName = &"idle"
var animation_time := 0.0
var state_timer := 0.0
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
	if kind == &"hero_actual":
		sprite.hframes = 6
		sprite.vframes = 9
	elif kind == &"character":
		sprite.hframes = 4
		sprite.vframes = 7
	else:
		sprite.hframes = 4
		sprite.vframes = 4
	sprite.scale = Vector2.ONE * base_scale
	add_child(sprite)
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
	attack_variant = 1 - attack_variant
	state_timer = duration
	var tween := create_tween()
	tween.tween_property(sprite, "scale", Vector2(base_scale * 1.12, base_scale * 0.92), duration * 0.45)
	tween.tween_property(sprite, "scale", Vector2.ONE * base_scale, duration * 0.55)


func play_hurt() -> void:
	if dead:
		return
	state = &"hurt"
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


func _hero_direction_row(direction: Vector2) -> int:
	if absf(direction.x) > absf(direction.y):
		return 4 if direction.x > 0.0 else 3
	return 1 if direction.y > 0.0 else 2


func _direction_frame(direction: Vector2) -> int:
	if absf(direction.x) > absf(direction.y):
		return 3 if direction.x > 0.0 else 2
	return 0 if direction.y > 0.0 else 1
