# Pixel Observatory — 项目交接文档

> 给接手的 agent：这份文档描述当前项目状态、架构、约定和坑。开工前请通读。
> 最后更新：2026-07-04

---

## 0. 项目一句话

**Pixel Observatory / 像素观测站** —— Godot 4.7 的 2D 像素风天文观测教育游戏。
玩家扮演加入学校天文俱乐部的新生，在学姐 Maya 带领下从肉眼观测一步步学到深空追踪。
纯本地运行（除可选的 AstronomyAPI 实时星图），双语 EN/中文。

---

## 1. 环境与命令

- **项目路径**：`E:\godot\ai-game-0628`
- **Godot exe**：`C:\Users\tntsg\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe`
- **存档路径**：`%APPDATA%\Godot\app_userdata\Pixel Observatory\savegame.json`
  （Bash 里：`$APPDATA/Godot/app_userdata/Pixel Observatory/savegame.json`）
- **平台**：Windows / PowerShell + Bash 均可

### 编译检查（每次改完必跑）
```bash
cd "E:/godot/ai-game-0628" && "C:/Users/tntsg/Downloads/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64.exe" --headless --quit 2>&1 | grep -iE "SCRIPT ERROR"
# 无 SCRIPT ERROR 即通过
```
注意：`--headless --import` 会报一堆 `"Spawning" Parse Error` —— 那是遗留的
`addons/BulletUpHell` 模板残留，**与本项目无关，正常运行不触发，忽略**。

### 跑单个场景
```bash
"...Godot...exe" --headless "res://scenes/sky_observation.tscn" --quit-after 90 2>&1 | grep -c "SCRIPT ERROR"
```

### 截图验证（不加 --headless，脚本自己 quit）
```bash
"...Godot...exe" --script res://tools/capture_xxx.gd
# 图存到 user:// 即上面的存档目录，用 Read 工具看
```

---

## 2. 关键约定（GDScript 4.7 严格模式 = warnings are errors）

1. `Dictionary.get()` 返回 Variant，**必须显式标类型**：`var x: String = d.get(...)`，不能 `:=`
2. **float 取模用 `fmod()`**，`%` 只能整数
3. **autoload 脚本不能用 `class_name`**（加载顺序问题），消费方用 `const X = preload(...)`
4. **所有面向玩家的字符串用 `GameManager.text("EN", "中文")`**，不硬编码单语
5. **Godot UI 坑（踩过多次）**：`TextureRect.expand_mode` / `Label.autowrap_mode` 必须在
   设 `size` **之前**设置，否则最小尺寸把节点顶回原大 / 文字撑宽标签
6. UI 全部程序化构建（Control + ColorRect/Label/Button），场景文件基本是空 Control + 脚本
7. 分辨率 1024×768，像素图用 `TEXTURE_FILTER_NEAREST`
8. **改完必须编译检查 + 跑相关测试**；测试会 `new_game()` 重置存档，**跑前先备份 savegame.json**

---

## 3. Autoload（顺序重要，见 project.godot）

```
SaveManager           user://savegame.json 读写
MissionManager        关卡数据加载
TeachingFlowManager   概念预习卡（Concept Brief）状态机
StoryManager          Maya 剧情层
GameManager           中枢：场景切换、进度、评估、双语（依赖前面所有）
```
StoryManager 在 GameManager 之前，因为 GameManager._ready 会用到；但两者互相
`get_node_or_null` 引用运行时安全。**不要改 autoload 结构**，所有场景依赖 GameManager。

---

## 4. 已完成的系统（按重要性）

### 4.1 九关教学主线（levels.json，当前只到 L9）
| 关 | 模式 | 目标 | 教学点 |
|----|------|------|--------|
| L1-2 | naked_eye | moon, polaris | 肉眼成像、肉眼极限 |
| L3 | telescope | moon | 折射镜组装（物镜/目镜） |
| L4 | telescope+focus | jupiter | 调焦/焦平面 |
| L5 | telescope+focus | jupiter | 倍率代价 |
| L6 | telescope | sirius | 寻星镜 |
| L7-8 | telescope+focus | orion_nebula | 反射镜/口径/集光 |
| L9 | telescope+focus | andromeda | 深空挑战 |

关卡字段：`observation_mode` / `equipment_stage` / `requires_telescope` /
`requires_focus` / `required_concept_card` / `teaching_steps` / `required_parts` /
`unlock_parts` / `unlock_equipment_stage` / `minimum_success_quality` / `badge`。

