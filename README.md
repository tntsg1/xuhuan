# Pixel Observatory / 像素观测站

> **2D 像素风天文观测教育游戏 | Godot 4.7**
>
> 玩家扮演加入学校天文俱乐部的新生，在学姐 Maya 带领下从肉眼观测一步步学到深空追踪。
> 纯本地运行，双语 EN/中文。

---

## 🎮 核心玩法

```
肉眼观测 → 组装折射望远镜 → 调焦 → 掌握倍率 → 寻星镜导航 → 深空观测 → 追踪天体
```

不是选择题游戏，不是点击观星。**核心特色**：亲手组装望远镜零件（三脚架、支架、镜筒、物镜、目镜、调焦旋钮、寻星镜），组装质量和零件选择直接影响观测结果。

### 三段式观星流程

| 模式 | 视野 | 用途 |
|------|------|------|
| 👁 Naked Eye | 120°×70° | 广角扫天，肉眼找目标 |
| 🔍 Finder Scope | 28°×18° | 中视野对准 |
| 🔭 Telescope | 6°×4° | 窄视野精确定位，居中后进入望远镜视野 |

支持 Az/Alt 方位角俯仰角导航、DMS 度分秒格式、实时星图背景（HYG 星表 1637 颗）、WASD 旋转 + Shift 加速。

---

## 📊 项目进度

| 系统 | 完成度 |
|------|--------|
| 系统骨架 | 80% |
| L1-L9 主线逻辑 | 75% |
| 教学/剧情框架 | 70% |
| 大厅交互 | 65% |
| 观星体验 | 55% |
| 关卡玩法差异 | 45% |
| 美术/UI polish | 45% |
| 牛顿镜/深空高级玩法 | 30% |

### 已完成关卡（L1-L9）

| 关 | 教学模式 | 目标天体 | 知识点 |
|----|---------|---------|--------|
| L1 | 肉眼 | Moon | 人眼成像原理 |
| L2 | 肉眼 | Polaris | 肉眼观测极限 |
| L3 | 折射镜组装 | Moon | 物镜/目镜/折射镜光路 |
| L4 | 调焦 | Jupiter | 焦平面与调焦 |
| L5 | 倍率 | Jupiter | 倍率代价（高倍率≠更好） |
| L6 | 寻星镜 | Sirius | 寻星镜辅助导航 |
| L7 | 牛顿镜概念 | Orion Nebula | 反射镜原理/口径 |
| L8 | 大口径 | Orion Nebula | 集光能力对比 |
| L9 | 深空挑战 | Andromeda | 综合深空观测 |

### L10-L24 已设计（待实现）

螺旋式重复练习结构，每 3-5 关一个主题反复变形：

| 章节 | 关卡 | 主题 |
|------|------|------|
| Ch3 | L10-13 | 调焦与倍率掌握 |
| Ch4 | L14-17 | 寻星镜与星空导航 |
| Ch5 | L18-21 | 集光与暗弱天体 |
| Ch6 | L22-24 | 追踪与耐心 |

详见 [`docs/levels_10_24_design.md`](docs/levels_10_24_design.md)

---

## 🏗️ 技术架构

- **引擎**：Godot 4.7（GDScript 严格模式）
- **分辨率**：1024×768，像素风 nearest-neighbor
- **UI**：全部 Control 节点程序化构建（ColorRect / TextureRect / Label / Button）
- **存档**：JSON 格式，`user://savegame.json`
- **星图**：HYG 星表 1637 颗星 + AstronomyAPI（在线）/ 离线 fallback

### 项目结构

