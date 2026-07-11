class_name ExperienceOrb
extends Node2D

var arena: Node
var value := 1
var velocity := Vector2.ZERO
var elapsed := 0.0
var force_magnet := false


static func create(new_arena: Node, at_position: Vector2, xp_value: int) -> ExperienceOrb:
	var orb := ExperienceOrb.new()
	orb.arena = new_arena
	orb.global_position = at_position
	orb.value = xp_value
	orb.velocity = Vector2.from_angle(randf() * TAU) * randf_range(25.0, 70.0)
	orb.z_index = 7
	return orb


func _process(delta: float) -> void:
	if not is_instance_valid(arena) or not is_instance_valid(arena.player) or not arena.run_active:
		return
	elapsed += delta
	velocity = velocity.move_toward(Vector2.ZERO, 180.0 * delta)
	global_position += velocity * delta
	var distance := global_position.distance_to(arena.player.global_position)
	var pickup_range: float = arena.player.pickup_range
	if force_magnet or distance < pickup_range:
		pickup_range = maxf(pickup_range, distance + 1.0) if force_magnet else pickup_range
		var magnet_speed := remap(clampf(distance, 0.0, pickup_range), pickup_range, 0.0, 120.0, 540.0)
		if force_magnet:
			magnet_speed = 900.0
		global_position = global_position.move_toward(arena.player.global_position, magnet_speed * delta)
	if distance < 24.0:
		arena.collect_xp(value)
		queue_free()
	queue_redraw()


func pull_to_player() -> void:
	force_magnet = true
	velocity = Vector2.ZERO


func _draw() -> void:
	var bob := sin(elapsed * 7.0) * 2.0
	var size := 5.0 + minf(value, 4) * 0.8
	draw_colored_polygon(PackedVector2Array([Vector2(0, -size + bob), Vector2(size, bob), Vector2(0, size + bob), Vector2(-size, bob)]), Color("79e6ff"))
	draw_polyline(PackedVector2Array([Vector2(0, -size + bob), Vector2(size, bob), Vector2(0, size + bob), Vector2(-size, bob), Vector2(0, -size + bob)]), Color("e8fdff"), 1.5)
