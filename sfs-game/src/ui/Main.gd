extends Control
## Main — 应用根节点：主题、页面路由、转场动画、安全区。
## 转场：前进右滑入 / 返回左滑入，配合缩放与淡入，避免界面"硬切"。

const StarfieldBg := preload("res://src/game/StarfieldBg.gd")
const MenuPage      := preload("res://src/ui/pages/MenuPage.gd")
const SettingsPage  := preload("res://src/ui/pages/SettingsPage.gd")
const ModsPage      := preload("res://src/ui/pages/ModsPage.gd")
const AboutPage     := preload("res://src/ui/pages/AboutPage.gd")
const SavePage      := preload("res://src/ui/pages/SavePage.gd")
const WorkshopPage  := preload("res://src/game/WorkshopPage.gd")
const FlightPage    := preload("res://src/game/FlightPage.gd")

const TRANS_OUT := 0.13
const TRANS_IN  := 0.30

var _pages: Dictionary = {}
var _current: String = ""

var _bg_layer: Control
var _page_root: Control
var _busy := false
var _gen := 0
var _booted := false
var _page_tweens: Dictionary = {}

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UiKit.theme

	_bg_layer = StarfieldBg.new()
	add_child(_bg_layer)

	_page_root = Control.new()
	_page_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_page_root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_page_root)

	_register_pages()
	_apply_safe_area()
	resized.connect(_apply_safe_area)
	Loc.locale_changed.connect(_on_locale)

	var start_page := "menu"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--page="):
			start_page = a.substr(7)
	show_page(start_page)

	var skip_boot := false
	for a in OS.get_cmdline_user_args():
		if a == "--skip-intro":
			skip_boot = true
	if not skip_boot:
		_play_boot()


func _register_pages() -> void:
	_add_page("menu", MenuPage)
	_add_page("settings", SettingsPage)
	_add_page("mods", ModsPage)
	_add_page("about", AboutPage)
	_add_page("saves", SavePage)
	_add_page("workshop", WorkshopPage)
	_add_page("flight", FlightPage)

func _add_page(id: String, script: GDScript) -> void:
	var p: Control = script.new()
	p.name = "Page_" + id
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	p.visible = false
	p.modulate = Color(1, 1, 1, 0)
	if p.has_method("set_nav"):
		p.set_nav(self)
	_page_root.add_child(p)
	_pages[id] = p

## 前进 / 返回方向：返回菜单或从飞行回工坊视为"后退"
func _direction_for(id: String) -> int:
	if _current == "":
		return 0
	if id == "menu":
		return -1
	if _current == "flight" and id == "workshop":
		return -1
	if id == "saves" or id == "settings" or id == "mods" or id == "about":
		return 1
	return 1

func show_page(id: String, payload: Dictionary = {}) -> void:
	if not _pages.has(id):
		push_warning("unknown page: " + id)
		return
	if _busy:
		# 转场过程中再次点按：直接把上一次转场收尾，避免叠帧
		_finish_transition()
	if _current == id:
		var same = _pages[id]
		if same.has_method("on_enter"):
			same.on_enter(payload)
		return

	var dir := _direction_for(id)
	var old: Control = _pages.get(_current, null) as Control
	var p: Control = _pages[id] as Control

	_current = id
	if old != null:
		if old.has_method("on_exit"):
			old.on_exit()
	if dir == 0:
		p.visible = true
		p.modulate = Color.WHITE
		p.position = Vector2.ZERO
		p.scale = Vector2.ONE
		if p.has_method("on_enter"):
			p.on_enter(payload)
		return

	_busy = true
	_gen += 1
	var my_gen := _gen
	_page_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var w := size.x
	# 旧页：轻微缩小 + 向反方向退场
	if old != null:
		_kill_page_tween(old)
		old.pivot_offset = old.size * 0.5
		var tw := old.create_tween()
		_page_tweens[old] = tw
		tw.set_parallel(true)
		tw.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(old, "modulate", Color(1, 1, 1, 0), TRANS_OUT)
		tw.tween_property(old, "scale", Vector2(0.985, 0.985), TRANS_OUT)
		tw.tween_property(old, "position", Vector2(-w * 0.012 * dir, 0), TRANS_OUT)
		tw.chain().tween_callback(_hide_page.bind(old))

	# 新页：从侧面滑入（先等旧页退场一点点，形成层次）
	p.visible = true
	p.modulate = Color(1, 1, 1, 0)
	p.scale = Vector2(0.985, 0.985)
	p.position = Vector2(w * 0.035 * dir, 0)
	p.pivot_offset = p.size * 0.5
	if p.has_method("on_enter"):
		p.on_enter(payload)

	_kill_page_tween(p)
	var tw2 := p.create_tween()
	_page_tweens[p] = tw2
	tw2.set_parallel(true)
	tw2.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw2.tween_property(p, "modulate", Color.WHITE, TRANS_IN).set_delay(0.04)
	tw2.tween_property(p, "position", Vector2.ZERO, TRANS_IN + 0.04).set_delay(0.04)
	tw2.tween_property(p, "scale", Vector2.ONE, TRANS_IN + 0.04).set_delay(0.04)
	tw2.chain().tween_callback(_maybe_finish.bind(my_gen))

