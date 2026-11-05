# Everything that comes down the race: steel fences, drafting gates,
# chickens, hay bales and lightning strikes. Position is bottom-centre.
extends Node2D

signal struck

enum Kind { FENCE, GATE, CHICKEN, HAY, LIGHTNING }

const OUTLINE := Color("141b24")
const STEEL := Color("6f8296")
const STEEL_LIGHT := Color("b4c6d6")
const STEEL_DARK := Color("4a5868")
const ZAP := Color(0.45, 0.85, 1.0)

var kind: Kind = Kind.FENCE
var size := Vector2.ZERO
var scrolls := true
var extra_speed := 0.0
var dead := false
var t := 0.0
var seed_offset := randf() * 10.0

# Lightning timing.
var warn_time := 1.1
var strike_time := 0.3


func setup(k: Kind) -> void:
	kind = k
	match kind:
		Kind.FENCE:
			size = Vector2(76.0, 92.0)
		Kind.GATE:
			size = Vector2(92.0, 250.0)
		Kind.CHICKEN:
			size = Vector2(46.0, 48.0)
			extra_speed = randf_range(60.0, 140.0)
		Kind.HAY:
			size = Vector2(50.0, 36.0)
		Kind.LIGHTNING:
			size = Vector2(80.0, 600.0)
			scrolls = false


func hitbox() -> Rect2:
	if kind == Kind.LIGHTNING and not is_striking():
		return Rect2()
	return Rect2(position.x - size.x * 0.5, position.y - size.y, size.x, size.y)


func is_striking() -> bool:
	return kind == Kind.LIGHTNING and t >= warn_time and t < warn_time + strike_time


func _process(delta: float) -> void:
	var was_striking := is_striking()
	t += delta
	if kind == Kind.LIGHTNING:
		if is_striking() and not was_striking:
			struck.emit()
		if t > warn_time + strike_time + 0.6:
			dead = true
	queue_redraw()


func _draw() -> void:
	match kind:
		Kind.FENCE:
			_draw_fence()
		Kind.GATE:
			_draw_gate()
		Kind.CHICKEN:
			_draw_chicken()
		Kind.HAY:
			_draw_hay()
		Kind.LIGHTNING:
			_draw_lightning()


func _bar(r: Rect2, fill: Color = STEEL) -> void:
	draw_rect(r.grow(3.0), OUTLINE)
	draw_rect(r, fill)
	draw_rect(Rect2(r.position, Vector2(r.size.x, minf(3.0, r.size.y))), STEEL_LIGHT)


func _draw_fence() -> void:
	for y in [-80.0, -52.0, -24.0]:
		_bar(Rect2(-40.0, y, 80.0, 10.0))
	_bar(Rect2(-38.0, -92.0, 11.0, 92.0), STEEL_DARK)
	_bar(Rect2(27.0, -92.0, 11.0, 92.0), STEEL_DARK)


func _draw_gate() -> void:
	# Swinging drafting gate with a chain on top.
	for i in 6:
		_bar(Rect2(-42.0, -228.0 + i * 40.0, 84.0, 10.0))
	draw_line(Vector2(-38.0, -10.0), Vector2(38.0, -220.0), OUTLINE, 11.0)
	draw_line(Vector2(-38.0, -10.0), Vector2(38.0, -220.0), STEEL, 6.0)
	_bar(Rect2(-50.0, -250.0, 14.0, 250.0), STEEL_DARK)
	_bar(Rect2(36.0, -250.0, 14.0, 250.0), STEEL_DARK)
	for i in 4:
		draw_arc(Vector2(43.0, -238.0 + i * 9.0), 6.0, 0.0, TAU, 10, Color("9aa4ad"), 3.0)
	# "DRAFT" sign, styled like the poster's status panel.
	var sign_rect := Rect2(-34.0, -150.0, 68.0, 28.0)
	draw_rect(sign_rect.grow(2.0), OUTLINE)
	draw_rect(sign_rect, Color(0.08, 0.2, 0.3))
	draw_rect(sign_rect, ZAP, false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(-34.0, -130.0), "DRAFT", HORIZONTAL_ALIGNMENT_CENTER, 68.0, 16, ZAP)


