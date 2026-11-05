# Scripted promo trailer for Get Moovin'. Runs the real game with an autopilot,
# scripted obstacles, captions, title cards and a synthesised soundtrack.
# Render with Godot's Movie Maker, e.g.:
#   godot --path . --write-movie trailer.avi --fixed-fps 30 res://trailer/trailer.tscn
extends Node

const MusicBuilder := preload("res://trailer/music.gd")
const ObstacleScript := preload("res://scripts/obstacle.gd")
const Kind := ObstacleScript.Kind
const POSTER := preload("res://assets/title_bg.png")
const BULL := preload("res://assets/bull.png")

const W := 1280.0
const H := 720.0
const LENGTH := 32.0
const GAME_START := 9.5
const FAST_FROM := 25.2
const END_CARD := 27.5
const THUNDER := [3.0, 4.2]
const ZAP := Color(0.45, 0.85, 1.0)
const GOLD := Color(1.0, 0.82, 0.25)
const RED := Color("d6262b")

# Captions shown over gameplay: [start, end, text].
const CAPTIONS := [
	[9.8, 12.6, "JUMP THE FENCES"],
	[12.9, 15.9, "SMASH THE GATES"],
	[16.1, 19.0, "BOWL THE CHICKENS"],
	[19.3, 22.0, "BULK UP ON HAY"],
	[22.3, 25.0, "DODGE THE LIGHTNING"],
	[25.3, 27.4, "IT ONLY GETS FASTER"],
]

# Obstacles by the time they should reach the bull: [arrive, kind, variant].
const EVENTS := [
	[10.5, Kind.FENCE, 0], [11.6, Kind.FENCE, 0], [12.5, Kind.FENCE, 0],
	[13.7, Kind.GATE, 0], [15.0, Kind.GATE, 0],
	[16.8, Kind.CHICKEN, 0], [17.15, Kind.CHICKEN, 0], [18.3, Kind.CHICKEN, 0],
	[19.9, Kind.HAY, 1], [21.0, Kind.HAY, 0], [21.8, Kind.HAY, 1],
	[25.6, Kind.FENCE, 0], [26.0, Kind.CHICKEN, 0], [26.5, Kind.GATE, 0],
	[26.9, Kind.HAY, 1], [27.3, Kind.FENCE, 0],
]

# Lightning strikes aimed at the bull: [spawn time, dodge direction].
const STRIKES := [[22.5, 1.0], [23.8, -1.0]]

@onready var main: Node = $Main
var overlay := Control.new()
var layer := CanvasLayer.new()
var music := AudioStreamPlayer.new()
var title_font := SystemFont.new()
var t := 0.0
var next_event := 0
var next_strike := 0
var dodge_until := 0.0
var dodge_dir := 0.0
var flash := 0.0
var slam_shake := 0.0
var started := false
var finished := false


func _ready() -> void:
	title_font.font_names = PackedStringArray(["Impact", "Arial Black", "Sans-Serif"])
	title_font.font_weight = 800

	layer.layer = 50
	add_child(layer)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(_draw_overlay)
	layer.add_child(overlay)

	main.auto_spawn = false
	main.high_score = 0  # Don't show whoever rendered the trailer's personal best.
	main.hud.visible = false

	var builder := MusicBuilder.new()
	music.stream = builder.build(LENGTH, GAME_START, END_CARD, FAST_FROM, THUNDER)
	music.volume_db = -6.0
	add_child(music)
	music.play()


func _process(delta: float) -> void:
	t += delta
	flash = maxf(0.0, flash - delta * 2.5)
	slam_shake = maxf(0.0, slam_shake - delta * 30.0)

	for th in THUNDER:
		if t - delta < th and t >= th:
			flash = 1.0
			main.background.flash = 1.0
			main.background._make_bolt()
			main.shake = 14.0

	if not started and t >= GAME_START:
		started = true
		flash = 1.0
		main._start_game()
		main.hud.visible = true
	if started and not finished:
		_drive_game(delta)
	if not finished and t >= END_CARD:
		finished = true
		flash = 1.0
		main.hud.visible = false
		main.bull.active = false
		main.process_mode = Node.PROCESS_MODE_DISABLED
	if t >= LENGTH:
		get_tree().quit()
	overlay.queue_redraw()


# --- Autopilot ---------------------------------------------------------------

