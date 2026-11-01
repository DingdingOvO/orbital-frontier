extends Control
## WorkshopPage — 火箭工坊
## 版式：蓝图几乎铺满整屏，零件在左侧窄栏，参数是一条贴在蓝图底部的横条（不是面板卡片）。
## 建造：0.5 m 网格，零件可拖到任意网格位置自由摆放，松手吸附；选中后可删除。

const CELL := 0.5              # 网格边长（米）
const PALETTE_W := 152.0       # 左侧零件栏宽度
const BAR_H := 46.0            # 底部参数条高度
const DRAG_THRESHOLD := 8.0    # 超过这个像素才算拖动
const GX_MIN := -40
const GX_MAX := 40
const GY_MAX := 90

var nav: Control
var _inst: Array = []          # [{id, gx, gy}]，gx/gy 为网格坐标（gy=0 贴地）
var _history: Array = []
var _cleared: Array = []
var _texts: Array = []
var _root: Control
var _board: Board
var _palette: Control
var _stat_vals: Dictionary = {}
var _hint_lbl: Label
var _part_btns: Array = []
var _preset_opt: OptionButton
var _preset_keys: Array = []
var _msg := ""
var _msg_t := 0.0

func set_nav(n: Control) -> void:
	nav = n

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build()
	Loc.locale_changed.connect(func(_c: String): _refresh_texts())
	_refresh_texts()
	for a in OS.get_cmdline_user_args():
		if a == "--preload-preset":
			load_preset("orbiter")
			break
	_update_stats()

func on_enter(_p: Dictionary) -> void:
	_apply_safe()
	_refresh_texts()
	_update_stats()
	if _board:
		_board.queue_redraw()

func on_safe_area() -> void:
	_apply_safe()

func _apply_safe() -> void:
	if _root == null:
		return
	var sf := UiKit.safe
	_root.offset_left = sf.x
	_root.offset_top = sf.y
	_root.offset_right = -sf.z
	_root.offset_bottom = -sf.w

# ══ 构建 ══════════════════════════════════════════════════
func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_root)
	_apply_safe()

	_build_topbar()

	_board = Board.new()
	_board.host = self
	_board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_board.offset_top = 58
	_board.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_board)

	_palette = _build_palette()
	_board.add_child(_palette)

	_board.add_child(_build_stat_strip())

func _build_topbar() -> void:
	var head := HBoxContainer.new()
	head.set_anchors_preset(Control.PRESET_TOP_WIDE)
	head.offset_left = 12
	head.offset_right = -16
	head.offset_top = 6
	head.offset_bottom = 56
	head.add_theme_constant_override("separation", 10)
	_root.add_child(head)

	var back := UiKit.ghost_button("", 15)
	back.icon_kind = "back"
	back.custom_minimum_size = Vector2(48, 46)
	back.pressed.connect(func():
		if nav:
			nav.go_back())
	head.add_child(back)

	var t := UiKit.label("", 20, UiKit.TEXT)
	t.add_theme_font_override("font", UiKit.font_ui_bold)
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_texts.append({"node": t, "key": "build.title"})
	head.add_child(t)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)

	_preset_keys = Parts.PRESETS.keys()
	_preset_opt = UiKit.option([], -1)
	_preset_opt.custom_minimum_size = Vector2(212, 44)
	_preset_opt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_preset_opt.item_selected.connect(_on_preset)
	head.add_child(_preset_opt)

	var undo := UiKit.ghost_button("", 15)
	undo.icon_kind = "undo"
	undo.custom_minimum_size = Vector2(44, 44)
	undo.tooltip_text = "Undo"
	undo.pressed.connect(_undo)
	head.add_child(undo)

	var clr := UiKit.ghost_button("", 15)
	clr.icon_kind = "trash"
	clr.custom_minimum_size = Vector2(44, 44)
	clr.pressed.connect(_clear)
	head.add_child(clr)

	var launch := UiKit.button("", true, 17)
	launch.custom_minimum_size = Vector2(136, 44)
	_texts.append({"node": launch, "key": "build.launch"})
	launch.pressed.connect(_launch)
	head.add_child(launch)

