class_name MinibossActor
extends CharacterBody2D

signal health_changed(current: float, maximum: float)
signal defeated(actor: MinibossActor)

@export var boss_id: StringName
@export var display_name := "小 Boss"
@export var max_health := 900.0
@export var move_speed := 72.0
@export var tint := Color("b96a6a")

var arena: Arena
var health := 900.0
var dead := false
var hit_radius := 38.0
var attack_timer := 1.5
var slow_multiplier := 1.0
var slow_timer := 0.0
var knockback_velocity := Vector2.ZERO
var elapsed := 0.0


func setup(new_arena: Arena, health_multiplier: float = 1.0) -> void:
	arena = new_arena
	max_health *= health_multiplier
	health = max_health
	add_to_group("boss")
	add_to_group("miniboss")
	collision_layer = 0
	set_collision_layer_value(3, true)
	collision_mask = 0
	set_collision_mask_value(2, true)
	set_collision_mask_value(4, true)
	health_changed.emit(health, max_health)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if dead or not is_instance_valid(arena) or not arena.run_active:
		velocity = Vector2.ZERO
		return
	elapsed += delta
	attack_timer -= delta
	if slow_timer > 0.0:
		slow_timer -= delta
		if slow_timer <= 0.0:
			slow_multiplier = 1.0
	var direction := global_position.direction_to(arena.player.global_position)
	velocity = direction * move_speed * slow_multiplier + knockback_velocity
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 360.0 * delta)
	move_and_slide()
	if attack_timer <= 0.0:
		_perform_signature_attack(direction)
	queue_redraw()


func _perform_signature_attack(direction: Vector2) -> void:
	match boss_id:
		&"bone_corpse_king":
			attack_timer = 3.2
			arena.telegraph_circle(global_position, 115.0, 0.55, Color("7fa66c"))
			arena.summon_minions_at(global_position, 4)
			_delayed_blast(115.0, 18.0, Color("7fa66c"))
		&"red_lantern_lady":
			attack_timer = 2.8
			for index in range(10):
				arena.spawn_enemy_projectile(global_position, Vector2.from_angle(TAU * float(index) / 10.0), 12.0, self, 245.0)
		&"iron_arm_monk":
			attack_timer = 3.0
			arena.telegraph_line(global_position, direction, 38.0, 360.0, 0.6)
			velocity = direction * 440.0
			_delayed_blast(145.0, 22.0, Color("c89c6a"))


func _delayed_blast(radius: float, damage: float, color: Color) -> void:
	await get_tree().create_timer(0.58).timeout
	if dead or not arena.run_active:
		return
	arena.spawn_effect(&"pulse", global_position, {"radius": radius, "duration": 0.4, "color": color})
	if global_position.distance_to(arena.player.global_position) <= radius + 18.0:
		arena.player.take_damage(DamageEvent.create(damage, self, global_position.direction_to(arena.player.global_position), 190.0, false, [&"miniboss"]))


func take_damage(event: DamageEvent) -> void:
	if dead:
		return
	var received := event.amount
	if event.source is PlayerActor:
		received *= arena.run_config.elite_boss_damage_multiplier * arena.skill_controller.target_category_damage_multiplier()
	health -= received
	knockback_velocity += event.direction.normalized() * event.knockback * 0.12
	arena.show_damage(global_position + Vector2(0, -55), received, Color("ffe5ca"), event.critical)
	health_changed.emit(maxf(health, 0.0), max_health)
	if health <= 0.0:
		dead = true
		collision_layer = 0
		collision_mask = 0
		defeated.emit(self)
		queue_free()


func apply_slow(multiplier: float, duration: float, _freeze: bool = false) -> void:
	slow_multiplier = minf(slow_multiplier, clampf(multiplier, 0.35, 1.0))
	slow_timer = maxf(slow_timer, duration)


func _draw() -> void:
	var pulse := 1.0 + sin(elapsed * 3.0) * 0.05
	draw_circle(Vector2.ZERO, 35.0 * pulse, Color(tint, 0.92))
	draw_circle(Vector2(0, -7), 22.0, Color(tint.lightened(0.18)))
	draw_line(Vector2(-26, 22), Vector2(26, 22), Color("2a1720"), 7.0)
	draw_arc(Vector2.ZERO, 43.0, 0.0, TAU, 32, Color(tint.lightened(0.35)), 3.0)
	draw_string(ThemeDB.fallback_font, Vector2(-70, -52), display_name, HORIZONTAL_ALIGNMENT_CENTER, 140.0, 18, Color("ffe8d2"))
