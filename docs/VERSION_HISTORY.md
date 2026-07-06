# Pixel Observatory Version History

本文档记录 Pixel Observatory / Starlight Observatory 从早期测试项目到当前可玩教学版本的主要进度。它不是严格的发布日志，而是面向 GitHub 读者的项目演进说明。

## v0.1 - 项目替换与 MVP 基础

目标：把原来的射击测试项目替换成 2D 像素天文观测教学游戏。

完成内容：

- 项目名称改为 Pixel Observatory。
- 主入口切换为 `main_menu.tscn`。
- 新增核心管理器：
  - `GameManager`
  - `SaveManager`
  - `MissionManager`
  - `AssemblyManager`
  - `TelescopeMath`
  - `ObservationSystem`
- 新增基础数据：
  - `telescope_parts.json`
  - `celestial_objects.json`
  - `levels.json`
  - `localization.json`
- 搭出第一版主循环：
  - Main Menu
  - Observatory Room
  - Telescope Assembly
  - Sky Observation
  - Telescope View
  - Learning Card
  - Learning Journal

问题：

- 早期界面太像文字工具页。
- 主观测室空间感不足。
- 交互点和任务流程不清楚。

## v0.2 - Observatory Room 初版

目标：把纯 UI 流程改成玩家可以走动的 2D 主基地。

完成内容：

- 新增可移动玩家角色。
- 增加主观测室交互点：
  - Mission Board
  - Parts Cabinet
  - Assembly Table
  - Observatory Door
  - Telescope Pad
  - Learning Journal
  - Stats Terminal
- 支持 WASD / Arrow 移动。
- 支持靠近后按 E 交互。
- 支持鼠标点击交互点。
- 顶部 HUD 显示 Level、Credits、Telescope Status、Mission。
- 底部提示区根据附近物体动态变化。

问题：

- 使用农场和工坊素材硬拼，主题不统一。
- 地板边缘和标签显示混乱。
- 玩家不知道该先去哪里。

## v0.3 - 主观测室重做

目标：从户外拼贴改成可信的学校天文社 / 小型天文台基地。

完成内容：

- Observatory Room 改成天文社基地布局。
- Observatory Door 可以进入内部控制室。
- 新增 `observatory_interior.tscn`。
- Telescope Pad 和 Observatory Door 都可以作为观星入口。
- 未组装望远镜时会提示玩家先去 Assembly Table。
- 完成组装后大厅提示玩家去 Telescope Pad 或 Observatory Door。

问题：

- 用切片素材重拼家具时透视关系容易错乱。
- 后续改成完整背景图 + 透明交互层。

## v0.4 - Assembly Table 可玩化

目标：让望远镜组装台从调试按钮界面变成清楚的核心玩法界面。

完成内容：

- 左侧改成 Parts Tray / 可用零件。
- 中间改成 Assembly Blueprint / 蓝图。
- 右侧改成 Inspector / Stats。
- 每个零件卡片显示图标、英文名、中文名、安装状态。
- 已安装零件显示 Installed / 已安装。
- 未安装零件显示 Not Installed / 未安装。
- 点击零件，再点击蓝图安装位完成安装。
- 顺序错误会提示先安装底部支撑结构。
- 错误位置会增加 wrong attempts 并显示反馈。
- Finish Assembly 会检查核心部件是否完整。

问题：

- 早期零件图标溢出卡片。
- installed 状态曾错误地从 unlocked 判断。
- 后续已改为读取 `GameManager.progress["assembly_state"]`。

## v0.5 - 第一关完整流程

目标：跑通 New Game -> Moon mission -> Learning Journal。

完成内容：

- New Game 初始状态为 `telescope_ready = false`。
- 完成 5 个核心部件后设置 `telescope_ready = true`。
- Mission Board 显示 Level 1 Moon 任务。
- Moon 在 Sky Observation 中明显可找。
- 选中 Moon 后进入 Telescope View。
- Identify Moon 后完成任务。
- Learning Card 显示 Moon 学习内容。
- Learning Journal 写入 Moon 记录。
- 完成 L1 后 credits 增加，current level 推进。