func _build_palette() -> Control:
	var p := UiKit.panel(Color(0.055, 0.085, 0.150, 0.94), 14, true, 8)
	p.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	p.offset_left = 10
	p.offset_right = 10 + PALETTE_W
	p.offset_top = 4
	p.offset_bottom = -BAR_H - 8
	p.mouse_filter = Control.MOUSE_FILTER_STOP

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)

	var hdr := UiKit.label("", 12, UiKit.CYAN)
	hdr.add_theme_font_override("font", UiKit.spaced_font(2))
	_texts.append({"node": hdr, "key": "build.parts"})
	v.add_child(hdr)

	var scroll := UiKit.themed_scroll(ScrollContainer.new())
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)

	# 两列图标网格：13 个零件在 720p 上一屏见底
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)

	for id in Parts.PALETTE:
		var b := PartTile.new()
		b.part_id = id
		b.host = self
		b.custom_minimum_size = Vector2(0, 70)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(b)
		_part_btns.append({"node": b, "id": id})
	return p

## 底部「一条」参数栏：细横条 + 竖线分隔，不是面板卡片
func _build_stat_strip() -> Control:
	var bar := PanelContainer.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_left = 0
	bar.offset_right = 0
	bar.offset_top = -BAR_H
	bar.offset_bottom = 0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.027, 0.043, 0.078, 0.96)
	sb.border_color = Color(UiKit.STROKE.r, UiKit.STROKE.g, UiKit.STROKE.b, 0.7)
	sb.border_width_top = 1
	sb.content_margin_left = 16.0
	sb.content_margin_right = 16.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	bar.add_theme_stylebox_override("panel", sb)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	h.alignment = BoxContainer.ALIGNMENT_BEGIN
	bar.add_child(h)

	for e in [["mass", "build.mass", "t"], ["dv", "build.dv", "m/s"],
			["twr", "build.twr", ""], ["stages", "build.stages", ""]]:
		if h.get_child_count() > 0:
			var sep := UiKit.label("·", 13, UiKit.TEXT_MUTE)
			sep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(sep)
		var k := UiKit.label("", 11, UiKit.TEXT_MUTE)
		k.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_texts.append({"node": k, "key": str(e[1])})
		h.add_child(k)
		var val := UiKit.label("—", 16, UiKit.TEXT)
		val.add_theme_font_override("font", UiKit.number_font(0))
		val.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(val)
		_stat_vals[str(e[0])] = val
		var unit: String = str(e[2])
		if unit != "":
			var u := UiKit.label(unit, 11, UiKit.TEXT_MUTE)
			u.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(u)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)

	_hint_lbl = UiKit.label("", 11, UiKit.TEXT_MUTE)
	_hint_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hint_lbl.clip_text = true
	_texts.append({"node": _hint_lbl, "key": "build.free"})
	h.add_child(_hint_lbl)
	return bar

# ══ 建造逻辑 ══════════════════════════════════════════════
static func cols_of(id: String) -> int:
	return maxi(1, int(ceil(Parts.width(id) / CELL - 0.001)))

static func rows_of(id: String) -> int:
	return maxi(1, int(ceil(Parts.height(id) / CELL - 0.001)))

func _push_history() -> void:
	_history.append(_inst.duplicate(true))
	if _history.size() > 60:
		_history.pop_front()

func _undo() -> void:
	if not _history.is_empty():
		_inst = _history.pop_back()
	elif not _cleared.is_empty():
		_inst = _cleared.duplicate(true)
		_cleared.clear()
	else:
		return
	_after_change()

func _clear() -> void:
	if _inst.is_empty():
		return
	_push_history()
	_cleared = _inst.duplicate(true)
	_inst.clear()
	_after_change()
	_toast("build.cleared")

## 默认落点：贴着中心列从地面往上找第一个空位（点按零件的"堆叠"行为）
func _default_cell(id: String) -> Vector2i:
	var cols := cols_of(id)
	var rows := rows_of(id)
	var gx := -int(floor(float(cols) * 0.5))
	for gy in GY_MAX:
		if _fits(id, gx, gy, -1):
			return Vector2i(gx, gy)
	return Vector2i(gx, 0)

func add_part(id: String) -> void:
	var c := _default_cell(id)
	add_part_at(id, c.x, c.y)

