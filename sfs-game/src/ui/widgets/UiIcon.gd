extends Control
class_name UiIcon
## UiIcon — 程序化矢量图标
## 全部用 draw_* 绘制，不依赖任何字体字形，因此在任何平台上都不会变成方块。

var kind := "":
	set(v):
		kind = v
		queue_redraw()
var tint := Color.WHITE:
	set(v):
		tint = v
		queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var c := size * 0.5
	var s := minf(size.x, size.y) / 24.0     # 以 24×24 为设计基准
	match kind:
		"play":
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-5.0, -8.0) * s,
				c + Vector2(-5.0, 8.0) * s,
				c + Vector2(9.0, 0.0) * s]), tint)
		"clock":
			draw_arc(c, 9.0 * s, 0.0, TAU, 32, tint, 2.2 * s)
			draw_line(c, c + Vector2(0.0, -5.5) * s, tint, 2.2 * s)
			draw_line(c, c + Vector2(4.5, 0.5) * s, tint, 2.2 * s)
		"folder":
			draw_rect(Rect2(c + Vector2(-9.0, -5.0) * s, Vector2(18.0, 12.0) * s), tint, false, 2.2 * s)
			draw_rect(Rect2(c + Vector2(-9.0, -8.5) * s, Vector2(8.5, 4.5) * s), tint, true)
		"gear":
			draw_arc(c, 4.6 * s, 0.0, TAU, 24, tint, 2.6 * s)
			for i in 8:
				var a := TAU * float(i) / 8.0
				var d := Vector2(cos(a), sin(a))
				draw_line(c + d * 6.2 * s, c + d * 9.2 * s, tint, 2.8 * s)
		"list":
			for i in 3:
				var y := c.y + (-6.0 + float(i) * 6.0) * s
				draw_circle(Vector2(c.x - 8.5 * s, y), 1.9 * s, tint)
				draw_line(Vector2(c.x - 3.5 * s, y), Vector2(c.x + 9.0 * s, y), tint, 2.2 * s)
		"info":
			draw_arc(c, 9.0 * s, 0.0, TAU, 32, tint, 2.2 * s)
			draw_circle(c + Vector2(0.0, -4.6) * s, 1.8 * s, tint)
			draw_line(c + Vector2(0.0, -1.0) * s, c + Vector2(0.0, 5.6) * s, tint, 2.6 * s)
		"exit":
			draw_rect(Rect2(c + Vector2(-9.0, -8.0) * s, Vector2(11.0, 16.0) * s), tint, false, 2.2 * s)
			draw_line(c, c + Vector2(9.5, 0.0) * s, tint, 2.2 * s)
			draw_polyline(PackedVector2Array([
				c + Vector2(5.0, -4.1) * s,
				c + Vector2(9.5, 0.0) * s,
				c + Vector2(5.0, 4.1) * s]), tint, 2.2 * s)
		"back":
			draw_line(c + Vector2(9.0, 0.0) * s, c + Vector2(-9.0, 0.0) * s, tint, 2.4 * s)
			draw_polyline(PackedVector2Array([
				c + Vector2(-3.0, -6.0) * s,
				c + Vector2(-9.5, 0.0) * s,
				c + Vector2(-3.0, 6.0) * s]), tint, 2.4 * s)
		"plus":
			draw_line(c + Vector2(-7.0, 0.0) * s, c + Vector2(7.0, 0.0) * s, tint, 2.4 * s)
			draw_line(c + Vector2(0.0, -7.0) * s, c + Vector2(0.0, 7.0) * s, tint, 2.4 * s)
		"trash":
			draw_line(c + Vector2(-7.0, -5.0) * s, c + Vector2(7.0, -5.0) * s, tint, 2.2 * s)
			draw_rect(Rect2(c + Vector2(-5.5, -5.0) * s, Vector2(11.0, 13.0) * s), tint, false, 2.2 * s)
			draw_line(c + Vector2(-2.5, -8.0) * s, c + Vector2(2.5, -8.0) * s, tint, 2.2 * s)
		"rocket":
			draw_polyline(PackedVector2Array([
				c + Vector2(0.0, -9.0) * s,
				c + Vector2(4.0, -1.0) * s,
				c + Vector2(4.0, 6.0) * s,
				c + Vector2(-4.0, 6.0) * s,
				c + Vector2(-4.0, -1.0) * s,
				c + Vector2(0.0, -9.0) * s]), tint, 2.2 * s)
			draw_line(c + Vector2(0.0, 6.0) * s, c + Vector2(0.0, 9.5) * s, tint, 2.2 * s)
		"map":
			draw_rect(Rect2(c + Vector2(-9.0, -7.0) * s, Vector2(18.0, 14.0) * s), tint, false, 2.2 * s)
			draw_circle(c, 3.2 * s, tint)
		"save":
			draw_rect(Rect2(c + Vector2(-8.0, -8.0) * s, Vector2(16.0, 16.0) * s), tint, false, 2.2 * s)
			draw_rect(Rect2(c + Vector2(-4.0, -8.0) * s, Vector2(8.0, 6.0) * s), tint, true)
			draw_rect(Rect2(c + Vector2(-5.0, 2.0) * s, Vector2(10.0, 6.0) * s), tint, true)
		"globe":
			draw_arc(c, 9.0 * s, 0.0, TAU, 32, tint, 2.2 * s)
			draw_arc(c, 9.0 * s, -PI * 0.5, PI * 0.5, 16, tint, 2.2 * s)
			draw_line(c + Vector2(-8.5, 0.0) * s, c + Vector2(8.5, 0.0) * s, tint, 2.2 * s)