### 4.2 三段式观星界面（sky_observation.gd，1199 行）
按 **1/2/3 或图标按钮**切换视角：
- **Naked Eye 120°×70°**：广角扫天，深空天体是暗斑
- **Finder 28°×18°**：中视野对准
- **Telescope 6°×4°**：窄视野，目标居中 ≤0.5° 才能进 Telescope View

WASD/方向键旋转（Az/Alt），Shift 加速；顶部方位角刻度带（N/E/S/W+数字）、
左侧俯仰角刻度带，全部 DMS 格式（`_format_dms`）。真实星空背景来自
`data/bright_stars.json`（HYG 星表 1637 颗，按当前时刻+洛杉矶坐标算 alt/az）。
天体位置来自 SkyPositionService（AstronomyAPI 在线 / 本地 RA-Dec / 离线 fallback）。

**背景是 v2 版**：`assets/reference/sky_observation_ui_bg_v2_1024.png`（用户 ChatGPT 生成的
mockup 缩放而来）。烘焙的准星/圆环中心在 (403,383)=VIEW_RECT 中心；EYE/FINDER/SCOPE
按钮是烘焙美术+透明热区+描金框覆盖；MISSION/SELECTED 面板内容动态填。
关键常量：`VIEW_RECT`/`AZ_BAND`/`ALT_BAND`/`MODE_RECTS`/`OBSERVE_RECT`/`BACK_RECT`。

**SELECTED 面板 = 任务目标面板**：默认显示任务目标（★），Target Az/Alt + 与当前
指向的带符号 Δ，每帧刷新；点其它天体临时查看。**视角继承**：`GameManager.last_sky_aim`
在 `_exit_tree` 存、`_ready` 恢复（含 view_mode），new_game 重置。
视野内底部有**大字引导条**镜像 guidance_label。

### 4.3 Telescope View（telescope_view.gd，762 行）
圆形镜筒 + 大像素 sprite（`assets/telescope_view/*_large.png`，只有这里显示细节）。
调焦滑条（Q/E 或鼠标）。**判定拆成单一 truth source**：
- `is_focus_acceptable()` = 只看 `focus_error <= focus_tolerance`（不看质量）
- `is_quality_acceptable()` = 只看 `observation.success`
- `can_identify_object()` = 两者都要
- `_focus_state()` = 容差比例式（容差内必定 sharp）
- target_focus 量化到滑条网格（snappedf 0.005），保证能精确拖到
- 深空 tolerance 0.07；三态文案：调焦/焦点对了但质量不足/可识别
- 深空质量不足文案指向零件柜升级

### 4.4 Focus Knob 实体部件
`basic_focus_knob`（type focus_knob，unlock L3 奖励）。组装台目镜旁有槽位，
安装顺序 tripod→…→eyepiece→focus_knob→finder_scope。未装时望远镜禁用调焦+
拦截识别。TelescopeMath 输出 `focus_control_score`。旧存档 `_migrate_progress_schema` 补字段。

### 4.5 TeachingFlowManager（教学流程状态机）
关卡的 `teaching_steps`（id/card_id/trigger/mode/required_once），trigger 有
before_observation/before_assembly/before_focus/before_identify/before_collimation。
UI 入口调 `GameManager.try_teaching_intercept(trigger, scene)`。
`seen_teaching_steps`（看过 brief）≠ `completed_concept_cards`（任务完成才解锁 Journal）。
learning_card.gd 模式驱动（brief / complete）。旧关卡无 teaching_steps 自动派生 fallback。

### 4.6 StoryManager（Maya 剧情层）
`data/story_dialogues.json`（intro + 每关 before/after + board_notes）。链式顺序：
**入口 → try_story_for_trigger → try_teaching_intercept → 场景**。
`story_dialogue.gd` 对话场景（Maya/player 头像、双语、Space/Enter/点击推进），
背景按当前任务目标显示对应天体（TARGET_VISUALS，无则纯星空，**不用 Moon 兜底**）。
**关键路由规则**：设备触发的剧情/brief **直达目标场景**（consume_return_scene 原样返回）；
只有 New Game intro 和任务完成才回大厅设 room guidance。

### 4.7 大厅引导 + 交互（observatory_room.gd，979 行）
- **room guidance**：`GameManager.room_guidance_target/title/hint`，任务完成后
  `update_room_guidance_for_level()` 按关卡派生下一步；到达目标场景 `go()` 自动清除
- **靠近才能交互**：`_click_interactable` 远处点击只提示"靠近后互动"，需按 E
- **Mission Board / Stats Terminal 弹窗**：任务板显示 Club Mission/Maya's Note/
  Objective/Equipment/Concept；统计终端显示性能条 + Club Credits 用途说明（升级商店"敬请期待"）
