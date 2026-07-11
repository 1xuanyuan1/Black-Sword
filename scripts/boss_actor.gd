class_name BossActor
extends CharacterBody2D

signal health_changed(current: float, maximum: float)
signal defeated

enum BossState { ENTER, CHASE, WINDUP, ATTACK, RECOVER, PHASE_TRANSITION, DEAD }

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
var slow_multiplier := 1.0
var slow_timer := 0.0
var state := BossState.ENTER
var enter_timer := 0.8
var recovery_timer := 0.0
var phase_transition_timer := 0.0
var state_history: Array[BossState] = [BossState.ENTER]


func setup(new_arena: Node) -> void:
	arena = new_arena
	add_to_group("enemies")
	add_to_group("boss")
	collision_layer = 0
	set_collision_layer_value(3, true)
	collision_mask = 0
	set_collision_mask_value(2, true)
	_set_animation(&"idle")
	set_state(BossState.ENTER)
	z_index = 8
	health_changed.emit(health, max_health)


func _physics_process(delta: float) -> void:
	_update_animation(delta)
	if dead or not is_instance_valid(arena) or not arena.run_active or not is_instance_valid(arena.player):
		velocity = Vector2.ZERO
		return
	if state == BossState.ENTER:
		enter_timer -= delta
		velocity = Vector2.ZERO
		if enter_timer <= 0.0:
			set_state(BossState.CHASE)
		return
	if state == BossState.PHASE_TRANSITION:
		phase_transition_timer -= delta
		velocity = Vector2.ZERO
		if phase_transition_timer <= 0.0:
			set_state(BossState.CHASE)
		return
	var ratio := health / max_health
	var target_phase := 3 if ratio <= 0.35 else (2 if ratio <= 0.7 else 1)
	if target_phase >= 2 and not entered_phase_two:
		entered_phase_two = true
		phase = 2
		_begin_phase_transition("顾沉舟：你记得我站在尸首之间。\n可曾记得，是谁从井里爬了出来？", Color("ffb06b"))
		return
	if target_phase >= 3 and not entered_phase_three:
		entered_phase_three = true
		phase = 3
		_begin_phase_transition("顾沉舟：很好。比上一次更快。\n我记得每一次你死在这里。", Color("ff6b81"))
		return
	phase = target_phase
	attack_timer -= delta
	summon_timer -= delta
	if slow_timer > 0.0:
		slow_timer -= delta
		if slow_timer <= 0.0:
			slow_multiplier = 1.0
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 220.0 * delta)
	if charge_time > 0.0:
		set_state(BossState.ATTACK)
		charge_time -= delta
		velocity = pending_direction * (480.0 + phase * 35.0) * slow_multiplier + knockback_velocity
		_set_animation(&"charge")
		if not charge_hit and global_position.distance_to(arena.player.global_position) < 58.0:
			charge_hit = true
			arena.player.take_damage(DamageEvent.create(24.0 + phase * 4.0, self, pending_direction, 260.0, false, [&"boss_charge"]))
		if charge_time <= 0.0:
			attack_timer = 1.4
			recovery_timer = 0.28
			set_state(BossState.RECOVER)
	elif windup > 0.0:
		set_state(BossState.WINDUP)
		windup -= delta
		velocity = knockback_velocity
		if windup <= 0.0:
			_resolve_pending_attack()
	elif recovery_timer > 0.0:
		recovery_timer -= delta
		velocity = knockback_velocity
		set_state(BossState.RECOVER)
		if recovery_timer <= 0.0:
			set_state(BossState.CHASE)
	else:
		set_state(BossState.CHASE)
		var direction: Vector2 = global_position.direction_to(arena.player.global_position)
		var distance := global_position.distance_to(arena.player.global_position)
		if distance > 105.0:
			velocity = direction * speed * (1.0 + 0.09 * phase) * slow_multiplier + knockback_velocity
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
	set_state(BossState.WINDUP)
	arena.telegraph_cone(global_position, pending_direction, 150.0, 1.72, windup)


func _start_charge() -> void:
	pending_attack = &"charge"
	pending_direction = global_position.direction_to(arena.player.global_position)
	windup = 0.72
	attack_timer = 3.4
	_set_animation(&"charge")
	set_state(BossState.WINDUP)
	arena.telegraph_line(global_position, pending_direction, 34.0, 520.0, windup)


func _start_volley() -> void:
	pending_attack = &"volley"
	pending_direction = global_position.direction_to(arena.player.global_position)
	windup = 0.7
	attack_timer = 3.2
	_set_animation(&"attack")
	set_state(BossState.WINDUP)
	arena.telegraph_cone(global_position, pending_direction, 230.0, 1.55, windup)


func _start_nova() -> void:
	if windup > 0.0 or dead:
		return
	pending_attack = &"nova"
	windup = 0.82
	attack_timer = 4.2
	_set_animation(&"attack")
	set_state(BossState.WINDUP)
	arena.telegraph_circle(global_position, 190.0, windup)


func _resolve_pending_attack() -> void:
	set_state(BossState.ATTACK)
	match pending_attack:
		&"slash":
			arena.spawn_effect(&"slash", global_position, {"direction": pending_direction, "radius": 155.0, "arc": 1.72, "duration": 0.35, "color": Color("ffdbbe")})
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
			arena.spawn_effect(&"pulse", global_position, {"radius": 190.0, "duration": 0.55, "color": Color("ff5b75")})
			arena.play_sfx(&"magic")
	pending_attack = &""
	if charge_time <= 0.0:
		recovery_timer = 0.3
		set_state(BossState.RECOVER)


func _begin_phase_transition(text: String, color: Color) -> void:
	charge_time = 0.0
	windup = 0.0
	pending_attack = &""
	phase_transition_timer = 0.78
	set_state(BossState.PHASE_TRANSITION)
	arena.announce(text, color)
	arena.telegraph_circle(global_position, 205.0, 0.62, color)
	_phase_transition_burst()


func _phase_transition_burst() -> void:
	await get_tree().create_timer(0.62).timeout
	if dead or not arena.run_active:
		return
	var count := 14 + phase * 3
	for index in range(count):
		arena.spawn_enemy_projectile(global_position, Vector2.from_angle(TAU * float(index) / float(count)), 8.0 + phase * 2.0, self, 250.0)
	if phase >= 3:
		arena.summon_minions(5)


func take_damage(event: DamageEvent) -> void:
	if dead:
		return
	var received_damage := event.amount
	if event.source is PlayerActor and is_instance_valid(arena) and arena.run_config is RunConfig:
		received_damage *= arena.run_config.elite_boss_damage_multiplier
		if arena.get("skill_controller") is SkillController:
			received_damage *= (arena.get("skill_controller") as SkillController).target_category_damage_multiplier()
	health -= received_damage
	knockback_velocity += event.direction.normalized() * event.knockback * 0.16
	_set_animation(&"hit")
	sprite.modulate = Color("fff1f1")
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.16)
	arena.show_damage(global_position + Vector2(0, -70), received_damage, Color("ffe6d0"), event.critical)
	health_changed.emit(maxf(health, 0.0), max_health)
	if health <= 0.0:
		_die()


func apply_slow(multiplier: float, duration: float, _freeze: bool = false) -> void:
	slow_multiplier = minf(slow_multiplier, clampf(multiplier, 0.35, 1.0))
	slow_timer = maxf(slow_timer, duration)


func _die() -> void:
	dead = true
	set_state(BossState.DEAD)
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


func set_state(new_state: BossState) -> void:
	if state == new_state and not state_history.is_empty():
		return
	state = new_state
	state_history.append(new_state)


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
