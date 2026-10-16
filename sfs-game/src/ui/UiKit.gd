extends Node
## UiKit — 设计系统：调色板 / 字体 / 主题 / 控件工厂
## 视觉语言：深空底 + 玻璃面板 + 青蓝强调色 + 高光描边

# ── 调色板（深底 + 高对比控件） ────────────────────────────
const INK        := Color("05080f")
const BG         := Color("0a1020")
const BG2        := Color("0f1830")
const PANEL      := Color("18243d")   # 面板明显亮于背景
const PANEL_HI   := Color("22345a")
const PANEL_LO   := Color("0d1526")
const STROKE     := Color("3b5488")   # 描边清晰可见
const STROKE_HI  := Color("5b7fd0")
const TEXT       := Color("ffffff")
const TEXT_DIM   := Color("c3d0e8")
const TEXT_MUTE  := Color("93a7c9")
const ACCENT     := Color("4d8bff")
const ACCENT_HI  := Color("8ab6ff")
const ACCENT_LO  := Color("2a63d6")
const CYAN       := Color("4ff0df")
const CYAN_LO    := Color("1a9c93")
const WARN       := Color("ffc861")
const DANGER     := Color("ff7583")
const OK         := Color("68eaa6")

const FONT_DIR := "res://assets/fonts/"

var theme: Theme
# 中文字体（思源黑体 多字重，静态实例 —— 之前用的是可变字体的 wght=100 超细默认实例，所以又细又糊）
var font_ui: FontFile
var font_ui_bold: FontFile
# 拉丁显示字体（Oxanium，用于标题与 Logo，中文自动回退思源黑体）
var font_display: FontFile
var font_display_mid: FontFile
# 等宽数字（JetBrains Mono，HUD 读数不会左右抖动）
var font_mono: FontFile
# 兼容旧引用
var font_base: FontFile

func _ready() -> void:
	_load_fonts()
	theme = _build_theme()

func _try_load(fname: String) -> FontFile:
	var p := FONT_DIR + fname
	if ResourceLoader.exists(p):
		return load(p) as FontFile
	push_warning("missing font: " + p)
	return null

func _load_fonts() -> void:
	font_ui = _try_load("NotoSansSC-Medium.ttf")
	if font_ui == null:
		font_ui = _try_load("NotoSansSC-Regular.ttf")
	font_ui_bold = _try_load("NotoSansSC-Bold.ttf")
	if font_ui_bold == null:
		font_ui_bold = font_ui
	font_display = _try_load("Oxanium-Bold.ttf")
	font_display_mid = _try_load("Oxanium-SemiBold.ttf")
	font_mono = _try_load("JetBrainsMono-Medium.ttf")
	if font_display == null:
		font_display = font_ui
	if font_display_mid == null:
		font_display_mid = font_display
	if font_mono == null:
		font_mono = font_ui
	# 拉丁字体不含汉字：挂上中文回退，否则中英混排会掉字
	if font_display != null and font_ui_bold != null:
		var fb1: Array[Font] = [font_ui_bold]
		font_display.fallbacks = fb1
	if font_display_mid != null and font_ui != null:
		var fb2: Array[Font] = [font_ui]
		font_display_mid.fallbacks = fb2
	if font_mono != null and font_ui != null:
		var fb3: Array[Font] = [font_ui]
		font_mono.fallbacks = fb3
	font_base = font_ui

func _build_theme() -> Theme:
	var th := Theme.new()
	if font_ui:
		th.default_font = font_ui
	th.default_font_size = 18
	return th

# ── 字体工具 ──────────────────────────────────────────────
## 显示字体变体（标题 / Logo）：拉丁 Oxanium，中文回退思源黑体 Bold
func spaced_font(spacing: int = 6, embolden: float = 0.0) -> FontVariation:
	var fv := FontVariation.new()
	fv.base_font = font_display if font_display else font_ui
	fv.spacing_glyph = spacing
	fv.variation_embolden = embolden
	return fv

## 数值字体变体：等宽数字，读数宽度恒定
func number_font(spacing: int = 1, embolden: float = 0.0) -> FontVariation:
	var fv := FontVariation.new()
	fv.base_font = font_mono if font_mono else font_ui
	fv.spacing_glyph = spacing
	fv.variation_embolden = embolden
	return fv