func add_part_at(id: String, gx: int, gy: int) -> bool:
	if not _fits(id, gx, gy, -1):
		# 落点被占：就近找一格，尽量不让用户白拖一次
		var found := false
		for d in range(1, 6):
			for off in [Vector2i(0, d), Vector2i(0, -d), Vector2i(d, 0), Vector2i(-d, 0)]:
				if _fits(id, gx + off.x, gy + off.y, -1):
					gx += off.x
					gy += off.y
					found = true
					break
			if found:
				break
		if not found:
			_toast("build.collide")
			return false
	_push_history()
	_inst.append({"id": id, "gx": gx, "gy": gy})
	_after_change()
	if _board:
		_board.pulse(gx, gy, cols_of(id), rows_of(id))
	UiKit.haptic(5, 0.4)
	return true

func move_part(idx: int, gx: int, gy: int) -> bool:
	if idx < 0 or idx >= _inst.size():
		return false
	var id := str(_inst[idx]["id"])
	if not _fits(id, gx, gy, idx):
		return false
	_push_history()
	_inst[idx]["gx"] = gx
	_inst[idx]["gy"] = gy
	_after_change()
	if _board:
		_board.pulse(gx, gy, cols_of(id), rows_of(id))
	UiKit.haptic(5, 0.45)
	return true

func _remove_part(idx: int) -> void:
	if idx < 0 or idx >= _inst.size():
		return
	_push_history()
	_inst.remove_at(idx)
	_after_change()
	UiKit.haptic(9, 0.6)

## 网格占用检测：矩形不重叠、在边界内
func _fits(id: String, gx: int, gy: int, ignore: int) -> bool:
	var cols := cols_of(id)
	var rows := rows_of(id)
	if gx < GX_MIN or gx + cols > GX_MAX or gy < 0 or gy + rows > GY_MAX:
		return false
	for i in _inst.size():
		if i == ignore:
			continue
		var it: Dictionary = _inst[i]
		var oid := str(it["id"])
		var ox := int(it["gx"])
		var oy := int(it["gy"])
		if gx < ox + cols_of(oid) and ox < gx + cols and gy < oy + rows_of(oid) and oy < gy + rows:
			return false
	return true

## 物理用的装配序列：按高度从底到顶排列，再转成「从顶到底」
func _design() -> Array:
	var arr := _inst.duplicate()
	arr.sort_custom(func(a, b):
		var ay := float(a["gy"]) + float(rows_of(str(a["id"]))) * 0.5
		var by := float(b["gy"]) + float(rows_of(str(b["id"]))) * 0.5
		if absf(ay - by) > 0.001:
			return ay < by
		return int(a["gx"]) < int(b["gx"]))
	var ids: Array = []
	for it in arr:
		ids.append(str(it["id"]))
	ids.reverse()
	return ids

func _bounds() -> Rect2i:
	if _inst.is_empty():
		return Rect2i()
	var x0 := 999999
	var y0 := 999999
	var x1 := -999999
	var y1 := -999999
	for it in _inst:
		var id := str(it["id"])
		var gx := int(it["gx"])
		var gy := int(it["gy"])
		x0 = mini(x0, gx)
		y0 = mini(y0, gy)
		x1 = maxi(x1, gx + cols_of(id))
		y1 = maxi(y1, gy + rows_of(id))
	return Rect2i(x0, y0, x1 - x0, y1 - y0)

func load_preset(key: String) -> void:
	if not Parts.PRESETS.has(key):
		return
	_push_history()
	_inst.clear()
	var ids: Array = Parts.PRESETS[key]
	var gy := 0
	for i in range(ids.size() - 1, -1, -1):
		var id := str(ids[i])
		var cols := cols_of(id)
		_inst.append({"id": id, "gx": -int(floor(float(cols) * 0.5)), "gy": gy})
		gy += rows_of(id)
	_after_change()

func _on_preset(i: int) -> void:
	if i <= 0 or (i - 1) >= _preset_keys.size():
		return
	load_preset(str(_preset_keys[i - 1]))

func _after_change() -> void:
	_update_stats()
	if _board:
		_board.selected = -1
		_board.queue_redraw()

func _update_stats() -> void:
	if _stat_vals.is_empty():
		return
	var ids := _design()
	if ids.is_empty():
		for k in _stat_vals:
			(_stat_vals[k] as Label).text = "—"
		(_stat_vals["stages"] as Label).text = "0"
		return
	var r := Rocket.new()
	r.setup(ids)
	(_stat_vals["mass"] as Label).text = "%.1f" % (r.total_mass() / 1000.0)
	(_stat_vals["dv"] as Label).text = "%.0f" % r.delta_v()
	(_stat_vals["twr"] as Label).text = "%.2f" % r.thrust_to_weight()
	(_stat_vals["stages"] as Label).text = str(r.stages.size())