- **装备解锁通知**：`pending_unlock_notice` → 任务完成卡显示 NEW PARTS +
  回大厅弹 Maya 弹窗（暂停移动，`take_pending_unlock_notice` 消费）
- 角色 4 方向像素图，脚底锚点 `PLAYER_FOOT_Y`，等比缩放

### 4.8 其它
- **ObservationSystem**：evaluate(stats, obj, extra_context)，naked_eye 分支只看亮度，
  telescope 分支 focus_error 扣 clarity，`minimum_success_quality` 控制成功门槛
- **升级件**：objective_100mm / stable_mount / eyepiece_10mm（L5-7 解锁）
- **Journal 改名 Club Logbook**，Credits 改 CLUB CREDITS
- 9 张学习图解 `assets/learning_diagrams/`、8 个天体图标、大 sprite —— 都是 Pillow 程序生成

---

## 5. 测试工具（tools/，都会 new_game 重置存档 → 跑前备份！）

**回归套件（改动后必跑相关的）**：
| 测试 | 覆盖 |
|------|------|
| `flow_test.gd` | 9 关端到端通关 |
| `v2_progression_test.gd` | 教学进度 + 调焦 + 星云焦点 |
| `teaching_flow_test.gd` | Concept Brief 拦截/路由 |
| `story_flow_test.gd` | Maya 剧情链 + room guidance |
| `sky_view_test.gd` | DMS 格式 + 天体位置 |
| `focus_nebula_test.gd` | 深空调焦可解性 |

标准跑法（备份+还原）：
```bash
SAVE_DIR="$APPDATA/Godot/app_userdata/Pixel Observatory"
cp "$SAVE_DIR/savegame.json" "$SAVE_DIR/savegame.backup.json"
for t in flow_test v2_progression_test teaching_flow_test story_flow_test sky_view_test focus_nebula_test; do
  "...Godot...exe" --headless --script "res://tools/$t.gd" 2>&1 | grep -E "PASS|FAIL" | tail -1
done
cp "$SAVE_DIR/savegame.backup.json" "$SAVE_DIR/savegame.json"
```

**capture_*.gd** 是截图工具，用来目视验证 UI，非回归。

---

## 6. 待办 / 下一步

### 已设计未实现：L10-L24（见 `docs/levels_10_24_design.md`）
**螺旋式重复练习结构**：不再一关一新概念，而是每 3-5 关一个主题反复变形。
- Ch3 (L10-13) 调焦与倍率掌握
- Ch4 (L14-17) 寻星镜与星空导航
- Ch5 (L18-21) 集光与暗弱天体
- Ch6 (L22-24) 追踪与耐心

实现分三批：🟢 纯数据文案(L12/14/16/18/19) → 🟡 轻量扩展(倍率切换/seeing/随机/光污染) →
🔴 新机制(校准玩法 L15、漂移+追踪+驻留 L22-24 一套系统三关复用)。
新字段建议：`chapter_id`/`lesson_thread`/`practice_step`/`variation`/
`repeat_target_reason_en/zh`/`next_action`/`next_guidance_en/zh`。
**防重复感核心**：每个重复目标关卡的 `repeat_target_reason` 必须在任务板和剧情第一句展示。

### 其它未做
- Newtonian 反射镜零件仍是数据预留，L7-9 暂用折射镜零件顶替
- 寻星镜校准、collimation 玩法未做（before_collimation trigger 已就绪）
- 天穹遮罩 PNG(finder_dome_overlay) 已弃用（被 v2 刻度带取代），文件还在

---

## 7. ⚠️ 重要提醒

1. **大量工作未提交 git**：git 最新 commit 是 `fd0f370`（L7-8 时期），之后的三段式观星、
   Focus Knob、TeachingFlow、StoryManager、v2 背景、所有 UX 修复**全部未 commit**。
   接手 agent 若要 commit 需先 `git add` 并写清楚；用户没要求前不要主动 commit。
2. **API 密钥**：`data/local_api_keys.json`（已 gitignore），secret 绝不打印/进日志/进截图。
3. **每轮改完**：编译检查 → 跑相关测试（备份存档）→ 需要时截图目视验证。
4. **记忆文件**：`C:\Users\tntsg\.claude\projects\E--godot\memory\pixel-observatory-status.md`
   有跨会话的状态摘要，可参考但以代码现状为准。
5. 用户交流用中文；台词/UI 双语；技术回复中文为主。