```
├── scenes/              # 场景文件（空 Control + 脚本）
│   ├── main_menu.tscn
│   ├── observatory_room.tscn
│   ├── telescope_assembly.tscn
│   ├── sky_observation.tscn
│   ├── telescope_view.tscn
│   ├── learning_card.tscn
│   ├── learning_journal.tscn
│   └── story_dialogue.tscn
├── scripts/
│   ├── systems/         # 核心系统（autoload）
│   │   ├── game_manager.gd         # 中枢：场景切换、进度、评估、双语
│   │   ├── save_manager.gd         # user://savegame.json 读写
│   │   ├── mission_manager.gd      # 关卡数据加载与推进
│   │   ├── telescope_math.gd       # 望远镜性能计算
│   │   ├── assembly_manager.gd     # 组装顺序检查、完整性
│   │   ├── observation_system.gd   # 观测质量评估（含视觉特效）
│   │   ├── teaching_flow_manager.gd # 教学流程状态机（Concept Brief）
│   │   ├── story_manager.gd        # Maya 剧情层
│   │   └── localization.gd         # EN/中文双语切换
│   └── ui/              # 各场景 UI 脚本
│       ├── main_menu.gd
│       ├── observatory_room.gd     # 主大厅（979行）
│       ├── telescope_assembly_screen.gd
│       ├── sky_observation.gd      # 三段式观星（1199行）
│       ├── telescope_view.gd       # 望远镜视野（762行）
│       ├── learning_card.gd
│       ├── learning_journal.gd
│       ├── parts_cabinet.gd
│       └── story_dialogue.gd
├── data/                # JSON 数据
│   ├── levels.json                # 9个关卡 + 设计预留字段
│   ├── telescope_parts.json       # 6+ 零件数据
│   ├── celestial_objects.json     # 8个天体属性
│   ├── bright_stars.json          # HYG星表1637颗
│   ├── learning_cards.json        # 概念卡+教学图映射
│   ├── story_dialogues.json       # Maya剧情台词
│   └── celestial_catalog.json     # 天体目录
├── assets/              # 美术资源
│   ├── pixel_observatory/   # 望远镜零件 PNG（tripod/mount/tube/objective/eyepiece等）
│   ├── telescope_view/      # 天体大图（moon/jupiter/mars/orion_nebula/andromeda等）
│   ├── celestial_icons/     # 8个天体图标
│   ├── learning_diagrams/   # 11张教学图解
│   ├── characters/          # 角色头像 + 4方向像素图
│   ├── reference/           # 参考图/UI背景 mockup
│   ├── ui_extracted/        # 从参考图扣下的UI素材（金框、铭牌、道具图）
│   ├── sprout_lands/        # Sprout Lands 素材包（农场/家具/栅栏/草地）
│   └── tiny_swords/         # Tiny Swords 素材包（树木/云朵/岩石/水面）
├── tools/               # 测试 & 截图工具（17个脚本）
├── docs/                # 设计文档
│   ├── levels_10_24_design.md
│   └── PROJECT_HANDOFF.md
└── AGENTS.md            # AI Agent 项目指南（可丢给 Claude Code/Codex）
```

### Autoload 加载顺序

```
SaveManager → MissionManager → TeachingFlowManager → StoryManager → GameManager
```

---

## 🔧 已完成系统详情

### 主大厅 Observatory Room
- 完整伪 3D 天文台背景图（浮岛+水域+栅栏+悬崖+云朵）
- 角色 4 方向像素移动（WASD）
- 7 个可交互设备：Parts Cabinet、Assembly Table、Observation Pad、Mission Board、Learning Journal、Stats Terminal、Door
- 靠近才能交互（远距离点击提示"走近后再互动"）
- 任务间大厅引导（高亮下一个目标设备的 spotlight + Maya 提示卡）
- 装备解锁通知（回大厅弹 Maya 弹窗，暂停移动）
- 返回位置记忆（不从门口开始，回到上次离开的位置）

### 剧情系统 StoryManager
- Maya 作为天文俱乐部学姐导师角色
- New Game intro + L1/L3/L4 等关键节点剧情
- 链式路由：入口 → `try_story_for_trigger` → `try_teaching_intercept` → 场景
- 对话场景：Maya/玩家头像、双语、Space/Enter/点击推进
- 背景按当前任务目标显示对应天体（TARGET_VISUALS，无则纯星空，不硬编码月亮兜底）
- `consume_return_scene` 原样返回调用方，设备触发剧情直达目标场景

### 教学系统 TeachingFlowManager
- 操作前 Concept Brief（概念预习卡，操作前弹出）
- Mission Complete 后学习总结
- 状态分离：`seen_teaching_steps` / `seen_concept_briefs` / `completed_concept_cards`
- 15+ 触发时机：before_observation/before_assembly/before_focus/before_identify/before_collimation 等
- 9 张像素风教学图解（人眼成像、折射光路、焦平面、倍率视野、寻星镜对齐、口径集光等）
- 旧关卡无 teaching_steps 时自动派生 fallback

