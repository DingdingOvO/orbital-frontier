extends Control
class_name UiSegmented
## UiSegmented — 分段切换控件（语言切换 / 视图切换）
## 选中态用一块会滑动的亮块表示，切换时带缓动，而不是硬切颜色。

signal changed(index: int)

const PAD := 4.0
const SEG_W := 58.0
const H := 48.0

var items: Array = []
var index := 0
var _hl := 0.0          # 当前高亮块的中心位置
var _hover := -1
var _down := -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(PAD * 2.0 + SEG_W * 3.0, H)

func setup(names: Array, active: int) -> void:
	items = names.duplicate()
	index = clampi(active, 0, maxi(0, items.size() - 1))
	custom_minimum_size = Vector2(PAD * 2.0 + SEG_W * float(maxi(1, items.size())), H)
	_hl = _target_pos(index)
	queue_redraw()

func set_index(i: int, animated: bool = true) -> void:
	if i == index:
		return
	index = clampi(i, 0, maxi(0, items.size() - 1))
	if animated:
		var tw := create_tween()
		tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.tween_method(_set_hl, _hl, _target_pos(index), 0.24)
	else:
		_hl = _target_pos(index)
	queue_redraw()

func _set_hl(v: float) -> void:
	_hl = v
	queue_redraw()

func _target_pos(i: int) -> float:
	return PAD + SEG_W * (float(i) + 0.5)

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_down = _index_at(e.position)
			queue_redraw()
		else:
			var i := _index_at(e.position)
			if i >= 0 and i == _down and i != index:
				set_index(i)
				changed.emit(i)
				UiKit.haptic(6)
			_down = -1
			queue_redraw()
	elif e is InputEventMouseMotion:
		var h := _index_at(e.position)
		if h != _hover:
			_hover = h
			queue_redraw()

func _index_at(p: Vector2) -> int:
	if p.x < PAD or p.x > size.x - PAD or p.y < 0.0 or p.y > size.y:
		return -1
	if items.is_empty():
		return -1
	var i := int((p.x - PAD) / SEG_W)
	return clampi(i, 0, items.size() - 1)

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hover = -1
		queue_redraw()

func _draw() -> void:
	var h := size.y
	var seg_h := h - PAD * 2.0
	# 外壳
	UiKit.rounded(self, Rect2(0, 0, size.x, h), int(h * 0.5),
		Color(0.055, 0.086, 0.150, 0.94), Color(0.30, 0.43, 0.68, 0.55), 1)
	# 悬停 / 按下的淡色块
	if _hover >= 0 and _hover != index:
		var hx := PAD + SEG_W * float(_hover)
		UiKit.rounded(self, Rect2(hx, PAD, SEG_W, seg_h), int(seg_h * 0.5),
			Color(1, 1, 1, 0.06), Color(0, 0, 0, 0), 0)
	# 选中滑块
	var x := _hl - SEG_W * 0.5
	UiKit.rounded(self, Rect2(x, PAD, SEG_W, seg_h), int(seg_h * 0.5),
		Color("3b82f6"), Color("8ab6ff"), 1)
	var f: Font = UiKit.font_ui_bold if UiKit.font_ui_bold else ThemeDB.fallback_font
	for i in items.size():
		var cx := PAD + SEG_W * (float(i) + 0.5)
		var txt := str(items[i])
		var fs := 16
		var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var col := Color.WHITE if i == index else Color(0.72, 0.80, 0.93, 0.9)
		draw_string(f, Vector2(cx - w * 0.5, h * 0.5 + fs * 0.36), txt,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