func _drive_game(delta: float) -> void:
	var bull: Node2D = main.bull
	main.lives = main.START_LIVES
	bull.charge_energy = 1.0
	main.speed = 1000.0 if t >= FAST_FROM else 520.0

	var travel: float = (main.SPAWN_X - bull.position.x) / main.speed
	while next_event < EVENTS.size() and t >= float(EVENTS[next_event][0]) - travel:
		_spawn(EVENTS[next_event])
		next_event += 1
	if next_strike < STRIKES.size() and t >= float(STRIKES[next_strike][0]):
		main._spawn_lightning()
		dodge_dir = STRIKES[next_strike][1]
		dodge_until = t + 0.95
		next_strike += 1

	# Step out of the lightning after the warning has had time to read.
	_set_action("move_left", dodge_until - t < 0.5 and dodge_until > t and dodge_dir < 0.0)
	_set_action("move_right", dodge_until - t < 0.5 and dodge_until > t and dodge_dir > 0.0)

	var want_jump := false
	var want_charge := false
	for child in main.world.get_children():
		var o := child as ObstacleScript
		if o == null or o.dead:
			continue
		var dx: float = o.position.x - bull.position.x
		match o.kind:
			Kind.FENCE:
				want_jump = want_jump or (dx > 0.0 and dx < main.speed * 0.3 + 70.0)
			Kind.GATE, Kind.CHICKEN:
				want_charge = want_charge or (dx > -40.0 and dx < main.speed * 0.45)
			Kind.HAY:
				if o.position.y < main.GROUND_Y - 80.0:
					want_jump = want_jump or (dx > 0.0 and dx < main.speed * 0.25)

	if want_jump and bull.on_ground:
		Input.action_press("jump")
	elif not bull.on_ground and bull.velocity.y > -150.0:
		Input.action_release("jump")
	_set_action("charge", want_charge)


func _set_action(action: String, on: bool) -> void:
	if on and not Input.is_action_pressed(action):
		Input.action_press(action)
	elif not on and Input.is_action_pressed(action):
		Input.action_release(action)


func _spawn(ev: Array) -> void:
	var kind: Kind = ev[1]
	if kind == Kind.HAY:
		if int(ev[2]) == 1:
			main._hay_arc(main.SPAWN_X, 4, 140.0, 110.0)
		else:
			main._hay_arc(main.SPAWN_X, 5, 10.0, 0.0)
	else:
		main._add(kind, main.SPAWN_X)


# --- Overlay -----------------------------------------------------------------

func _draw_overlay() -> void:
	if t < GAME_START:
		_draw_intro()
	elif t < END_CARD:
		_draw_captions()
	else:
		_draw_end_card()

	if flash > 0.0:
		overlay.draw_rect(Rect2(0, 0, W, H), Color(0.85, 0.95, 1.0, flash * 0.8))
	# Fade in from and out to black.
	var black := maxf(1.0 - t / 0.6, (t - (LENGTH - 0.8)) / 0.8)
	if black > 0.0:
		overlay.draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, clampf(black, 0.0, 1.0)))


func _ease_out_back(x: float) -> float:
	var c := 1.70158
	x = clampf(x, 0.0, 1.0)
	return 1.0 + (c + 1.0) * pow(x - 1.0, 3.0) + c * pow(x - 1.0, 2.0)


func _title(text: String, center: Vector2, size: int, color: Color, alpha: float = 1.0, angle: float = 0.0, scale: float = 1.0) -> void:
	var width := title_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	overlay.draw_set_transform(center, angle, Vector2.ONE * scale)
	var pos := Vector2(-width * 0.5, size * 0.35)
	overlay.draw_string_outline(title_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, maxi(8, size / 5), Color(0, 0, 0, alpha))
	overlay.draw_string(title_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(color, alpha))
	overlay.draw_set_transform(Vector2.ZERO)


func _window_alpha(start: float, stop: float, fade: float = 0.25) -> float:
	return clampf(minf((t - start) / fade, (stop - t) / fade), 0.0, 1.0)


