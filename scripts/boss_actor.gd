class_name BossActor
extends CharacterBody2D

signal health_changed(current: float, maximum: float)
signal defeated

const IDLE_TEXTURE := preload("res://assets/actors/boss/Idle.png")
const WALK_TEXTURE := preload("res://assets/actors/boss/Walk.png")
const HIT_TEXTURE := preload("res://assets/actors/boss/Hit.png")
const ATTACK_LEFT_TEXTURE := preload("res://assets/actors/boss/AttackLeft.png")
const ATTACK_RIGHT_TEXTURE := preload("res://assets/actors/boss/AttackRight.png")
const CHARGE_LEFT_TEXTURE := preload("res://assets/actors/boss/ChargeLeft.png")
const CHARGE_RIGHT_TEXTURE := preload("res://assets/actors/boss/ChargeRight.png")

@onready var character_visual: Node2D = $CharacterVisual
@onready var sprite: Sprite2D = $CharacterVisual/CharacterSprite
@onready var body_collision: CollisionShape2D = $BodyCollision

var arena: Node
var max_health := 2800.0
var health := 2800.0
var dead := false
var hit_radius := 48.0
var speed := 72.0
var attack_timer := 1.8
var windup := 0.0
var pending_attack: StringName = &""
var pending_direction := Vector2.DOWN
var attack_index := 0
var phase := 1
var animation_time := 0.0
var animation_name: StringName = &"idle"
var animation_fps := 9.0
var knockback_velocity := Vector2.ZERO
var charge_time := 0.0
var charge_hit := false
var summon_timer := 12.0
var entered_phase_two := false
var entered_phase_three := false


func setup(new_arena: Node) -> void:
	arena = new_arena
	add_to_group("enemies")
	add_to_group("boss")
	collision_layer = 0
	set_collision_layer_value(3, true)
	collision_mask = 0
	set_collision_mask_value(2, true)
	_set_animation(&"idle")
	z_index = 8
	health_changed.emit(health, max_health)


func _physics_process(delta: float) -> void:
	_update_animation(delta)
	if dead or not is_instance_valid(arena) or not arena.run_active or not is_instance_valid(arena.player):
		velocity = Vector2.ZERO
		return
	var ratio := health / max_health
	phase = 3 if ratio <= 0.4 else (2 if ratio <= 0.7 else 1)
	if phase >= 2 and not entered_phase_two:
		entered_phase_two = true
		arena.announce("剑豪震怒·弹幕解禁", Color("ffb06b"))
		_start_nova()
	if phase >= 3 and not entered_phase_three:
		entered_phase_three = true
		arena.announce("鬼门大开·怨军再临", Color("ff6b81"))
		arena.summon_minions(5)
	attack_timer -= delta
	summon_timer -= delta
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 220.0 * delta)
	if charge_time > 0.0:
		charge_time -= delta
		velocity = pending_direction * (480.0 + phase * 35.0) + knockback_velocity
		_set_animation(&"charge")
		if not charge_hit and global_position.distance_to(arena.player.global_position) < 58.0:
			charge_hit = true
			arena.player.take_damage(DamageEvent.create(24.0 + phase * 4.0, self, pending_direction, 260.0, false, [&"boss_charge"]))
		if charge_time <= 0.0:
			attack_timer = 1.4
	elif windup > 0.0:
		windup -= delta
		velocity = knockback_velocity
		if windup <= 0.0:
			_resolve_pending_attack()
	else:
		var direction: Vector2 = global_position.direction_to(arena.player.global_position)
		var distance := global_position.distance_to(arena.player.global_position)
		if distance > 105.0:
			velocity = direction * speed * (1.0 + 0.09 * phase) + knockback_velocity
			pending_direction = direction
			_set_animation(&"walk")
		else:
			velocity = knockback_velocity
			_set_animation(&"idle")
		if attack_timer <= 0.0:
			_choose_attack(distance)
		if phase == 3 and summon_timer <= 0.0:
			summon_timer = 16.0
			arena.summon_minions(4)
	move_and_slide()
	global_position.x = clampf(global_position.x, arena.bounds.position.x + 60.0, arena.bounds.end.x - 60.0)
	global_position.y = clampf(global_position.y, arena.bounds.position.y + 60.0, arena.bounds.end.y - 60.0)


func _choose_attack(distance: float) -> void:
	attack_index += 1
	var choice := attack_index % (4 if phase >= 2 else 2)
	if choice == 0 or (distance < 125.0 and choice == 1):
		_start_slash()
	elif choice == 1:
		_start_charge()
	elif choice == 2:
		_start_volley()
	else:
		_start_nova()


func _start_slash() -> void:
	pending_attack = &"slash"
	pending_direction = global_position.direction_to(arena.player.global_position)
	windup = 0.68
	attack_timer = 3.0
	_set_animation(&"attack")
	arena.telegraph_cone(global_position, pending_direction, 150.0, 1.72, windup)