问题：

- 早期星图按钮像普通 UI 控件。
- Telescope View 在识别前曾直接显示目标名称，后续已移除。

## v0.6 - Sky Observation 视觉升级

目标：让观星界面更像教学型 2D 像素星空，而不是普通按钮列表。

完成内容：

- 不同天体使用不同视觉：
  - Moon：大淡黄色月球。
  - Polaris：小白星。
  - Sirius：蓝白亮星。
  - Betelgeuse：红橙星。
  - Mars：红橙行星。
  - Jupiter：条纹行星。
  - Orion Nebula：紫色雾团。
  - Andromeda：蓝色椭圆星系。
- 透明 Button 只作为点击热区。
- 选中目标显示金色细框。
- 识别前不在星图上直接暴露真实名称。
- 右侧面板显示任务提示、选择状态和 Observe / Back。

## v0.7 - Telescope View 视觉升级

目标：让望远镜视野像真实通过镜筒观察。

完成内容：

- 中间改成圆形望远镜视野。
- 圆外使用深色遮罩。
- 镜头有金色 / 铜色外环。
- 不同天体在望远镜中显示不同图像。
- 观测质量影响视觉：
  - Excellent / Good：清楚。
  - Fair：略模糊。
  - Poor：暗、噪点多。
  - Failed：几乎看不清。
- Identify choices 保留真实名称，用作识别环节。
- 选错目标不会完成当前任务。

## v0.8 - Parts Cabinet 与 Assembly Table 分离

目标：修正信息架构，让零件柜和组装台不再混成同一个界面。

完成内容：

- Parts Cabinet 只用于查看零件库存、说明和状态。
- Assembly Table 才进入 `telescope_assembly.tscn`。
- GameManager 新增 `parts` 场景映射。
- 组装台左侧从 Parts Cabinet 改名为 Parts Tray / Available Parts。
- 组装完成后设置下一步引导：
  - Go to Telescope Pad or Observatory Door to begin sky observation.

## v0.9 - 主观测室完整背景图方案

目标：停止拆家具重拼，改为完整背景图 + 透明交互层。

完成内容：

- 使用完整 observatory room 背景图。
- 不再用切片家具拼主房间。
- 交互 hitbox 完全透明。
- 靠近时只显示细边框。
- 玩家、交互层、HUD 叠在背景上。
- 保留返回位置逻辑。
- 修正 Telescope Pad、Stats Terminal、Learning Journal 等交互框尺寸。

问题：

- 早期玩家角色比例过小 / 过大。
- 后续重做 spritesheet 并保持脚底锚点。

## v1.0 - 玩家角色动画规范化

目标：解决角色方向错误、串帧、头皮残影、脚底锚点漂移。

完成内容：

- 生成 `player_observer_4dir_clean.png`。
- 4 columns x 4 rows。
- 行方向：
  - row 0 = down
  - row 1 = left
  - row 2 = right
  - row 3 = up
- 每行 4 帧：
  - column 0 = idle
  - column 1-3 = walk
- 角色脚底锚点固定。
- 视觉尺寸和碰撞尺寸分离。
- Observatory Room 交互检测改用脚底位置。

## v1.1 - 真实星体位置系统

目标：让 Sky Observation 根据今晚真实星体位置摆放像素星体。

完成内容：

- 新增 `SkyPositionService.gd`。
- 新增 `celestial_catalog.json`。
- 新增 `observing_config.json`。
- Moon、Mars、Jupiter 支持 AstronomyAPI 在线位置。
- Polaris、Sirius、Betelgeuse、Orion Nebula、Andromeda 使用本地 RA/Dec 计算。
- 如果 API key 缺失或请求失败，自动 fallback。
- 所有目标即使低于地平线也保留可点击，不阻断主线。

安全处理：

