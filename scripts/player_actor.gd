class_name PlayerActor
extends CharacterBody2D

signal health_changed(current: float, maximum: float)
signal died
signal revived(rank: int)

const LEGACY_HERO_TEXTURE := preload("res://assets/actors/hero/samurai_blue.png")

@export var character_id: StringName = &"black_sword"
@export var character_display_name := "黑剑客"
@export var initial_skill_id: StringName = &"black_slash"
@export var character_texture: Texture2D
@export var character_visual_kind: StringName = &"hero_actual"
@export var character_visual_scale := 0.72

@onready var visual: ActorVisual = $CharacterVisual
@onready var body_collision: CollisionShape2D = $BodyCollision
@onready var follow_camera: Camera2D = $FollowCamera

var arena: Node
var max_health := 100.0
var health := 100.0
var base_speed := 210.0
var speed_multiplier := 1.0
var pickup_range := 92.0
var invulnerability := 0.0
var dead := false
var last_direction := Vector2.DOWN
var knockback_velocity := Vector2.ZERO
var virtual_move_input := Vector2.ZERO
var revive_rank := 0
var revive_used := false


func setup(new_arena: Node) -> void:
	arena = new_arena
	add_to_group("player")
	collision_layer = 1
	collision_mask = 0
	set_collision_mask_value(2, true)
	visual.setup(character_texture, character_visual_kind, character_visual_scale, Color.WHITE)
	follow_camera.limit_left = int(arena.bounds.position.x)
	follow_camera.limit_top = int(arena.bounds.position.y)
	follow_camera.limit_right = int(arena.bounds.end.x)
	follow_camera.limit_bottom = int(arena.bounds.end.y)
	visual.death_animation_finished.connect(func() -> void: died.emit())
	health_changed.emit(health, max_health)


func apply_run_config(config: RunConfig) -> void:
	if config == null:
		return
	max_health = 100.0 * config.health_multiplier
	health = max_health
	revive_rank = clampi(config.revive_rank, 0, 3)
	revive_used = false
	health_changed.emit(health, max_health)


func _physics_process(delta: float) -> void:
	if invulnerability > 0.0:
		invulnerability -= delta
	if dead or not is_instance_valid(arena) or not arena.run_active:
		velocity = Vector2.ZERO
		return
	var keyboard_input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var input := keyboard_input
	if virtual_move_input.length_squared() > keyboard_input.length_squared():
		input = virtual_move_input.limit_length(1.0)
	if input.length_squared() > 0.01:
		last_direction = input.normalized()
	velocity = input * base_speed * speed_multiplier + knockback_velocity
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 650.0 * delta)
	move_and_slide()
	global_position.x = clampf(global_position.x, arena.bounds.position.x + 28.0, arena.bounds.end.x - 28.0)
	global_position.y = clampf(global_position.y, arena.bounds.position.y + 28.0, arena.bounds.end.y - 28.0)
	visual.set_motion(last_direction, input.length_squared() > 0.01)


func set_virtual_move_input(value: Vector2) -> void:
	virtual_move_input = value.limit_length(1.0)


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
		if _try_revive():
			return
		dead = true
		velocity = Vector2.ZERO
		visual.play_death()


func _try_revive() -> bool:
	if revive_rank <= 0 or revive_used:
		return false
	const HEALTH_RATIOS := [0.0, 0.30, 0.50, 0.70]
	const INVULNERABILITY_SECONDS := [0.0, 1.5, 2.0, 3.0]
	revive_used = true
	health = max_health * HEALTH_RATIOS[revive_rank]
	invulnerability = INVULNERABILITY_SECONDS[revive_rank]
	knockback_velocity = Vector2.ZERO
	if is_instance_valid(arena) and arena.has_method("clear_nearby_for_revive"):
		arena.clear_nearby_for_revive(global_position, 180.0)
	health_changed.emit(health, max_health)
	revived.emit(revive_rank)
	return true


func heal(amount: float) -> void:
	if dead:
		return
	health = minf(max_health, health + amount)
	health_changed.emit(health, max_health)


func play_attack(attack_direction: Vector2 = Vector2.ZERO) -> void:
	if attack_direction.length_squared() > 0.01:
		last_direction = attack_direction.normalized()
		visual.set_motion(last_direction, false)
	visual.play_attack()
