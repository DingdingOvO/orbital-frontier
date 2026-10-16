extends Control
## WorkshopPage — 火箭工坊
## 顶部工具栏（预设下拉/撤销/清空/发射）｜左零件库（可拖拽）｜中组装区｜底部实时参数条

const PART_COLOR := {
	"pod": Color("e7effb"),
	"nose": Color("ccd8ec"),
	"chute": Color("f2a93b"),
	"tank": Color("dde5f2"),
	"engine": Color("8590a4"),
	"decoupler": Color("58627a"),
	"fin": Color("79839b"),
	"legs": Color("6b758a"),
}

var nav: Control
var _parts: Array = []
var _texts: Array = []
var _preview: Control
var _part_btns: Array = []
var _preset_opt: OptionButton
var _preset_keys: Array = []

var _val_mass: Label
var _val_dv: Label
var _val_twr: Label
var _val_stages: Label
var _hint: Label

func set_nav(n: Control) -> void:
	nav = n

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	Loc.locale_changed.connect(func(_c: String): _refresh_texts())
	_refresh_texts()
	# 调试用：-- --preload-preset 直接装填预设火箭（自动化验证用）
	for a in OS.get_cmdline_user_args():
		if a == "--preload-preset":
			_parts = (Parts.PRESETS["orbiter"] as Array).duplicate()
			break
	_update_stats()

func on_enter(_p: Dictionary) -> void:
	_refresh_texts()
	_update_stats()
	_preview.queue_redraw()

# ══ 构建 ══════════════════════════════════════════════════
func _build() -> void:
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 34)
	root.add_theme_constant_override("margin_right", 34)
	root.add_theme_constant_override("margin_top", 24)
	root.add_theme_constant_override("margin_bottom", 22)
	add_child(root)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	root.add_child(col)

	col.add_child(_build_toolbar())

	# 主体：左零件库 + 右（组装区 + 参数条）
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	col.add_child(body)
	body.add_child(_build_palette())
	body.add_child(_build_assembly())

	_hint = UiKit.label("", 13, UiKit.TEXT_MUTE)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_texts.append({"node": _hint, "key": "build.tap"})
	col.add_child(_hint)

func _build_toolbar() -> Control:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)

	var back := UiKit.ghost_button("←  " + Loc.t("common.back"))
	back.pressed.connect(func(): nav.go_back())
	head.add_child(back)

	var t := UiKit.title("", 26)
	_texts.append({"node": t, "key": "build.title"})
	head.add_child(t)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)

	var pl := UiKit.label("", 15, UiKit.TEXT_DIM)
	_texts.append({"node": pl, "key": "build.preset"})
	head.add_child(pl)
	_preset_keys = Parts.PRESETS.keys()
	_preset_opt = UiKit.option([], -1)
	_preset_opt.custom_minimum_size = Vector2(240, 44)
	_preset_opt.item_selected.connect(_on_preset)
	head.add_child(_preset_opt)

	var undo := UiKit.ghost_button("")
	_texts.append({"node": undo, "key": "build.undo"})
	undo.pressed.connect(_undo)
	head.add_child(undo)

	var clr := UiKit.ghost_button("")
	_texts.append({"node": clr, "key": "build.clear"})
	clr.pressed.connect(_clear)
	head.add_child(clr)

	var launch := UiKit.button("", true, 20)
	launch.custom_minimum_size = Vector2(160, 50)
	_texts.append({"node": launch, "key": "build.launch"})
	launch.pressed.connect(_launch)
	head.add_child(launch)
	return head

func _build_palette() -> Control:
	var p := UiKit.panel(UiKit.PANEL, 18, true, 14)
	p.custom_minimum_size = Vector2(236, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)

	var hdr := UiKit.label("", 15, UiKit.CYAN)
	_texts.append({"node": hdr, "key": "build.parts"})
	v.add_child(hdr)

	var scroll := UiKit.themed_scroll(ScrollContainer.new())
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 7)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	for id in Parts.PALETTE:
		var b := PartButton.new()
		b.part_id = id
		b.host = self
		b.custom_minimum_size = Vector2(0, 54)
		list.add_child(b)
		_part_btns.append({"node": b, "id": id})
	return p