## 正文字体变体（按钮 / 小标题用，中文不掉字）
func ui_font(spacing: int = 0, bold: bool = false) -> FontVariation:
	var fv := FontVariation.new()
	fv.base_font = font_ui_bold if (bold and font_ui_bold) else font_ui
	if spacing != 0:
		fv.spacing_glyph = spacing
	return fv

# ── 样式积木 ──────────────────────────────────────────────
func _sb(bg: Color, border: Color = Color(0, 0, 0, 0), radius: int = 14,
		bw: int = 0, pad_h: int = 0, pad_v: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	if bw > 0:
		sb.border_color = border
		sb.set_border_width_all(bw)
	if pad_h > 0:
		sb.content_margin_left = pad_h
		sb.content_margin_right = pad_h
	if pad_v > 0:
		sb.content_margin_top = pad_v
		sb.content_margin_bottom = pad_v
	sb.anti_aliasing = true
	return sb

## 顶部高光：叠一层极淡的白到透明的竖向渐变，制造玻璃质感
func _gloss(ctrl: Control, radius: int, strength: float = 0.055, height_ratio: float = 0.55) -> void:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, strength))
	g.set_color(1, Color(1, 1, 1, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	gt.width = 4
	gt.height = 64
	var r := TextureRect.new()
	r.texture = gt
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.anchor_bottom = height_ratio
	ctrl.add_child(r)

## 左侧强调条
func _accent_bar(ctrl: Control, color: Color, w: int = 3) -> void:
	var bar := ColorRect.new()
	bar.color = color
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	bar.offset_right = w
	bar.offset_top = 10
	bar.offset_bottom = -10
	ctrl.add_child(bar)

# ── 自绘工具 ──────────────────────────────────────────────
## 圆角矩形（供自绘控件复用）
static func rounded(c: CanvasItem, r: Rect2, radius: int, bg: Color,
		border: Color = Color(0, 0, 0, 0), bw: int = 0) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(maxi(0, radius))
	if bw > 0:
		sb.border_color = border
		sb.set_border_width_all(bw)
	sb.draw(c.get_canvas_item(), r)

# ── 基础文本 ──────────────────────────────────────────────
func label(text: String, size: int = 18, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if font_base:
		l.add_theme_font_override("font", font_base)
	return l

func title(text: String, size: int = 32, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", spaced_font(3, 0.02))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

## 带发光的主标题（用于 Logo）
func glow_title(text: String, size: int = 60, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", spaced_font(4, 0.02))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0.26, 0.58, 1.0, 0.34))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_constant_override("shadow_outline_size", 4)
	return l

## 数字读数（大号数字 + 小号单位）
func stat_value(value: String, unit: String, size: int = 26,
		vc: Color = TEXT, uc: Color = TEXT_MUTE) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 5)
	var v := label(value, size, vc)
	v.add_theme_font_override("font", number_font(1))
	h.add_child(v)
	var u := label(unit, int(size * 0.5), uc)
	u.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	u.size_flags_vertical = Control.SIZE_SHRINK_END
	h.add_child(u)
	return h

# ── 按钮 ──────────────────────────────────────────────────
## 按钮：primary = 亮蓝底 + 纯白字（全站主操作，与主菜单「开始游戏」一致）
##       否则 = 深灰底 + 纯白字
func button(text: String, primary: bool = false, size: int = 20) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", ui_font(2, primary))
	b.add_theme_font_size_override("font_size", size)

	var bg: Color
	var fg: Color
	var edge: Color
	var r := 14
	if primary:
		bg = Color("3b82f6")
		fg = Color("ffffff")
		edge = Color("8ab6ff")
	else:
		bg = Color("232b3a")
		fg = Color.WHITE
		edge = Color("3d4a63")

	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_color_override("font_pressed_color", fg)
	b.add_theme_color_override("font_disabled_color", Color("9aa8c0"))
	b.add_theme_stylebox_override("normal", _sb(bg, edge, r, 1, 26, 14))
	b.add_theme_stylebox_override("hover", _sb(bg.lightened(0.14), edge.lightened(0.2), r, 1, 26, 14))
	b.add_theme_stylebox_override("pressed", _sb(bg.darkened(0.16), edge, r, 1, 26, 14))
	b.add_theme_stylebox_override("focus", _sb(bg, Color("7db0ff"), r, 2, 26, 14))
	b.add_theme_stylebox_override("disabled", _sb(Color("1a2130"), Color("2c3648"), r, 1, 26, 14))
	if primary:
		var sb := _sb(bg, edge, r, 1, 26, 14)
		sb.shadow_color = Color(0.23, 0.51, 0.96, 0.35)
		sb.shadow_size = 12
		sb.shadow_offset = Vector2(0, 3)
		b.add_theme_stylebox_override("normal", sb)
	_animate_lift(b)
	return b

## 次级按钮：统一深灰底 + 纯白字（与 menu_button level 2 同一套配色）
func ghost_button(text: String, size: int = 17) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", font_ui)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color("9aa8c0"))
	b.add_theme_stylebox_override("normal", _sb(Color("232b3a"), Color("3d4a63"), 12, 1, 20, 11))
	b.add_theme_stylebox_override("hover", _sb(Color("2f3a4e"), Color("5b719c"), 12, 1, 20, 11))
	b.add_theme_stylebox_override("pressed", _sb(Color("1a2130"), Color("7db0ff"), 12, 1, 20, 11))
	b.add_theme_stylebox_override("disabled", _sb(Color("151b28"), Color("29334a"), 12, 1, 20, 11))
	return b

## 菜单项：大按钮 + 左侧强调条 + 悬浮右移
func menu_item(text: String, primary: bool = false, size: int = 21) -> Button:
	var b := button(text, primary, size)
	b.custom_minimum_size = Vector2(0, 58)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_constant_override("icon_max_width", 0)
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb: StyleBoxFlat = b.get_theme_stylebox(st)
		if sb:
			sb.content_margin_left = 34
			sb.content_margin_right = 26
			sb.content_margin_top = 16
			sb.content_margin_bottom = 16
	if primary:
		_accent_bar(b, Color(1, 1, 1, 0.55), 3)
	else:
		_accent_bar(b, ACCENT, 3)
	return b

## 悬浮反馈：只改 modulate，绝不碰 position/size（容器内改 position 会与布局冲突成死循环）
func _animate_lift(b: Button) -> void:
	b.mouse_entered.connect(func():
		if not is_instance_valid(b):
			return
		var tw := b.create_tween()
		tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(b, "modulate", Color(1.15, 1.15, 1.15, 1.0), 0.13)
	)
	b.mouse_exited.connect(func():
		if not is_instance_valid(b):
			return
		var tw := b.create_tween()
		tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(b, "modulate", Color.WHITE, 0.13)
	)

## 圆形图标按钮（用于飞行控制）
func round_button(text: String, diameter: int = 66, size: int = 22,
		accent: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(diameter, diameter)
	b.add_theme_font_override("font", number_font(0))
	b.add_theme_font_size_override("font_size", size)
	var c := ACCENT if accent else PANEL_HI
	var e := ACCENT_HI if accent else STROKE_HI
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", INK)
	var r := int(diameter * 0.5)
	b.add_theme_stylebox_override("normal", _sb(c, e, r, 1))
	b.add_theme_stylebox_override("hover", _sb(c.lightened(0.16), e.lightened(0.2), r, 1))
	b.add_theme_stylebox_override("pressed", _sb(CYAN, CYAN, r, 1))
	b.add_theme_stylebox_override("disabled", _sb(PANEL_LO, STROKE, r, 1))
	_gloss(b, r, 0.09, 0.55)
	return b

# ── 菜单按钮（统一规格 + 三级对比度） ──────────────────────
const IconButtonScript := preload("res://src/ui/widgets/UiIconButton.gd")

const MENU_H := 62          # 所有菜单按钮统一高度
const MENU_W := 420         # 主按钮统一宽度
const MENU_R := 16          # 统一圆角

## 统一规格的菜单按钮：左侧矢量图标 + 居中文字
## level 0 = 亮蓝底 + 纯白字 + 辉光（最高视觉优先级）
## level 1 = 深蓝底 + 纯白字（次优先）
## level 2 = 深灰底 + 纯白字（常规操作）
func menu_button(text: String, icon: String, level: int = 2,
		width: int = MENU_W, height: int = MENU_H, radius: int = MENU_R) -> Button:
	var b: UiIconButton = IconButtonScript.new()
	b.text = text
	b.icon_kind = icon
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(width, height)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.clip_text = true
	b.add_theme_font_override("font", ui_font(0, level == 0))
	b.add_theme_font_size_override("font_size", 21 if level == 0 else 19)

	# 三级明度递减：亮蓝 > 深蓝 > 深灰，全部配纯白字保证对比度
	var bg: Color
	var fg: Color
	var edge: Color
	match level:
		0:
			bg = Color("3b82f6")
			fg = Color("ffffff")
			edge = Color("8ab6ff")
		1:
			bg = Color("1e4fa8")
			fg = Color("ffffff")
			edge = Color("3d6fd0")
		_:
			bg = Color("232b3a")
			fg = Color("ffffff")
			edge = Color("3d4a63")

	b.icon_tint = fg
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_color_override("font_pressed_color", fg)
	b.add_theme_stylebox_override("normal", _sb(bg, edge, radius, 1, 18, 14))
	b.add_theme_stylebox_override("hover", _sb(bg.lightened(0.14), edge.lightened(0.3), radius, 1, 18, 14))
	b.add_theme_stylebox_override("pressed", _sb(bg.darkened(0.16), edge, radius, 1, 18, 14))
	# 不可用状态统一为「深灰底 + 灰字」，任何层级都不会变成隐形按钮
	b.add_theme_stylebox_override("disabled", _sb(Color("1a2130"), Color("2c3648"), radius, 1, 18, 14))
	b.add_theme_color_override("font_disabled_color", Color("9aa8c0"))
	b.add_theme_stylebox_override("focus", _sb(bg, edge, radius, 2, 18, 14))
	# 最高优先级按钮加一层外发光，和次级拉开差距
	if level == 0:
		var sb0 := _sb(bg, edge, radius, 1, 18, 14)
		sb0.shadow_color = Color(0.23, 0.51, 0.96, 0.42)
		sb0.shadow_size = 16
		sb0.shadow_offset = Vector2(0, 4)
		b.add_theme_stylebox_override("normal", sb0)
	_animate_lift(b)
	return b

# ── 容器 ──────────────────────────────────────────────────
func panel(bg: Color = PANEL, radius: int = 18, border: bool = true,
		pad: int = 18) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := _sb(bg, STROKE if border else Color(0, 0, 0, 0), radius, 1 if border else 0)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = int(pad * 0.9)
	sb.content_margin_bottom = int(pad * 0.9)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 14
	sb.shadow_offset = Vector2(0, 5)
	p.add_theme_stylebox_override("panel", sb)
	return p

## 玻璃面板（半透明，用于 HUD 覆盖层）
func glass(alpha: float = 0.62, radius: int = 16, pad: int = 16) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := _sb(Color(0.05, 0.08, 0.15, alpha), Color(0.45, 0.62, 1.0, 0.20), radius, 1)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = int(pad * 0.85)
	sb.content_margin_bottom = int(pad * 0.85)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 10
	p.add_theme_stylebox_override("panel", sb)
	return p

func hsep(h: int = 12) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

## 给 ScrollContainer 套上深色主题滚动条（默认滚动条在深底上极其突兀）
func themed_scroll(scroll: ScrollContainer) -> ScrollContainer:
	scroll.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var vbar := scroll.get_v_scroll_bar()
	if vbar:
		vbar.add_theme_stylebox_override("scroll", _sb(Color(1, 1, 1, 0.05), Color(0, 0, 0, 0), 4))
		vbar.add_theme_stylebox_override("grabber", _sb(Color(0.42, 0.58, 0.9, 0.55), Color(0, 0, 0, 0), 4))
		vbar.add_theme_stylebox_override("grabber_highlight", _sb(Color(0.55, 0.72, 1.0, 0.85), Color(0, 0, 0, 0), 4))
		vbar.add_theme_stylebox_override("grabber_pressed", _sb(Color(0.62, 0.80, 1.0, 0.95), Color(0, 0, 0, 0), 4))
		vbar.custom_minimum_size = Vector2(8, 0)
	var hbar := scroll.get_h_scroll_bar()
	if hbar:
		hbar.add_theme_stylebox_override("scroll", _sb(Color(1, 1, 1, 0.05), Color(0, 0, 0, 0), 4))
		hbar.add_theme_stylebox_override("grabber", _sb(Color(0.42, 0.58, 0.9, 0.55), Color(0, 0, 0, 0), 4))
		hbar.add_theme_stylebox_override("grabber_highlight", _sb(Color(0.55, 0.72, 1.0, 0.85), Color(0, 0, 0, 0), 4))
		hbar.custom_minimum_size = Vector2(0, 8)
	return scroll

func divider(alpha: float = 0.6) -> Control:
	var c := ColorRect.new()
	c.color = Color(STROKE.r, STROKE.g, STROKE.b, alpha)
	c.custom_minimum_size = Vector2(0, 1)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

## 短装饰线（渐隐）
func accent_rule(width: int = 110, height: int = 3, col: Color = ACCENT) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(width, height)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var g := Gradient.new()
	g.set_color(0, col)
	g.set_color(1, Color(col.r, col.g, col.b, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0.5)
	gt.fill_to = Vector2(1, 0.5)
	gt.width = 128
	gt.height = 8
	var r := TextureRect.new()
	r.texture = gt
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(r)
	return holder

# ── 输入控件 ──────────────────────────────────────────────
func slider(value: float, minv: float, maxv: float, step: float = 0.01) -> UiSlider:
	var s := UiSlider.new()
	s.setup(value, minv, maxv, step)
	return s

func toggle(on: bool) -> UiToggle:
	var t := UiToggle.new()
	t.setup(on)
	return t

func option(items: Array, index: int) -> OptionButton:
	var o := OptionButton.new()
	o.focus_mode = Control.FOCUS_NONE
	for i in items.size():
		o.add_item(str(items[i]), i)
	o.selected = clampi(index, 0, max(0, items.size() - 1))
	o.add_theme_font_override("font", font_base)
	o.add_theme_font_size_override("font_size", 19)
	o.custom_minimum_size = Vector2(220, 46)
	o.add_theme_color_override("font_color", TEXT)
	o.add_theme_color_override("font_hover_color", Color.WHITE)
	o.add_theme_color_override("font_pressed_color", Color.WHITE)
	o.add_theme_stylebox_override("normal", _sb(PANEL_HI, STROKE, 12, 1, 20, 11))
	o.add_theme_stylebox_override("hover", _sb(PANEL_HI.lightened(0.10), STROKE_HI, 12, 1, 20, 11))
	o.add_theme_stylebox_override("pressed", _sb(ACCENT.darkened(0.2), ACCENT_HI, 12, 1, 20, 11))
	o.add_theme_stylebox_override("focus", _sb(PANEL_HI, ACCENT_HI, 12, 2, 20, 11))
	# 弹出列表也统一深色皮肤，否则是刺眼的默认灰
	var pop := o.get_popup()
	pop.add_theme_font_override("font", font_base)
	pop.add_theme_font_size_override("font_size", 18)
	pop.add_theme_stylebox_override("panel", _sb(PANEL, STROKE_HI, 12, 1, 6, 6))
	pop.add_theme_stylebox_override("hover", _sb(ACCENT, Color(0, 0, 0, 0), 8, 0, 10, 7))
	pop.add_theme_stylebox_override("separator", _sb(STROKE, Color(0, 0, 0, 0), 0, 0, 0, 1))
	pop.add_theme_color_override("font_color", TEXT)
	pop.add_theme_color_override("font_hover_color", Color.WHITE)
	pop.add_theme_constant_override("item_start_padding", 12)
	pop.add_theme_constant_override("item_end_padding", 12)
	pop.add_theme_constant_override("v_separation", 3)
	return o

func setting_row(text: String, control: Control, hint: String = "") -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 2)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(label(text, 18, TEXT))
	if hint != "":
		left.add_child(label(hint, 13, TEXT_MUTE))
	row.add_child(left)
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(control)
	return row
