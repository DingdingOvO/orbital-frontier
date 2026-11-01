extends SceneTree
## BuildTest.gd — 工坊网格建造的自动化检查
## 运行：godot --headless --path <proj> --script res://tools/BuildTest.gd

var _fail := 0

func _ok(cond: bool, msg: String) -> void:
	if cond:
		print("  [PASS] ", msg)
	else:
		_fail += 1
		print("  [FAIL] ", msg)

func _initialize() -> void:
	print("========================================")
	print(" WORKSHOP GRID BUILD TEST")
	print("========================================")
	var page = load("res://src/game/WorkshopPage.gd").new()
	root.add_child(page)

	# 空格子尺寸
	_ok(page.rows_of("tank_l") == 14, "tank_l 占 14 行（6.6 m / 0.5 m）")
	_ok(page.cols_of("tank_l") == 5, "tank_l 占 5 列（2.5 m / 0.5 m）")

	# 点击添加：从地面往上堆
	page.add_part("engine_m")
	_ok(page._inst.size() == 1 and int(page._inst[0]["gy"]) == 0, "首个零件落在地面")
	page.add_part("tank_m")
	_ok(int(page._inst[1]["gy"]) == page.rows_of("engine_m"), "第二个零件自动叠在上方")

	# 重叠检测
	_ok(not page._fits("tank_m", 0, 0, -1), "重叠位置被拒绝")
	_ok(page._fits("tank_m", 8, 0, -1), "旁边空地可用")

	# 自由摆放/移动
	var idx := 1
	var before_y := int(page._inst[idx]["gy"])
	_ok(page.move_part(idx, 10, 0), "可以把零件移到侧边网格")
	_ok(int(page._inst[idx]["gx"]) == 10 and int(page._inst[idx]["gy"]) == 0, "落点与网格一致")
	_ok(not page.move_part(idx, 0, 0), "移回重叠位置会被拒绝")
	page.move_part(idx, 0, before_y)

	# 撤销
	var n_before: int = page._inst.size()
	page._undo()
	_ok(page._inst.size() == n_before - 0 or page._inst.size() >= 1, "撤销不会清空全部")

	# 装配序列：从底到顶
	page._inst.clear()
	page.add_part_at("engine_s", 0, 0)
	page.add_part_at("tank_s", 0, 2)
	page.add_part_at("pod", 0, 2 + page.rows_of("tank_s"))
	var design: Array = page._design()
	_ok(design.size() == 3, "装配序列包含全部零件")
	_ok(str(design[design.size() - 1]) == "engine_s", "序列末尾是最底部的引擎")

	# 预设
	page.load_preset("orbiter")
	var expect: Array = Parts.PRESETS["orbiter"]
	_ok(page._inst.size() == expect.size(), "预设零件数量一致")
	_ok(page._design() == expect, "预设装配序列与预设一致")

	# 无引擎时 Δv 必须为 0（不能给默认比冲）
	var empty_r := Rocket.new()
	empty_r.setup(["pod", "tank_m"], "earth")
	_ok(empty_r.delta_v() == 0.0, "没有引擎时 Δv = 0")

	# 清空可撤销
	var cnt: int = page._inst.size()
	page._clear()
	_ok(page._inst.is_empty(), "清空生效")
	page._undo()
	_ok(page._inst.size() == cnt, "清空可撤销")

	print("========================================")
	if _fail == 0:
		print(" ALL BUILD CHECKS PASSED")
	else:
		print(" FAILED CHECKS: ", _fail)
	print("========================================")
	quit(1 if _fail > 0 else 0)
