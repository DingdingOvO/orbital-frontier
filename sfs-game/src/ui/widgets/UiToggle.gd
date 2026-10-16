extends Control
class_name UiToggle
## UiToggle — 自绘开关（替换 Godot 默认 CheckButton，其默认皮肤在深色背景上极不协调）

signal toggled(on: bool)

var on := false
var _anim := 0.0
var _hover := false

const W := 64.0
const H := 34.0

func _ready() -> void:
	custom_minimum_size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	_anim = 1.0 if on else 0.0
	set_process(false)

func setup(v: bool) -> void:
	on = v
	_anim = 1.0 if v else 0.0
	queue_redraw()

func set_on(v: bool) -> void:
	if on == v:
		return
	on = v
	set_process(true)

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		on = not on
		toggled.emit(on)
		set_process(true)

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		_hover = true
		queue_redraw()
	elif what == NOTIFICATION_MOUSE_EXIT:
		_hover = false
		queue_redraw()

func _process(delta: float) -> void:
	var target := 1.0 if on else 0.0
	_anim = move_toward(_anim, target, delta * 7.0)
	queue_redraw()
	if is_equal_approx(_anim, target):
		set_process(false)

func _draw() -> void:
	var r := size.y * 0.5
	var off_col := UiKit.PANEL_LO if not _hover else UiKit.PANEL_LO.lightened(0.08)
	var bg := off_col.lerp(UiKit.ACCENT, _anim)
	var border := UiKit.STROKE_HI if _anim < 0.5 else UiKit.ACCENT_HI
	if _hover:
		border = border.lightened(0.15)
	UiKit.rounded(self, Rect2(0, 0, size.x, size.y), int(r), bg, border, 1)
	var kx := lerpf(r, size.x - r, _anim)
	draw_circle(Vector2(kx, r), r - 4.0, Color.WHITE)
