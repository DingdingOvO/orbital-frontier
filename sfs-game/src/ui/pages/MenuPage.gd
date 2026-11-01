extends Control
## MenuPage — 主菜单
## 布局：左侧信息列（品牌 + 操作）/ 右侧程序化轨道插画 / 顶部语言分段切换
## 交互：错峰入场、按钮按压回弹 + 触感、存档卡片实时摘要、语言切换滑动高亮

const SegScript := preload("res://src/ui/widgets/UiSegmented.gd")

const W := 404.0          # 统一内容宽度
const BTN_H := 66.0       # 主按钮高度
const ROW_H := 56.0       # 三个次级按钮高度
const CARD_H := 92.0      # 继续任务卡片高度
const SIDE := 72.0        # 左右安全边距

var nav: Control
var _texts: Array = []
var _lang: Control
var _left: VBoxContainer
var _logo: Label
var _kicker: Label
var _sub: Label
var _rule: Control
var _start: Button
var _resume: Button
var _resume_kicker: Label
var _resume_title: Label
var _resume_sub: Label
var _row: HBoxContainer
var _quit: Button
var _ver: Label
var _hint: Label
var _built := false

func set_nav(n: Control) -> void:
	nav = n

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build()
	Loc.locale_changed.connect(func(_c: String): _refresh())
	refresh_save()
	_refresh()
	resized.connect(_apply_layout)
	_apply_layout()
	# 首屏入场（延迟一帧，等容器完成布局）
	await get_tree().process_frame
	if not _built:
		_built = true
		_play_entrance()

func on_enter(_payload: Dictionary) -> void:
	refresh_save()
	_refresh()
	# 从子页面返回时，整列轻微上浮，给"回来了"一个明确反馈
	if _built and is_inside_tree():
		UiKit.pop_in(_start, 0.0, 0.34, 0.97)
		UiKit.pop_in(_resume, 0.05, 0.34, 0.97)

