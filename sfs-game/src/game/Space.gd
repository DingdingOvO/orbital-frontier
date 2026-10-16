extends RefCounted
class_name Space
## 星体与轨道力学工具（SI 单位：m / s / kg）
## 数值取自公开天文常数，非任何游戏数据。

const G0 := 9.80665   # 标准重力加速度（比冲换算用）

const BODIES := {
	"earth": {
		"name_key": "planet.earth",
		"mu": 3.986004418e14,      # 引力常数
		"radius": 6371000.0,       # 平均半径
		"atmo_h": 70000.0,         # 大气顶
		"rho0": 1.225,             # 海平面密度
		"scale_h": 8500.0,         # 大气标高
		"soi": 9.24e8,             # 影响球半径
		"color": Color("2b6fd6"),
		"color2": Color("14386f"),
		"atmo_color": Color(0.35, 0.62, 1.0, 0.22),
		"land_color": Color("3f7a4a"),
		"pos": Vector2.ZERO,
	},
	"moon": {
		"name_key": "planet.moon",
		"mu": 4.9048695e12,
		"radius": 1737000.0,
		"atmo_h": 0.0,
		"rho0": 0.0,
		"scale_h": 1000.0,
		"soi": 6.6e7,
		"color": Color("b9bec9"),
		"color2": Color("6f7683"),
		"atmo_color": Color(0, 0, 0, 0),
		"land_color": Color("8a8f9a"),
		"pos": Vector2(3.844e8, 0.0),   # 地月平均距离
		"parent": "earth",
		"orbit_radius": 3.844e8,
		"orbit_period": 2360591.0,
	},
	"mars": {
		"name_key": "planet.mars",
		"mu": 4.282837e13,
		"radius": 3389500.0,
		"atmo_h": 60000.0,
		"rho0": 0.020,
		"scale_h": 11100.0,
		"soi": 5.77e8,
		"color": Color("c1552f"),
		"color2": Color("6d2b16"),
		"atmo_color": Color(0.85, 0.45, 0.3, 0.16),
		"land_color": Color("a04a28"),
		"pos": Vector2(2.25e11, 0.0),
	},
}

static func body(id: String) -> Dictionary:
	return BODIES.get(id, BODIES["earth"])

static func mu(id: String) -> float:
	return float(body(id).get("mu", 3.986004418e14))

static func radius(id: String) -> float:
	return float(body(id).get("radius", 6371000.0))

## 重力加速度矢量（位置相对行星中心）
static func gravity(id: String, rel_pos: Vector2) -> Vector2:
	var r := rel_pos.length()
	if r < 1.0:
		return Vector2.ZERO
	var m := mu(id)
	return -rel_pos.normalized() * (m / (r * r))

## 大气密度（指数模型）
static func density(id: String, altitude: float) -> float:
	var b := body(id)
	var h: float = float(b.get("atmo_h", 0.0))
	if h <= 0.0 or altitude >= h:
		return 0.0
	var rho0: float = float(b.get("rho0", 0.0))
	var sh: float = float(b.get("scale_h", 8500.0))
	return rho0 * exp(-max(0.0, altitude) / sh)

## 圆轨道速度
static func circular_speed(id: String, r: float) -> float:
	if r <= 0.0:
		return 0.0
	return sqrt(mu(id) / r)

## 由状态矢量求轨道根数（返回 a, e, apoapsis, periapsis；双曲线时 apoapsis = INF）
static func orbital_elements(id: String, rel_pos: Vector2, rel_vel: Vector2) -> Dictionary:
	var m := mu(id)
	var r := rel_pos.length()
	var v := rel_vel.length()
	if r < 1.0 or m <= 0.0:
		return {"a": 0.0, "e": 0.0, "apo": 0.0, "peri": 0.0, "hyper": false, "period": 0.0}
	var energy := 0.5 * v * v - m / r
	var a := -m / (2.0 * energy) if absf(energy) > 1e-12 else INF
	# 偏心率矢量
	var rv := rel_pos.dot(rel_vel)
	var e_vec := (rel_pos * (v * v - m / r) - rel_vel * rv) / m
	var e := e_vec.length()
	var apo := a * (1.0 + e)
	var peri := a * (1.0 - e)
	var hyper := energy >= 0.0
	var period := 0.0
	if not hyper and a > 0.0:
		period = TAU * sqrt(pow(a, 3.0) / m)
	return {"a": a, "e": e, "apo": apo, "peri": max(0.0, peri), "hyper": hyper, "period": period}