- API secret 只读取本地 `data/local_api_keys.json`。
- `data/local_api_keys.json` 已加入 `.gitignore`。
- 不把 secret 写死进脚本。

## v1.2 - 教学节奏调整

目标：让原理讲解出现在实际操作之前，而不是只在任务完成后出现。

完成内容：

- 新增 / 强化 `TeachingFlowManager`。
- 增加 Concept Brief。
- 区分：
  - seen teaching steps
  - seen concept briefs
  - completed concept cards
- 在 Assembly、Sky Observation、Telescope View 前触发不同教学提示。
- 完成任务后仍显示 Mission Complete 和学习卡总结。

## v1.3 - Focus Knob 成为真实部件

目标：让调焦不是凭空出现的 UI，而是望远镜系统中的真实零件。

完成内容：

- 新增 Basic Focus Knob。
- Assembly Table 支持安装 Focus Knob。
- `TelescopeMath` 新增 `focus_control_score`。
- Telescope View 如果未安装 Focus Knob，会提示无法完成精确调焦。
- Sky Observation / Telescope View 显示方位角和俯仰角 DMS 提示。

## v1.4 - Learning Card 图解放大

目标：让学习卡里的教学图成为主要学习内容，而不是小缩略图。

完成内容：

- Concept Brief 图解放大到页面主视觉区域。
- Mission Complete 中的 Concept learned 图不再过小。
- TextureRect 使用 `STRETCH_KEEP_ASPECT_CENTERED`。
- 保持原图比例。
- 为光路、焦平面、调焦等图解预留足够阅读面积。

## v1.5 - Orion Nebula 通关体验修正

目标：解决玩家感觉“怎么调焦都没用”的问题。

完成内容：

- L7 Orion Nebula 允许 Fair 质量通关。
- L8 再要求 Good，用来教学大口径集光。
- UI 文案区分：
  - 焦点没对准：继续调焦。
  - 焦点已对准但设备不够：提示 aperture / stability 不足。
  - 焦点已对准且可完成：提示可以识别。
- `focus_nebula_test`、`flow_test`、`v2_progression_test` 随之更新。

## v1.6 - Main Menu 正式化

目标：把简陋按钮菜单改成完整、沉浸的 Starlight Observatory 首页。

完成内容：

- 使用用户提供的完整主菜单图作为背景。
- 不再重画标题、面板或按钮。
- 背景缩放为 1024x768。
- New Game / Continue / Settings / Language / Quit 使用透明按钮热区。
- 鼠标 hover 时显示轻微金色高亮和描边。
- 鼠标 pressed 时轻微变暗。
- Continue 无存档时点击只提示 No save found yet，不再用黑色遮罩破坏按钮颜色。

## v1.7 - Sky Observation 模式按钮统一

目标：修复 Eye / Finder / Scope 三个按钮颜色不一致。

完成内容：

- 使用用户提供的统一按钮图片。
- 预缩放为 `sky_view_mode_buttons_uniform_250x76.png`。
- 覆盖原背景里旧的三按钮区域。
- 保留透明热区。
- 当前模式只显示细金色框。
- 不再把 unavailable / inactive 状态染成不同底色。

## v1.8 - Jupiter 观测贴图升级

目标：让 Jupiter 的望远镜画面更接近真实观测质量变化。

完成内容：

- 新增三张 Jupiter 状态贴图：
  - `jupiter_clear.png`
  - `jupiter_blurry.png`
  - `jupiter_dim.png`
- Telescope View 根据质量和 visual_effect 自动选择：
  - Excellent / Good / clear -> clear
  - Fair / blurry -> blurry
  - Poor / Failed / dim -> dim
- 保留原 `jupiter_large.png` 作为 fallback。

## 当前仍需处理

- 清理旧 shooter / BulletUpHell / Starfall 残留资源和插件报错。
- 继续修复中文编码乱码。
- 为更多天体补齐 clear / blurry / dim 贴图。
- 继续平衡 L10-L24 的任务难度。
- 优化 Godot 导出配置。
- 整理最终素材授权和 Credits。
