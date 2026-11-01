extends SceneTree
## FlowTest.gd — 真实走一遍「主菜单 → 工坊 → 发射 → 飞行」并截图
## 运行：DISPLAY=:99 godot --path <proj> --resolution 1280x720 --script res://tools/FlowTest.gd

func _initialize() -> void:
	var main = load("res://src/ui/Main.gd").new()
	root.add_child(main)
	main.size = Vector2(1280, 720)   # 脚本直启时没有场景根自动铺满，手动给尺寸
	await create_timer(0.6).timeout
	print("[FLOW] page=", main._current)

	main.show_page("workshop")
	await create_timer(0.7).timeout
	var ws = main._pages["workshop"]
	print("[FLOW] page=", main._current, " parts=", ws._inst.size())
	_shoot("/tmp/flow_workshop.png")

	ws.load_preset("orbiter")
	await create_timer(0.4).timeout
	ws.add_part_at("fin", -7, 2)
	ws.add_part_at("fin", 6, 2)
	await create_timer(0.3).timeout
	print("[FLOW] parts=", ws._inst.size(), " design=", ws._design().size())
	print("[SIZE] main=", main.size, " root=", main._page_root.size, " page=", ws.size, " inner=", ws._root.size, " board=", ws._board.size, " scale=", ws.scale, " pos=", ws.position)
	_shoot("/tmp/flow_built.png")

	ws._launch()
	await create_timer(1.2).timeout
	print("[FLOW] page=", main._current, " rocket_parts=", main._pages["flight"].rocket.parts.size())
	_shoot("/tmp/flow_flight.png")
	quit()

func _shoot(path: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(path)
	print("[SHOT] ", path)
