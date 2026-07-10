class_name CombatProjectile
extends Node2D

var arena: Node
var owner_node: Node
var direction := Vector2.RIGHT
var speed := 360.0
var damage := 10.0
var radius := 14.0
var lifetime := 2.0
var elapsed := 0.0
var pierce := 0
var projectile_kind: StringName = &"sword"
var hostile := false
var homing := false
var returning := false
var returned := false
var knockback := 30.0
var hit_ids: Dictionary = {}
var turn_speed := 5.0
var bounces_remaining := 0
var bounce_count := 0
var homing_lockout := 0.0
var explosion_radius := 0.0
var explosion_damage_multiplier := 0.0
var split_count := 0
var split_damage_multiplier := 0.5
var impact_triggered := false


static func create(options: Dictionary) -> CombatProjectile:
	var projectile := CombatProjectile.new()
	projectile.arena = options.get("arena")
	projectile.owner_node = options.get("owner")
	projectile.global_position = options.get("position", Vector2.ZERO)
	projectile.direction = options.get("direction", Vector2.RIGHT).normalized()
	projectile.speed = options.get("speed", 360.0)
	projectile.damage = options.get("damage", 10.0)
	projectile.radius = options.get("radius", 14.0)
	projectile.lifetime = options.get("lifetime", 2.0)
	projectile.pierce = options.get("pierce", 0)
	projectile.projectile_kind = options.get("kind", &"sword")
	projectile.hostile = options.get("hostile", false)
	projectile.homing = options.get("homing", false)
	projectile.returning = options.get("returning", false)
	projectile.knockback = options.get("knockback", 30.0)
	projectile.bounces_remaining = options.get("bounces", 0)
	projectile.turn_speed = options.get("turn_speed", 5.0)
	projectile.explosion_radius = options.get("explosion_radius", 0.0)
	projectile.explosion_damage_multiplier = options.get("explosion_damage_multiplier", 0.0)
	projectile.split_count = options.get("split_count", 0)
	projectile.split_damage_multiplier = options.get("split_damage_multiplier", 0.5)
	projectile.z_index = 12
	return projectile


func _physics_process(delta: float) -> void:
	if not is_instance_valid(arena) or not arena.run_active:
		return
	elapsed += delta
	homing_lockout = maxf(homing_lockout - delta, 0.0)
	if homing and not hostile and homing_lockout <= 0.0:
		var target: Variant = arena.nearest_enemy(global_position)
		if is_instance_valid(target):
			var desired: Vector2 = global_position.direction_to(target.global_position)
			direction = direction.lerp(desired, clampf(turn_speed * delta, 0.0, 1.0)).normalized()
	if returning and not returned and elapsed > lifetime * 0.48:
		returned = true
		direction *= -1.0
		hit_ids.clear()
	if _move_with_world_collision(direction * speed * delta):
		return
	rotation = direction.angle() + PI * 0.5
	queue_redraw()
	if hostile:
		_check_player_hit()
	else:
		_check_enemy_hits()
	if elapsed >= lifetime or not arena.bounds.grow(180.0).has_point(global_position):
		queue_free()


func _move_with_world_collision(motion: Vector2) -> bool:
	var destination := global_position + motion
	if not is_inside_tree() or get_world_2d() == null:
		global_position = destination
		return false
	var query := PhysicsRayQueryParameters2D.create(global_position, destination, 2)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		global_position = destination
		return false
	var hit_position: Vector2 = hit.get("position", global_position)
	var hit_normal: Vector2 = hit.get("normal", -direction)
	if bounces_remaining > 0 and not hostile:
		bounces_remaining -= 1
		bounce_count += 1
		direction = direction.bounce(hit_normal).normalized()
		global_position = hit_position + hit_normal * maxf(3.0, radius * 0.22)
		homing_lockout = 0.22
		arena.add_effect(EffectNode.create(&"pulse", hit_position, {"radius": 22.0, "duration": 0.18, "color": Color("9eeeff")}))
		return false
	arena.add_effect(EffectNode.create(&"pulse", hit_position, {"radius": 14.0, "duration": 0.13, "color": Color("c6e9ff") if not hostile else Color("ff7777")}))
	queue_free()
	return true