func _hide_page(p: Control) -> void:
	if is_instance_valid(p) and p != _pages.get(_current, null):
		p.visible = false

func _maybe_finish(gen: int) -> void:
	if gen == _gen:
		_finish_transition()

func _kill_page_tween(p: Control) -> void:
	if _page_tweens.has(p):
		var t: Tween = _page_tweens[p] as Tween
		if t and t.is_valid():
			t.kill()
		_page_tweens.erase(p)

func _finish_transition() -> void:
	_busy = false
	_page_root.mouse_filter = Control.MOUSE_FILTER_PASS
	for k in _pages.keys():
		var pg: Control = _pages[k] as Control
		if k == _current:
			pg.visible = true
			pg.modulate = Color.WHITE
			pg.position = Vector2.ZERO
			pg.scale = Vector2.ONE
		else:
			pg.visible = false
			pg.modulate = Color(1, 1, 1, 0)

func go_back() -> void:
	show_page("menu")

func _on_locale(_c: String) -> void:
	pass

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back_pressed()

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		_on_back_pressed()

func _on_back_pressed() -> void:
	match _current:
		"menu":
			pass
		"flight":
			show_page("workshop")
		_:
			go_back()

# ── 安全区：刘海 / 圆角 / 手势条 ─────────────────────────
## 只把「页面内容」内缩，星空背景仍然满屏，视觉上不会出现黑边
func _apply_safe_area() -> void:
	var l := 0.0
	var t := 0.0
	var r := 0.0
	var b := 0.0
	if OS.has_feature("mobile"):
		var safe := DisplayServer.get_display_safe_area()
		var scr := DisplayServer.screen_get_size()
		if scr.x > 0 and scr.y > 0 and safe.size.x > 0:
			l = clampf(float(safe.position.x) / float(scr.x), 0.0, 0.12)
			t = clampf(float(safe.position.y) / float(scr.y), 0.0, 0.12)
			r = clampf(1.0 - float(safe.position.x + safe.size.x) / float(scr.x), 0.0, 0.12)
			b = clampf(1.0 - float(safe.position.y + safe.size.y) / float(scr.y), 0.0, 0.12)
	if _page_root == null:
		return
	_page_root.offset_left = size.x * l
	_page_root.offset_top = size.y * t
	_page_root.offset_right = -size.x * r
	_page_root.offset_bottom = -size.y * b

# ── 启动动画 ─────────────────────────────────────────────
func _play_boot() -> void:
	var ov := Control.new()
	ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(ov)

	var bg := ColorRect.new()
	bg.color = Color("05080f")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.add_child(bg)

	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.add_child(cc)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 14)
	cc.add_child(col)

	var mark := Label.new()
	mark.text = "ORBITAL FRONTIER"
	mark.add_theme_font_override("font", UiKit.spaced_font(9, 0.03))
	mark.add_theme_font_size_override("font_size", 24)
	mark.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(mark)

	var bar_wrap := Control.new()
	bar_wrap.custom_minimum_size = Vector2(200, 3)
	bar_wrap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(bar_wrap)
	var track := ColorRect.new()
	track.color = Color(1, 1, 1, 0.10)
	track.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar_wrap.add_child(track)
	var fill := ColorRect.new()
	fill.color = UiKit.ACCENT
	fill.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	fill.offset_right = 0
	bar_wrap.add_child(fill)

	mark.modulate = Color(1, 1, 1, 0)
	bar_wrap.modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(mark, "modulate", Color.WHITE, 0.35)
	tw.tween_property(bar_wrap, "modulate", Color.WHITE, 0.3).set_delay(0.1)
	tw.tween_property(fill, "offset_right", 200.0, 0.55).set_delay(0.2) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.chain().tween_interval(0.18)
	tw.chain().tween_property(ov, "modulate", Color(1, 1, 1, 0), 0.42) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.chain().tween_callback(func():
		ov.visible = false
		ov.queue_free())
	_booted = true