func _build_assembly() -> Control:
	var p := UiKit.panel(UiKit.PANEL_LO, 18, true, 12)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)

	_preview = Preview.new()
	_preview.host = self
	_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview.custom_minimum_size = Vector2(400, 260)
	v.add_child(_preview)

	# 参数条：贴在蓝图面板内部下方（不横跨整个界面）
	v.add_child(_build_stats_bar())
	return p

func _build_stats_bar() -> Control:
	var bar := UiKit.panel(UiKit.PANEL, 14, true, 12)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 0)
	bar.add_child(h)

	_val_mass = _stat_cell(h, "build.mass", "t")
	_cell_sep(h)
	_val_dv = _stat_cell(h, "build.dv", "m/s")
	_cell_sep(h)
	_val_twr = _stat_cell(h, "build.twr", "")
	_cell_sep(h)
	_val_stages = _stat_cell(h, "build.stages", "")
	return bar

func _cell_sep(parent: Control) -> void:
	var s := ColorRect.new()
	s.color = UiKit.STROKE
	s.custom_minimum_size = Vector2(1, 40)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(s)

func _stat_cell(parent: Control, key: String, unit: String) -> Label:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 0)
	parent.add_child(box)
	var k := UiKit.label("", 13, UiKit.TEXT_MUTE)
	k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_texts.append({"node": k, "key": key})
	box.add_child(k)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 5)
	box.add_child(row)
	var v := UiKit.label("—", 26, UiKit.TEXT)
	v.add_theme_font_override("font", UiKit.spaced_font(1, 0.02))
	row.add_child(v)
	if unit != "":
		var u := UiKit.label(unit, 13, UiKit.TEXT_MUTE)
		u.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		row.add_child(u)
	return v

# ══ 逻辑 ══════════════════════════════════════════════════
func add_part(id: String) -> void:
	_parts.append(id)
	_after_change()

func _remove_part(idx: int) -> void:
	if idx >= 0 and idx < _parts.size():
		_parts.remove_at(idx)
		_after_change()

func _undo() -> void:
	if not _parts.is_empty():
		_parts.remove_at(_parts.size() - 1)
		_after_change()

func _clear() -> void:
	_parts.clear()
	_after_change()

func _on_preset(i: int) -> void:
	# index 0 是「— 选择预设 —」占位项，真正的预设从 1 开始
	if i <= 0 or (i - 1) >= _preset_keys.size():
		return
	_parts = (Parts.PRESETS[_preset_keys[i - 1]] as Array).duplicate()
	_after_change()

func _after_change() -> void:
	_update_stats()
	_preview.queue_redraw()

func _update_stats() -> void:
	if _val_mass == null:
		return
	if _parts.is_empty():
		_val_mass.text = "—"
		_val_dv.text = "—"
		_val_twr.text = "—"
		_val_stages.text = "0"
		return
	var r := Rocket.new()
	r.setup(_parts)
	_val_mass.text = "%.1f" % (r.total_mass() / 1000.0)
	_val_dv.text = "%.0f" % r.delta_v()
	_val_twr.text = "%.2f" % r.thrust_to_weight()
	_val_stages.text = str(r.stages.size())

func _launch() -> void:
	if _parts.is_empty():
		_hint.text = str({"zh_CN": "请先添加零件", "zh_TW": "請先添加零件", "en": "Add parts first"}.get(Loc.current, "Add parts first"))
		return
	var r := Rocket.new()
	r.setup(_parts)
	if r.max_thrust() <= 0.0:
		_hint.text = str({"zh_CN": "需要至少一台引擎", "zh_TW": "需要至少一台引擎", "en": "Need at least one engine"}.get(Loc.current, "Need an engine"))
		return
	if bool(Cfg.get_value("auto_save", true)):
		SaveGame.cache_design(_parts)
	nav.show_page("flight", {"design": _parts.duplicate()})

func _part_color(kind: String) -> Color:
	return PART_COLOR.get(kind, Color(0.82, 0.86, 0.92)) as Color

