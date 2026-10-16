extends Node
## Loc — 自研轻量本地化（简体中文 / 繁體中文 / English）
## 支持运行时即时切换，无需重启；提供 t("key") 与 t("key", {arg}) 占位符。

signal locale_changed(code: String)

const CODES := ["zh_CN", "zh_TW", "en"]

const NAMES := {
	"zh_CN": "简体中文",
	"zh_TW": "繁體中文",
	"en": "English",
}

const SHORT := {
	"zh_CN": "简",
	"zh_TW": "繁",
	"en": "EN",
}

var current: String = "zh_CN"

# key -> { zh_CN, zh_TW, en }
var D: Dictionary = {}

func _ready() -> void:
	_build()
	var saved: String = str(Cfg.get_value("language", ""))
	if saved != "" and CODES.has(saved):
		current = saved
	else:
		current = _detect()
		Cfg.set_value("language", current)

func _detect() -> String:
	var os_locale := OS.get_locale()          # e.g. zh_CN, zh_TW, en_US
	var l := os_locale.to_lower()
	if l.begins_with("zh"):
		if l.contains("tw") or l.contains("hk") or l.contains("hant"):
			return "zh_TW"
		return "zh_CN"
	if l.begins_with("en"):
		return "en"
	return "en"

func set_locale(code: String) -> void:
	if not CODES.has(code) or code == current:
		return
	current = code
	Cfg.set_value("language", code)
	locale_changed.emit(code)

func next_locale() -> void:
	var i := CODES.find(current)
	set_locale(CODES[(i + 1) % CODES.size()])

func t(key: String, args: Dictionary = {}) -> String:
	var entry = D.get(key, null)
	var s: String
	if entry == null:
		s = key
	else:
		s = str(entry.get(current, entry.get("en", key)))
	if not args.is_empty():
		for k in args.keys():
			s = s.replace("{" + str(k) + "}", str(args[k]))
	return s