# ══ 布局 ══════════════════════════════════════════════════
func _build() -> void:
	add_child(Backdrop.new())

	_left = VBoxContainer.new()
	_left.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	_left.alignment = BoxContainer.ALIGNMENT_CENTER
	_left.add_theme_constant_override("separation", 0)
	add_child(_left)

	# ── 品牌 ──
	_kicker = UiKit.label("", 12, UiKit.CYAN)
	_kicker.add_theme_font_override("font", UiKit.spaced_font(4))
	_kicker.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_left.add_child(_kicker)

	_left.add_child(UiKit.hsep(10))
	_logo = UiKit.glow_title("", 56)
	_logo.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_left.add_child(_logo)

	_left.add_child(UiKit.hsep(4))
	_sub = UiKit.label("", 13, UiKit.TEXT_MUTE)
	_sub.add_theme_font_override("font", UiKit.spaced_font(6))
	_sub.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_left.add_child(_sub)

	_left.add_child(UiKit.hsep(16))
	_rule = UiKit.accent_rule(96, 3, UiKit.ACCENT)
	_left.add_child(_rule)
	_left.add_child(UiKit.hsep(30))

	# ── 开始：纯白底 + 纯黑字（全站最高优先级）──
	_start = _wide(UiKit.menu_button("", "play", 0, int(W), int(BTN_H), 18))
	_start.pressed.connect(func(): nav.show_page("workshop"))
	_left.add_child(_start)
	_texts.append({"node": _start, "key": "menu.start"})

	_left.add_child(UiKit.hsep(10))

	# ── 继续：带存档摘要的卡片 ──
	_resume = ResumeCard.new()
	_resume.custom_minimum_size = Vector2(W, CARD_H)
	_resume.focus_mode = Control.FOCUS_NONE
	_resume._apply_styles(true)
	_resume.pressed.connect(func(): nav.show_page("saves"))
	UiKit.press_fx(_resume)
	_left.add_child(_resume)
	_build_resume_children()

	_left.add_child(UiKit.hsep(10))

	# ── 三个次级入口 ──
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 8)
	_row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_left.add_child(_row)
	var cell_w := int((W - 16.0) / 3.0)
	_cell("menu.mods", "folder", cell_w, func(): nav.show_page("mods"))
	_cell("menu.settings", "gear", cell_w, func(): nav.show_page("settings"))
	_cell("menu.about", "info", cell_w, func(): nav.show_page("about"))

	_left.add_child(UiKit.hsep(10))

	_quit = _wide(UiKit.menu_button("", "exit", 2, int(W), int(ROW_H), 16))
	_quit.pressed.connect(func():
		UiKit.haptic(12)
		get_tree().quit())
	_left.add_child(_quit)
	_texts.append({"node": _quit, "key": "menu.quit"})

	# ── 右上：语言分段切换 ──
	_lang = SegScript.new()
	_lang.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_lang.offset_left = -(SIDE + 4.0 + 58.0 * 3.0 + 8.0)
	_lang.offset_top = 24
	_lang.offset_right = -SIDE
	_lang.offset_bottom = 72
	_lang.changed.connect(func(i: int): Loc.set_locale(Loc.CODES[i]))
	add_child(_lang)

	# ── 底部：版本 / 操作提示 ──
	_ver = UiKit.label("", 12, Color(0.72, 0.80, 0.93, 0.62))
	_ver.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_ver.offset_left = SIDE
	_ver.offset_top = -38
	_ver.offset_right = SIDE + 260
	_ver.offset_bottom = -16
	_texts.append({"node": _ver, "key": "app.version", "args": {"v": "0.3.0"}})
	add_child(_ver)

	_hint = UiKit.label("", 12, Color(0.72, 0.80, 0.93, 0.55))
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_hint.offset_left = -SIDE - 380
	_hint.offset_top = -38
	_hint.offset_right = -SIDE
	_hint.offset_bottom = -16
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_texts.append({"node": _hint, "key": "menu.hint.touch" if UiKit.is_touch() else "menu.hint.mouse"})
	add_child(_hint)

func _wide(b: Button) -> Button:
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return b

func _cell(key: String, icon: String, w: int, cb: Callable) -> void:
	var b := UiKit.menu_button("", icon, 2, w, int(ROW_H), 14)
	b.add_theme_font_size_override("font_size", 16)
	b.pressed.connect(cb)
	_row.add_child(b)
	_texts.append({"node": b, "key": key})

func _build_resume_children() -> void:
	var b := _resume

	_resume_kicker = UiKit.label("", 11, Color(1, 1, 1, 0.72))
	_resume_kicker.add_theme_font_override("font", UiKit.spaced_font(3))
	_resume_kicker.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_resume_kicker.offset_left = 66
	_resume_kicker.offset_top = 15
	_resume_kicker.offset_right = -50
	_resume_kicker.offset_bottom = 31
	_resume_kicker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(_resume_kicker)
	_texts.append({"node": _resume_kicker, "key": "menu.resume.kicker"})

	_resume_title = UiKit.label("", 19, Color.WHITE)
	_resume_title.add_theme_font_override("font", UiKit.ui_font(1, true))
	_resume_title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_resume_title.offset_left = 66
	_resume_title.offset_top = 31
	_resume_title.offset_right = -50
	_resume_title.offset_bottom = 58
	_resume_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resume_title.clip_text = true
	b.add_child(_resume_title)

	_resume_sub = UiKit.label("", 12, Color(1, 1, 1, 0.80))
	_resume_sub.add_theme_font_override("font", UiKit.number_font(0))
	_resume_sub.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_resume_sub.offset_left = 66
	_resume_sub.offset_top = 59
	_resume_sub.offset_right = -50
	_resume_sub.offset_bottom = 79
	_resume_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resume_sub.clip_text = true
	b.add_child(_resume_sub)

	var ic := UiIcon.new()
	ic.kind = "rocket"
	ic.tint = Color.WHITE
	ic.set_anchors_preset(Control.PRESET_TOP_LEFT)
	ic.offset_left = 26
	ic.offset_top = 30
	ic.offset_right = 54
	ic.offset_bottom = 58
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ic)

	var chev := UiIcon.new()
	chev.kind = "chev"
	chev.tint = Color(1, 1, 1, 0.72)
	chev.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	chev.offset_left = -40
	chev.offset_top = 35
	chev.offset_right = -18
	chev.offset_bottom = 57
	chev.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(chev)