func _refresh_texts() -> void:
	for e in _texts:
		if is_instance_valid(e.node):
			e.node.text = Loc.t(e.key)
	for e in _part_btns:
		if is_instance_valid(e.node):
			e.node.queue_redraw()
	# 预设下拉：第 0 项是占位文案，之后是各预设
	var keep := _preset_opt.selected
	_preset_opt.clear()
	_preset_opt.add_item(Loc.t("build.preset.none"))
	for k in _preset_keys:
		_preset_opt.add_item(Loc.t("preset." + str(k)))
	# selected = -1 会让下拉框显示为空白，默认落在占位项上
	_preset_opt.selected = keep if keep >= 0 else 0

# ══ 零件按钮（支持拖拽 + 点击） ════════════════════════════
class PartButton extends Button:
	var part_id := ""
	var host = null
	var _icon: Control

	func _ready() -> void:
		focus_mode = Control.FOCUS_NONE
		alignment = HORIZONTAL_ALIGNMENT_LEFT
		add_theme_font_override("font", UiKit.font_base)
		add_theme_font_size_override("font_size", 16)
		_apply_style()
		_icon = PartIcon.new()
		_icon.part_id = part_id
		_icon.position = Vector2(16, 13)
		_icon.size = Vector2(28, 28)
		add_child(_icon)
		pressed.connect(func(): host.add_part(part_id))
		mouse_entered.connect(func(): _apply_style(true))
		mouse_exited.connect(func(): _apply_style(false))

	func _apply_style(hover: bool = false) -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = UiKit.PANEL_HI.lightened(0.06) if hover else UiKit.PANEL_HI
		sb.border_color = UiKit.STROKE_HI if hover else UiKit.STROKE
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(12)
		sb.content_margin_left = 56
		sb.content_margin_right = 14
		sb.content_margin_top = 13
		sb.content_margin_bottom = 13
		var st := "hover" if hover else "normal"
		add_theme_stylebox_override(st, sb)
		add_theme_stylebox_override("pressed", sb)
		add_theme_stylebox_override("focus", sb)
		modulate = Color(1.12, 1.12, 1.12, 1.0) if hover else Color.WHITE

	func _draw() -> void:
		# 名称文本（右侧）+ 拖拽提示
		var f: Font = UiKit.font_base if UiKit.font_base else ThemeDB.fallback_font
		var d: Dictionary = Parts.def(part_id)
		var nm := Loc.t(str(d.get("name_key", part_id)))
		draw_string(f, Vector2(56, size.y * 0.5 + 6), nm,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UiKit.TEXT)
		var kg := Parts.dry_mass(part_id) + Parts.fuel_cap(part_id)
		draw_string(f, Vector2(size.x - 14 - Measure.text_width(f, "%d kg" % int(kg), 12),
			size.y * 0.5 + 5), "%d kg" % int(kg),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiKit.TEXT_MUTE)

	func _get_drag_data(_pos: Vector2) -> Variant:
		var preview := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = UiKit.ACCENT
		sb.set_corner_radius_all(10)
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		sb.content_margin_top = 8
		sb.content_margin_bottom = 8
		preview.add_theme_stylebox_override("panel", sb)
		var f: Font = UiKit.font_base if UiKit.font_base else ThemeDB.fallback_font
		var d: Dictionary = Parts.def(part_id)
		var l := Label.new()
		l.text = Loc.t(str(d.get("name_key", part_id)))
		l.add_theme_font_override("font", f)
		l.add_theme_font_size_override("font_size", 15)
		l.add_theme_color_override("font_color", Color.WHITE)
		preview.add_child(l)
		set_drag_preview(preview)
		return {"part": part_id}

# 小工具：测量文本宽度
class Measure:
	static func text_width(f: Font, s: String, sz: int) -> float:
		return f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x

# ══ 零件缩略图标 ══════════════════════════════════════════
class PartIcon extends Control:
	var part_id := ""

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(28, 28)

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