### 组装台 Telescope Assembly
- 支持零件：Tripod、Mount、Tube、Objective Lens、Eyepiece、Focus Knob、Finder Scope
- 点击式安装（左侧零件列表选零件 → 点击工作台上对应的发光安装槽）
- 安装顺序强制检查（必须先装三脚架→支架→镜筒→物镜→目镜→调焦旋钮→寻星镜）
- 错误提示（零件类型不匹配、安装顺序不对）
- 对齐评分（一次装对=100分，错一次=85分，错多次=70分）
- ScrollContainer 防止零件列表溢出
- 零件图标 UI 层绘制（不缩放原图，避免溢出）

### 零件柜 Parts Cabinet
- 查看和解锁/装备零件
- 肉眼阶段显示"还没有望远镜零件"
- 后续零件（100mm大口径物镜、10mm高倍目镜、稳定支架）解锁后显示
- 可扩展为"设备柜"界面

### 状态终端 Stats Terminal
- 显示望远镜六维性能：Assembly / Light / Clarity / Stability / Focus Control / Magnification
- 性能条视觉化展示
- Club Credits 用途说明（未来升级商店入口）

### 观星台 Sky Observation（核心亮点）
- **三段式视角切换**（肉眼/寻星镜/望远镜），按钮或 1/2/3 数字键切换
- **Az/Alt 方位角+俯仰角导航**：顶部方位角刻度带（N/E/S/W+数字）、左侧俯仰角刻度带
- **DMS 格式**（度°分′秒″）：`_format_dms()` 格式化所有角度显示
- **实时星图背景**：HYG 星表 1637 颗亮星，按当前时刻+洛杉矶坐标计算 alt/az 投影
- **SkyPositionService**：AstronomyAPI 在线获取精确天体位置 / 本地 RA-Dec / 离线 fallback
- **v2 烘焙背景**：`sky_observation_ui_bg_v2_1024.png`（用户 ChatGPT 生成 mockup 缩放），准星/圆环/模式按钮是烘焙美术+透明热区
- **SELECTED 面板**：默认显示任务目标（★），含 Target Az/Alt 与当前指向的 Δ 差异，每帧刷新
- **视角继承**：`GameManager.last_sky_aim` 在退出时存、进入时恢复（含 view_mode）
- **引导条**：底部大字引导文字镜像 guidance_label

### 望远镜视野 Telescope View
- **圆形镜筒** + 黑色外环遮罩
- **天体大图 sprite**（`assets/telescope_view/*_large.png`，只有这里显示细节）
- **调焦旋钮**（Q/E 键或鼠标拖滑条），target_focus 量化到滑条网格（snappedf 0.005）
- **三态判定系统**（单一 truth source）：
  - `is_focus_acceptable()` = focus_error ≤ focus_tolerance（不看质量）
  - `is_quality_acceptable()` = observation.success
  - `can_identify_object()` = 两者都需要
  - `_focus_state()` = 容差比例式（容差内必定 sharp）
- 深空 tolerance 0.07（比行星宽松）
- 三态文案：调焦中 / 焦点对了但质量不足 → 指向零件柜升级 / 可识别
- 质量不足文案区分原因：口径不够、组装质量差、环境限制

### Focus Knob 实体零件
- `basic_focus_knob`（type: focus_knob，L3 奖励解锁）
- 组装台目镜旁有独立槽位
- 安装顺序：tripod → mount → tube → objective → eyepiece → **focus_knob** → finder_scope
- 未装调焦旋钮时望远镜禁用调焦+拦截识别
- TelescopeMath 输出 `focus_control_score`
- 旧存档 `_migrate_progress_schema` 自动补字段

### 学习卡 Learning Card
- 两种模式：Concept Brief（操作前概念预习）+ Mission Complete（完成后学习总结）
- 教学图放大显示（不再是小缩略图）
- Mission Complete 显示：观测结果、奖励学分、学到的概念、Maya 复盘
- 装备解锁通知（NEW PARTS 列表）

