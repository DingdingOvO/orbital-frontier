extends Control
## StarfieldBg — 三层视差星空背景，缓慢漂移 + 闪烁。

var _bg_tex: GradientTexture2D
var _layers: Array = []      # [{speed, stars:[{x,y,r,a,ph,tw}]}]
var _t: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_make_bg()
	_reseed()
	resized.connect(_reseed)

func _make_bg() -> void:
	var g := Gradient.new()
	g.set_color(0, Color("0d1730"))
	g.set_color(1, Color("04060d"))
	g.add_point(0.45, Color("080e1e"))
	_bg_tex = GradientTexture2D.new()
	_bg_tex.gradient = g
	_bg_tex.fill_from = Vector2(0.5, 0.0)
	_bg_tex.fill_to = Vector2(0.5, 1.0)
	_bg_tex.width = 4
	_bg_tex.height = 256

func _reseed() -> void:
	var s := size
	if s.x < 4 or s.y < 4:
		s = Vector2(1280, 720)
	_layers = []
	var cfg := [
		{"speed": 6.0,  "count": 90, "rmin": 0.6, "rmax": 1.2, "amin": 0.25, "amax": 0.55},
		{"speed": 14.0, "count": 55, "rmin": 1.0, "rmax": 1.9, "amin": 0.4,  "amax": 0.8},
		{"speed": 26.0, "count": 22, "rmin": 1.6, "rmax": 2.8, "amin": 0.6,  "amax": 1.0},
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261011
	for c in cfg:
		var stars: Array = []
		for i in c.count:
			stars.append({
				"x": rng.randf_range(0, s.x),
				"y": rng.randf_range(0, s.y),
				"r": rng.randf_range(c.rmin, c.rmax),
				"a": rng.randf_range(c.amin, c.amax),
				"ph": rng.randf_range(0, TAU),
				"tw": rng.randf_range(0.6, 2.2),
			})
		_layers.append({"speed": c.speed, "stars": stars})

func _process(delta: float) -> void:
	_t += delta
	var w := size.x
	if w < 4:
		w = 1280
	for layer in _layers:
		var spd: float = layer.speed
		for s in layer.stars:
			s.x -= spd * delta
			if s.x < -4.0:
				s.x += w + 8.0
	queue_redraw()

func _draw() -> void:
	if _bg_tex:
		draw_texture_rect(_bg_tex, Rect2(Vector2.ZERO, size), false)
	# 一层柔和的深蓝光晕，营造大气感
	draw_circle(size * Vector2(0.78, 1.06), size.y * 0.75, Color(0.10, 0.22, 0.45, 0.18))
	for layer in _layers:
		for s in layer.stars:
			var tw: float = 0.7 + 0.3 * sin(_t * s.tw + s.ph)
			draw_circle(Vector2(s.x, s.y), s.r, Color(0.85, 0.92, 1.0, s.a * tw))
