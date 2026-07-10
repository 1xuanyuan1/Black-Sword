class_name EnemyActor
extends CharacterBody2D

signal defeated(enemy: EnemyActor, xp_value: int, death_position: Vector2)

var arena: Node
var definition: EnemyDefinition
var visual := ActorVisual.new()
var health := 20.0
var max_health := 20.0
var dead := false
var elite := false
var hit_radius := 18.0
var attack_timer := 0.5
var attack_windup := 0.0
var attack_pending := false
var knockback_velocity := Vector2.ZERO
var slow_multiplier := 1.0
var slow_timer := 0.0
var charge_timer := 2.8
var charge_velocity := Vector2.ZERO
var charge_time := 0.0


func setup(new_arena: Node, new_definition: EnemyDefinition, is_elite: bool = false, health_multiplier: float = 1.0) -> void:
	arena = new_arena
	definition = new_definition
	elite = is_elite
	max_health = definition.max_health * health_multiplier * (2.15 if elite else 1.0)
	health = max_health
	hit_radius = 24.0 if definition.id == &"revenant" else 17.0
	visual.setup(definition.texture, definition.visual_kind, definition.scale_factor * (1.18 if elite else 1.0), definition.tint)
	if elite:
		visual.sprite.modulate = Color("ffd877")
	add_child(visual)
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = hit_radius * 0.72
	collision.shape = shape
	collision.position.y = 5.0
	add_child(collision)
	add_to_group("enemies")
	visual.death_animation_finished.connect(_finish_death)


func _physics_process(delta: float) -> void:
	if dead or not is_instance_valid(arena) or not arena.run_active or not is_instance_valid(arena.player):
		velocity = Vector2.ZERO
		return
	attack_timer -= delta
	charge_timer -= delta
	if slow_timer > 0.0:
		slow_timer -= delta
		if slow_timer <= 0.0:
			slow_multiplier = 1.0
	if attack_pending:
		attack_windup -= delta
		velocity = knockback_velocity
		if attack_windup <= 0.0:
			_resolve_attack()
	else:
		_update_behavior(delta)
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 520.0 * delta)
	move_and_slide()
	global_position.x = clampf(global_position.x, arena.bounds.position.x + 20.0, arena.bounds.end.x - 20.0)
	global_position.y = clampf(global_position.y, arena.bounds.position.y + 20.0, arena.bounds.end.y - 20.0)
	visual.set_motion(global_position.direction_to(arena.player.global_position), velocity.length_squared() > 4.0)


func _update_behavior(delta: float) -> void:
	var to_player := global_position.direction_to(arena.player.global_position)
	var distance := global_position.distance_to(arena.player.global_position)
	match definition.behavior:
		&"ranged":
			if distance > 205.0:
				velocity = to_player * definition.speed * slow_multiplier + knockback_velocity
			elif distance < 145.0:
				velocity = -to_player * definition.speed * 0.7 * slow_multiplier + knockback_velocity
			else:
				velocity = to_player.rotated(PI * 0.5) * definition.speed * 0.35 + knockback_velocity
			if attack_timer <= 0.0 and distance < definition.attack_range:
				_begin_attack(0.35)
		&"charger":
			if charge_time > 0.0:
				charge_time -= delta
				velocity = charge_velocity + knockback_velocity
				if distance < 36.0:
					arena.player.take_damage(DamageEvent.create(definition.damage * 1.3, self, charge_velocity.normalized(), 190.0, false, [&"charge"]))
					charge_time = 0.0
			elif charge_timer <= 0.0 and distance < 390.0:
				charge_timer = 3.4
				charge_velocity = to_player * 310.0
				arena.telegraph_line(global_position, to_player, 20.0, 330.0, 0.62)
				_begin_attack(0.62, true)
			else:
				velocity = to_player * definition.speed * slow_multiplier + knockback_velocity
				if attack_timer <= 0.0 and distance < definition.attack_range:
					_begin_attack(0.3)
		_:
			velocity = to_player * definition.speed * slow_multiplier + knockback_velocity
			if attack_timer <= 0.0 and distance < definition.attack_range:
				_begin_attack(0.24)


func _begin_attack(windup: float, is_charge: bool = false) -> void:
	attack_pending = true
	attack_windup = windup
	set_meta("pending_charge", is_charge)
	visual.play_attack(windup)


func _resolve_attack() -> void:
	attack_pending = false
	attack_timer = definition.attack_cooldown
	if get_meta("pending_charge", false):
		charge_time = 0.55
		set_meta("pending_charge", false)
		return
	var to_player := global_position.direction_to(arena.player.global_position)
	if definition.behavior == &"ranged":
		arena.spawn_enemy_projectile(global_position, to_player, definition.damage, self)
	elif global_position.distance_to(arena.player.global_position) < definition.attack_range + 18.0:
		arena.player.take_damage(DamageEvent.create(definition.damage, self, to_player, 120.0, false, [&"melee"]))


func take_damage(event: DamageEvent) -> void:
	if dead:
		return
	health -= event.amount
	knockback_velocity += event.direction.normalized() * event.knockback
	visual.play_hurt()
	arena.show_damage(global_position + Vector2(0, -28), event.amount, Color("f4f1db"), event.critical)
	if health <= 0.0:
		dead = true
		velocity = Vector2.ZERO
		set_collision_layer_value(1, false)
		set_collision_mask_value(1, false)
		visual.play_death()


func apply_slow(multiplier: float, duration: float, freeze: bool = false) -> void:
	if dead:
		return
	slow_multiplier = 0.0 if freeze else minf(slow_multiplier, multiplier)
	slow_timer = maxf(slow_timer, 0.55 if freeze else duration)


func _finish_death() -> void:
	defeated.emit(self, definition.xp_value * (4 if elite else 1), global_position)
	queue_free()