# ══ 组装区 ════════════════════════════════════════════════
class Preview extends Control:
	var host = null
	var hit: Array = []
	var _hover_drop := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
		return typeof(data) == TYPE_DICTIONARY and data.has("part")

	func _drop_data(_pos: Vector2, data: Variant) -> void:
		_hover_drop = false
		host.add_part(str(data["part"]))
		queue_redraw()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_DRAG_BEGIN:
			_hover_drop = true
			queue_redraw()
		elif what == NOTIFICATION_DRAG_END:
			_hover_drop = false
			queue_redraw()

	func _draw() -> void:
		hit.clear()
		# 拖拽高亮
		if _hover_drop:
			Draw.rounded_rect(self, Rect2(6, 6, size.x - 12, size.y - 12), 14,
				Color(0.30, 0.55, 1.0, 0.10), Color(0.45, 0.70, 1.0, 0.55), 3)
		elif bool(Cfg.get_value("show_grid", true)):
			var step := 44.0
			var x := 0.0
			var guard := 0
			while x < size.x and guard < 120:
				draw_line(Vector2(x, 0), Vector2(x, size.y), Color(1, 1, 1, 0.045))
				x += step
				guard += 1
			var y := 0.0
			guard = 0
			while y < size.y and guard < 120:
				draw_line(Vector2(0, y), Vector2(size.x, y), Color(1, 1, 1, 0.045))
				y += step
				guard += 1

		var parts: Array = host._parts
		if parts.is_empty():
			var f: Font = UiKit.font_base if UiKit.font_base else ThemeDB.fallback_font
			var msg := "把左侧零件拖到这里，或直接点击添加"
			if host.Loc.current == "zh_TW":
				msg = "把左側零件拖到這裡，或直接點擊加入"
			elif host.Loc.current == "en":
				msg = "Drag parts here, or simply tap them"
			var fs := 17
			var w := f.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(f, Vector2(size.x * 0.5 - w * 0.5, size.y * 0.5), msg,
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.72, 0.81, 0.95, 0.9))
			return

		var sum: Dictionary = Parts.summarize(parts)
		var H: float = max(1.0, sum["height"])
		var W: float = max(0.4, sum["width"])
		var s: float = min((size.x - 150.0) / (W * 1.6), (size.y - 90.0) / (H * 1.08))
		s = clampf(s, 3.0, 260.0)
		var cx := size.x * 0.5
		var base_y := size.y * 0.94
		var y := base_y
		for i in range(parts.size() - 1, -1, -1):
			var id: String = parts[i]
			var d: Dictionary = Parts.def(id)
			var h: float = float(d.get("h", 1.0)) * s
			var w: float = float(d.get("w", 1.0)) * s
			var kind: String = str(d.get("kind", "tank"))
			var rect := Rect2(cx - w * 0.5, y - h, w, h)
			Draw.part(self, kind, rect, d)
			hit.append({"idx": i, "rect": rect})
			y -= h
		# 高度标注
		var fnt: Font = UiKit.font_base if UiKit.font_base else ThemeDB.fallback_font
		draw_string(fnt, Vector2(cx + W * s * 0.5 + 16, base_y - H * s * 0.5),
			"%.1f m" % H, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.75, 0.85, 1.0, 0.7))

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			var mp: Vector2 = e.position
			for h in hit:
				if (h.rect as Rect2).grow(5.0).has_point(mp):
					host._remove_part(int(h.idx))
					return

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

	static func part(c: CanvasItem, kind: String, r: Rect2, d: Dictionary) -> void:
		var col: Color = {
			"pod": Color("e7effb"), "nose": Color("ccd8ec"), "chute": Color("f2a93b"),
			"tank": Color("dde5f2"), "engine": Color("8590a4"),
			"decoupler": Color("58627a"), "fin": Color("79839b"), "legs": Color("6b758a"),
		}.get(kind, Color("dde5f2"))
		var stroke := col.darkened(0.45)
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
						r.size.x * 0.7, r.size.y * 0.55), col.darkened(0.35), true)
				elif kind == "tank":
					c.draw_line(Vector2(r.position.x + 2, r.position.y + r.size.y * 0.5),
						Vector2(r.position.x + r.size.x - 2, r.position.y + r.size.y * 0.5),
						Color(1, 1, 1, 0.22), 1.0)
				elif kind == "pod":
					var wr := Rect2(r.position.x + r.size.x * 0.22, r.position.y + r.size.y * 0.3,
						r.size.x * 0.56, r.size.y * 0.3)
					c.draw_rect(wr, Color("1a2740"), true)
					c.draw_rect(wr, Color("6fd8ff"), false, 1.0)
				elif kind == "chute":
					c.draw_rect(Rect2(r.position.x + r.size.x * 0.3, r.position.y + r.size.y * 0.2,
						r.size.x * 0.4, r.size.y * 0.5), col.darkened(0.2), true)