### 学习日志 Club Logbook
- 卡片式列表（滚动），每条记录带颜色编码侧边条
- 质量徽章（Excellent 绿/Good 黄/Fair 橙/Poor 红）
- 双语学习文本
- 空状态提示

### 升级系统
- `objective_100mm`（100mm 大口径物镜，L7 解锁）
- `stable_mount`（稳定支架，L6 解锁）
- `eyepiece_10mm`（10mm 高倍目镜，L5 解锁）
- 零件对比显示（属性数值差异）

---

## ⚠️ 当前待修问题

1. **观星台触发剧情后不应退回大厅** — 如果玩家已经站在 Observation Pad 按 E，剧情/教学结束应直接进入 Sky Observation
2. **大厅引导不够醒目** — 需要 spotlight 效果：屏幕暗下来，目标设备区域高光，大号 Maya 提示卡
3. **L5 倍率关卡缺少新操作** — 需要 Low/Med/High 三档目镜切换机制，否则像重复观测 Jupiter
4. **Sky Observation UI 拥挤** — 右侧 Mission/Selected/Current Aim/Guidance 信息重复，需简化
5. **牛顿镜阶段不完整** — 主镜/副镜/准直/collimation 玩法仍是数据预留，L7-9 暂用折射镜零件
6. **Credits 无实际用途** — 需要升级商店系统
7. **Learning Journal 需要重构** — 建议分为 Observations / Concepts / Equipment / Reports 四个标签
8. **Orion Nebula 体验可能卡关** — 基础配置下 Quality=Fair 不能过，建议 L7 允许 Fair 通关
9. **Door 和 Observation Pad 功能重叠** — Observation Pad 应是观星入口，Door 应用剧情/屋顶
10. **天穹遮罩 PNG** — `finder_dome_overlay.png` 已被 v2 刻度带取代，文件还在但弃用

---

## 🧪 测试工具

```bash
# 编译检查（每次改完必跑）
cd "E:/godot/ai-game-0628"
"...Godot...exe" --headless --quit 2>&1 | grep "SCRIPT ERROR"

# 回归测试套件（跑前先备份存档）
for t in flow_test v2_progression_test teaching_flow_test story_flow_test sky_view_test focus_nebula_test; do
  "...Godot...exe" --headless --script "res://tools/$t.gd" 2>&1 | grep -E "PASS|FAIL" | tail -1
done
```

| 测试 | 覆盖范围 |
|------|---------|
| `flow_test.gd` | 9关端到端通关 |
| `v2_progression_test.gd` | 教学进度 + 调焦 + 星云焦点 |
| `teaching_flow_test.gd` | Concept Brief 拦截/路由 |
| `story_flow_test.gd` | Maya 剧情链 + room guidance |
| `sky_view_test.gd` | DMS 格式 + 天体位置计算 |
| `focus_nebula_test.gd` | 深空调焦可解性验证 |

---

## 📋 详细更新历史

### Phase 1 — 项目初始化（2026-06-28 ~ 06-30）

**06-28**
- 根据 Spec §30 的 19 步开发计划搭建项目
- 创建 Godot 4.7 2D 项目，1024×768 分辨率
- 建立项目结构：`scenes/`、`scripts/systems/`、`scripts/ui/`、`data/`、`assets/`

**06-29 ~ 06-30**
- **主菜单**：星空背景 + New Game/Continue/Quit + 语言切换
- **观测室**：最初版本 — 绿色校园场景，十字路径，Mission Board/Parts Cabinet/Telescope/Journal/Computer 五个交互物
- **组装台**：左面板（零件列表+图标）、中面板（工作台+望远镜轮廓+6个发光安装槽）、右面板（性能统计+反馈）
- **星空观测**：深色星空背景 + ✦ 天体按钮 + 右侧任务面板
- **望远镜视野**：圆形镜筒视觉 + 质量评级 + 天体识别选项
- **核心数据系统**：
  - `telescope_parts.json`：6 个零件（basic_tripod、basic_mount、starter_tube、objective_60mm、eyepiece_20mm、basic_finder_scope）
  - `celestial_objects.json`：8 个天体（Moon、Polaris、Sirius、Mars、Jupiter、Betelgeuse、Orion Nebula、Andromeda）
  - `levels.json`：6 个关卡
