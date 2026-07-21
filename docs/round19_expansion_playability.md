# Round 19 — 扩展内容可玩性修复（星座观测 / 望远镜选择 / 快速组装 / 扩展剧情）

日期：2026-07-20。目标：让 L92-L131、星座观测、望远镜类型选择、快速组装、扩展剧情达到主线关卡的可玩标准——玩家第一次进入即知道"现在做什么、下一步、为什么、成功得到什么"。**不修改关卡数据/物理/坐标/通关条件；不破坏 L1-L91。**

## 一、修改文件列表与作用

| 文件 | 状态 | 作用 |
| --- | --- | --- |
| `scripts/ui/constellation_observation.gd` | 重写 | 星座观测四阶段流程（识别→连线→导航→记录）+ 右侧步骤/进度/原因面板 |
| `scripts/ui/telescope_types.gd` | 新增 | 望远镜类型选择/图鉴界面（7 家族，浏览+确认两种模式） |
| `scenes/telescope_types.tscn` | 新增 | 上述界面场景 |
| `scripts/systems/game_manager.gd` | 修改 | 注册 telescope_types 场景；`uses_family_selection()`；`prepared_readiness_report()` |
| `scripts/ui/observatory_room.gd` | 修改 | 高级关卡装配台先进类型选择；HUD 新增「望远镜图鉴」按钮 |
| `scripts/ui/developer_console.gd` | 修改 | Prepare 按钮显示详细就绪报告 |
| `scripts/systems/story_manager.gd` | 修改 | 合并扩展 board_notes 子字典（修复覆盖 L1-91 的 bug） |
| `data/expansion/story_dialogues.json` | 扩充 | 23 条练习关 before + 40 条 after + 40 条 board_notes（92-131） |
| `tools/timeline_progression_test.gd` | 修改 | 乱码扫描扩展到扩展 json + 星座/望远镜脚本 |
| `tools/expansion_playability_test.gd` | 新增 | 26 项新系统验收 |

## 二、星座观测——四阶段真流程（原为"选星座→点几颗星→灰按钮"）

- **阶段 1 识别**：顶部「目标：Big Dipper / 北斗七星」+「第一步：选择与淡色轮廓一致的星座」。正确按钮**金色脉冲**；星图显示目标轮廓的淡色虚线预览；选错在右侧红字「这不是当前任务目标。请比较整个星座的形状」。选项按钮**双语**。
- **阶段 2 连线**：选对后隐藏选项，进入「第二步：连接第 N/7 颗星——跟随金色脉冲环」。下一颗待点星带**编号 + 金色脉冲环 + 箭头**；已连星变绿、已连线金色实线、未连线淡色虚线；连错提示「请先点击第 N 颗星」；完成时整条轮廓**闪光**。
- **阶段 3 导航**：「第三步：调整望远镜方向，将目标移到视野中心」。显示实时 Az/Alt；目标环在滚动窗口坐标里偏移，中心画**方向箭头**指向应移动方向；接近时提示「继续微调，目标即将居中」。支持 A/D W/S + Shift、鼠标/触屏拖动。
- **阶段 4 记录**：识别+连线+季节+锁定四条件全满足，Record 才点亮并播放高光动画；未满足时按钮旁**明确写出缺什么**（如「记录未开放：请把星座移到中心（方位差 -24.0°，高度差 12.0°）」）。记录后走 `complete_current_mission` → Mission Complete/日志。
- **右侧面板**始终显示：MISSION（目标名/类型/导航提示）、当前步骤 N/4、大字号"现在要做什么"、PROGRESS（星座识别✓/连线 3/7/方位差/高度差/季节可见性，各带绿色达成色）、Record 按钮+原因。

## 三、望远镜类型选择界面（`望远镜图鉴` 按钮 / 高级关卡装配前）

- 7 个家族：折射式 / 牛顿反射式 / 多布森 / 卡塞格林 / 格里高利 / 红外·空间 / FAST 射电。
- 每个显示：**工作原理、优点、缺点、适合目标、解锁状态**。
- 未解锁家族标 `[未解锁]` 并写出解锁关卡，不可进入。
- 任务推荐的家族标「今晚任务推荐使用」+ 原因（如"镜面能消除折射镜观测织女星时的色差，并为深空收集更多光线"），但**所有已解锁家族都能选择进入，不强制**。
- 入口：① 大厅顶栏「望远镜图鉴」随时浏览；② 高级（反射镜家族）关卡走到组装台时先进此界面确认，Build 按钮再进对应装配台。折射式/多布森等基础/特殊关卡按原路由不变。