func _draw_intro() -> void:
	# Vignette over the live stormy backdrop.
	overlay.draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.35))

	if t < 2.9:
		_title("THE STORM IS ROLLING IN", Vector2(W * 0.5, 330.0), 64, Color.WHITE, _window_alpha(0.5, 2.8))
	elif t < 4.1:
		_title("THE GATES ARE LOCKED", Vector2(W * 0.5, 330.0), 64, ZAP, _window_alpha(3.15, 4.05, 0.15))
	elif t < 6.4:
		_draw_bull_slam()
	else:
		_draw_poster(t - 6.4, 1.0)
		var a := _window_alpha(7.0, 9.5, 0.3)
		overlay.draw_rect(Rect2(0, 600, W, 64), Color(0, 0, 0, 0.6 * a))
		_title("AN ENDLESS STOCKYARD RUNNER", Vector2(W * 0.5, 632.0), 40, Color.WHITE, a)


func _draw_bull_slam() -> void:
	var k := clampf((t - 4.2) / 0.25, 0.0, 1.0)
	var y := lerpf(-500.0, 660.0, k * k)
	if k >= 1.0 and slam_shake == 0.0 and t < 4.5:
		slam_shake = 18.0
	var shake := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * slam_shake
	var scale := 0.72
	var size := Vector2(BULL.get_size()) * scale
	overlay.draw_texture_rect(BULL, Rect2(Vector2(W * 0.5 - size.x * 0.5, y - size.y) + shake, size), false)
	if k >= 1.0:
		var a := _window_alpha(4.5, 6.4, 0.2)
		var pop := 1.0 + 0.25 * (1.0 - _ease_out_back((t - 4.5) / 0.3))
		_title("ONE BULL", Vector2(250.0, 300.0) + shake, 80, GOLD, a, -0.06, pop)
		_title("AIN'T WAITIN'", Vector2(1030.0, 420.0) + shake, 72, Color.WHITE, a, 0.05, pop)


func _draw_poster(local_t: float, alpha: float) -> void:
	# Fit to height so the title and tagline stay in frame, then push in slowly.
	var zoom := 1.0 + minf(local_t, 4.5) * 0.012
	var tex_size := Vector2(POSTER.get_size())
	var size := tex_size * (H / tex_size.y) * zoom
	overlay.draw_rect(Rect2(0, 0, W, H), Color("0b111b"))
	overlay.draw_texture_rect(POSTER, Rect2(Vector2(W, H) * 0.5 - size * 0.5, size), false, Color(1, 1, 1, alpha))


func _draw_captions() -> void:
	for c in CAPTIONS:
		var start: float = c[0]
		var stop: float = c[1]
		if t < start or t > stop:
			continue
		var into := _ease_out_back((t - start) / 0.35)
		var out := clampf((t - (stop - 0.25)) / 0.25, 0.0, 1.0)
		var x := lerpf(W + 400.0, W * 0.5, into) - out * out * (W * 0.5 + 500.0)
		var y := 225.0
		overlay.draw_set_transform(Vector2(x, y), -0.04, Vector2.ONE)
		overlay.draw_rect(Rect2(-380.0, 34.0, 760.0, 10.0), ZAP)
		overlay.draw_set_transform(Vector2.ZERO)
		_title(c[2], Vector2(x, y), 78, GOLD if c[2] != "IT ONLY GETS FASTER" else RED, 1.0, -0.04)


func _draw_end_card() -> void:
	var local_t := t - END_CARD
	_draw_poster(local_t, 1.0)
	var a := clampf((local_t - 0.6) / 0.4, 0.0, 1.0)
	overlay.draw_rect(Rect2(0, 250, 360, 230), Color(0, 0, 0, 0.55 * a))
	overlay.draw_rect(Rect2(W - 360, 250, 360, 230), Color(0, 0, 0, 0.55 * a))
	var pop := 1.0 + 0.3 * (1.0 - _ease_out_back((local_t - 0.6) / 0.35))
	_title("PLAY", Vector2(180.0, 330.0), 96, GOLD, a, -0.05, pop)
	_title("NOW", Vector2(180.0, 420.0), 96, GOLD, a, -0.05, pop)
	var b := clampf((local_t - 1.1) / 0.4, 0.0, 1.0)
	_title("JUMP", Vector2(W - 180.0, 300.0), 48, Color.WHITE, b, 0.04)
	_title("SMASH", Vector2(W - 180.0, 365.0), 48, ZAP, b, 0.04)
	_title("CHARGE", Vector2(W - 180.0, 430.0), 48, RED, b, 0.04)
