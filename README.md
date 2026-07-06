# Pixel Observatory / 像素天文台

Pixel Observatory 是一个使用 Godot 4.7 制作的 2D 像素风天文观测教学游戏。玩家扮演刚加入学校 Astronomy Club 的新成员，在 Maya 的引导下，从肉眼观测开始，逐步学习折射望远镜、调焦、倍率、寻星镜、深空观测和追踪支架。

这个项目的目标不是做一个静态星图按钮页，而是让玩家通过真实的操作流程理解天文观测：

- 先用肉眼找大方向。
- 再用寻星镜缩小搜索范围。
- 最后用主望远镜细看目标。
- 组装错误、口径不足、倍率过高、调焦不准、稳定性差，都会影响最终观测画面。

---

## 当前项目状态

当前版本已经完成一条完整的教学主线，并且把早期 24 关的教学结构、剧情框架、观测流程和 UI 基础都接起来了。

已完成的核心内容：

- Observatory Room 主观测室大厅。
- Mission Board 任务板。
- Parts Cabinet 零件柜。
- Telescope Assembly Table 望远镜组装台。
- Sky Observation 星空观测界面。
- Telescope View 望远镜视野与识别界面。
- Learning Card / Concept Brief 教学卡。
- Learning Journal / Club Logbook 学习记录。
- SaveManager 本地 JSON 存档。
- TeachingFlowManager 教学流程状态机。
- StoryManager 剧情触发系统。
- Maya 天文俱乐部导师剧情线。
- Focus Knob 作为真实可安装零件。
- 三段式观测流程：Naked Eye / Finder Scope / Telescope Alignment。
- Telescope View 调焦、观测质量、识别判定。
- L1-L24 关卡数据与章节结构。

当前重点仍然是体验打磨：任务引导、UI 排版、观测反馈、组装视觉比例、剧情连贯性。

---

## 游戏核心循环

```text
主观测室大厅
  -> 接任务 / 查看当前目标
  -> 零件柜选择装备
  -> 组装台安装望远镜零件
  -> 星空观测：肉眼 -> 寻星镜 -> 主镜对准
  -> 望远镜视野：调焦 -> 观察 -> 识别
  -> 任务完成卡 / Maya 复盘 / 日志记录
  -> 解锁下一阶段
```

---

## 关卡章节结构

### Chapter 1: Naked Eye Observation / 肉眼观测

| 关卡 | 目标 | 教学重点 |
|---|---|---|
| L1 | Moon | 人眼如何成像，为什么先从月亮开始 |
| L2 | Polaris / Sirius | 肉眼能看到什么，肉眼看不到什么 |

### Chapter 2: First Telescope / 第一台望远镜

| 关卡 | 目标 | 教学重点 |
|---|---|---|
| L3 | Moon | 组装基础折射望远镜，理解物镜、镜筒、目镜 |
| L4 | Jupiter | 安装 Focus Knob，学习焦平面和调焦 |
| L5 | Jupiter | 高倍率不是永远更好 |
| L6 | Sirius / Polaris | 使用 Finder Scope 缩小搜索范围 |
| L7 | Orion Nebula | 进入反射镜 / 深空观测阶段 |
| L8 | Orion Nebula | 大口径收集更多光 |
| L9 | Andromeda | 第一次深空综合挑战 |

### Chapter 3: Focus and Magnification Mastery / 调焦与倍率掌握

| 关卡 | 目标 | 变化变量 |
|---|---|---|
| L10 | Jupiter | 对比低/中/高倍率，体会高倍率代价 |
| L11 | Mars | 低空目标受大气影响，高倍率更容易失败 |
| L12 | Moon | 明亮目标可以承受更高倍率，但仍要重新调焦 |
| L13 | 自选目标 | 玩家独立选择倍率和目标，完成复习任务 |

### Chapter 4: Finder and Sky Navigation / 寻星镜与星空导航

| 关卡 | 目标 | 变化变量 |
|---|---|---|
| L14 | Mars | 使用 Azimuth / Altitude 坐标找目标 |
| L15 | Sirius | 校准 Finder Scope，让寻星镜与主镜中心一致 |
| L16 | Jupiter | 体验直接用窄视野主镜找目标为什么困难 |
| L17 | 随机亮目标 | 独立完成 Eye -> Finder -> Telescope 流程 |

### Chapter 5: Light Gathering and Faint Objects / 集光与暗弱天体

| 关卡 | 目标 | 变化变量 |
|---|---|---|
| L18 | Orion Nebula | Fair 质量也可以是深空观测成功 |
| L19 | Orion Nebula | 同一目标换大口径，直接比较亮度差异 |
| L20 | Andromeda | 城市光污染下的低质量观测 |
| L21 | Andromeda | 暗空条件下同设备效果提升 |