func _launch() -> void:
	var ids := _design()
	if ids.is_empty():
		_toast("build.need_part")
		return
	var r := Rocket.new()
	r.setup(ids)
	if r.max_thrust() <= 0.0:
		_toast("build.need_engine")
		return
	if bool(Cfg.get_value("auto_save", true)):
		SaveGame.cache_design(ids)
	nav.show_page("flight", {"design": ids.duplicate()})

func _toast(key: String) -> void:
	if _hint_lbl == null:
		return
	_hint_lbl.text = Loc.t(key)
	_hint_lbl.add_theme_color_override("font_color", UiKit.WARN)
	_msg = key
	_msg_t = 2.4

func _process(dt: float) -> void:
	if _msg_t > 0.0:
		_msg_t -= dt
		if _msg_t <= 0.0 and _hint_lbl:
			_hint_lbl.text = Loc.t("build.free")
			_hint_lbl.add_theme_color_override("font_color", UiKit.TEXT_MUTE)

func _refresh_texts() -> void:
	for e in _texts:
		if is_instance_valid(e.node):
			e.node.text = Loc.t(e.key)
	if _msg_t > 0.0 and _msg != "":
		_hint_lbl.text = Loc.t(_msg)
	else:
		_hint_lbl.add_theme_color_override("font_color", UiKit.TEXT_MUTE)
	for e in _part_btns:
		if is_instance_valid(e.node):
			e.node.queue_redraw()
	var keep := _preset_opt.selected
	_preset_opt.clear()
	_preset_opt.add_item(Loc.t("build.preset.none"))
	for k in _preset_keys:
		_preset_opt.add_item(Loc.t("preset." + str(k)))
	_preset_opt.selected = keep if keep >= 0 else 0

# ══ 零件栏图标块 ══════════════════════════════════════════
class PartTile extends Button:
	var part_id := ""
	var host = null
	var _icon: Control

	func _ready() -> void:
		focus_mode = Control.FOCUS_NONE
		text = ""
		clip_text = true
		_style(false)
		_icon = PartIcon.new()
		_icon.part_id = part_id
		_icon.position = Vector2(0, 9)
		add_child(_icon)
		resized.connect(_place)
		_place()
		pressed.connect(func():
			host.add_part(part_id))
		mouse_entered.connect(func(): _style(true))
		mouse_exited.connect(func(): _style(false))
		UiKit.press_fx(self, 0.96)
		var sk := "part.short." + part_id
		var nm := Loc.t(sk)
		if nm == sk:
			nm = Loc.t(str(Parts.def(part_id).get("name_key", part_id)))
		tooltip_text = nm

	func _place() -> void:
		if _icon:
			_icon.size = Vector2(26, 26)
			_icon.position = Vector2((size.x - 26.0) * 0.5, 10.0)
		queue_redraw()

	func _style(hover: bool) -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = UiKit.PANEL_HI.lightened(0.08) if hover else UiKit.PANEL_HI
		sb.border_color = UiKit.STROKE_HI if hover else Color(UiKit.STROKE.r, UiKit.STROKE.g, UiKit.STROKE.b, 0.75)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(10)
		sb.content_margin_left = 2
		sb.content_margin_right = 2
		for st in ["normal", "hover", "pressed", "focus"]:
			add_theme_stylebox_override(st, sb)
		modulate = Color(1.12, 1.12, 1.12, 1.0) if hover else Color.WHITE

	func _draw() -> void:
		var f: Font = UiKit.font_ui if UiKit.font_ui else ThemeDB.fallback_font
		var d: Dictionary = Parts.def(part_id)
		var sk := "part.short." + part_id
		var nm := Loc.t(sk)
		if nm == sk:
			nm = Loc.t(str(d.get("name_key", part_id)))
		# 窄格子：名字过长时缩到 9px 并居中，绝不截断成半个单词
		var fs := 10
		if f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > size.x - 4.0:
			fs = 9
		draw_string(f, Vector2(0, size.y - 8), nm, HORIZONTAL_ALIGNMENT_CENTER,
			size.x, fs, UiKit.TEXT_DIM)

	func _get_drag_data(_pos: Vector2) -> Variant:
		var chip := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = UiKit.ACCENT
		sb.set_corner_radius_all(10)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 7
		sb.content_margin_bottom = 7
		chip.add_theme_stylebox_override("panel", sb)
		var l := Label.new()
		var f: Font = UiKit.font_ui if UiKit.font_ui else ThemeDB.fallback_font
		l.text = Loc.t(str(Parts.def(part_id).get("name_key", part_id)))
		l.add_theme_font_override("font", f)
		l.add_theme_font_size_override("font_size", 14)
		l.add_theme_color_override("font_color", Color.WHITE)
		chip.add_child(l)
		set_drag_preview(chip)
		return {"part": part_id}

