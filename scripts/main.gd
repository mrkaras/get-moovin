# Game flow for Get Moovin': title -> run -> drafted (game over).
# Spawns obstacles, scrolls the world, resolves collisions and keeps score.
extends Node2D

enum State { TITLE, PLAYING, GAME_OVER }

const BullScript := preload("res://scripts/bull.gd")
const ObstacleScript := preload("res://scripts/obstacle.gd")
const BackgroundScript := preload("res://scripts/background.gd")
const FxScript := preload("res://scripts/fx.gd")
const HudScript := preload("res://scripts/hud.gd")
const SfxScript := preload("res://scripts/sfx.gd")
const Kind := ObstacleScript.Kind

const GROUND_Y := 600.0
const SPAWN_X := 1400.0
const START_SPEED := 460.0
const MAX_SPEED := 1050.0
const ACCEL := 9.0
const START_LIVES := 3
const BASE_WEIGHT := 985
const SAVE_PATH := "user://highscore.cfg"

const STEEL_DEBRIS := Color("8a9bad")
const SPARK := Color(0.45, 0.85, 1.0)
const FEATHER := Color("f4f1e8")
const HAY_BITS := Color("e2b844")
const DUST := Color(0.55, 0.42, 0.3, 0.7)

@onready var background: BackgroundScript = $Background
@onready var world: Node2D = $World
@onready var bull: BullScript = $Bull
@onready var fx: FxScript = $FX
@onready var camera: Camera2D = $Camera2D
@onready var hud: HudScript = $HUD
@onready var sfx: SfxScript = $SFX

var state: State = State.TITLE
var state_time := 0.0
var speed := 0.0
var distance := 0.0
var bonus := 0
var lives := START_LIVES
var hay_eaten := 0
var gates_smashed := 0
var chickens_bowled := 0
var high_score := 0
var new_best := false
var spawn_timer := 0.0
var lightning_timer := 0.0
var dust_timer := 0.0
var shake := 0.0
var was_charging := false
var auto_spawn := true  # The trailer turns this off and places obstacles itself.


func _ready() -> void:
	randomize()
	process_mode = Node.PROCESS_MODE_ALWAYS
	for n: Node in [background, world, bull, fx]:
		n.process_mode = Node.PROCESS_MODE_PAUSABLE
	bull.ground_y = GROUND_Y
	bull.jumped.connect(_on_bull_jumped)
	bull.landed.connect(_on_bull_landed)
	hud.main = self
	_load_high_score()
	_enter_title()


func score() -> int:
	return int(distance / 10.0) + bonus


func weight() -> int:
	return BASE_WEIGHT + hay_eaten * 5


func difficulty() -> float:
	return clampf((speed - START_SPEED) / (MAX_SPEED - START_SPEED), 0.0, 1.0)


func status_text() -> String:
	if state == State.GAME_OVER:
		return "DRAFTED"
	if bull.invulnerable > 0.0:
		return "HURTIN'"
	if bull.charging:
		return "CHARGIN'"
	if not bull.on_ground:
		return "AIRBORNE"
	return "MOOVIN'"


func _enter_title() -> void:
	state = State.TITLE
	state_time = 0.0
	speed = 0.0
	_clear_world()
	bull.active = false
	bull.reset(640.0)
	bull.visible = false
	hud.set_mode("title")


func _start_game() -> void:
	state = State.PLAYING
	state_time = 0.0
	speed = START_SPEED
	distance = 0.0
	bonus = 0
	lives = START_LIVES
	hay_eaten = 0
	gates_smashed = 0
	chickens_bowled = 0
	new_best = false
	spawn_timer = 1.2
	lightning_timer = 5.0
	_clear_world()
	bull.visible = true
	bull.reset(260.0)
	bull.active = true
	hud.set_mode("playing")
	sfx.play("start")


func _game_over() -> void:
	state = State.GAME_OVER
	state_time = 0.0
	bull.active = false
	bull.charging = false
	if score() > high_score:
		high_score = score()
		new_best = true
		_save_high_score()
	hud.set_mode("over")
	sfx.play("gameover", 0.0)


