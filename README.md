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
│   │   ├── game_manager.gd
│   │   ├── save_manager.gd
│   │   ├── mission_manager.gd
│   │   ├── telescope_math.gd
│   │   ├── assembly_manager.gd
│   │   ├── observation_system.gd
│   │   ├── teaching_flow_manager.gd
│   │   ├── story_manager.gd
│   │   └── localization.gd
│   └── ui/              # 各场景 UI 脚本
├── data/                # JSON 数据
│   ├── levels.json
│   ├── telescope_parts.json
│   ├── celestial_objects.json
│   ├── bright_stars.json
│   ├── learning_cards.json
│   └── story_dialogues.json
├── assets/              # 美术资源
│   ├── pixel_observatory/   # 望远镜零件 PNG
│   ├── telescope_view/      # 天体大图（月球/木星/星云等）
│   ├── celestial_icons/     # 天体图标
│   ├── learning_diagrams/   # 教学图解（11张）
│   ├── characters/          # 角色头像
│   ├── reference/           # 参考图/UI背景
│   ├── ui_extracted/        # 从参考图扣下的UI素材
│   ├── sprout_lands/        # Sprout Lands 素材包
│   └── tiny_swords/         # Tiny Swords 素材包
├── tools/               # 测试 & 截图工具
├── docs/                # 设计文档
└── AGENTS.md            # AI Agent 项目指南
```

---

## 🔧 已完成系统详情

### 主大厅 Observatory Room
- 完整伪 3D 天文台背景图
- 角色 4 方向像素移动（WASD）
- 7 个可交互设备：Parts Cabinet、Assembly Table、Observation Pad、Mission Board、Learning Journal、Stats Terminal、Door
- 靠近才能交互（远距离点击提示"走近后再互动"）
- 任务间大厅引导（高亮下一个目标设备）
- 装备解锁通知（回大厅弹 Maya 弹窗）

### 剧情系统 StoryManager
- Maya 作为导师角色
- New Game intro + L1/L3/L4 等关键节点剧情
- 剧情可链入教学 brief
- 对话场景：Maya/玩家头像、双语、Space/Enter 推进
- 背景按当前任务目标显示对应天体

### 教学系统 TeachingFlowManager
- 操作前 Concept Brief（概念预习卡）
- Mission Complete 后学习总结
- 区分 `seen_teaching_steps` / `seen_concept_briefs` / `completed_concept_cards`
- 9 张像素风教学图解（人眼成像、折射光路、焦平面、倍率视野、寻星镜对齐、口径集光等）

### 组装台 Telescope Assembly
- 支持零件：Tripod、Mount、Tube、Objective Lens、Eyepiece、Focus Knob、Finder Scope
- 点击式安装（左选零件 → 点对应安装槽）
- 顺序检查 + 错误提示 + 对齐评分
- ScrollContainer 防止零件溢出

### 观星台 Sky Observation
- 三段式视角切换（肉眼/寻星镜/望远镜）
- Az/Alt 方位角俯仰角导航（DMS 格式）
- 星图刻度带 + 方位/俯仰引导
- HYG 星表实时星图背景
- AstronomyAPI 在线星体位置（离线 fallback）

### 望远镜视野 Telescope View
- 圆形镜筒 + 天体大图 sprite
- 调焦旋钮（Q/E 或鼠标滑条）
- 三态判定：焦点对准 / 质量不足 / 可识别
- 深空 tolerance 宽松（Fair 也可通关）

### 学习卡 + 日志
- Concept Brief 和 Mission Complete 两种模式
- 教学图解放大显示
- Club Logbook 记录观测 + 概念卡

---

## ⚠️ 当前待修问题

1. **观星台触发剧情后不应退回大厅** — 如果玩家站在 Observation Pad 按 E，应直达观星界面
2. **大厅引导不够醒目** — 需要 spotlight 效果（暗屏+高亮目标设备）
3. **L5 倍率关卡缺少新操作** — 需要 Low/Med/High 三档目镜切换
4. **Sky Observation UI 拥挤** — 右侧面板信息重复，需简化
5. **牛顿镜阶段不完整** — 主镜/副镜/准直玩法是数据预留
6. **Credits 无实际用途** — 需要升级商店系统
7. **Learning Journal 需要重构** — 分为 Observations / Concepts / Equipment / Reports

---

## 🧪 测试工具

```bash
# 编译检查
cd "E:/godot/ai-game-0628"
"...Godot...exe" --headless --quit 2>&1 | grep "SCRIPT ERROR"

# 回归测试（跑前备份存档）
"...Godot...exe" --headless --script "res://tools/flow_test.gd"      # 9关端到端
"...Godot...exe" --headless --script "res://tools/focus_nebula_test.gd"  # 深空调焦
```

---

## 📋 更新历史

### 2026-07-04
- 三段式观星界面（肉眼/寻星镜/望远镜 + Az/Alt 导航）
- Focus Knob 实体零件 + 调焦滑条
- TeachingFlowManager 教学流程状态机
- StoryManager Maya 剧情层
- 大厅引导系统 + 角色 4 方向像素图
- L1-L9 九关主线可完整跑通

### 2026-07-02
- 观测室 v4 浮岛布局重设计
- Learning Journal 卡片式重设计
- 主菜单 + 组装台 UI 美化
- 修复 AtlasTexture filter_clip 渗色

### 2026-06-30
- 项目初始化：Godot 4.7 2D 项目
- 基础场景搭建（主菜单、观测室、组装台、星空、望远镜视野）
- 数据系统（telescope_parts.json、celestial_objects.json、levels.json）
- 核心系统（TelescopeMath、AssemblyManager、ObservationSystem、SaveManager）
- Sprout Lands + Tiny Swords 素材集成

---

## 📝 开发约定

1. 所有面向玩家的字符串用 `GameManager.text("EN", "中文")`，不硬编码单语
2. 改完必须编译检查（`--headless --quit`），然后跑相关测试
3. GDScript 严格模式：`:=` 必须显式类型、float 取模用 `fmod()`、autoload 不用 `class_name`
4. 测试会 `new_game()` 重置存档，跑前先备份 `savegame.json`
5. 用户交流用中文，台词/UI 双语，技术回复中文为主