- **核心算法**：
  - `TelescopeMath`：Magnification / Light / Stability / Clarity / FOV / Assembly Score 计算
  - `AssemblyManager`：安装顺序检查、完整性判断、对齐评分
  - `ObservationSystem`：stats vs 天体要求 → 质量评级 + 视觉特效 + 反馈文本
- **SaveManager**：JSON 存取 user://savegame.json
- **GameManager**：场景切换、进度管理、双语系统、数据加载
- **Localization**：EN/EN+中文 双语切换

**06-30（下午）— 贴图 Bug 修复**
- 修复 `AtlasTexture.filter_clip`：添加 `filter_clip = true`，消除区域渗色
- 修复像素贴图渲染：`project.godot` 添加 `textures/canvas_textures/default_texture_filter=0`（nearest-neighbor）
- 修复玩家动画内存泄漏：预缓存 `player_idle_tex` / `player_move_tex`，不再每帧创建 AtlasTexture
- 所有 `%` 浮点取模改为 `fmod()`（GDScript 严格模式要求）

---

### Phase 2 — UI 重设计与美术集成（2026-07-01 ~ 07-02）

**07-01 — 观测室 v1→v2：浮岛风格**
- 导入 Sprout Lands 栅栏（`fences.png`）+ Tiny Swords 云朵、岩石、树木
- 重写观测室为浮岛风格：水域背景+云朵+草地+悬崖石柱+栅栏
- 望远镜缩小（从巨型装饰 → 120×72 组装台尺寸）
- 添加路径系统（入口→任务板/工坊→望远镜→日志）
- 添加区域名牌（📋 Mission Board、🔧 Parts Workshop、🔭 Telescope Pad 等）
- 修复草地 tileset 平铺 bug：改用纯色 ColorRect + 散落草簇装饰
- 修复栅栏 tileset 拉伸问题：改用纯色木桩 ColorRect
- 天文台建筑：从黑色空框 → 圆顶+观测窗+门
- 底部 UI 文字重叠修复：3行独立区域，英文+中文不再叠压
- 添加预提取参考图素材（`assets/ui_extracted/`：金框UI条、黄铜铭牌、道具图）

**07-02 — 观测室 v3→v4**
- 树木改用 Tiny Swords Tree1.png 精确 AtlasTexture 区域（119×190）
- 云朵改用 Tiny Swords Clouds_01.png 精确区域
- 岩石改用 Tiny Swords Rock1/2.png 独立 PNG
- **观测室 v4 最终版**：路径引导+区域分区+清晰视觉层级
- **Learning Journal 重设计**：从纯文字墙 → 卡片式列表（颜色编码侧边条+质量徽章+编号+学习文本）
- 主菜单重设计：星空+浮岛剪影+望远镜轮廓
- 组装台 UI 美化：深色工坊风格+网格底纹+蓝色点缀线
- 星空观测 UI 更新：深空背景+深色右侧面板
- 望远镜视野 UI 更新：深色观测室氛围+可读性提升
- **GitHub 上传**：初始化 git 仓库，推送到 `tntsg1/xuhuan`，后续持续 commit

---

### Phase 3 — 系统深化与可玩性（2026-07-03 ~ 07-04）

**07-03 — 深空关卡 + 升级系统**
- **L7 Collect More Light**（Orion Nebula）+ **L8 Deep Sky Challenge**（Andromeda）关卡数据
- 升级零件系统：
  - `objective_100mm`（100mm 大口径物镜，L7 解锁）
  - `stable_mount`（稳定支架，L6 解锁）
  - `eyepiece_10mm`（10mm 高倍目镜，L5 解锁）
- 零件柜装备/卸载 UI
- 头显端到端测试（`flow_test.gd`）+ 平衡性检查工具