func _build() -> void:
	D = {
		# ── 品牌 ─────────────────────────────────
		"app.title":        {"zh_CN": "星轨计划", "zh_TW": "星軌計劃", "en": "ORBITAL FRONTIER"},
		"app.logo":         {"zh_CN": "星轨计划", "zh_TW": "星軌計劃", "en": "ORBITAL FRONTIER"},
		"app.tagline":      {"zh_CN": "建造 · 发射 · 入轨 · 着陆", "zh_TW": "建造 · 發射 · 入軌 · 著陸", "en": "BUILD · LAUNCH · ORBIT · LAND"},
		"app.kicker":       {"zh_CN": "2D 轨道航天沙盒", "zh_TW": "2D 軌道航太沙盒", "en": "2D ORBITAL SANDBOX"},
		"app.subtitle":     {"zh_CN": "ORBITAL FRONTIER", "zh_TW": "ORBITAL FRONTIER", "en": "星轨计划"},
		"app.version":      {"zh_CN": "版本 {v}", "zh_TW": "版本 {v}", "en": "Version {v}"},

		# ── 主菜单 ───────────────────────────────
		"menu.start":       {"zh_CN": "开始", "zh_TW": "開始", "en": "START"},
		"menu.continue":    {"zh_CN": "继续", "zh_TW": "繼續", "en": "CONTINUE"},
		"menu.settings":    {"zh_CN": "设置", "zh_TW": "設定", "en": "SETTINGS"},
		"menu.mods":        {"zh_CN": "Mod", "zh_TW": "Mod", "en": "MODS"},
		"menu.about":       {"zh_CN": "关于", "zh_TW": "關於", "en": "ABOUT"},
		"menu.quit":        {"zh_CN": "退出", "zh_TW": "結束", "en": "QUIT"},
		"menu.sandbox":     {"zh_CN": "沙盒模式", "zh_TW": "沙盒模式", "en": "SANDBOX"},
		"menu.quicklaunch": {"zh_CN": "快速发射", "zh_TW": "快速發射", "en": "QUICK LAUNCH"},

		# ── 存档 ─────────────────────────────────
		"save.title":       {"zh_CN": "存档", "zh_TW": "存檔", "en": "SAVES"},
		"save.new":         {"zh_CN": "新建存档", "zh_TW": "新增存檔", "en": "New Save"},
		"save.empty":       {"zh_CN": "还没有存档，点下方新建一个", "zh_TW": "還沒有存檔，點下方新增一個", "en": "No saves yet — create one below"},
		"save.enter":       {"zh_CN": "进入", "zh_TW": "進入", "en": "Enter"},
		"save.delete":      {"zh_CN": "删除", "zh_TW": "刪除", "en": "Delete"},
		"save.stat.launch": {"zh_CN": "发射", "zh_TW": "發射", "en": "Launches"},
		"save.stat.orbit":  {"zh_CN": "入轨", "zh_TW": "入軌", "en": "Orbits"},
		"save.stat.land":   {"zh_CN": "着陆", "zh_TW": "著陸", "en": "Landings"},
		"save.stat.ach":    {"zh_CN": "成就", "zh_TW": "成就", "en": "Achievements"},
		"save.best_alt":    {"zh_CN": "最高高度", "zh_TW": "最高高度", "en": "Best Altitude"},
		"save.satellites":  {"zh_CN": "在轨卫星", "zh_TW": "在軌衛星", "en": "Satellites"},
		"save.default_name": {"zh_CN": "我的航天计划", "zh_TW": "我的航太計畫", "en": "My Space Program"},
		"save.created":     {"zh_CN": "创建于 {d}", "zh_TW": "建立於 {d}", "en": "Created {d}"},
		"save.confirm_del": {"zh_CN": "确定删除这个存档？", "zh_TW": "確定刪除此存檔？", "en": "Delete this save?"},

		# ── 通用 ─────────────────────────────────
		"common.back":      {"zh_CN": "返回", "zh_TW": "返回", "en": "BACK"},
		"common.ok":        {"zh_CN": "确定", "zh_TW": "確定", "en": "OK"},
		"common.cancel":    {"zh_CN": "取消", "zh_TW": "取消", "en": "CANCEL"},
		"common.close":     {"zh_CN": "关闭", "zh_TW": "關閉", "en": "CLOSE"},
		"common.on":        {"zh_CN": "开", "zh_TW": "開", "en": "ON"},
		"common.off":       {"zh_CN": "关", "zh_TW": "關", "en": "OFF"},
		"common.language":  {"zh_CN": "语言", "zh_TW": "語言", "en": "LANGUAGE"},
		"common.yes":       {"zh_CN": "是", "zh_TW": "是", "en": "YES"},
		"common.no":        {"zh_CN": "否", "zh_TW": "否", "en": "NO"},
		"common.empty":     {"zh_CN": "（空）", "zh_TW": "（空）", "en": "(empty)"},

		# ── 设置 ─────────────────────────────────
		"set.title":        {"zh_CN": "设置", "zh_TW": "設定", "en": "SETTINGS"},
		"set.audio":        {"zh_CN": "音频", "zh_TW": "音訊", "en": "Audio"},
		"set.sfx":          {"zh_CN": "音效", "zh_TW": "音效", "en": "Sound Effects"},
		"set.music":        {"zh_CN": "音乐", "zh_TW": "音樂", "en": "Music"},
		"set.graphics":     {"zh_CN": "画面", "zh_TW": "畫面", "en": "Graphics"},
		"set.quality":      {"zh_CN": "画质", "zh_TW": "畫質", "en": "Quality"},
		"set.q.low":        {"zh_CN": "低", "zh_TW": "低", "en": "Low"},
		"set.q.medium":     {"zh_CN": "中", "zh_TW": "中", "en": "Medium"},
		"set.q.high":       {"zh_CN": "高", "zh_TW": "高", "en": "High"},
		"set.gameplay":     {"zh_CN": "玩法", "zh_TW": "玩法", "en": "Gameplay"},
		"set.vibration":    {"zh_CN": "震动反馈", "zh_TW": "震動回饋", "en": "Vibration"},
		"set.units":        {"zh_CN": "单位制", "zh_TW": "單位制", "en": "Units"},
		"set.units.metric":{"zh_CN": "公制", "zh_TW": "公制", "en": "Metric"},
		"set.units.imperial":{"zh_CN": "英制", "zh_TW": "英制", "en": "Imperial"},
		"set.traj":         {"zh_CN": "显示预测轨道", "zh_TW": "顯示預測軌道", "en": "Show Predicted Trajectory"},
		"set.grid":         {"zh_CN": "显示建造网格", "zh_TW": "顯示建造網格", "en": "Show Builder Grid"},
		"set.warp":         {"zh_CN": "最大时间加速", "zh_TW": "最大時間加速", "en": "Max Time Warp"},
		"set.autosave":     {"zh_CN": "自动保存", "zh_TW": "自動保存", "en": "Auto Save"},
		"set.reset":        {"zh_CN": "恢复默认", "zh_TW": "恢復預設", "en": "Reset to Defaults"},
		"set.reset.done":   {"zh_CN": "已恢复默认设置", "zh_TW": "已恢復預設設定", "en": "Defaults restored"},

		# ── Mod ──────────────────────────────────
		"mod.title":        {"zh_CN": "Mod 管理", "zh_TW": "Mod 管理", "en": "Mod Manager"},
		"mod.installed":    {"zh_CN": "已安装", "zh_TW": "已安裝", "en": "Installed"},
		"mod.enabled":      {"zh_CN": "已启用", "zh_TW": "已啟用", "en": "Enabled"},
		"mod.disabled":     {"zh_CN": "已停用", "zh_TW": "已停用", "en": "Disabled"},
		"mod.import":       {"zh_CN": "导入 Mod 包 (.zip)", "zh_TW": "匯入 Mod 包 (.zip)", "en": "Import Mod (.zip)"},
		"mod.openfolder":   {"zh_CN": "打开 Mod 文件夹", "zh_TW": "開啟 Mod 資料夾", "en": "Open Mods Folder"},
		"mod.none":         {"zh_CN": "还没有安装任何 Mod", "zh_TW": "還沒有安裝任何 Mod", "en": "No mods installed yet"},
		"mod.hint":         {"zh_CN": "把 Mod 文件夹放入 mods 目录，或导入 .zip 包。", "zh_TW": "把 Mod 資料夾放入 mods 目錄，或匯入 .zip 包。", "en": "Drop a mod folder into the mods directory, or import a .zip."},
		"mod.path_copied":  {"zh_CN": "Mod 目录路径已复制到剪贴板：{p}", "zh_TW": "Mod 目錄路徑已複製到剪貼簿：{p}", "en": "Mods path copied to clipboard: {p}"},
		"mod.imported":     {"zh_CN": "已导入 {n} 个 Mod", "zh_TW": "已匯入 {n} 個 Mod", "en": "Imported {n} mod(s)"},
		"mod.failed":       {"zh_CN": "导入失败：{e}", "zh_TW": "匯入失敗：{e}", "en": "Import failed: {e}"},
		"mod.toggle":       {"zh_CN": "启用/停用", "zh_TW": "啟用/停用", "en": "Toggle"},
		"mod.remove":       {"zh_CN": "删除", "zh_TW": "刪除", "en": "Remove"},
		"mod.builtin":      {"zh_CN": "内置示例", "zh_TW": "內建範例", "en": "Bundled Sample"},

		# ── 关于 ─────────────────────────────────
		"about.title":      {"zh_CN": "关于", "zh_TW": "關於", "en": "ABOUT"},
		"about.desc":       {"zh_CN": "一款 2D 轨道航天沙盒：自由组装多级火箭，在真实引力场中发射、入轨、变轨与着陆。", "zh_TW": "一款 2D 軌道航太沙盒：自由組裝多級火箭，在真實引力場中發射、入軌、變軌與著陸。", "en": "A 2D orbital sandbox: assemble multi-stage rockets, then launch, orbit, transfer and land inside a real gravity field."},
		"about.platforms":  {"zh_CN": "支持平台", "zh_TW": "支援平台", "en": "Platforms"},
		"about.credits":    {"zh_CN": "自制引擎 · Godot 4.7 · 原创素材", "zh_TW": "自製引擎 · Godot 4.7 · 原創素材", "en": "Custom build · Godot 4.7 · Original assets"},

		# ── 建造 ─────────────────────────────────
		"build.title":      {"zh_CN": "火箭工坊", "zh_TW": "火箭工坊", "en": "ROCKET WORKSHOP"},
		"build.parts":      {"zh_CN": "零件", "zh_TW": "零件", "en": "Parts"},
		"build.stats":      {"zh_CN": "参数", "zh_TW": "參數", "en": "Stats"},
		"build.mass":       {"zh_CN": "总质量", "zh_TW": "總質量", "en": "Mass"},
		"build.dv":         {"zh_CN": "Δv 预算", "zh_TW": "Δv 預算", "en": "Delta-v"},
		"build.twr":        {"zh_CN": "推重比", "zh_TW": "推重比", "en": "TWR"},
		"build.stages":     {"zh_CN": "级数", "zh_TW": "級數", "en": "Stages"},
		"build.launch":     {"zh_CN": "发射", "zh_TW": "發射", "en": "LAUNCH"},
		"build.clear":      {"zh_CN": "清空", "zh_TW": "清空", "en": "CLEAR"},
		"build.undo":       {"zh_CN": "撤销", "zh_TW": "復原", "en": "UNDO"},
		"build.preset":     {"zh_CN": "预设", "zh_TW": "預設", "en": "PRESETS"},
		"build.preset.none": {"zh_CN": "— 选择预设 —", "zh_TW": "— 選擇預設 —", "en": "— Choose preset —"},
		"preset.sounding":  {"zh_CN": "探空火箭（亚轨道）", "zh_TW": "探空火箭（亞軌道）", "en": "Sounding Rocket (suborbital)"},
		"preset.orbiter":   {"zh_CN": "轨道火箭（入轨）", "zh_TW": "軌道火箭（入軌）", "en": "Orbital Rocket (to orbit)"},
		"preset.lunar":     {"zh_CN": "奔月火箭（重型三级）", "zh_TW": "奔月火箭（重型三級）", "en": "Lunar Rocket (heavy 3-stage)"},
		"build.tap":        {"zh_CN": "点击零件加入火箭，点机身零件可移除", "zh_TW": "點擊零件加入火箭，點機身零件可移除", "en": "Tap a part to stack it; tap a stacked part to remove"},

		# 零件名
		"part.capsule":     {"zh_CN": "指令舱", "zh_TW": "指令艙", "en": "Command Pod"},
		"part.tank_s":      {"zh_CN": "燃料罐 S", "zh_TW": "燃料罐 S", "en": "Fuel Tank S"},
		"part.tank_m":      {"zh_CN": "燃料罐 M", "zh_TW": "燃料罐 M", "en": "Fuel Tank M"},
		"part.tank_l":      {"zh_CN": "燃料罐 L", "zh_TW": "燃料罐 L", "en": "Fuel Tank L"},
		"part.engine_s":    {"zh_CN": "引擎 S", "zh_TW": "引擎 S", "en": "Engine S"},
		"part.engine_m":    {"zh_CN": "引擎 M", "zh_TW": "引擎 M", "en": "Engine M"},
		"part.engine_vac":  {"zh_CN": "真空引擎", "zh_TW": "真空引擎", "en": "Vacuum Engine"},
		"part.engine_h":    {"zh_CN": "重型引擎", "zh_TW": "重型引擎", "en": "Heavy Engine"},
		"part.decoupler":   {"zh_CN": "分离器", "zh_TW": "分離器", "en": "Decoupler"},
		"part.fin":         {"zh_CN": "尾翼", "zh_TW": "尾翼", "en": "Fins"},
		"part.chute":       {"zh_CN": "降落伞", "zh_TW": "降落傘", "en": "Parachute"},
		"part.nose":        {"zh_CN": "整流罩", "zh_TW": "整流罩", "en": "Nose Cone"},
		"part.legs":        {"zh_CN": "着陆支架", "zh_TW": "著陸支架", "en": "Landing Legs"},

		# ── 游戏 HUD ─────────────────────────────
		"hud.altitude":     {"zh_CN": "高度", "zh_TW": "高度", "en": "ALTITUDE"},
		"hud.speed":        {"zh_CN": "速度", "zh_TW": "速度", "en": "SPEED"},
		"hud.vspeed":       {"zh_CN": "垂直速度", "zh_TW": "垂直速度", "en": "VERT SPEED"},
		"hud.flight":       {"zh_CN": "飞行数据", "zh_TW": "飛行資料", "en": "FLIGHT"},
		"hud.mission":      {"zh_CN": "任务", "zh_TW": "任務", "en": "MISSION"},
		"hud.met":          {"zh_CN": "任务时间", "zh_TW": "任務時間", "en": "MISSION TIME"},
		"hud.apoapsis":     {"zh_CN": "远地点", "zh_TW": "遠地點", "en": "APO"},
		"hud.periapsis":    {"zh_CN": "近地点", "zh_TW": "近地點", "en": "PERI"},
		"hud.throttle":     {"zh_CN": "节流", "zh_TW": "節流", "en": "THR"},
		"hud.fuel":         {"zh_CN": "燃料", "zh_TW": "燃料", "en": "FUEL"},
		"hud.stage":        {"zh_CN": "级", "zh_TW": "級", "en": "STAGE"},
		"hud.warp":         {"zh_CN": "加速", "zh_TW": "加速", "en": "WARP"},
		"hud.map":          {"zh_CN": "地图", "zh_TW": "地圖", "en": "MAP"},
		"hud.stage_btn":    {"zh_CN": "分离", "zh_TW": "分離", "en": "STAGE"},
		"hud.pause":        {"zh_CN": "暂停", "zh_TW": "暫停", "en": "PAUSE"},
		"hud.resume":       {"zh_CN": "继续", "zh_TW": "繼續", "en": "RESUME"},
		"hud.revert":       {"zh_CN": "回到工坊", "zh_TW": "回到工坊", "en": "WORKSHOP"},
		"hud.crashed":      {"zh_CN": "火箭已损毁", "zh_TW": "火箭已損毀", "en": "Rocket Destroyed"},
		"hud.landed":       {"zh_CN": "着陆成功！", "zh_TW": "著陸成功！", "en": "Touchdown!"},
		"hud.landed_on":    {"zh_CN": "已着陆于 {p}", "zh_TW": "已著陸於 {p}", "en": "Landed on {p}"},
		"hud.orbit":        {"zh_CN": "已入轨！", "zh_TW": "已入軌！", "en": "ORBIT ACHIEVED"},
		"hud.escaped":      {"zh_CN": "已逃逸", "zh_TW": "已逃逸", "en": "ESCAPED"},
		"hud.steer":        {"zh_CN": "转向", "zh_TW": "轉向", "en": "STEER"},
		"hud.camera":       {"zh_CN": "视角", "zh_TW": "視角", "en": "VIEW"},
		"hud.center":       {"zh_CN": "居中", "zh_TW": "居中", "en": "CENTER"},

		# ── 飞行实时引导 ─────────────────────────
		"guide.pad":        {"zh_CN": "把节流阀推到 100%，点火升空", "zh_TW": "把節流閥推到 100%，點火升空", "en": "Open the throttle to 100% and lift off"},
		"guide.climb":      {"zh_CN": "垂直爬升：保持 0° 倾角，一直到 2 km 高度", "zh_TW": "垂直爬升：保持 0° 傾角，一直到 2 km 高度", "en": "Climb straight up — hold 0° until 2 km"},
		"guide.turn":       {"zh_CN": "向右倾斜（↻）开始重力转弯：边加速边把弹道压平", "zh_TW": "向右傾斜（↻）開始重力轉彎：邊加速邊把彈道壓平", "en": "Tilt right (↻) for a gravity turn — accelerate while flattening out"},
		"guide.circularize": {"zh_CN": "保持水平加速，把近地点抬到 100 km 以上", "zh_TW": "保持水平加速，把近地點抬到 100 km 以上", "en": "Keep burning horizontally until periapsis clears 100 km"},
		"guide.orbit":      {"zh_CN": "已进入轨道！打开地图查看完整轨道", "zh_TW": "已進入軌道！開啟地圖查看完整軌道", "en": "Orbit achieved — open the map to inspect it"},
		"guide.landed":     {"zh_CN": "已安全着陆", "zh_TW": "已安全著陸", "en": "Safely landed"},
		"guide.crashed":    {"zh_CN": "任务失败：箭体损毁", "zh_TW": "任務失敗：箭體損毀", "en": "Mission failed — vehicle destroyed"},

		# ── 星球 ─────────────────────────────────
		"planet.earth":     {"zh_CN": "地球", "zh_TW": "地球", "en": "Earth"},
		"planet.moon":      {"zh_CN": "月球", "zh_TW": "月球", "en": "Moon"},
		"planet.mars":      {"zh_CN": "火星", "zh_TW": "火星", "en": "Mars"},

		# ── 提示 ─────────────────────────────────
		"tip.launch_hint":  {"zh_CN": "按住节流阀并点击发射点火", "zh_TW": "按住節流閥並點擊發射點火", "en": "Hold throttle, tap LAUNCH to ignite"},
		"tip.saved":        {"zh_CN": "已保存", "zh_TW": "已保存", "en": "Saved"},
		"tip.unsaved_quit": {"zh_CN": "有未保存的进度，确定退出？", "zh_TW": "有未儲存的進度，確定結束？", "en": "Unsaved progress. Quit anyway?"},
	}