func _clear_world() -> void:
	for child in world.get_children():
		child.queue_free()
	fx.clear()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and state == State.PLAYING:
		get_tree().paused = not get_tree().paused
		hud.paused = get_tree().paused
		return
	if get_tree().paused:
		return
	if event.is_action_pressed("jump") or event.is_action_pressed("ui_accept"):
		if state == State.TITLE:
			_start_game()
		elif state == State.GAME_OVER and state_time > 0.8:
			_start_game()


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	state_time += delta
	match state:
		State.TITLE:
			background.scroll += 60.0 * delta
		State.PLAYING:
			_update_play(delta)
		State.GAME_OVER:
			speed = move_toward(speed, 0.0, 1400.0 * delta)
			# Let him land if he was drafted mid-air.
			if bull.position.y < GROUND_Y:
				bull.velocity.y += bull.GRAVITY * delta
				bull.position.y = minf(GROUND_Y, bull.position.y + bull.velocity.y * delta)
	_scroll_world(delta)

	shake = move_toward(shake, 0.0, 45.0 * delta)
	camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake


func _update_play(delta: float) -> void:
	speed = minf(MAX_SPEED, speed + ACCEL * delta)
	distance += speed * delta
	bull.run_rate = speed / START_SPEED

	spawn_timer -= delta
	if auto_spawn and spawn_timer <= 0.0:
		_spawn_pattern()
		spawn_timer = maxf(0.9, randf_range(1.0, 1.8) * lerpf(1.0, 0.7, difficulty()))

	lightning_timer -= delta
	if auto_spawn and lightning_timer <= 0.0 and distance > 2500.0:
		_spawn_lightning()
		lightning_timer = randf_range(3.5, 7.0) * lerpf(1.0, 0.55, difficulty())

	if bull.charging and not was_charging:
		sfx.play("charge")
	was_charging = bull.charging

	dust_timer -= delta
	if bull.on_ground and dust_timer <= 0.0:
		dust_timer = 0.06 if bull.charging else 0.12
		fx.burst(Vector2(bull.position.x - 30.0, GROUND_Y - 4.0), DUST, 2, 160.0, 12.0, 200.0, 0.5)

	_check_collisions()


func _scroll_world(delta: float) -> void:
	var dx := speed * delta
	background.scroll += dx
	fx.scroll_speed = speed
	for child in world.get_children():
		var o := child as ObstacleScript
		if o == null:
			continue
		if o.scrolls:
			o.position.x -= dx + o.extra_speed * delta
		if o.dead or o.position.x < -200.0:
			o.queue_free()


func _add(kind: Kind, x: float, y: float = GROUND_Y) -> ObstacleScript:
	var o := ObstacleScript.new()
	o.setup(kind)
	o.position = Vector2(x, y)
	world.add_child(o)
	return o


func _hay_arc(center_x: float, count: int, base_height: float, arc: float) -> void:
	for i in count:
		var k := float(i) / maxf(1.0, count - 1.0)
		var h := base_height + sin(k * PI) * arc
		_add(Kind.HAY, center_x + (k - 0.5) * 60.0 * count, GROUND_Y - h)


func _spawn_pattern() -> void:
	var d := difficulty()
	var roll := randf()
	if roll < 0.30:
		_add(Kind.FENCE, SPAWN_X)
		if randf() < 0.5:
			_hay_arc(SPAWN_X, 4, 140.0, 110.0)
	elif roll < 0.48 and distance > 1200.0:
		_add(Kind.GATE, SPAWN_X)
	elif roll < 0.68:
		_add(Kind.CHICKEN, SPAWN_X)
		if d > 0.35 and randf() < 0.5:
			_add(Kind.CHICKEN, SPAWN_X + 90.0)
	elif roll < 0.80 and d > 0.2:
		# Double fence: needs a double jump or a charge.
		_add(Kind.FENCE, SPAWN_X)
		_add(Kind.FENCE, SPAWN_X + speed * 0.5)
	else:
		if randf() < 0.5:
			_hay_arc(SPAWN_X, 5, 10.0, 0.0)
		else:
			_hay_arc(SPAWN_X, 5, 160.0, 140.0)


