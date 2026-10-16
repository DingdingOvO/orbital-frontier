# 星轨计划 ORBITAL FRONTIER

一款原创的 2D 轨道航天沙盒游戏（玩法对标 Spaceflight Simulator 类）：自由组装多级火箭，
在真实引力场里发射、重力转弯、入轨、变轨与着陆。**用 Godot 4.7 原生引擎开发，不套 WebView 壳。**

---

## 什么地方可以玩

| 平台 | 获取方式 |
|---|---|
| **网页版（在线试玩，无需安装）** | https://a22c4b2609950ecfa.app.workbuddy.host |
| **Android APK（可直装）** | 官网下载页，或 `sfs-game/build/android/orbital-frontier.apk`（27 MB，包名 `com.orbitalfrontier.game`，minSdk 24 / targetSdk 36，arm64） |
| Windows / macOS / Linux | Godot 工程已配好导出预设，用 Godot 4.7 打开 `sfs-game/` 一键导出 |
| iOS | 需 Apple 开发者账号签名 |

---

## 玩法

主菜单 → **开始**（进火箭工坊）→ 堆零件 → **发射** → 推节流阀点火 → 重力转弯 → 入轨 / 着陆。

**飞行页有实时引导条**，会随高度提示当前该做什么：
`推节流阀点火` → `垂直爬升` → `向右倾斜做重力转弯` → `抬升近地点` → `已进入轨道`

**操作**

| 操作 | 说明 |
|---|---|
| 节流阀滑杆 / `100%` 按钮 | 控制推力 |
| `↺` `↻` | 姿态转向（按住） |
| 分离 / 降落伞 | 分级、开伞减速 |
| 地图 / ×1…×1000 | 切换轨道视图、时间加速 |
| 鼠标拖动 / 滚轮 / 双指捏合 / 双击 | 平移视角、缩放、回到跟随 |

**三套预设**（推重比与 Δv 都经过配平）

| 预设 | 起飞质量 | 推重比 | Δv 预算 | 用途 |
|---|---|---|---|---|
| 探空火箭 sounding | 3.9 t | 1.59 | 2.9 km/s | 亚轨道打高 |
| 轨道火箭 orbiter | 52 t | 1.55 | 10.2 km/s | 入轨 |
| 奔月火箭 lunar | 96 t | 1.39 | 13.0 km/s | 地月转移 |

---

## 技术要点

- **物理**：牛顿引力 + 指数大气模型 + 比冲随气压插值 + 燃料质量流 + 多级分离 + 开普勒轨道根数解算 + 解析轨道采样
- **精度**：位置积分走 **float64**。Godot 的 `Vector2` 是 32 位浮点，在 6371 km 量级下最小步进约 0.5 m，
  低速位移（伞降、悬停）会被直接舍入清零 —— 所以物理位置用双精度分量积分，`Vector2` 只做渲染缓存
- **字体**：思源黑体（400/500/700 三个静态字重）+ Oxanium（标题/Logo 拉丁）+ JetBrains Mono（HUD 等宽数字），
  按工程实际用字裁剪，中英混排靠 `Font.fallbacks` 回退
- **UI**：自建设计系统（UiKit），滑杆 / 开关 / 滚动条 / 下拉菜单全部自绘，不用 Godot 默认皮肤
- **本地化**：自研 i18n，简中 / 繁中 / English 运行时即时切换

---

## 目录

```
sfs-game/
  project.godot            工程配置
  assets/fonts/            裁剪后的字体（6 个字重，约 930 KB）
  src/autoload/            Cfg 配置 · Loc 本地化 · SaveGame 多存档 · ModHost · UiKit 设计系统
  src/ui/pages/            主菜单 · 设置 · Mod · 关于 · 存档
  src/ui/widgets/          自绘滑杆 / 开关
  src/game/                Parts 零件 · Rocket 物理 · Space 天体力学 · WorkshopPage 工坊 · FlightPage 飞行
  tools/                   自动化测试与字体生成（已从导出包排除）
  android/build/           Godot Android Gradle 模板
website/                   官网（介绍页 + 下载页）与内嵌的 WebAssembly 网页版
preview/                   运行截图
```

## 开发用命令

```bash
# 自动化冒烟测试（起飞 / 入轨 / 伞降 / 坠毁 / 轨道数学，30+ 项断言）
godot --headless --path sfs-game --script res://tools/Smoke.gd

# 重新生成裁剪字体
python3 sfs-game/tools/gen_fonts.py

# 导出
godot --headless --path sfs-game --export-release "Android" build/android/orbital-frontier.apk
godot --headless --path sfs-game --export-release "Web" build/web/index.html

# 演示模式（内置自动驾驶，自动完成入轨；也可用于截图）
godot --path sfs-game -- --page=flight --autofly
```

## 素材声明

全部零件数值取自公开航天工程量级，图形为程序化矢量绘制，字体为 SIL OFL 开源字体，无任何第三方游戏素材。
