extends SceneTree
## UiDrag.gd — 在真实窗口里用合成鼠标事件验证「拖动零件到网格」整条链路
## 运行：DISPLAY=:99 godot --path <proj> --resolution 1280x720 --script res://tools/UiDrag.gd

func _initialize() -> void:
	var page = load("res://src/game/WorkshopPage.gd").new()
	root.add_child(page)
	await _wait(0.4)

	page.load_preset("orbiter")
	await _wait(0.4)

	var b = page._board
	var before: Array = page._inst.duplicate(true)
	var idx := 1
	var r: Rect2 = b._rect_of(page._inst[idx])
	var p: Vector2 = b.global_position + r.get_center()
	print("[DRAG] part=", page._inst[idx]["id"], " cell=", page._inst[idx]["gx"], ",", page._inst[idx]["gy"], " screen=", p)

	_send_button(p, true)
	await _wait(0.08)
	for i in range(1, 9):
		_send_motion(p + Vector2(14.0 * i, 24.0 * i))
		await _wait(0.03)
	await _wait(0.1)
	_shoot("/tmp/drag_mid.png")
	_send_button(p + Vector2(112, 192), false)
	await _wait(0.3)

	var after: Dictionary = page._inst[idx]
	print("[DRAG] result cell=", after["gx"], ",", after["gy"], " moved=", int(after["gx"]) != int(before[idx]["gx"]) or int(after["gy"]) != int(before[idx]["gy"]))
	_shoot("/tmp/drag_after.png")
	quit()
	return

func _wait(s: float) -> void:
	await create_timer(s).timeout

func _send_button(p: Vector2, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = p
	e.global_position = p
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	Input.parse_input_event(e)

func _send_motion(p: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = p
	e.global_position = p
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	e.relative = Vector2(4, 4)
	Input.parse_input_event(e)

func _shoot(path: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(path)
	print("[SHOT] ", path)