## 四、快速组装就绪报告（开发者调试台）

`_debug_prepare_equipment()` 原本已完成主装配/镜筒子装配/准直 92/主槽安装；本轮新增 `prepared_readiness_report()` 校验实际完成度，Prepare 按钮显示：

> 当前测试设备已完整准备。主装配：完成。 镜筒内部：完成。 准直：92%。观测入口：已开放。

肉眼/星座关显示「无需装配。观测入口：已开放」。缺件时列出缺哪个槽位并标「观测入口：未开放」。

## 五、扩展剧情补全（L92-131）

- 之前只有 17 关有 before 剧情。现补齐：所有练习/重复关的 `_before`（说明今晚**改变了哪个操作条件**，如水星更高窗口/更快暮光、金星双倍率曝光、土星手动追踪 8 秒、天王星更严对焦、海王星侧视法等）。
- 所有 40 关 `_after`：第一行=Mission Complete 上 Maya 总结，第二行=下一步去哪。
- 40 条 board_notes（92-131）：任务板一句话要点。
- 修复：StoryManager 合并扩展剧情时，board_notes 子字典原被整体覆盖导致 L1-91 公告消失——改为**子字典合并**。

## 六、乱码检查结果

全项目**无真实乱码**。用户看到的 `璇嗗埆瀹屾暣褰㈢姸` 是编辑器/终端按 GBK 解码 UTF-8 的显示误判（码点校验为合法中文）。唯一命中乱码模式的文件是 `timeline_progression_test.gd` 自身的**检测模式串**。该测试的扫描范围已扩展到 `data/expansion/*.json` + `constellation_observation.gd` + `telescope_view.gd`。English 模式只显示英文，Chinese 模式显示完整中文（截图为证）。

## 七、真实坐标与推进顺序

- 星座锚定 RA/Dec，按当前时钟+站点算 alt/az；低于地平线保留教学模拟位置并在界面注明「今晚：教学模拟位置（真实位置低于地平线）」，不静默移位。星图/寻星镜/望远镜共用 `sky_position_service`。
- `campaign_order.json` 已驱动正常推进（`next_level_number`/`order_index`），扩展关穿插在旧知识之间，跳关仅开发者用；本轮确认无需改动。

## 八、测试结果

- **新增** `tools/expansion_playability_test.gd`：26 项全过（望远镜选择门控×3、解锁状态×3、各家族就绪报告×9、四阶段星座流程×11）。
- **PC 回归全绿**（本轮实跑）：observation_expansion / timeline_progression / real_position / flow / story_audit / observatory_interaction / advanced_newtonian / advanced_observatory / teaching_flow / story_flow / v2_progression / core_task_flow / mission_board / developer_console / nested_tube / sky_view / sky_observation_guidance / observation_ui_acceptance / animation_feedback / coordinate_lock / collimation_optics / focus_nebula / mobile_controls / assembly_template / debug_prepare / auto_equip / l30_guidance / identify_quiz —— 全部 PASS。
- 测试运行前后备份/还原真实存档（pre-r19 / pre-r19b）。

## 九、截图（tools/shots/）

- `r19_constellation_1_identify_en/zh` · `_2_connect_en/zh` · `_3_navigate_en/zh` · `_4_ready_en/zh`（四阶段中英各一）
- `r19_telescope_types_en/zh`（望远镜选择，推荐态）
- `r19_quick_prepare_zh`（调试台就绪报告）

## 十、仍未完成 / 已知不足（据实列出）

1. **零件托盘按家族过滤**：零件已在数据里带 `telescope_family`，零件柜有家族标签，但"类型选择 → 装配台"的交接尚未把玩家选中的家族作为过滤条件传下去——高级装配台仍读 `level.telescope_family`。真正的"选牛顿→托盘只剩牛顿+通用件"还需在 advanced_assembly 接收家族参数。
2. **行星专属贴图**：水星/天王星/海王星目前复用通用圆面贴图；操作条件（曝光/倍率/对焦/暗适应/追踪）已按行星不同，但清晰/失焦/暗弱三态贴图未逐行星区分。
3. **星座恒星悬停名**：仅在星图上以小字显示编号，无独立浮层 tooltip。
4. **望远镜图鉴无家族缩略图**：目前纯文字（原理/优缺点/目标），无光路示意图。
5. 手机竖屏：本项目为 16:9 横屏设计，竖屏未做专门适配（横屏移动模式见 Round 18 文档）。