## 真近点角 → 轨道上的位置（相对行星中心的惯性系）
static func position_at_true_anomaly(id: String, rel_pos: Vector2, rel_vel: Vector2, nu: float) -> Vector2:
	var el := orbital_elements(id, rel_pos, rel_vel)
	var a: float = el["a"]
	var e: float = el["e"]
	if not is_finite(a) or a <= 0.0:
		return rel_pos
	var p := a * (1.0 - e * e)
	var r := p / (1.0 + e * cos(nu))
	# 构建轨道平面基向量（用当前状态确定）
	var h := rel_pos.cross(rel_vel)
	var rhat := rel_pos.normalized()
	var that := Vector2(-rhat.y, rhat.x)
	var omega := atan2(rel_pos.y, rel_pos.x)  # 简化：以当前径向为参考
	var ang := omega + nu - _current_true_anomaly(id, rel_pos, rel_vel)
	return rhat.rotated(ang - 0.0) * r  # 近似绘制用

static func _current_true_anomaly(id: String, rel_pos: Vector2, rel_vel: Vector2) -> float:
	var el := orbital_elements(id, rel_pos, rel_vel)
	var e: float = el["e"]
	var r := rel_pos.length()
	var a: float = el["a"]
	if not is_finite(a) or a <= 0.0 or e < 1e-9:
		return 0.0
	var cosnu := (a * (1.0 - e * e) / r - 1.0) / e
	return acos(clampf(cosnu, -1.0, 1.0))

## 由当前状态矢量解析采样一整圈闭合轨道，返回世界坐标点阵（比数值积分准得多）
static func sample_orbit(id: String, rel_pos: Vector2, rel_vel: Vector2, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var m := mu(id)
	var r := rel_pos.length()
	if r < 1.0 or m <= 0.0 or n < 3:
		return pts
	var el := orbital_elements(id, rel_pos, rel_vel)
	var a: float = el["a"]
	var e: float = el["e"]
	if not is_finite(a) or a <= 0.0 or e >= 1.0 or e < 0.0:
		return pts
	var p := a * (1.0 - e * e)
	if p <= 0.0 or not is_finite(p):
		return pts
	# 近地点方向直接由偏心率矢量给出（比反推真近点角稳健）
	var rv := rel_pos.dot(rel_vel)
	var e_vec := (rel_pos * (rel_vel.length_squared() - m / r) - rel_vel * rv) / m
	var omega := 0.0
	if e_vec.length() > 1e-9:
		omega = atan2(e_vec.y, e_vec.x)
	else:
		omega = atan2(rel_pos.y, rel_pos.x)
	for i in n + 1:
		var nu := TAU * float(i) / float(n)
		var rr := p / (1.0 + e * cos(nu))
		if rr <= 0.0 or rr > 1.0e10 or not is_finite(rr):
			continue
		pts.append(Vector2(cos(nu + omega), sin(nu + omega)) * rr)
	return pts

## 用简单的前向积分预测轨迹（用于尚未入轨的弹道），返回 Vector2 数组（相对行星中心）
static func predict_trajectory(id: String, rel_pos: Vector2, rel_vel: Vector2, steps: int, dt: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var p := rel_pos
	var v := rel_vel
	for i in steps:
		var g := gravity(id, p)
		v += g * dt
		p += v * dt
		if i % 2 == 0:
			pts.append(p)
		if p.length() < radius(id):
			pts.append(p)
			break
	return pts
