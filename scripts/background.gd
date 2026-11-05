# Stormy stockyard backdrop: sky, clouds, distant lightning, yard rails and
# cracked dirt, scrolled at different parallax rates.
extends Node2D

const WIDTH := 1280.0
const GROUND_Y := 600.0
const SKY_TOP := Color("0b111b")
const SKY_BOTTOM := Color("2e3d50")
const CLOUD := Color("252f3c")
const CLOUD_LIGHT := Color("3b4859")
const RAIL := Color("3f4d5d")
const RAIL_LIGHT := Color("66788b")
const OUTLINE := Color("10151c")
const DIRT := Color("6b4a2e")
const DIRT_TOP := Color("8b6643")
const ZAP := Color(0.45, 0.85, 1.0)
const AMBER := Color(1.0, 0.6, 0.25)

var scroll := 0.0
var flash := 0.0
var clouds: Array[Dictionary] = []
var bolt := PackedVector2Array()
var bolt_color := ZAP
var bolt_time := 0.0
var next_bolt := 2.0


func _ready() -> void:
	for i in 22:
		var far := i < 12
		clouds.append({
			"x": randf() * 1700.0,
			"y": randf_range(30.0, 260.0) if far else randf_range(380.0, 520.0),
			"r": randf_range(60.0, 120.0) if far else randf_range(50.0, 90.0),
			"rate": 0.06 if far else 0.25,
			"color": CLOUD if far else CLOUD_LIGHT,
		})


func _process(delta: float) -> void:
	flash = maxf(0.0, flash - delta * 2.0)
	bolt_time = maxf(0.0, bolt_time - delta)
	next_bolt -= delta
	if next_bolt <= 0.0:
		_make_bolt()
		next_bolt = randf_range(1.5, 4.5)
	queue_redraw()


func _make_bolt() -> void:
	bolt = PackedVector2Array()
	var p := Vector2(randf_range(80.0, WIDTH - 80.0), 0.0)
	var end_y := randf_range(280.0, 470.0)
	while p.y < end_y:
		bolt.append(p)
		p += Vector2(randf_range(-40.0, 40.0), randf_range(25.0, 55.0))
	bolt.append(p)
	bolt_color = ZAP if randf() < 0.7 else AMBER
	bolt_time = 0.25
	flash = maxf(flash, 0.35)


func _draw() -> void:
	# Sky gradient.
	var bands := 24
	for i in bands:
		var c := SKY_TOP.lerp(SKY_BOTTOM, float(i) / bands)
		draw_rect(Rect2(0.0, i * GROUND_Y / bands, WIDTH, GROUND_Y / bands + 1.0), c)

	if bolt_time > 0.0:
		var a := bolt_time / 0.25
		draw_polyline(bolt, Color(bolt_color, 0.3 * a), 12.0)
		draw_polyline(bolt, Color(bolt_color, a), 4.0)
		draw_polyline(bolt, Color(1, 1, 1, a), 1.5)

	for c in clouds:
		var x := fposmod(float(c["x"]) - scroll * float(c["rate"]), 1700.0) - 200.0
		var y: float = c["y"]
		var r: float = c["r"]
		var col: Color = c["color"]
		draw_circle(Vector2(x, y), r, col)
		draw_circle(Vector2(x + r * 0.9, y + r * 0.2), r * 0.75, col)
		draw_circle(Vector2(x - r * 0.9, y + r * 0.25), r * 0.7, col)

	_draw_yard_rails()
	_draw_ground()

	if flash > 0.0:
		draw_rect(Rect2(0.0, 0.0, WIDTH, 720.0), Color(0.75, 0.9, 1.0, flash * 0.3))


func _draw_yard_rails() -> void:
	var spacing := 190.0
	var off := fposmod(scroll * 0.5, spacing)
	for y in [470.0, 510.0, 550.0]:
		draw_rect(Rect2(0.0, y - 2.0, WIDTH, 13.0), OUTLINE)
		draw_rect(Rect2(0.0, y, WIDTH, 9.0), RAIL)
		draw_rect(Rect2(0.0, y, WIDTH, 2.0), RAIL_LIGHT)
	var x := -off
	while x < WIDTH + spacing:
		draw_rect(Rect2(x - 2.0, 440.0, 18.0, 162.0), OUTLINE)
		draw_rect(Rect2(x, 442.0, 14.0, 160.0), RAIL)
		draw_rect(Rect2(x, 442.0, 3.0, 160.0), RAIL_LIGHT)
		x += spacing


func _draw_ground() -> void:
	draw_rect(Rect2(0.0, GROUND_Y, WIDTH, 120.0), DIRT)
	draw_rect(Rect2(0.0, GROUND_Y, WIDTH, 6.0), DIRT_TOP)
	draw_rect(Rect2(0.0, GROUND_Y + 6.0, WIDTH, 3.0), OUTLINE)

	# Cracks and pebbles, deterministic per tile so they scroll seamlessly.
	var tile := 160.0
	var first := int(floor(scroll / tile))
	for i in range(first, first + 10):
		var x := i * tile - scroll
		var h := absi(hash(i))
		var cx := x + float(h % 100)
		var cy := GROUND_Y + 25.0 + float((h / 100) % 70)
		var pts := PackedVector2Array([Vector2(cx, cy)])
		for j in 4:
			var k := (h >> (j * 3)) % 7
			pts.append(pts[pts.size() - 1] + Vector2(14.0 + k * 3.0, float(k) - 3.0))
		draw_polyline(pts, Color("3e2a19"), 2.0)
		var pebble := Vector2(x + float((h / 7) % 150), GROUND_Y + 18.0 + float((h / 13) % 90))
		draw_circle(pebble, 4.0 + float(h % 4), Color("4f5560"))
		draw_circle(pebble + Vector2(-1.0, -1.0), 2.0, Color("7a808a"))
