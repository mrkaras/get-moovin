# Lightweight particles (debris, feathers, dust, sparks) and score popups.
extends Node2D

var scroll_speed := 0.0
var particles: Array[Dictionary] = []
var texts: Array[Dictionary] = []


func burst(pos: Vector2, color: Color, count: int, speed: float = 400.0, size: float = 8.0, gravity: float = 1400.0, life: float = 0.8) -> void:
	for i in count:
		var a := randf_range(-PI, 0.0)
		particles.append({
			"pos": pos,
			"vel": Vector2(cos(a), sin(a)) * randf_range(speed * 0.3, speed),
			"color": color,
			"size": randf_range(size * 0.5, size),
			"gravity": gravity,
			"life": life,
			"max_life": life,
			"rot": randf() * TAU,
			"spin": randf_range(-12.0, 12.0),
		})


func popup(pos: Vector2, text: String, color: Color = Color.WHITE) -> void:
	texts.append({"pos": pos, "text": text, "color": color, "life": 1.0})


func clear() -> void:
	particles.clear()
	texts.clear()


func _process(delta: float) -> void:
	for p in particles:
		var vel: Vector2 = p["vel"]
		vel.y += float(p["gravity"]) * delta
		p["vel"] = vel
		p["pos"] = Vector2(p["pos"]) + vel * delta - Vector2(scroll_speed * delta * 0.7, 0.0)
		p["life"] = float(p["life"]) - delta
		p["rot"] = float(p["rot"]) + float(p["spin"]) * delta
	particles = particles.filter(func(p: Dictionary) -> bool: return float(p["life"]) > 0.0)

	for tx in texts:
		tx["pos"] = Vector2(tx["pos"]) + Vector2(0.0, -70.0 * delta)
		tx["life"] = float(tx["life"]) - delta
	texts = texts.filter(func(tx: Dictionary) -> bool: return float(tx["life"]) > 0.0)
	queue_redraw()


func _draw() -> void:
	for p in particles:
		var c: Color = p["color"]
		c.a *= clampf(float(p["life"]) / float(p["max_life"]) * 2.0, 0.0, 1.0)
		var s: float = p["size"]
		draw_set_transform(Vector2(p["pos"]), float(p["rot"]), Vector2.ONE)
		draw_rect(Rect2(-s * 0.5, -s * 0.3, s, s * 0.6), c)
	draw_set_transform(Vector2.ZERO)

	var font := ThemeDB.fallback_font
	for tx in texts:
		var c: Color = tx["color"]
		c.a = clampf(float(tx["life"]) * 2.0, 0.0, 1.0)
		var pos: Vector2 = tx["pos"] - Vector2(100.0, 0.0)
		draw_string_outline(font, pos, tx["text"], HORIZONTAL_ALIGNMENT_CENTER, 200.0, 28, 8, Color(0, 0, 0, c.a))
		draw_string(font, pos, tx["text"], HORIZONTAL_ALIGNMENT_CENTER, 200.0, 28, c)