func _check_enemy_hits() -> void:
	for enemy in arena.enemies:
		if not is_instance_valid(enemy) or enemy.dead:
			continue
		var id: int = enemy.get_instance_id()
		if hit_ids.has(id):
			continue
		if global_position.distance_squared_to(enemy.global_position) <= pow(radius + enemy.hit_radius, 2.0):
			hit_ids[id] = true
			var damage_tags: Array[StringName] = [&"projectile"]
			if projectile_kind == &"rasengan":
				damage_tags.append(&"rasengan")
			enemy.take_damage(DamageEvent.create(damage, owner_node, direction, knockback, false, damage_tags))
			if projectile_kind == &"rasengan":
				_trigger_rasengan_impact(enemy)
			pierce -= 1
			if pierce < 0:
				queue_free()
				return


func _trigger_rasengan_impact(primary_enemy: Node) -> void:
	if impact_triggered:
		return
	impact_triggered = true
	var visual_radius: float = maxf(radius * 1.65, explosion_radius)
	arena.add_effect(EffectNode.create(&"pulse", global_position, {"radius": visual_radius, "duration": 0.30, "color": Color("69d8ff")}))
	if explosion_radius > 0.0 and explosion_damage_multiplier > 0.0:
		for other_enemy in arena.enemies.duplicate():
			if not is_instance_valid(other_enemy) or other_enemy == primary_enemy or other_enemy.dead:
				continue
			if global_position.distance_to(other_enemy.global_position) <= explosion_radius + other_enemy.hit_radius:
				var blast_direction: Vector2 = global_position.direction_to(other_enemy.global_position)
				other_enemy.take_damage(DamageEvent.create(
					damage * explosion_damage_multiplier,
					owner_node,
					blast_direction,
					knockback * 0.72,
					false,
					[&"projectile", &"rasengan", &"area"],
				))
	if split_count > 0:
		_spawn_rasengan_fragments()


func _spawn_rasengan_fragments() -> void:
	for i in range(split_count):
		var spread: float = remap(float(i), 0.0, float(maxi(split_count - 1, 1)), -0.82, 0.82)
		arena.add_projectile(CombatProjectile.create({
			"arena": arena,
			"owner": owner_node,
			"position": global_position,
			"direction": direction.rotated(spread),
			"speed": speed * 1.16,
			"damage": damage * split_damage_multiplier,
			"radius": maxf(radius * 0.56, 12.0),
			"pierce": 0,
			"lifetime": 1.45,
			"kind": &"rasengan",
			"homing": true,
			"turn_speed": 5.2,
			"knockback": knockback * 0.55,
			# 分裂弹不再继续分裂，避免指数增长。
			"split_count": 0,
		}))


func _check_player_hit() -> void:
	if not is_instance_valid(arena.player) or arena.player.dead:
		return
	if global_position.distance_squared_to(arena.player.global_position) <= pow(radius + 18.0, 2.0):
		arena.player.take_damage(DamageEvent.create(damage, owner_node, direction, knockback, false, [&"enemy_projectile"]))
		queue_free()


func _draw() -> void:
	var glow := Color("fff4b8") if not hostile else Color("ff6b6b")
	match projectile_kind:
		&"wave":
			draw_colored_polygon(PackedVector2Array([Vector2(-radius, -5), Vector2(0, -radius * 1.4), Vector2(radius, -5), Vector2(0, radius * 0.35)]), Color("d9f5ff"))
			draw_line(Vector2(0, -radius * 1.3), Vector2(0, radius * 0.3), Color("202945"), 3.0)
		&"orb":
			draw_circle(Vector2.ZERO, radius, Color(glow, 0.32))
			draw_circle(Vector2.ZERO, radius * 0.52, glow)
		&"rasengan":
			var spin: float = elapsed * 12.0
			draw_circle(Vector2.ZERO, radius * 1.15, Color(0.24, 0.78, 1.0, 0.18))
			draw_circle(Vector2.ZERO, radius * 0.82, Color("72ddff"))
			draw_circle(Vector2.ZERO, radius * 0.44, Color("d9f8ff"))
			for i in range(3):
				var start_angle: float = spin + TAU * float(i) / 3.0
				draw_arc(Vector2.ZERO, radius * (0.54 + float(i) * 0.12), start_angle, start_angle + PI * 1.25, 18, Color("e5fbff"), 2.4, true)
		&"sword":
			draw_colored_polygon(PackedVector2Array([Vector2(-3, -18), Vector2(3, -18), Vector2(4, 9), Vector2.ZERO, Vector2(-4, 9)]), glow)
			draw_line(Vector2(-8, 8), Vector2(8, 8), glow, 3.0)
		_: draw_circle(Vector2.ZERO, radius, glow)