### Chapter 6: Tracking and Patience / 追踪与耐心

| 关卡 | 目标 | 变化变量 |
|---|---|---|
| L22 | Sirius | 天体漂移，手动保持居中 8 秒 |
| L23 | Jupiter | 解锁 Tracking Mount，设置追踪 |
| L24 | Andromeda | 长时间稳定观测，完成最终深空记录 |

---

## 已实现系统细节

### 1. TeachingFlowManager

集中管理教学卡触发，不再把大量 if-else 写散在 UI 里。

支持：

- `before_observation`
- `before_assembly`
- `before_focus`
- `before_identify`
- `before_collimation`

进度字段区分：

- `seen_teaching_steps`: 看过的前置教学步骤。
- `seen_concept_briefs`: 看过的概念预习卡。
- `completed_concept_cards`: 完成任务后真正解锁到 Journal 的知识卡。

这样“看过预习”不会等于“已经学会并记录”。

### 2. StoryManager

负责剧情事件触发和去重。

当前剧情框架：

- 玩家是学校 Astronomy Club 新成员。
- Maya 是主要导师角色。
- New Game 后播放 intro。
- L1 / L3 / L4 等关键节点有剧情引导。
- Mission Complete 中可以显示 Maya 的复盘句。

### 3. Sky Observation

从旧版“静态星体按钮页”改成三段式观测流程：

- Naked Eye: 超广角，只能看到亮目标。
- Finder Scope: 中等视野，用来定位。
- Telescope Alignment: 窄视野，用来精确居中。

显示内容：

- 当前方位角 Azimuth。
- 当前俯仰角 Altitude。
- 目标方位角 / 俯仰角。
- DMS 度分秒格式。
- 具体转动提示，例如向东转多少度、抬高多少度。

### 4. Telescope View

望远镜视野中已经拆开两套判定：

- Focus 是否对准：只看 `focus_error <= focus_tolerance`。
- Overall Quality 是否足够：看口径、稳定性、亮度、目标类型、天气等。

因此深空目标不会再出现“焦点明明对了但永远像没对上”的错误反馈。

典型反馈：

- `Adjust focus before identifying.`
- `Focus aligned, but telescope quality is still too low.`
- `Image clear enough. Ready to identify.`

### 5. Parts Cabinet

零件柜已经从普通库存列表整理成装备柜 UI。

特点：

- 按 Support / Optics / Aiming / Control 分类。
- 每个零件卡显示图标、名称、用途、关键属性、装备状态。
- 已装备 / 可装备 / 未解锁状态清晰区分。
- 支持滚动，后续更多零件不会溢出。
- 当前任务推荐零件会高亮。
- 更换零件会提示需要回组装台重新安装。

### 6. Telescope Assembly Table

组装台已经支持真实零件图像，并区分具体装备：

- 60mm objective 与 100mm objective 显示不同图。
- 20mm eyepiece 与 10mm eyepiece 显示不同图。
- basic mount / stable mount / tracking mount 有不同尺寸。
- basic tripod 放大后能作为承重结构。
- 已安装时不再显示粗糙几何方块。

当前仍在继续打磨装配图比例和连接关系。

### 7. ObservationSystem

观测质量综合考虑：

- observation mode。
- target type。
- telescope stats。
- focus error。
- aperture / light score。
- stability。
- seeing / sky brightness / clouds。
- magnification。
- tracking。

支持裸眼观测、望远镜观测和深空观测差异。

---

## 零件系统

| 零件 | 类型 | 作用 |
|---|---|---|
| Basic Tripod | Support | 基础三脚架，支撑整台望远镜 |
| Basic Mount | Support | 基础支架，可以转动但高倍率易抖 |
| Starter Telescope Tube | Support | 保持物镜和目镜同轴 |
| 60mm Starter Lens | Objective | 入门物镜，适合月亮和亮星 |
| 100mm Wide Aperture Lens | Objective | 大口径物镜，适合星云和星系 |
| 20mm Low Power Eyepiece | Eyepiece | 低倍率、宽视野，适合找目标 |
| 10mm High Power Eyepiece | Eyepiece | 高倍率、窄视野，适合亮目标细节 |
| Basic Finder Scope | Aiming | 寻星镜，用来先找到目标 |
| Basic Focus Knob | Control | 调焦旋钮，移动目镜到焦平面 |
| Heavy Stable Mount | Support | 稳定支架，减少高倍率抖动 |
| Tracking Mount | Support | 追踪支架，抵消地球自转造成的漂移 |

---

## 版本进度记录

### v0.1 - 项目初始化

基础内容：

- 建立 Godot 4.7 项目。
- 建立主菜单、观测室、组装台、观测界面、学习卡基础场景。
- 建立 `GameManager`、`SaveManager`、`TelescopeMath`、`AssemblyManager`、`ObservationSystem`。
- 支持本地 JSON 存档。