func on_safe_area() -> void:
	_apply_layout()

func _apply_layout() -> void:
	var narrow := size.x < 900.0
	var sf := UiKit.safe
	var side := (32.0 if narrow else SIDE) + sf.x
	_left.offset_left = side
	_left.offset_right = side + W + 16.0
	_left.offset_top = 74.0 + sf.y
	_left.offset_bottom = -56.0 - sf.w
	_ver.offset_left = side
	_ver.offset_bottom = -18.0 - sf.w
	_hint.offset_left = -side - 380.0
	_hint.offset_right = -side
	_hint.offset_bottom = -18.0 - sf.w
	if _lang:
		_lang.offset_left = -(side + 4.0 + 58.0 * 3.0 + 8.0)
		_lang.offset_right = -side
		_lang.offset_top = 22.0 + sf.y

func _play_entrance() -> void:
	var seq: Array = [_kicker, _logo, _sub, _rule, _start, _resume, _row, _quit, _lang, _ver, _hint]
	for i in seq.size():
		if is_instance_valid(seq[i]):
			UiKit.pop_in(seq[i], 0.03 + 0.045 * float(i), 0.46, 0.94)

# ══ 数据 / 文案 ═══════════════════════════════════════════
## 主菜单没进存档时也要显示摘要：直接读最近一个存档的元数据
func refresh_save() -> void:
	var slots: Array = SaveGame.list_slots()
	var card: ResumeCard = _resume as ResumeCard
	if slots.is_empty():
		_resume_title.text = Loc.t("menu.resume.none")
		_resume_sub.text = Loc.t("menu.resume.hint")
		_resume_kicker.modulate = Color(1, 1, 1, 0.55)
		card.empty = true
		_resume.disabled = true
		card.ach = 0.0
		card._apply_styles(false)
		return
	var s: Dictionary = slots[0]
	var st: Dictionary = s.get("stats", {})
	var ach: Dictionary = s.get("achievements", {})
	_resume_title.text = str(s.get("name", Loc.t("menu.continue")))
	var nl := int(st.get("launches", 0))
	var no := int(st.get("orbits", 0))
	var ns := (st.get("satellites", []) as Array).size()
	if Loc.current == "en":
		_resume_sub.text = "%d launch%s · %d orbit%s · %d satellite%s" % [
			nl, "" if nl == 1 else "es", no, "" if no == 1 else "s", ns, "" if ns == 1 else "s"]
	else:
		_resume_sub.text = Loc.t("menu.resume.stats", {"launch": nl, "orbit": no, "sat": ns})
	_resume_kicker.modulate = Color.WHITE
	card.empty = false
	_resume.disabled = false
	card.ach = clampf(float(ach.size()) / float(SaveGame.ACHIEVEMENTS.size()), 0.0, 1.0)
	card._apply_styles(true)
	card.queue_redraw()

func _refresh() -> void:
	for e in _texts:
		if is_instance_valid(e.node):
			e.node.text = Loc.t(e.key, e.get("args", {}))
	_kicker.text = Loc.t("app.kicker")
	_logo.text = Loc.t("app.logo")
	_sub.text = Loc.t("app.subtitle")
	# Logo：英文名更长，按可用宽度自适应字号，避免溢出列宽
	var base := 56
	var f := UiKit.spaced_font(4, 0.02)
	var w := f.get_string_size(Loc.t("app.logo"), HORIZONTAL_ALIGNMENT_LEFT, -1, base).x
	if w > W - 4.0:
		base = int(maxf(30.0, base * (W - 4.0) / w))
	_logo.add_theme_font_size_override("font_size", base)
	_lang.setup(Loc.CODES.map(func(c): return Loc.SHORT.get(c, c)), Loc.CODES.find(Loc.current))
	_hint.text = Loc.t("menu.hint.touch" if UiKit.is_touch() else "menu.hint.mouse")