**07-04 — 三段式观星 + 教学系统 + 剧情系统**
- **三段式观星界面重写**（1199行）：肉眼 120° / 寻星镜 28° / 望远镜 6°
- Az/Alt 方位角俯仰角导航（DMS 度分秒格式）
- HYG 星表 1637 颗星实时星图背景
- SkyPositionService（AstronomyAPI 在线 / 本地 RA-Dec / 离线 fallback）
- v2 烘焙背景 mockup 集成
- SELECTED 面板（目标方位角 + Δ差异实时刷新）
- 视角继承（离开时保存，回来时恢复）
- **TeachingFlowManager**：教学流程状态机，15+ 触发时机
- **StoryManager**：Maya 剧情层，对话场景（头像+双语+推进）
- **Focus Knob 实体零件**：L3 解锁，独立槽位，调焦滑条
- **大厅引导系统**：room_guidance 按关卡派生下一步
- **装备解锁通知**：Maya 弹窗 + NEW PARTS 列表
- **角色 4 方向像素图**（`player_observer_4dir_clean.png`）
- **9 张像素风教学图解**（人眼成像、折射光路、焦平面、倍率视野、寻星镜对齐、口径集光、反射光路、深空观测、准直对齐）
- **8 个天体图标 + 大图 sprite**（用于望远镜视野细节显示）
- **11 张教学图** 全部 Pillow 程序生成
- **5 个回归测试**全部通过
- Club Logbook 改名 + Credits 改 CLUB CREDITS

**07-04（晚）— Bug 修复马拉松**
- 修复组装台左侧零件原图溢出 → UI 层绘制简化图标
- 修复 `unlocked` 被误当成 `installed` 的问题
- 修复组装台 installed 状态来源，只读 `assembly_state.installed`
- 修复观星台/Stats Terminal/设备远距离点击直接进入的问题
- 修复大厅返回位置（不再每次回门口）
- 修复角色 spritesheet 方向和大小问题
- 修复角色与实际位置不一致的问题
- 修复大厅家具拼贴混乱 → 完整背景 + 透明交互层
- 修复观测天体全部长得一样 → 加入不同 PNG 天体图
- 修复 Telescope View 中 "Ready to identify" 和 "Quality too low" 同时出现 → 三态判定重构
- 修复学习卡教学图太小 → 放大学图解
- 修复 Mission Complete 概念卡重复/brief 重复
- 修复组装台零件数量增加后溢出 → 加入 ScrollContainer
- 修复剧情背景硬编码月亮 → 通用背景 + 按目标显示
- 新增 `focus_nebula_test.gd`：验证 Orion Nebula 在数学上可对焦
- 修复部分已完成概念卡重复弹出的问题
- 修复 L9 完成后重复弹学习卡
- 旧存档 `_migrate_progress_schema` 自动补新字段

---

### Phase 4 — 文档与交接（2026-07-04 ~ 07-05）

**07-04**
- 编写 `AGENTS.md`（AI Agent 项目指南，288行）— 可丢给 Claude Code/Codex/Cursor
- 编写 `docs/levels_10_24_design.md`：L10-L24 螺旋式重复练习关卡设计
- 编写 `docs/PROJECT_HANDOFF.md`：完整技术交接文档
- 编写 `README.md`：GitHub 项目首页

**07-05**
- README 详细化：补充完整更新历史、系统详情、测试命令
- 全部推送到 GitHub `tntsg1/xuhuan`

---

## 📝 开发约定

1. 所有面向玩家的字符串用 `GameManager.text("EN", "中文")`，不硬编码单语
2. 改完必须编译检查（`--headless --quit`），然后跑相关测试
3. GDScript 4.7 严格模式（warnings are errors）：
   - `Dictionary.get()` 返回 Variant，必须显式标类型：`var x: String = d.get(...)`
   - float 取模用 `fmod()`，`%` 只能整数
   - autoload 脚本不能用 `class_name`（加载顺序问题），消费方用 `const X = preload(...)`
   - lambda 循环变量用 `var captured := i` 捕获
4. Godot UI 坑：
   - `TextureRect.expand_mode` / `Label.autowrap_mode` 必须在设 `size` 之前设置
   - 像素图用 `TEXTURE_FILTER_NEAREST`
5. 测试会 `new_game()` 重置存档，**跑前先备份保存**：
   ```
   cp savegame.json savegame.backup.json
   ```
6. 用户交流用中文；台词/UI 双语；技术回复中文为主
7. 不要修改 autoload 结构和加载顺序
8. API 密钥（`data/local_api_keys.json`）已 gitignore，绝不打印/进日志/进截图