# ══ 蓝图（网格 + 自由摆放） ════════════════════════════════
class Board extends Control:
	var host = null
	var hit: Array = []
	var selected := -1

	# 视图变换：world(m) → screen(px)
	var s := 30.0
	var ox := 0.0
	var oy := 0.0
	var _left := 0.0
	var _right := 0.0
	var _top := 0.0
	var _bottom := 0.0

	# 拖动状态
	var _press_idx := -1
	var _press_pos := Vector2.ZERO
	var _dragging := false
	var _drag_cell := Vector2i.ZERO
	var _drag_ok := false
	var _drag_off := Vector2i.ZERO
	var _hover_drop := false
	var _pulse := Rect2()
	var _pulse_t := 0.0

	## 放置/移动成功后的落点脉冲（网格对齐的即时反馈）
	func pulse(gx: int, gy: int, cols: int, rows: int) -> void:
		_view()
		var step := CELL * s
		_pulse = Rect2(ox + float(gx) * step, oy - float(gy + rows) * step,
			float(cols) * step, float(rows) * step)
		_pulse_t = 1.0
		set_process(true)

	func _process(dt: float) -> void:
		if _pulse_t > 0.0:
			_pulse_t = maxf(0.0, _pulse_t - dt * 2.4)
			queue_redraw()

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _view() -> void:
		# 拖动中锁定视图：否则落点会改变包围盒，整支火箭跟着缩放/平移，手感很差
		if _dragging:
			return
		_left = PALETTE_W + 26.0
		_right = size.x - 24.0
		_top = 16.0
		_bottom = size.y - BAR_H - 20.0
		var b: Rect2i = host._bounds()
		if b.size == Vector2i.ZERO:
			s = 30.0
			ox = (_left + _right) * 0.5
			oy = _bottom - 30.0
			return
		var wm := float(b.size.x) * CELL
		var hm := float(b.size.y) * CELL
		s = minf((_right - _left) / (wm + 2.0), (_bottom - _top) / (hm + 2.0))
		s = clampf(s, 5.0, 120.0)
		ox = (_left + _right) * 0.5 - (float(b.position.x) + float(b.size.x) * 0.5) * CELL * s
		oy = (_top + _bottom) * 0.5 + (float(b.position.y) + float(b.size.y) * 0.5) * CELL * s

	func _rect_of(it: Dictionary) -> Rect2:
		var id := str(it["id"])
		var gx := int(it["gx"])
		var gy := int(it["gy"])
		var cols: int = host.cols_of(id)
		var rows: int = host.rows_of(id)
		var w := float(cols) * CELL * s
		var h := float(rows) * CELL * s
		var cx := ox + (float(gx) + float(cols) * 0.5) * CELL * s
		var bottom := oy - float(gy) * CELL * s
		return Rect2(cx - w * 0.5, bottom - h, w, h)

	func _cell_at(p: Vector2) -> Vector2i:
		return Vector2i(int(floor((p.x - ox) / (CELL * s))), int(floor((oy - p.y) / (CELL * s))))

	func _draw() -> void:
		_view()
		hit.clear()

		# 蓝图底：压暗星空，让网格成为主角（不遮住全屏背景的层次）
		draw_rect(Rect2(0, 0, size.x, size.y), Color(0.020, 0.033, 0.064, 0.58), true)

		# 网格
		var step := CELL * s
		var major := step * 4.0
		var gx0 := int(ceil((_left - ox) / step))
		var gx1 := int(floor((_right - ox) / step))
		var gy0 := int(ceil((oy - _bottom) / step))
		var gy1 := int(floor((oy - _top) / step))
		for gx in range(gx0, gx1 + 1):
			var x := ox + float(gx) * step
			var c := Color(1, 1, 1, 0.085)
			if gx % 4 == 0:
				c = Color(0.45, 0.66, 1.0, 0.20)
			draw_line(Vector2(x, _top), Vector2(x, _bottom), c, 1.0)
		for gy in range(gy0, gy1 + 1):
			var y := oy - float(gy) * step
			var c := Color(1, 1, 1, 0.085)
			if gy % 4 == 0:
				c = Color(0.45, 0.66, 1.0, 0.20)
			draw_line(Vector2(_left, y), Vector2(_right, y), c, 1.0)

		# 落点脉冲
		if _pulse_t > 0.0 and _pulse.has_area():
			var g := _pulse.grow(10.0 * (1.0 - _pulse_t))
			draw_rect(g, Color(0.42, 0.85, 1.0, 0.55 * _pulse_t), false, 2.0)

		# 地面
		if oy > _top and oy < _bottom:
			draw_line(Vector2(_left, oy), Vector2(_right, oy), Color(0.35, 0.62, 1.0, 0.55), 2.0)

		# 拖拽落点高亮
		if _dragging and _press_idx >= 0:
			var id := str(host._inst[_press_idx]["id"])
			var cols: int = host.cols_of(id)
			var rows: int = host.rows_of(id)
			var r := Rect2(ox + float(_drag_cell.x) * step, oy - float(_drag_cell.y + rows) * step,
				float(cols) * step, float(rows) * step)
			draw_rect(r, Color(0.30, 0.85, 0.55, 0.18) if _drag_ok else Color(1.0, 0.35, 0.4, 0.18), true)
			draw_rect(r, Color(0.35, 0.95, 0.65, 0.85) if _drag_ok else Color(1.0, 0.4, 0.45, 0.85), false, 1.5)

		var inst: Array = host._inst
		if inst.is_empty():
			var f: Font = UiKit.font_ui if UiKit.font_ui else ThemeDB.fallback_font
			var msg := Loc.t("build.empty")
			var fs := 16
			var w := f.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(f, Vector2((_left + _right) * 0.5 - w * 0.5, (_top + _bottom) * 0.5),
				msg, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.72, 0.81, 0.95, 0.85))
			return

		for i in inst.size():
			if _dragging and i == _press_idx:
				continue
			var it: Dictionary = inst[i]
			var id := str(it["id"])
			var r := _rect_of(it)
			var d: Dictionary = Parts.def(id)
			Draw.part(self, str(d.get("kind", "tank")), r, d)
			hit.append({"idx": i, "rect": r})
			if i == selected:
				Draw.rounded_rect(self, r.grow(3.0), 6, Color(0, 0, 0, 0),
					Color(0.36, 0.66, 1.0, 0.95), 2)
				var bp := Vector2(r.end.x - 1.0, r.position.y + 1.0)
				draw_circle(bp, 12.0, Color(1.0, 0.46, 0.51, 0.98))
				draw_line(bp + Vector2(-4, -4), bp + Vector2(4, 4), Color.WHITE, 2.2)
				draw_line(bp + Vector2(4, -4), bp + Vector2(-4, 4), Color.WHITE, 2.2)

		# 拖动中的幽灵件
		if _dragging and _press_idx >= 0:
			var it: Dictionary = inst[_press_idx]
			var id := str(it["id"])
			var cols: int = host.cols_of(id)
			var rows: int = host.rows_of(id)
			var w := float(cols) * CELL * s
			var h := float(rows) * CELL * s
			var cx := ox + (float(_drag_cell.x) + float(cols) * 0.5) * step
			var bottom := oy - float(_drag_cell.y) * step
			var r := Rect2(cx - w * 0.5, bottom - h, w, h)
			Draw.part(self, str(Parts.def(id).get("kind", "tank")), r, Parts.def(id), 0.72)
			var cr := Rect2(ox + float(_drag_cell.x) * step, oy - float(_drag_cell.y + rows) * step,
				float(cols) * step, float(rows) * step)
			draw_rect(cr, Color(0.35, 0.98, 0.62, 0.95) if _drag_ok else Color(1.0, 0.38, 0.44, 0.95), false, 2.0)

	# ── 输入：鼠标 + 触摸统一处理 ──────────────────────────
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventScreenTouch:
			if e.pressed:
				_press(e.position)
			else:
				_release(e.position)
		elif e is InputEventScreenDrag:
			_motion(e.position)
		elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				_press(e.position)
			else:
				_release(e.position)
		elif e is InputEventMouseMotion and (e.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_motion(e.position)

	func _press(p: Vector2) -> void:
		_press_pos = p
		_dragging = false
		# 删除徽标优先
		if selected >= 0:
			for h in hit:
				if int(h.idx) == selected:
					var r: Rect2 = h.rect
					if Vector2(r.end.x - 1.0, r.position.y + 1.0).distance_to(p) <= 22.0:
						var idx := selected
						selected = -1
						host._remove_part(idx)
						return
		for h in hit:
			var r: Rect2 = h.rect
			if r.grow(8.0).has_point(p):
				_press_idx = int(h.idx)
				selected = _press_idx
				var c := _cell_at(p)
				var id := str(host._inst[_press_idx]["id"])
				var it: Dictionary = host._inst[_press_idx]
				_drag_off = c - Vector2i(int(it["gx"]), int(it["gy"]))
				_drag_cell = Vector2i(int(it["gx"]), int(it["gy"]))
				_drag_ok = true
				queue_redraw()
				return
		_press_idx = -1
		selected = -1
		queue_redraw()

	func _motion(p: Vector2) -> void:
		if _press_idx < 0:
			return
		if not _dragging and p.distance_to(_press_pos) < DRAG_THRESHOLD:
			return
		_dragging = true
		var c := _cell_at(p) - _drag_off
		var id := str(host._inst[_press_idx]["id"])
		var rows: int = host.rows_of(id)
		# 以指针为中心抓取：让它跟手，而不是跳到左上角
		_drag_cell = Vector2i(c.x, maxi(0, c.y))
		_drag_ok = host._fits(id, _drag_cell.x, _drag_cell.y, _press_idx)
		queue_redraw()

	func _release(p: Vector2) -> void:
		if _dragging and _press_idx >= 0:
			var idx := _press_idx
			_dragging = false   # 先解锁视图，落点脉冲才用得上正确的缩放
			if _drag_ok and host.move_part(idx, _drag_cell.x, _drag_cell.y):
				selected = idx
			else:
				selected = idx
				host._after_change()
		_dragging = false
		_press_idx = -1
		queue_redraw()

	# ── 从零件栏拖入 ───────────────────────────────────────
	func _can_drop_data(p: Vector2, data: Variant) -> bool:
		var ok: bool = typeof(data) == TYPE_DICTIONARY and data.has("part")
		if ok:
			_hover_drop = true
			_drag_ok = true
			_drag_cell = _cell_at(p)
			_drag_cell.x -= int(host.cols_of(str(data["part"])) * 0.5)
			queue_redraw()
		return ok

	func _drop_data(p: Vector2, data: Variant) -> void:
		_hover_drop = false
		var id := str(data["part"])
		var c := _cell_at(p)
		c.x -= int(host.cols_of(id) * 0.5)
		host.add_part_at(id, c.x, maxi(0, c.y))
		queue_redraw()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_DRAG_END:
			_hover_drop = false
			queue_redraw()

# ══ 零件缩略图标 ══════════════════════════════════════════
class PartIcon extends Control:
	var part_id := ""

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var d: Dictionary = Parts.def(part_id)
		var kind: String = str(d.get("kind", "tank"))
		var col: Color = {
			"pod": Color("e7effb"), "nose": Color("ccd8ec"), "chute": Color("f2a93b"),
			"tank": Color("dde5f2"), "engine": Color("8590a4"),
			"decoupler": Color("58627a"), "fin": Color("79839b"), "legs": Color("6b758a"),
		}.get(kind, Color("dde5f2"))
		var w := size.x
		var h := size.y
		var cx := w * 0.5
		match kind:
			"nose":
				draw_colored_polygon(PackedVector2Array([
					Vector2(cx, h * 0.08), Vector2(w * 0.82, h * 0.92), Vector2(w * 0.18, h * 0.92)]), col)
			"fin":
				draw_colored_polygon(PackedVector2Array([
					Vector2(cx, h * 0.15), Vector2(w * 0.1, h * 0.95), Vector2(w * 0.9, h * 0.95)]), col)
			"chute":
				draw_arc(Vector2(cx, h * 0.72), w * 0.36, PI, TAU, 24, col, 3.0)
				draw_line(Vector2(cx, h * 0.72), Vector2(cx, h * 0.95), col.darkened(0.3), 2.0)
			"engine":
				draw_rect(Rect2(w * 0.28, h * 0.1, w * 0.44, h * 0.5), col, true)
				draw_colored_polygon(PackedVector2Array([
					Vector2(w * 0.22, h * 0.6), Vector2(w * 0.78, h * 0.6),
					Vector2(w * 0.92, h * 0.92), Vector2(w * 0.08, h * 0.92)]), col.darkened(0.28))
			"pod":
				draw_rect(Rect2(w * 0.24, h * 0.15, w * 0.52, h * 0.7), col, true)
				draw_circle(Vector2(cx, h * 0.42), w * 0.13, Color("16233c"))
				draw_circle(Vector2(cx, h * 0.42), w * 0.07, Color("6fd8ff"))
			"decoupler":
				draw_rect(Rect2(w * 0.08, h * 0.38, w * 0.84, h * 0.24), col, true)
			"legs":
				draw_line(Vector2(cx, h * 0.2), Vector2(w * 0.12, h * 0.95), col, 3.0)
				draw_line(Vector2(cx, h * 0.2), Vector2(w * 0.88, h * 0.95), col, 3.0)
			_:
				draw_rect(Rect2(w * 0.26, h * 0.1, w * 0.48, h * 0.8), col, true)
				draw_line(Vector2(w * 0.26, h * 0.5), Vector2(w * 0.74, h * 0.5), col.darkened(0.3), 1.5)

# ══ 绘制工具 ══════════════════════════════════════════════
class Draw:
	static func rounded_rect(c: CanvasItem, r: Rect2, radius: float,
			bg: Color, border: Color, bw: float) -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = bg
		sb.border_color = border
		sb.set_border_width_all(int(bw))
		sb.set_corner_radius_all(int(radius))
		sb.draw(c.get_canvas_item(), r)

	static func part(c: CanvasItem, kind: String, r: Rect2, d: Dictionary, alpha: float = 1.0) -> void:
		var col: Color = {
			"pod": Color("e7effb"), "nose": Color("ccd8ec"), "chute": Color("f2a93b"),
			"tank": Color("dde5f2"), "engine": Color("8590a4"),
			"decoupler": Color("58627a"), "fin": Color("79839b"), "legs": Color("6b758a"),
		}.get(kind, Color("dde5f2"))
		if alpha < 1.0:
			col.a = alpha
		var stroke := col.darkened(0.45)
		stroke.a = alpha
		match kind:
			"nose":
				var pts := PackedVector2Array([
					Vector2(r.position.x, r.position.y + r.size.y),
					Vector2(r.position.x + r.size.x * 0.5, r.position.y),
					Vector2(r.position.x + r.size.x, r.position.y + r.size.y)])
				c.draw_colored_polygon(pts, col)
				c.draw_polyline(pts + PackedVector2Array([pts[0]]), stroke, 1.5)
			"fin":
				var fpts := PackedVector2Array([
					Vector2(r.position.x + r.size.x * 0.5, r.position.y),
					Vector2(r.position.x - r.size.x * 1.2, r.position.y + r.size.y),
					Vector2(r.position.x + r.size.x * 0.5, r.position.y + r.size.y * 0.9),
					Vector2(r.position.x + r.size.x * 2.2, r.position.y + r.size.y)])
				c.draw_colored_polygon(fpts, col)
			_:
				c.draw_rect(r, col, true)
				c.draw_rect(r, stroke, false, 1.5)
				if kind == "engine":
					c.draw_rect(Rect2(r.position.x + r.size.x * 0.15, r.position.y + r.size.y,
						r.size.x * 0.7, r.size.y * 0.55), Color(col.darkened(0.35), alpha), true)
				elif kind == "tank":
					c.draw_line(Vector2(r.position.x + 2, r.position.y + r.size.y * 0.5),
						Vector2(r.position.x + r.size.x - 2, r.position.y + r.size.y * 0.5),
						Color(1, 1, 1, 0.22 * alpha), 1.0)
				elif kind == "pod":
					var wr := Rect2(r.position.x + r.size.x * 0.22, r.position.y + r.size.y * 0.3,
						r.size.x * 0.56, r.size.y * 0.3)
					c.draw_rect(wr, Color(0.10, 0.15, 0.24, alpha), true)
					c.draw_rect(wr, Color(0.44, 0.85, 1.0, alpha), false, 1.0)
				elif kind == "chute":
					c.draw_rect(Rect2(r.position.x + r.size.x * 0.3, r.position.y + r.size.y * 0.2,
						r.size.x * 0.4, r.size.y * 0.5), Color(col.darkened(0.2), alpha), true)