### v0.2 - 第一版观测流程

完成内容：

- 任务系统和关卡数据雏形。
- 组装台按顺序安装基础零件。
- Telescope View 支持识别目标。
- Learning Journal 记录观测结果。

问题：

- 星空观测仍偏静态。
- 星体位置和真实观测逻辑还不够强。

### v0.3 - UI 大厅与日志重构

完成内容：

- Observatory Room 改成更完整的像素天文台大厅。
- 学习日志改成卡片式记录。
- 主菜单和组装台视觉初步优化。
- 增加更多任务和基础升级零件。

### v0.4 - SkyPositionService 与真实天空数据

完成内容：

- 增加 `SkyPositionService`。
- Moon / Mars / Jupiter 支持 AstronomyAPI 在线位置。
- Polaris / Sirius / Betelgeuse / Orion Nebula / Andromeda 使用本地 RA/Dec 计算。
- API 失败时使用 fallback，不阻塞游戏。

### v0.5 - Finder Scope / 局部视野

完成内容：

- Sky Observation 从全天固定星图改成可旋转望远镜视野。
- 支持 azimuth / altitude 控制。
- 支持 FOV 判定。
- 只显示当前视野内目标。
- 使用 `shortest_angle_degrees` 处理 0/360 度跨界。

### v0.6 - Telescope View 视觉与识别修复

完成内容：

- Telescope View Back 返回 Observatory，不再错误返回 Assembly。
- Identify 选项限制为最多 4 个。
- 右侧面板不再溢出。
- 星体显示改用 PNG 图像，不再用几何图形拼。
- Moon / Mars / Jupiter / stars / nebula / galaxy 的望远镜视野表现区分。

### v0.7 - 玩家比例与大厅交互修复

完成内容：

- 修正 Observatory Room 玩家角色比例。
- 改为等比缩放，避免角色被拉伸。
- 保持脚底锚点和交互范围稳定。

### v1.0 - Pixel Observatory v2 教学主线

完成内容：

- 重新规划 L1-L9。
- 加入 naked eye observation。
- 加入 equipment_stage。
- 加入 focus training。
- 学习卡支持图解。
- 前几关从肉眼 -> 折射镜 -> 调焦 -> 深空挑战。

### v1.1 - Teaching Flow State Machine

完成内容：

- 新增 `TeachingFlowManager`。
- 使用 `teaching_steps` 数据驱动教学卡。
- 支持一个关卡多个前置 brief。
- 区分 seen brief 和 completed concept card。
- Mission Complete 与 Concept Brief 分离。

### v1.2 - Focus Knob 成为真实零件

完成内容：

- `basic_focus_knob` 加入 `telescope_parts.json`。
- L4 之后需要安装 Focus Knob 才能调焦。
- `TelescopeMath` 增加 `focus_control_score`。
- Telescope View 无 Focus Knob 时不能完成调焦任务。

### v1.3 - Story System / Maya 剧情框架

完成内容：

- 新增 `StoryManager`。
- 新增 `story_dialogues.json`。
- 引入 Maya 作为天文俱乐部导师。
- New Game intro、L1、L3、L4 关键节点支持剧情。
- Mission Complete 可显示 Maya 复盘。

### v1.4 - 三段式 Sky Observation

完成内容：

- Sky Observation 支持 Naked Eye / Finder Scope / Telescope Alignment 三模式。
- 当前 Az / Alt 与目标 Az / Alt 使用 DMS 显示。
- Guidance 显示具体转动角度。
- 不同模式下星体大小不同：肉眼小点，寻星镜小亮斑，Telescope View 才显示细节。

### v1.5 - Focus 与 Quality 判定拆分

完成内容：

- `is_focus_acceptable()` 只判断调焦。
- `is_quality_acceptable()` 只判断观测质量。
- 深空目标焦点对准但质量不足时，会明确提示 telescope quality / aperture / stability 问题。
- 修复 Orion Nebula 永远像无法对焦的问题。

### v1.6 - 流程体验修复

完成内容：

- 修复剧情/教学从设备触发后又退回大厅的问题。
- 从 Observation Pad 触发 brief 后直接进入 Sky Observation。
- 从 Assembly Table 触发 brief 后直接进入 Assembly。
- 从 Sky Observation 触发 focus brief 后直接进入 Telescope View。
- 大厅增加下一步引导和目标高亮。
- 远距离点击家具不再直接进入界面。

### v1.7 - Main Menu 重做

完成内容：

- 主菜单替换为 Starlight Observatory 风格标题画面。
- 增加沉浸式背景图和更完整的菜单状态。
- 首页视觉更接近正式游戏入口。

### v1.8 - L10-L24 章节规划与数据扩展