func _start_charge() -> void:
	pending_attack = &"charge"
	pending_direction = global_position.direction_to(arena.player.global_position)
	windup = 0.72
	attack_timer = 3.4
	_set_animation(&"charge")
	arena.telegraph_line(global_position, pending_direction, 34.0, 520.0, windup)


func _start_volley() -> void:
	pending_attack = &"volley"
	pending_direction = global_position.direction_to(arena.player.global_position)
	windup = 0.7
	attack_timer = 3.2
	_set_animation(&"attack")
	arena.telegraph_cone(global_position, pending_direction, 230.0, 1.55, windup)


func _start_nova() -> void:
	if windup > 0.0 or dead:
		return
	pending_attack = &"nova"
	windup = 0.82
	attack_timer = 4.2
	_set_animation(&"attack")
	arena.telegraph_circle(global_position, 190.0, windup)


func _resolve_pending_attack() -> void:
	match pending_attack:
		&"slash":
			arena.add_effect(EffectNode.create(&"slash", global_position, {"direction": pending_direction, "radius": 155.0, "arc": 1.72, "duration": 0.35, "color": Color("ffdbbe")}))
			var to_player := global_position.direction_to(arena.player.global_position)
			if global_position.distance_to(arena.player.global_position) <= 155.0 and absf(pending_direction.angle_to(to_player)) <= 0.86:
				arena.player.take_damage(DamageEvent.create(21.0 + phase * 4.0, self, pending_direction, 210.0, false, [&"boss_slash"]))
			arena.play_sfx(&"slash")
		&"charge":
			charge_time = 0.82
			charge_hit = false
		&"volley":
			var count := 7 + phase * 2
			for i in range(count):
				var offset := remap(float(i), 0.0, float(count - 1), -0.72, 0.72)
				arena.spawn_enemy_projectile(global_position, pending_direction.rotated(offset), 10.0 + phase * 2.0, self, 290.0)
			arena.play_sfx(&"magic")
		&"nova":
			var count := 12 + phase * 3
			for i in range(count):
				arena.spawn_enemy_projectile(global_position, Vector2.from_angle(TAU * float(i) / float(count)), 9.0 + phase * 2.0, self, 260.0)
			arena.add_effect(EffectNode.create(&"pulse", global_position, {"radius": 190.0, "duration": 0.55, "color": Color("ff5b75")}))
			arena.play_sfx(&"magic")
	pending_attack = &""


func take_damage(event: DamageEvent) -> void:
	if dead:
		return
	health -= event.amount
	knockback_velocity += event.direction.normalized() * event.knockback * 0.16
	_set_animation(&"hit")
	sprite.modulate = Color("fff1f1")
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.16)
	arena.show_damage(global_position + Vector2(0, -70), event.amount, Color("ffe6d0"), event.critical)
	health_changed.emit(maxf(health, 0.0), max_health)
	if health <= 0.0:
		_die()


func apply_slow(_multiplier: float, _duration: float, _freeze: bool = false) -> void:
	pass


func _die() -> void:
	dead = true
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	_set_animation(&"hit")
	var tween := create_tween()
	for i in range(4):
		tween.tween_property(sprite, "modulate", Color("ffffff"), 0.08)
		tween.tween_property(sprite, "modulate", Color("ff5b5b"), 0.08)
	tween.tween_property(sprite, "rotation", -0.42, 0.28).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property(sprite, "scale", Vector2(3.3, 1.6), 0.28)
	tween.tween_interval(0.45)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func() -> void: defeated.emit(); queue_free())


func _set_animation(name: StringName) -> void:
	if animation_name == name and sprite.texture != null:
		return
	animation_name = name
	animation_time = 0.0
	match name:
		&"walk":
			sprite.texture = WALK_TEXTURE
			sprite.hframes = 6
			sprite.vframes = 1
			animation_fps = 10.0
		&"hit":
			sprite.texture = HIT_TEXTURE
			sprite.hframes = 4
			sprite.vframes = 1
			animation_fps = 12.0
		&"attack":
			sprite.texture = ATTACK_RIGHT_TEXTURE if pending_direction.x >= 0.0 else ATTACK_LEFT_TEXTURE
			sprite.hframes = 4
			sprite.vframes = 1
			animation_fps = 11.0
		&"charge":
			sprite.texture = CHARGE_RIGHT_TEXTURE if pending_direction.x >= 0.0 else CHARGE_LEFT_TEXTURE
			sprite.hframes = 3
			sprite.vframes = 1
			animation_fps = 12.0
		_:
			sprite.texture = IDLE_TEXTURE
			sprite.hframes = 6
			sprite.vframes = 1
			animation_fps = 8.0
	sprite.frame = 0


func _update_animation(delta: float) -> void:
	animation_time += delta
	var frames := maxi(sprite.hframes, 1)
	var row := 0
	if sprite.vframes > 1:
		row = 0 if pending_direction.y >= 0.0 else 1
	sprite.frame_coords = Vector2i(int(animation_time * animation_fps) % frames, row)
