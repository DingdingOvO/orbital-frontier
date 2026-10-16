extends Control
class_name UiSlider
## UiSlider — 自绘滑杆（深色主题适配 + 触摸友好）
## 替换 Godot 默认 HSlider：默认皮肤在深色背景上几乎是隐形的

signal value_changed(v: float)

var min_value := 0.0
var max_value := 1.0
var step := 0.01
var value := 0.0

var _dragging := false
var _focus := false

const KNOB := 24.0
const TRACK := 8.0
const HEIGHT := 36.0

func _ready() -> void:
	custom_minimum_size = Vector2(250, HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE

func setup(v: float, mn: float, mx: float, st: float = 0.01) -> void:
	min_value = mn
	max_value = mx
	step = st
	value = clampf(v, mn, mx)
	queue_redraw()

func set_value(v: float) -> void:
	value = clampf(v, min_value, max_value)
	queue_redraw()

func _ratio() -> float:
	if max_value <= min_value:
		return 0.0
	return clampf((value - min_value) / (max_value - min_value), 0.0, 1.0)

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_dragging = true
			_set_from_x(e.position.x)
		else:
			_dragging = false
			queue_redraw()
	elif e is InputEventMouseMotion and _dragging:
		_set_from_x(e.position.x)

func _set_from_x(x: float) -> void:
	var pad := KNOB * 0.5
	var span := maxf(1.0, size.x - KNOB)
	var t := clampf((x - pad) / span, 0.0, 1.0)
	var nv := min_value + (max_value - min_value) * t
	if step > 0.0:
		nv = roundf(nv / step) * step
	nv = clampf(nv, min_value, max_value)
	var changed := not is_equal_approx(nv, value)
	value = nv
	queue_redraw()
	if changed:
		value_changed.emit(value)

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		_focus = true
		queue_redraw()
	elif what == NOTIFICATION_MOUSE_EXIT:
		_focus = false
		queue_redraw()

func _draw() -> void:
	var cy := size.y * 0.5
	var pad := KNOB * 0.5
	var x0 := pad
	var x1 := size.x - pad
	var t := _ratio()
	var fx := x0 + (x1 - x0) * t

	# 轨道底色
	UiKit.rounded(self, Rect2(x0, cy - TRACK * 0.5, x1 - x0, TRACK), int(TRACK * 0.5), UiKit.PANEL_LO)
	# 已填充
	if fx > x0 + 0.5:
		UiKit.rounded(self, Rect2(x0, cy - TRACK * 0.5, fx - x0, TRACK), int(TRACK * 0.5), UiKit.ACCENT)
	# 把手光晕
	if _focus or _dragging:
		draw_circle(Vector2(fx, cy), KNOB * 0.5 + 5.0, Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, 0.22))
	# 把手
	var kr := KNOB * 0.5 if not (_focus or _dragging) else KNOB * 0.5 + 1.5
	draw_circle(Vector2(fx, cy), kr, Color.WHITE)
	draw_arc(Vector2(fx, cy), kr, 0.0, TAU, 40,
		UiKit.ACCENT_HI if (_focus or _dragging) else UiKit.STROKE_HI, 2.0)
