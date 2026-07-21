# Round 22 — 自由观测非任务天体 + 天体详情面板

日期：2026-07-20。在保留任务目标机制的前提下,允许玩家选择并观测星空中任意可见天体。任务目标与自由目标在数据层用 `is_mission_target` / `is_free_observation` 明确区分,自由观测**永不完成/失败当前任务、不触发识别题**,单独记入日志。

## 一、任务观测 vs 自由观测

| | 任务目标 | 自由目标 |
| --- | --- | --- |
| 判定 | `selected_object_id == current_target_object_id()` | `GameManager.is_free_observation()`==true |
| 详情面板边框 | 金色 + "MISSION TARGET / 任务目标" | 青色 + "FREE OBSERVATION / 自由观测" |
| 望远镜界面 | 识别题 → 观测成功推进任务 | **无识别题**,自由结果 + "加入日志" |
| 完成记录 | 任务完成 + Mission Complete | `entry_kind="free_observation"` 日志,+5 积分 |
| 关卡推进 | 是 | 否(不解锁、不跳剧情、不误判) |
| 光学机制 | 定位/瞄准/寻星镜/调焦/倍率/视宁度/云层/漂移全保留 | 完全相同 |

## 二、完整流程

**任务观测**:选中任务目标 → 详情金框 → OBSERVE → 望远镜识别题 → 正确+质量达标 → 任务完成。

**自由观测**:点击星图中任意可见天体 → 详情青框(资料/建议/知识)→ OBSERVE → 望远镜自由界面(同样的调焦/倍率/视宁度/漂移)→ "自由观测" 结果 → "加入日志"(+5 积分)/ "返回星图"。返回后保留观测地点、时间、设备与选择。重复同一天体+同设备+同质量不重复记录;换目镜/望远镜/质量则记为"新的观测记录"。

## 三、右侧天体详情面板（可滚动）

由星图右侧的 **「Details / 详情」** 按钮打开,`ScrollContainer` 结构:
- **固定顶部**:天体名(EN / 中文)、类别、任务/自由徽章(金/青边框)。
- **可滚动中部**:天文资料(视星等、RA、Dec、方位角、高度角、可见性、观测地点、当地时间)+ 观测建议(按天体类型和当前设备动态生成:低倍/广角/暗适应/侧视/降倍/等待视宁度/云层提示)+ 科学知识。文本自动换行,鼠标滚轮 + 手机单指滑动。
- **固定底部**:Observe / Back。
- 不可见目标可见性显示 "地平线以下 / 高度过低";可见显示 "当前可见"。

## 四、与观测地点系统结合

自由目标同样遵守地平线规则:`object_detail()` 用当前观测地点 lat/lon 实时算高度角/方位角/可见性;地平线以下时面板明确显示原因,可经世界地图换点后重算(沿用 Round 21 的推荐 + 弧线动画)。不因"自由观测"绕过真实位置计算。

## 五、修改与新增文件

新增：
- `tools/free_observation_test.gd` — 19 项验收。
- `tools/shots/r22_detail_mission.png`（金框任务）、`r22_detail_free.png`（青框自由）。

修改：
- `scripts/systems/game_manager.gd` — `is_free_observation()`、`object_detail()`（名/类/星等/RA/Dec/Az/Alt/可见性/地点/当地时间 + 任务标记）、`observation_advice()`（按类型+设备+环境）、`record_free_observation()`（distinct entry_kind + 签名去重 + 5 积分)、`dict_text_for()`。
- `scripts/ui/sky_observation.gd` — 「详情」按钮 + 可滚动详情面板(`_open_detail_panel`/`_close_detail_panel`/`_visibility_phrase`/`_dsection`/`_drow`);选中即刷新已开面板。
- `scripts/ui/telescope_view.gd` — `is_free_observation` 分支:`_build_free_observation_panel()`(替代识别题)+ `_add_free_observation_to_logbook()`。

现有点击选中任意天体的基础设施(每个天体一个透明按钮 → `_select_object`)已存在,故非任务天体的选择/定位/观测直接可用。

## 六、测试结果

`tools/free_observation_test.gd`（19 项全过）：
- 选非任务天体判定为自由;选任务目标不是自由 ✅
- object_detail 区分任务/自由并带天文数据;建议正常生成 ✅
- 自由望远镜界面**无识别题** ✅
- 自由观测**不推进关卡、不标记完成** ✅
- 自由记录 entry_kind 独立;相同设置去重;不同质量为新记录 ✅
- 任务目标仍正常完成 ✅
- 地平线以下自由目标报告不可见 ✅
- Back 设置 observatory spawn=telescope(不误回组装台）✅

回归全绿:free_observation / horizon_location / flow / v2 / teaching / story / core_task / sky_view / sky_observation_guidance / observation_ui_acceptance / coordinate_lock / focus_nebula …（未破坏任务识别与 L1-L24 流程）。

## 七、仍未完成/已知不足

1. 详情面板为「Details 按钮打开的滚动浮层」,而非把右侧烘焙木框面板整体替换(木框面板区域烘焙在背景里,整体替换风险高);滚动/固定顶底/换行/双语均满足。
2. 自由观测的"结果卡"较简：文字结果 + 加入日志,未做独立的图文结果卡场景。
3. 点击天体的金/青名称标签与扫描环动画为基础实现(选中即刷新面板),未做逐段淡入的富动画。
4. `object_detail` 的距离/所属星座字段:数据源未含,面板暂显示已有字段(星等/RA/Dec/Az/Alt 等)。
5. 月球/行星走在线实时定位(has_coords=false 时显示 "Live"),其地平线判定依赖在线数据可用性。