# ══ 继续任务卡片 ══════════════════════════════════════════
class ResumeCard extends Button:
	var ach := 0.0
	var empty := true

	func _ready() -> void:
		clip_contents = false

	func _apply_styles(has_save: bool) -> void:
		var bg := Color("3b82f6") if has_save else Color("151b28")
		var edge := Color("8ab6ff") if has_save else Color("2c3648")
		add_theme_stylebox_override("normal", _sb(bg, edge, 16, 1))
		add_theme_stylebox_override("hover", _sb(bg.lightened(0.10) if has_save else bg, edge, 16, 1))
		add_theme_stylebox_override("pressed", _sb(bg.darkened(0.14), edge, 16, 1))
		add_theme_stylebox_override("disabled", _sb(Color("151b28"), Color("2c3648"), 16, 1))
		add_theme_stylebox_override("focus", _sb(bg, edge, 16, 2))
		queue_redraw()

	func _sb(bg: Color, edge: Color, r: int, bw: int) -> StyleBoxFlat:
		var sb := StyleBoxFlat.new()
		sb.bg_color = bg
		sb.border_color = edge
		sb.set_border_width_all(bw)
		sb.set_corner_radius_all(r)
		sb.shadow_color = Color(0, 0, 0, 0.28)
		sb.shadow_size = 6
		sb.shadow_offset = Vector2(0, 3)
		return sb

	func _draw() -> void:
		# 左侧图标底圈
		draw_circle(Vector2(40, size.y * 0.5), 21.0,
			Color(0, 0, 0, 0.16) if not empty else Color(1, 1, 1, 0.05))
		# 底部成就进度（极细，不抢视线）
		var y := size.y - 9.0
		var x0 := 22.0
		var w := maxf(10.0, size.x - 44.0)
		UiKit.rounded(self, Rect2(x0, y, w, 3), 2, Color(0, 0, 0, 0.20))
		if ach > 0.0:
			UiKit.rounded(self, Rect2(x0, y, maxf(6.0, w * ach), 3), 2, Color(1, 1, 1, 0.9))

