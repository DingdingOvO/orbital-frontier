extends Control
## MenuPage — 主菜单
## 视觉规范：三级对比度 + 全按钮统一宽高圆角 + 每个按钮配矢量图标
##   level 0  纯白底 / 纯黑字     最高优先级（开始游戏）
##   level 1  亮蓝底 / 纯白字     次优先（继续）
##   level 2  深灰底 / 纯白字     常规操作（Mod / 设置 / 关于 / 退出）

var nav: Control

const W := 420                    # 主按钮统一宽度
const SW := 134                   # 三连按钮单体宽度（134×3 + 8×2 = 418 ≈ 420）
const GAP := 10                   # 统一间距

var _texts: Array = []
var _lang_btns: Array = []
var _btn_continue: Button
var _kicker: Label
var _logo: Label
var _sub: Label

func set_nav(n: Control) -> void:
	nav = n

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build()
	Loc.locale_changed.connect(func(_c: String): _refresh())
	_refresh()

func on_enter(_payload: Dictionary) -> void:
	_refresh()

# ── 构建 ─────────────────────────────────────────────────
func _build() -> void:
	add_child(PlanetArc.new())

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	center.add_child(col)

	# ── 品牌区 ──
	_kicker = UiKit.label("", 13, UiKit.CYAN)
	_kicker.add_theme_font_override("font", UiKit.spaced_font(4))
	_kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_kicker)

	col.add_child(UiKit.hsep(12))
	_logo = UiKit.glow_title("", 58)
	_logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_logo)
	col.add_child(UiKit.hsep(6))
	_sub = UiKit.label("", 17, UiKit.TEXT_DIM)
	_sub.add_theme_font_override("font", UiKit.spaced_font(7))
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_sub)

	col.add_child(UiKit.hsep(30))

	# ── 主操作：纯白底 + 纯黑字（最高视觉优先级）──
	var start := UiKit.menu_button("", "play", 0, W)
	start.pressed.connect(func(): nav.show_page("workshop"))
	col.add_child(start)
	_text_map(start, "menu.start")

	col.add_child(UiKit.hsep(GAP))

	# ── 继续：亮蓝底 + 纯白字 ──
	_btn_continue = UiKit.menu_button("", "clock", 1, W)
	_btn_continue.pressed.connect(func(): nav.show_page("saves"))
	col.add_child(_btn_continue)
	_text_map(_btn_continue, "menu.continue")

	col.add_child(UiKit.hsep(GAP))

	# ── 三连按钮：Mod / 设置 / 关于 ──
	var row_wrap := CenterContainer.new()
	col.add_child(row_wrap)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row_wrap.add_child(row)
	_cell(row, "menu.mods", "folder", func(): nav.show_page("mods"))
	_cell(row, "menu.settings", "gear", func(): nav.show_page("settings"))
	_cell(row, "menu.about", "info", func(): nav.show_page("about"))

	col.add_child(UiKit.hsep(GAP))

	# ── 退出 ──
	var quit := UiKit.menu_button("", "exit", 2, W)
	quit.pressed.connect(func(): get_tree().quit())
	col.add_child(quit)
	_text_map(quit, "menu.quit")

	# ── 右上角语言（同套配色：选中亮蓝 / 未选中深灰）──
	var lang_box := HBoxContainer.new()
	lang_box.add_theme_constant_override("separation", 6)
	lang_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	lang_box.offset_left = -198
	lang_box.offset_top = 28
	lang_box.offset_right = -28
	lang_box.offset_bottom = 66
	add_child(lang_box)
	for code in Loc.CODES:
		var b := UiKit.menu_button(Loc.SHORT.get(code, code), "", 2, 54, 38, 10)
		b.add_theme_font_size_override("font_size", 15)
		b.pressed.connect(func(): Loc.set_locale(code))
		lang_box.add_child(b)
		_lang_btns.append({"node": b, "code": code})

	# ── 底部版本 ──
	var ver := UiKit.label("", 12, UiKit.TEXT_MUTE)
	ver.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	ver.offset_left = -200
	ver.offset_top = -38
	ver.offset_right = 200
	ver.offset_bottom = -14
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_texts.append({"node": ver, "key": "app.version", "args": {"v": "0.1.0"}})
	add_child(ver)

func _text_map(node: Button, key: String) -> void:
	_texts.append({"node": node, "key": key})

func _cell(parent: Control, key: String, icon: String, cb: Callable) -> void:
	var b := UiKit.menu_button("", icon, 2, SW)
	b.add_theme_font_size_override("font_size", 17)
	b.pressed.connect(cb)
	parent.add_child(b)
	_text_map(b, key)

# ── 刷新 ─────────────────────────────────────────────────
func _refresh() -> void:
	_kicker.text = Loc.t("app.kicker")
	_logo.text = Loc.t("app.logo")
	_sub.text = Loc.t("app.subtitle")
	for e in _texts:
		if is_instance_valid(e.node):
			e.node.text = Loc.t(e.key, e.get("args", {}))
	if is_instance_valid(_btn_continue):
		var ok: bool = SaveGame.has_save()
		_btn_continue.disabled = not ok
		# 禁用时图标同步变灰，避免"亮图标 + 灰底"的割裂感
		_btn_continue.set("icon_tint", Color.WHITE if ok else Color("9aa8c0"))
	for e in _lang_btns:
		if is_instance_valid(e.node):
			var on: bool = e.code == Loc.current
			e.node.set("icon_tint", Color.WHITE)
			e.node.add_theme_color_override("font_color", Color.WHITE)
			e.node.add_theme_stylebox_override("normal",
				UiKit._sb(Color("3b82f6") if on else Color("232b3a"),
					Color("7db0ff") if on else Color("3d4a63"), 10, 1, 14, 8))
			e.node.add_theme_stylebox_override("hover",
				UiKit._sb(Color("4a8ffa") if on else Color("2c3648"),
					Color("9cc2ff"), 10, 1, 14, 8))

# ── 装饰：底部行星弧 ──────────────────────────────────────
class PlanetArc extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		offset_top = -300
		offset_bottom = 0

	func _draw() -> void:
		var cx := size.x * 0.5
		var cy := size.y + 900.0
		var r := 1020.0
		draw_arc(Vector2(cx, cy), r + 16.0, PI * 1.24, PI * 1.76, 110, Color(0.22, 0.52, 1.0, 0.07), 30.0)
		draw_arc(Vector2(cx, cy), r + 5.0, PI * 1.24, PI * 1.76, 110, Color(0.30, 0.62, 1.0, 0.20), 7.0)
		draw_circle(Vector2(cx, cy), r, Color("0a1428"))
		draw_circle(Vector2(cx, cy), r - 3.0, Color("0b1730"))
		draw_arc(Vector2(cx, cy), r, PI * 1.24, PI * 1.76, 110, Color(0.42, 0.72, 1.0, 0.55), 2.0)
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		for i in 46:
			var x := rng.randf_range(0, size.x)
			var y := rng.randf_range(0, size.y)
			draw_circle(Vector2(x, y), rng.randf_range(0.6, 1.5),
				Color(0.82, 0.9, 1.0, rng.randf_range(0.2, 0.55)))
