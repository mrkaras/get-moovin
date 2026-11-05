# Score, lives, charge meter and the poster-style "LIVE WEIGHT / STATUS" sign,
# plus the title, pause and game-over screens.
extends CanvasLayer

const TITLE_ART := preload("res://assets/title_bg.png")
const ZAP := Color(0.45, 0.85, 1.0)
const PANEL := Color(0.06, 0.13, 0.2, 0.82)
const RED := Color("d6262b")
const W := 1280.0

var main: Node  # Set by main.gd; read for stats.
var mode := "title"
var paused := false
var damage_flash := 0.0
var t := 0.0

var font: Font = ThemeDB.fallback_font
var title_art := TextureRect.new()
var canvas := Control.new()
var panel_box := StyleBoxFlat.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	title_art.texture = TITLE_ART
	title_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	title_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title_art)

	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(_draw_hud)
	add_child(canvas)

	panel_box.bg_color = PANEL
	panel_box.border_color = ZAP
	panel_box.set_border_width_all(3)
	panel_box.set_corner_radius_all(8)
	panel_box.shadow_color = Color(ZAP, 0.35)
	panel_box.shadow_size = 8


func set_mode(new_mode: String) -> void:
	mode = new_mode
	t = 0.0


func _process(delta: float) -> void:
	t += delta
	damage_flash = maxf(0.0, damage_flash - delta * 2.5)
	title_art.visible = mode == "title"
	canvas.queue_redraw()


