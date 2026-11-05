# Automated smoke test: plays the game with scripted inputs and saves screenshots.
# Run: godot --path . --script res://tools/playtest.gd -- <output_dir>
extends SceneTree

var main: Node
var frame := 0
var out_dir := "user://playtest"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _send(action: String, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("shot ", name, " score=", main.score(), " lives=", main.lives, " speed=", int(main.speed))


func _process(_delta: float) -> bool:
	frame += 1
	match frame:
		40: _shot("01_title")
		45: _send("jump", true)
		47: _send("jump", false)
	if frame > 60 and frame < 1500:
		# Crude autopilot: jump at fences, charge at gates/chickens.
		main.lives = 3
		for child in main.world.get_children():
			var dx: float = child.position.x - main.bull.position.x
			if dx > 60.0 and dx < 190.0:
				if child.kind == 0 and main.bull.on_ground:
					_send("jump", true)
				elif child.kind in [1, 2]:
					_send("charge", true)
		if frame % 4 == 0:
			_send("jump", false)
		if frame % 50 == 0:
			_send("charge", false)
	match frame:
		200: _shot("02_running")
		520: _shot("03_running")
		900: _shot("04_running")
		1300: _shot("05_running")
		1500:
			main.lives = 1
			main._hurt(main.world.get_child(0) if main.world.get_child_count() > 0 else null)
		1600: _shot("06_game_over")
		1610: quit()
	return false