# ══ 背景插画 ══════════════════════════════════════════════
## 程序化绘制：星点 + 大气光晕 + 行星弧 + 轨道抛物线（卫星沿轨迹缓慢飞行）
class Backdrop extends Control:
	var _t := 0.0
	var _par := Vector2.ZERO
	var _stars: Array = []
	var _glow: GradientTexture2D

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		# 径向渐变贴图：用来画柔和的星云/大气光晕（draw_circle 的硬边太"平"）
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1.0))
		g.add_point(0.45, Color(1, 1, 1, 0.38))
		g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0.0))
		_glow = GradientTexture2D.new()
		_glow.gradient = g
		_glow.fill = GradientTexture2D.FILL_RADIAL
		_glow.fill_from = Vector2(0.5, 0.5)
		_glow.fill_to = Vector2(1.0, 0.5)
		_glow.width = 128
		_glow.height = 128
		var rng := RandomNumberGenerator.new()
		rng.seed = 77213
		for i in 90:
			_stars.append({
				"x": rng.randf(), "y": rng.randf(),
				"r": rng.randf_range(0.5, 1.6),
				"a": rng.randf_range(0.15, 0.55),
				"ph": rng.randf_range(0.0, TAU),
				"tw": rng.randf_range(0.5, 1.8),
			})

	func _process(delta: float) -> void:
		_t += delta
		var mp := get_viewport().get_mouse_position()
		var target := Vector2(
			clampf((mp.x / maxf(1.0, size.x) - 0.5) * -2.0, -1.0, 1.0),
			clampf((mp.y / maxf(1.0, size.y) - 0.5) * -2.0, -1.0, 1.0))
		_par = _par.lerp(target, 1.0 - pow(0.002, delta))
		queue_redraw()

	func _soft_glow(center: Vector2, radius: float, tint: Color) -> void:
		if _glow == null:
			return
		draw_texture_rect(_glow, Rect2(center - Vector2(radius, radius),
			Vector2(radius, radius) * 2.0), false, tint)

	func _curve(t: float) -> Vector2:
		var p0 := Vector2(size.x * 0.44, size.y * 1.02)
		var p1 := Vector2(size.x * 0.66, size.y * 0.02)
		var p2 := Vector2(size.x * 1.04, size.y * 0.34)
		var u := 1.0 - t
		return p0 * u * u + p1 * 2.0 * u * t + p2 * t * t

	func _draw() -> void:
		var w := size.x
		var h := size.y

		# 柔和星云（径向渐变，无硬边）
		_soft_glow(Vector2(w * 0.74, h * 0.16) + _par * 6.0, h * 0.85, Color(0.16, 0.34, 0.78, 0.30))
		_soft_glow(Vector2(w * 0.28, h * 0.92) + _par * 4.0, h * 0.62, Color(0.10, 0.44, 0.60, 0.18))

		# 星点（视差 + 呼吸）
		for s in _stars:
			var p := Vector2(float(s.x) * w, float(s.y) * h) + _par * (3.0 + float(s.r) * 2.0)
			var tw := 0.65 + 0.35 * sin(_t * float(s.tw) + float(s.ph))
			draw_circle(p, float(s.r), Color(0.86, 0.92, 1.0, float(s.a) * tw))

		# 行星地平线（右下角）：只露一角，留出大片天空给轨道线
		var pc := Vector2(w * 1.00, h * 1.44) + _par * 12.0
		var pr := h * 0.78
		_soft_glow(pc, pr * 1.30, Color(0.18, 0.42, 1.0, 0.30))
		draw_circle(pc, pr, Color(0.031, 0.056, 0.108, 1.0))
		# 大气边缘光
		draw_arc(pc, pr, PI * 1.06, PI * 1.94, 160, Color(0.42, 0.72, 1.0, 0.62), 2.0)
		draw_arc(pc, pr + 8.0, PI * 1.14, PI * 1.86, 130, Color(0.30, 0.60, 1.0, 0.13), 11.0)
		# 极淡的表面带
		for i in 2:
			var rr := pr * (0.94 - float(i) * 0.05)
			draw_arc(pc, rr, PI * 1.22, PI * 1.78, 90, Color(0.36, 0.58, 0.95, 0.030), 12.0)

		# 轨道抛物线
		var pts := PackedVector2Array()
		for i in 49:
			pts.append(_curve(float(i) / 48.0) + _par * 5.0)
		draw_polyline(pts, Color(0.34, 0.66, 1.0, 0.26), 1.6, true)
		draw_polyline(pts, Color(0.50, 0.78, 1.0, 0.07), 9.0, true)

		# 卫星：沿轨迹循环 + 渐隐拖尾
		var t := fmod(_t * 0.045, 1.0)
		if t > 0.02 and t < 0.98:
			for i in 10:
				var tt := t - float(i) * 0.006
				if tt < 0.0:
					continue
				var fade := 1.0 - float(i) / 10.0
				draw_circle(_curve(tt) + _par * 5.0, 2.2 * fade, Color(0.70, 0.88, 1.0, 0.30 * fade))
			var sp := _curve(t) + _par * 5.0
			draw_circle(sp, 13.0, Color(0.35, 0.68, 1.0, 0.16))
			draw_circle(sp, 4.0, Color.WHITE)
			draw_circle(sp, 2.0, Color(0.75, 0.95, 1.0))
