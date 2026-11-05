# The Get Moovin' bull: runs, double-jumps, charges horns-first.
# Position is the point between his hooves on the ground.
extends Node2D

signal jumped(double: bool)
signal landed

const TEXTURE := preload("res://assets/bull.png")
const GRAVITY := 2800.0
const FAST_FALL_GRAVITY := 6000.0
const JUMP_VELOCITY := -1120.0
const DOUBLE_JUMP_VELOCITY := -980.0
const JUMP_CUT_VELOCITY := -450.0
const MOVE_SPEED := 430.0
const MIN_X := 110.0
const MAX_X := 760.0
const CHARGE_DRAIN := 0.55
const CHARGE_REGEN := 0.16
const CHARGE_MIN_START := 0.2
const SPRITE_SCALE := 0.24
const BODY_SIZE := Vector2(88.0, 158.0)

var ground_y := 600.0
var velocity := Vector2.ZERO
var on_ground := true
var jumps_left := 2
var charging := false
var charge_energy := 1.0
var invulnerable := 0.0
var active := false
var run_rate := 1.0
var input_delay := 0.0
var t := 0.0

var sprite := Sprite2D.new()


func _ready() -> void:
	sprite.texture = TEXTURE
	sprite.offset = Vector2(0.0, -TEXTURE.get_height() * 0.5)
	sprite.scale = Vector2.ONE * SPRITE_SCALE
	add_child(sprite)


func reset(start_x: float) -> void:
	position = Vector2(start_x, ground_y)
	velocity = Vector2.ZERO
	on_ground = true
	jumps_left = 2
	charging = false
	charge_energy = 1.0
	invulnerable = 0.0
	input_delay = 0.2


func hitbox() -> Rect2:
	var r := Rect2(position.x - BODY_SIZE.x * 0.5, position.y - BODY_SIZE.y, BODY_SIZE.x, BODY_SIZE.y)
	if charging:
		# Horns-first lean reaches a bit further forward.
		r.size.x += 24.0
	return r


func bounce() -> void:
	velocity.y = -820.0
	on_ground = false
	jumps_left = 1


func _process(delta: float) -> void:
	t += delta
	if invulnerable > 0.0:
		invulnerable -= delta
	if active:
		_handle_input(delta)
	_animate(delta)
	queue_redraw()


func _handle_input(delta: float) -> void:
	input_delay -= delta
	var can_act := input_delay <= 0.0

	var dir := Input.get_axis("move_left", "move_right")
	position.x = clampf(position.x + dir * MOVE_SPEED * delta, MIN_X, MAX_X)

	if can_act and Input.is_action_just_pressed("jump") and jumps_left > 0:
		var double := not on_ground
		velocity.y = DOUBLE_JUMP_VELOCITY if double else JUMP_VELOCITY
		jumps_left -= 1
		on_ground = false
		jumped.emit(double)
	if Input.is_action_just_released("jump") and velocity.y < JUMP_CUT_VELOCITY:
		velocity.y = JUMP_CUT_VELOCITY

	var wants_charge := can_act and Input.is_action_pressed("charge")
	charging = wants_charge and charge_energy > 0.0 and (charging or charge_energy >= CHARGE_MIN_START)
	if charging:
		charge_energy = maxf(0.0, charge_energy - CHARGE_DRAIN * delta)
	else:
		charge_energy = minf(1.0, charge_energy + CHARGE_REGEN * delta)

	if not on_ground:
		var g := FAST_FALL_GRAVITY if Input.is_action_pressed("duck") else GRAVITY
		velocity.y += g * delta
		position.y += velocity.y * delta
		if position.y >= ground_y:
			position.y = ground_y
			velocity.y = 0.0
			on_ground = true
			jumps_left = 2
			landed.emit()


func _animate(delta: float) -> void:
	var target_rot := 0.0
	var sx := SPRITE_SCALE
	var sy := SPRITE_SCALE
	var bob := 0.0

	if not active:
		# Idle: chest out, breathing.
		sy *= 1.0 + sin(t * 2.4) * 0.015
	elif on_ground:
		var phase := t * 11.0 * run_rate
		var stride := absf(sin(phase))
		bob = stride * 9.0
		target_rot = sin(phase) * 0.06
		sy *= 0.97 + stride * 0.06
		sx *= 1.03 - stride * 0.06
	else:
		target_rot = clampf(velocity.y / 4000.0, -0.25, 0.25)
		sy *= 1.0 + clampf(-velocity.y / 12000.0, -0.06, 0.08)

	if charging:
		target_rot = 0.32 + sin(t * 40.0) * 0.03
		sx *= 1.06

	sprite.rotation = lerp_angle(sprite.rotation, target_rot, minf(1.0, delta * 14.0))
	sprite.scale = Vector2(sx, sy)
	sprite.position = Vector2(0.0, -bob)
	var blink := invulnerable > 0.0 and fmod(t, 0.16) < 0.08
	sprite.modulate = Color(1, 1, 1, 0.35) if blink else Color.WHITE


func _draw() -> void:
	# Ground shadow shrinks as he gets airborne.
	var height := ground_y - position.y
	var k := clampf(1.0 - height / 500.0, 0.35, 1.0)
	draw_set_transform(Vector2(0.0, height), 0.0, Vector2(1.0, 0.22))
	draw_circle(Vector2.ZERO, 62.0 * k, Color(0, 0, 0, 0.35 * k))
	draw_set_transform(Vector2.ZERO)

	if not charging:
		return

	# Afterimages trailing behind.
	var tex_size := Vector2(TEXTURE.get_size())
	for i in range(3, 0, -1):
		draw_set_transform(sprite.position + Vector2(-34.0 * i, 0.0), sprite.rotation, sprite.scale)
		draw_texture(TEXTURE, Vector2(-tex_size.x * 0.5, -tex_size.y), Color(0.35, 0.8, 1.0, 0.32 / i))
	draw_set_transform(Vector2.ZERO)

	# Crackling electric arcs around the body.
	for i in 4:
		var a := randf() * TAU
		var center := Vector2(10.0, -90.0)
		var p := center + Vector2(cos(a) * 70.0, sin(a) * 95.0)
		var pts := PackedVector2Array([p])
		for j in 4:
			p += Vector2(randf_range(-18.0, 18.0), randf_range(-18.0, 18.0))
			pts.append(p)
		draw_polyline(pts, Color(0.45, 0.85, 1.0, 0.9), 3.0)
		draw_polyline(pts, Color(1, 1, 1, 0.9), 1.0)