func _spawn_lightning() -> void:
	var x := clampf(bull.position.x + randf_range(-50.0, 50.0), bull.MIN_X, bull.MAX_X)
	var o := _add(Kind.LIGHTNING, x)
	o.warn_time = lerpf(1.2, 0.8, difficulty())
	o.struck.connect(_on_lightning_struck.bind(o))


func _on_lightning_struck(o: ObstacleScript) -> void:
	sfx.play("thunder", 0.1)
	background.flash = 1.0
	shake = maxf(shake, 10.0)
	fx.burst(o.position, SPARK, 18, 500.0, 7.0, 1200.0, 0.6)


func _check_collisions() -> void:
	var bb := bull.hitbox()
	for child in world.get_children():
		var o := child as ObstacleScript
		if o == null or o.dead or not bb.intersects(o.hitbox()):
			continue
		match o.kind:
			Kind.HAY:
				o.dead = true
				hay_eaten += 1
				bonus += 25
				bull.charge_energy = minf(1.0, bull.charge_energy + 0.2)
				fx.burst(o.position + Vector2(0.0, -18.0), HAY_BITS, 10, 260.0, 7.0)
				fx.popup(o.position + Vector2(0.0, -40.0), "+25", HAY_BITS)
				sfx.play("hay", 0.1)
			Kind.LIGHTNING:
				_hurt(o)
			Kind.CHICKEN:
				var stomp := bull.velocity.y > 0.0 and bb.end.y < o.position.y - o.size.y * 0.4
				if bull.charging or stomp:
					chickens_bowled += 1
					_smash(o, 100, "BAWK! +100")
					if stomp:
						bull.bounce()
				else:
					_hurt(o)
			Kind.FENCE, Kind.GATE:
				if bull.charging:
					var is_gate := o.kind == Kind.GATE
					if is_gate:
						gates_smashed += 1
					_smash(o, 60 if is_gate else 30, "SMASH! +%d" % (60 if is_gate else 30))
				else:
					_hurt(o)


func _smash(o: ObstacleScript, points: int, text: String) -> void:
	o.dead = true
	bonus += points
	shake = maxf(shake, 7.0)
	fx.popup(o.position + Vector2(0.0, -o.size.y - 20.0), text, Color(1.0, 0.85, 0.3))
	_debris(o)
	sfx.play("bawk" if o.kind == Kind.CHICKEN else "smash")


func _debris(o: ObstacleScript) -> void:
	var center := o.position + Vector2(0.0, -o.size.y * 0.5)
	if o.kind == Kind.CHICKEN:
		fx.burst(center, FEATHER, 16, 420.0, 10.0, 500.0, 1.2)
	else:
		fx.burst(center, STEEL_DEBRIS, 14, 650.0, 16.0, 1600.0, 1.0)
		fx.burst(center, SPARK, 8, 500.0, 6.0, 900.0, 0.4)


func _hurt(o: ObstacleScript) -> void:
	if bull.invulnerable > 0.0:
		return
	lives -= 1
	bull.invulnerable = 1.6
	shake = 16.0
	hud.damage_flash = 1.0
	sfx.play("hurt")
	if o.kind != Kind.LIGHTNING:
		o.dead = true
		_debris(o)
	if lives <= 0:
		_game_over()


func _on_bull_jumped(double: bool) -> void:
	sfx.play("double_jump" if double else "jump")
	if double:
		fx.burst(bull.position, SPARK, 8, 300.0, 6.0, 600.0, 0.4)


func _on_bull_landed() -> void:
	sfx.play("land")
	shake = maxf(shake, 3.0)
	fx.burst(Vector2(bull.position.x, GROUND_Y - 4.0), DUST, 8, 260.0, 14.0, 300.0, 0.6)


func _load_high_score() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		high_score = int(cfg.get_value("scores", "high", 0))


func _save_high_score() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("scores", "high", high_score)
	cfg.save(SAVE_PATH)