完成内容：

- L10-L13 聚焦倍率与调焦掌握。
- L14-L17 聚焦寻星镜与天空导航。
- L18-L21 聚焦集光与暗弱天体。
- L22-L24 聚焦追踪与耐心观测。
- 新增 `chapter_id`、`lesson_thread`、`practice_step`、`variation`、`repeat_target_reason`、`next_guidance` 等数据字段。

### v1.9 - Parts Cabinet 与 Telescope Assembly 视觉升级

完成内容：

- 零件柜重做为可滚动装备列表。
- 加入任务推荐、装备状态、属性标签和重新组装提示。
- 新增 `assets/telescope_parts/`，导入 11 张正式零件图。
- 组装台左侧托盘和蓝图使用正式零件图。
- 删除粗糙几何零件图。
- 调整基础支架、三脚架、60mm / 100mm 物镜的显示比例。

---

## 测试与验证

常用命令：

```bash
C:/Users/tntsg/Downloads/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64_console.exe --headless --path E:/godot/ai-game-0628 --scene res://scenes/observatory_room.tscn --quit-after 5

C:/Users/tntsg/Downloads/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64_console.exe --headless --path E:/godot/ai-game-0628 --scene res://scenes/sky_observation.tscn --quit-after 5

C:/Users/tntsg/Downloads/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64_console.exe --headless --path E:/godot/ai-game-0628 --scene res://scenes/telescope_view.tscn --quit-after 5

C:/Users/tntsg/Downloads/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64_console.exe --headless --path E:/godot/ai-game-0628 --scene res://scenes/telescope_assembly.tscn --quit-after 5
```

自动测试：

```bash
C:/Users/tntsg/Downloads/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64_console.exe --headless --path E:/godot/ai-game-0628 --script res://tools/flow_test.gd

C:/Users/tntsg/Downloads/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64_console.exe --headless --path E:/godot/ai-game-0628 --script res://tools/v2_progression_test.gd

C:/Users/tntsg/Downloads/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64_console.exe --headless --path E:/godot/ai-game-0628 --script res://tools/teaching_flow_test.gd

C:/Users/tntsg/Downloads/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64_console.exe --headless --path E:/godot/ai-game-0628 --script res://tools/story_flow_test.gd

C:/Users/tntsg/Downloads/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64_console.exe --headless --path E:/godot/ai-game-0628 --script res://tools/sky_view_test.gd

C:/Users/tntsg/Downloads/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64_console.exe --headless --path E:/godot/ai-game-0628 --script res://tools/focus_nebula_test.gd
```

---

## 技术栈

| 项目 | 内容 |
|---|---|
| 引擎 | Godot 4.7 |
| 语言 | GDScript |
| 分辨率 | 1024 x 768 |
| 存档 | JSON 本地存档 |
| 图像风格 | Pixel Art |
| 星体位置 | AstronomyAPI + 本地 RA/Dec fallback |
| UI | Godot Control 节点程序化构建 |
| 测试 | Headless scene smoke tests + GDScript flow tests |

---

## 重要文件

| 文件 | 说明 |
|---|---|
| `scripts/systems/game_manager.gd` | 全局进度、路由、任务完成、装备状态 |
| `scripts/systems/teaching_flow_manager.gd` | 教学流程状态机 |
| `scripts/systems/story_manager.gd` | 剧情事件管理 |
| `scripts/systems/observation_system.gd` | 观测质量计算 |
| `scripts/systems/telescope_math.gd` | 望远镜统计属性计算 |
| `scripts/systems/sky_position_service.gd` | 星空位置计算与 API fallback |
| `scripts/ui/observatory_room.gd` | 主观测室大厅 |
| `scripts/ui/parts_cabinet.gd` | 零件柜 |
| `scripts/ui/telescope_assembly_screen.gd` | 组装台 |
| `scripts/ui/sky_observation.gd` | 星空观测 |
| `scripts/ui/telescope_view.gd` | 望远镜视野 |
| `data/levels.json` | 关卡数据 |
| `data/telescope_parts.json` | 零件数据 |
| `data/story_dialogues.json` | 剧情对白 |
| `data/learning_cards.json` | 学习卡数据 |

---

## 开发注意

- 不要把 `data/local_api_keys.json` 提交到仓库。
- AstronomyAPI secret 只从本地文件读取，不写进脚本。
- UI 文案尽量走 `GameManager.text(en, zh)` 或统一双语字段。
- 改观测流程后至少跑 `flow_test.gd` 和 `v2_progression_test.gd`。
- 改教学卡或剧情后跑 `teaching_flow_test.gd` 和 `story_flow_test.gd`。
- 改 Sky Observation 后跑 `sky_view_test.gd`。
- 改 Telescope View 调焦后跑 `focus_nebula_test.gd`。