func _draw_chicken() -> void:
	var step := sin((t + seed_offset) * 22.0)
	var bob := absf(step) * 3.0
	# Legs
	draw_line(Vector2(-4.0, -14.0), Vector2(-4.0 + step * 6.0, 0.0), Color("e08a1e"), 3.0)
	draw_line(Vector2(6.0, -14.0), Vector2(6.0 - step * 6.0, 0.0), Color("e08a1e"), 3.0)
	# Body
	draw_set_transform(Vector2(2.0, -26.0 - bob), 0.0, Vector2(1.25, 1.0))
	draw_circle(Vector2.ZERO, 17.0, OUTLINE)
	draw_circle(Vector2.ZERO, 15.0, Color("f4f1e8"))
	draw_set_transform(Vector2.ZERO)
	# Tail feathers
	draw_colored_polygon(PackedVector2Array([Vector2(18.0, -30.0 - bob), Vector2(30.0, -46.0 - bob), Vector2(24.0, -24.0 - bob)]), Color("e6e1d3"))
	# Wing
	draw_arc(Vector2(6.0, -26.0 - bob), 9.0, 0.2, 2.6, 8, Color("c9c2b0"), 3.0)
	# Head
	var head := Vector2(-16.0, -42.0 - bob)
	draw_circle(head, 10.0, OUTLINE)
	draw_circle(head, 8.5, Color("f4f1e8"))
	draw_circle(head + Vector2(1.0, -9.0), 4.5, Color("d6262b"))
	draw_circle(head + Vector2(-4.0, -9.0), 4.0, Color("d6262b"))
	draw_colored_polygon(PackedVector2Array([head + Vector2(-7.0, -2.0), head + Vector2(-16.0, 1.0), head + Vector2(-7.0, 4.0)]), Color("f0a21e"))
	draw_circle(head + Vector2(5.0, 6.0), 3.0, Color("d6262b"))
	draw_circle(head + Vector2(-3.0, -2.0), 2.0, OUTLINE)


func _draw_hay() -> void:
	var bob := sin((t + seed_offset) * 4.0) * 4.0
	var r := Rect2(-25.0, -36.0 + bob, 50.0, 36.0)
	draw_rect(r.grow(3.0), Color("5a3d14"))
	draw_rect(r, Color("e2b844"))
	for i in 6:
		var x := r.position.x + 5.0 + i * 8.0
		draw_line(Vector2(x, r.position.y + 3.0), Vector2(x + 3.0, r.end.y - 3.0), Color("c4972c"), 2.0)
	draw_rect(Rect2(-14.0, r.position.y, 4.0, 36.0), Color("7a4f1d"))
	draw_rect(Rect2(10.0, r.position.y, 4.0, 36.0), Color("7a4f1d"))
	draw_rect(Rect2(r.position, Vector2(50.0, 4.0)), Color("f6dc7c"))


func _draw_lightning() -> void:
	if t < warn_time:
		# Pulsing target on the ground.
		var pulse := 0.5 + 0.5 * sin(t * 18.0)
		var grow := t / warn_time
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.25))
		draw_circle(Vector2.ZERO, 45.0 * grow, Color(ZAP, 0.15 + 0.2 * pulse))
		draw_arc(Vector2.ZERO, 45.0, 0.0, TAU, 32, Color(ZAP, 0.5 + 0.5 * pulse), 4.0)
		draw_set_transform(Vector2.ZERO)
		draw_line(Vector2(0.0, -position.y), Vector2.ZERO, Color(ZAP, 0.08 + 0.1 * pulse), 40.0 * grow)
		draw_string(ThemeDB.fallback_font, Vector2(-20.0, -60.0), "!", HORIZONTAL_ALIGNMENT_CENTER, 40.0, 48, Color(1, 1, 0.6, pulse))
	elif is_striking():
		var pts := PackedVector2Array()
		var y := -position.y
		var x := 0.0
		while y < 0.0:
			pts.append(Vector2(x, y))
			y += randf_range(30.0, 60.0)
			x = clampf(x + randf_range(-26.0, 26.0), -30.0, 30.0)
		pts.append(Vector2.ZERO)
		draw_polyline(pts, Color(ZAP, 0.35), 26.0)
		draw_polyline(pts, ZAP, 10.0)
		draw_polyline(pts, Color.WHITE, 4.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.3))
		draw_circle(Vector2.ZERO, 70.0, Color(ZAP, 0.5))
		draw_set_transform(Vector2.ZERO)
	else:
		# Scorch mark fading out.
		var fade := 1.0 - (t - warn_time - strike_time) / 0.6
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.22))
		draw_circle(Vector2.ZERO, 50.0, Color(0.05, 0.05, 0.05, 0.6 * fade))
		draw_set_transform(Vector2.ZERO)