func _text(pos: Vector2, text: String, size: int, color: Color = Color.WHITE, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	canvas.draw_string_outline(font, pos, text, align, width, size, maxi(4, size / 4), Color(0, 0, 0, color.a))
	canvas.draw_string(font, pos, text, align, width, size, color)


func _centered(y: float, text: String, size: int, color: Color = Color.WHITE) -> void:
	_text(Vector2(0.0, y), text, size, color, HORIZONTAL_ALIGNMENT_CENTER, W)


func _draw_hud() -> void:
	match mode:
		"title":
			_draw_title()
		"playing":
			_draw_stats()
		"over":
			_draw_stats()
			_draw_game_over()
	if paused:
		canvas.draw_rect(Rect2(0, 0, W, 720), Color(0, 0, 0, 0.5))
		_centered(340.0, "PAUSED", 72, ZAP)
		_centered(390.0, "Esc / P to keep moovin'", 24)
	if damage_flash > 0.0:
		canvas.draw_rect(Rect2(0, 0, W, 720), Color(RED, damage_flash * 0.35))


func _draw_title() -> void:
	var pulse := 0.6 + 0.4 * sin(t * 4.0)
	var box := Rect2(30.0, 250.0, 330.0, 250.0)
	panel_box.draw(canvas.get_canvas_item(), box)
	_text(box.position + Vector2(20.0, 42.0), "HOW TO MOOV", 26, ZAP)
	var controls := [
		["Arrows / A D", "move"],
		["Space / W", "jump (x2)"],
		["Shift / J", "charge"],
		["S / Down", "slam down"],
		["Esc / P", "pause"],
	]
	for i in controls.size():
		var row := box.position + Vector2(20.0, 82.0 + i * 30.0)
		_text(row, controls[i][0], 20, Color(1.0, 0.85, 0.3))
		_text(row + Vector2(160.0, 0.0), controls[i][1], 20)

	var best_box := Rect2(W - 360.0, 250.0, 330.0, 250.0)
	panel_box.draw(canvas.get_canvas_item(), best_box)
	_text(best_box.position + Vector2(20.0, 42.0), "THE RULES", 26, ZAP)
	var rules := [
		"Jump the steel fences",
		"Charge through gates",
		"Bowl over the chickens",
		"Eat hay to bulk up",
		"Dodge the lightning!",
	]
	for i in rules.size():
		_text(best_box.position + Vector2(20.0, 82.0 + i * 30.0), rules[i], 20)

	canvas.draw_rect(Rect2(0.0, 600.0, W, 70.0), Color(0, 0, 0, 0.55))
	_centered(648.0, "PRESS SPACE TO GET MOOVIN'", 40, Color(1, 1, 1, pulse))
	if main.high_score > 0:
		_text(Vector2(W - 30.0 - 300.0, 40.0), "BEST  %d" % main.high_score, 28, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, 300.0)


func _draw_stats() -> void:
	_text(Vector2(30.0, 56.0), "SCORE  %d" % main.score(), 40)
	_text(Vector2(30.0, 88.0), "BEST  %d" % maxi(main.high_score, main.score()), 22, Color(1, 1, 1, 0.8))

	for i in main.START_LIVES:
		_heart(Vector2(46.0 + i * 46.0, 122.0), i < main.lives)

	# Charge meter.
	var bar := Rect2(30.0, 152.0, 230.0, 20.0)
	var energy: float = main.bull.charge_energy
	var fill := ZAP
	if main.bull.charging:
		fill = ZAP.lerp(Color.WHITE, 0.5 + 0.5 * sin(t * 40.0))
	elif energy < main.bull.CHARGE_MIN_START:
		fill = Color(0.4, 0.5, 0.6)
	canvas.draw_rect(bar.grow(3.0), Color(0, 0, 0, 0.8))
	canvas.draw_rect(Rect2(bar.position, Vector2(bar.size.x * energy, bar.size.y)), fill)
	_text(bar.position + Vector2(8.0, 16.0), "CHARGE", 16)

	# Poster sign: LIVE WEIGHT / STATUS.
	var sign_rect := Rect2(W - 330.0, 20.0, 300.0, 86.0)
	panel_box.draw(canvas.get_canvas_item(), sign_rect)
	_text(sign_rect.position + Vector2(18.0, 36.0), "LIVE WEIGHT: %dkg" % main.weight(), 24, ZAP)
	_text(sign_rect.position + Vector2(18.0, 70.0), "STATUS: %s" % main.status_text(), 24, ZAP)


func _heart(c: Vector2, full: bool) -> void:
	var col := RED if full else Color(0.25, 0.25, 0.3)
	var pts := PackedVector2Array([c + Vector2(-17.0, -3.0), c + Vector2(17.0, -3.0), c + Vector2(0.0, 17.0)])
	for pass_i in 2:
		var grow := 3.0 if pass_i == 0 else 0.0
		var color := Color.BLACK if pass_i == 0 else col
		canvas.draw_circle(c + Vector2(-8.0, -6.0), 10.0 + grow, color)
		canvas.draw_circle(c + Vector2(8.0, -6.0), 10.0 + grow, color)
		var p := pts
		if grow > 0.0:
			p = PackedVector2Array([pts[0] + Vector2(-grow, 0.0), pts[1] + Vector2(grow, 0.0), pts[2] + Vector2(0.0, grow * 1.5)])
		canvas.draw_colored_polygon(p, color)


func _draw_game_over() -> void:
	var a := minf(1.0, t * 2.0)
	canvas.draw_rect(Rect2(0, 0, W, 720), Color(0, 0, 0, 0.6 * a))
	_centered(230.0, "DRAFTED!", 96, Color(RED, a))
	_centered(290.0, "WE AIN'T PICKIN CHICKENS", 36, Color(1, 1, 1, a))
	_centered(370.0, "SCORE  %d" % main.score(), 48, Color(1, 1, 1, a))
	if main.new_best:
		_centered(415.0, "NEW BEST!", 30, Color(1.0, 0.85, 0.3, a * (0.6 + 0.4 * sin(t * 6.0))))
	else:
		_centered(415.0, "BEST  %d" % main.high_score, 26, Color(1, 1, 1, 0.8 * a))
	_centered(470.0, "Hay eaten: %d     Gates smashed: %d     Chickens bowled: %d" % [main.hay_eaten, main.gates_smashed, main.chickens_bowled], 22, Color(ZAP, a))
	if t > 0.8:
		_centered(560.0, "PRESS SPACE TO GO AGAIN", 34, Color(1, 1, 1, 0.6 + 0.4 * sin(t * 4.0)))
