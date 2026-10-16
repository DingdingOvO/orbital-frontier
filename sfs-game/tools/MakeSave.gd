extends SceneTree
## MakeSave.gd — 造一个测试存档，用于验证主菜单"继续"按钮的启用态外观
## 运行: godot --headless --path <proj> --script res://tools/MakeSave.gd

func _initialize() -> void:
	var id: String = SaveGame.create_slot("演示任务")
	SaveGame.load_slot(id)
	SaveGame.record_launch()
	SaveGame.record_orbit()
	SaveGame.record_stage()
	SaveGame.add_satellite("SAT-00001", "earth", 354720.0, 132760.0)
	SaveGame.cache_design(Parts.PRESETS["orbiter"])
	SaveGame.save_current()
	print("slot = ", id)
	print("has_save = ", SaveGame.has_save())
	print("slots = ", SaveGame.list_slots().size())
	quit(0)
