class_name PlayerActor
extends CharacterBody2D

signal health_changed(current: float, maximum: float)
signal died

const HERO_TEXTURE := preload("res://assets/actors/hero/hero_actual.png")
const LEGACY_HERO_TEXTURE := preload("res://assets/actors/hero/samurai_blue.png")

var arena: Node
var visual := ActorVisual.new()
var max_health := 100.0
var health := 100.0
var base_speed := 210.0
var speed_multiplier := 1.0
var pickup_range := 92.0
var invulnerability := 0.0
var dead := false
var last_direction := Vector2.DOWN
var knockback_velocity := Vector2.ZERO


func setup(new_arena: Node) -> void:
	arena = new_arena
	add_to_group("player")
	collision_layer = 1
	collision_mask = 1
	set_collision_mask_value(2, true)
	visual.setup(HERO_TEXTURE, &"hero_actual", 0.72, Color.WHITE)
	add_child(visual)
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 14.0
	collision.shape = shape
	collision.position.y = 8.0
	add_child(collision)
	visual.death_animation_finished.connect(func() -> void: died.emit())
	health_changed.emit(health, max_health)


func _physics_process(delta: float) -> void:
	if invulnerability > 0.0:
		invulnerability -= delta
	if dead or not is_instance_valid(arena) or not arena.run_active:
		velocity = Vector2.ZERO
		return
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input.length_squared() > 0.01:
		last_direction = input.normalized()
	velocity = input * base_speed * speed_multiplier + knockback_velocity
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 650.0 * delta)
	move_and_slide()
	global_position.x = clampf(global_position.x, arena.bounds.position.x + 28.0, arena.bounds.end.x - 28.0)
	global_position.y = clampf(global_position.y, arena.bounds.position.y + 28.0, arena.bounds.end.y - 28.0)
	visual.set_motion(last_direction, input.length_squared() > 0.01)


func take_damage(event: DamageEvent) -> void:
	if dead or invulnerability > 0.0:
		return
	health = maxf(health - event.amount, 0.0)
	invulnerability = 0.6
	knockback_velocity += event.direction.normalized() * event.knockback
	visual.play_hurt()
	arena.play_sfx(&"hit")
	arena.show_damage(global_position + Vector2(0, -36), event.amount, Color("ff8888"))
	health_changed.emit(health, max_health)
	if health <= 0.0:
		dead = true
		velocity = Vector2.ZERO
		visual.play_death()


func heal(amount: float) -> void:
	if dead:
		return
	health = minf(max_health, health + amount)
	health_changed.emit(health, max_health)


func play_attack() -> void:
	visual.play_attack()
