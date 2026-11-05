# Cuts the bull out of its white background and saves a transparent PNG.
# Run: godot --headless --path . --script res://tools/make_sprite.gd
extends SceneTree

const SRC := "res://assets/source/bull_watch.jpg"
const DST := "res://assets/bull.png"
const THRESHOLD := 0.80


func _is_bg(c: Color) -> bool:
	var lo: float = min(c.r, min(c.g, c.b))
	var hi: float = max(c.r, max(c.g, c.b))
	return lo > THRESHOLD and hi - lo < 0.08


func _init() -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(SRC))
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var visited := PackedByteArray()
	visited.resize(w * h)
	var stack: Array[Vector2i] = []
	for x in w:
		stack.append(Vector2i(x, 0))
		stack.append(Vector2i(x, h - 1))
	for y in h:
		stack.append(Vector2i(0, y))
		stack.append(Vector2i(w - 1, y))

	# Flood fill from the borders so light pixels inside the bull (horns) survive.
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h:
			continue
		var i := p.y * w + p.x
		if visited[i]:
			continue
		visited[i] = 1
		if not _is_bg(img.get_pixelv(p)):
			continue
		img.set_pixelv(p, Color(0, 0, 0, 0))
		stack.append(p + Vector2i.RIGHT)
		stack.append(p + Vector2i.LEFT)
		stack.append(p + Vector2i.DOWN)
		stack.append(p + Vector2i.UP)

	# Clear enclosed background pockets (inside the tail loop, under the arm).
	# Small light regions such as horn highlights are kept.
	for sy in h:
		for sx in w:
			var si := sy * w + sx
			if visited[si] or not _is_bg(img.get_pixel(sx, sy)):
				continue
			var region: Array[Vector2i] = []
			var todo: Array[Vector2i] = [Vector2i(sx, sy)]
			while not todo.is_empty():
				var q: Vector2i = todo.pop_back()
				if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h:
					continue
				var qi := q.y * w + q.x
				if visited[qi] or not _is_bg(img.get_pixelv(q)):
					continue
				visited[qi] = 1
				region.append(q)
				todo.append(q + Vector2i.RIGHT)
				todo.append(q + Vector2i.LEFT)
				todo.append(q + Vector2i.DOWN)
				todo.append(q + Vector2i.UP)
			if region.size() > 400:
				for q in region:
					img.set_pixelv(q, Color(0, 0, 0, 0))

	# Soften the halo: fade edge pixels that are still very light.
	var out: Image = img.duplicate()
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			var c := img.get_pixel(x, y)
			if c.a == 0.0:
				continue
			var touches := img.get_pixel(x + 1, y).a == 0.0 or img.get_pixel(x - 1, y).a == 0.0 \
				or img.get_pixel(x, y + 1).a == 0.0 or img.get_pixel(x, y - 1).a == 0.0
			if touches:
				var lum := (c.r + c.g + c.b) / 3.0
				c.a = clampf(1.0 - (lum - 0.5) * 2.0, 0.0, 1.0)
				out.set_pixel(x, y, c)

	var used: Rect2i = out.get_used_rect()
	var cropped: Image = out.get_region(used.grow(4).intersection(Rect2i(0, 0, w, h)))
	cropped.save_png(ProjectSettings.globalize_path(DST))
	print("Saved ", DST, " size ", cropped.get_size())
	quit()
