# Mobile Controller Mode（移动端控制模式）

版本：2026-07-20（Round 18）。PC 键鼠输入完全不变；移动模式默认在检测到触摸屏时自动启用，也可在大厅「触控」设置里手动切换。

## 一、手机控制说明

| 游戏功能 | PC 输入 | 手机触摸 |
| --- | --- | --- |
| 大厅移动 | WASD / 方向键 | 左下角虚拟摇杆（8 方向吸附，速度与键盘一致） |
| 互动 | E | 右下角「互动」按钮（靠近可互动物体时点亮并显示物体名称） |
| 任务板 | Tab | 右下角「任务」按钮 |
| 观星台转动镜头 | 方向键 / 鼠标拖拽 | 单指拖动天空（灵敏度、俯仰反转可在设置调节） |
| 加速转动 | Shift 按住 | 左下「Boost」按住 |
| 切换 肉眼/寻星镜/望远镜 | 1 / 2 / 3 或点按钮 | 双指捏合（张开=放大一档，捏拢=缩小一档；自动跳过未安装的档位），也可直接点右侧模式按钮 |
| 寻星镜校准 | I / J / K / L | 校准关卡出现 ▲▼◀▶ 方向盘（48px 按钮，按住连续校准） |
| 调焦 | Q / E 或拖滑杆 | 望远镜画面下方 − / ＋ 按住微调（52px），焦距滑杆本身也支持触摸拖动 |
| 跟踪修正 | 方向键 | 望远镜视图内出现虚拟摇杆（漂移关卡） |
| 装配台 | 鼠标点击/拖拽 | 直接触摸（Godot 鼠标模拟，卡片、插槽、滚动、子蓝图均可点按） |
| OBSERVE / BACK / 菜单等按钮 | 鼠标 | 直接点按 |

方位/俯仰 DMS 读数、目标增量（ΔAz/ΔAlt）原本就常驻在观测界面右侧面板，拖动时实时刷新。

## 二、触摸区域布局图（1024×768 逻辑坐标，16:9 屏幕两侧信箱留边）

```
大厅 (observatory_room)
┌────────────────────────────────────────────┐
│ 顶栏 HUD               [触控 818,18] [菜单] │
│                                            │
│                （房间场景，点按物体也可互动）  │
│                                            │
│ ◯ 摇杆                        [互动 856,690]│
│ 圆心(58+r, 702−r) r=62×scale  [任务 856,624]│
│ └ 提示栏 (172,704 680×48)  按钮 168×56      │
└────────────────────────────────────────────┘

观星台 (sky_observation)
│ 天空区域 = 单指拖动 / 双指捏合                │
│ [Boost 96,686 120×48]  校准盘中心(600,658)   │
│ 模式按钮/OBSERVE/BACK 在右栏，直接点按        │

望远镜 (telescope_view)
│ 漂移关卡：左下虚拟摇杆                        │
│ [− 624,690 52×52] [＋ 684,690 52×52] 调焦    │
```

所有新增触摸控件 ≥ 44×44 px（摇杆 124px+、按钮 52–168px）。摇杆/按钮 z_index=150，浮在场景上但根节点 MOUSE_FILTER_IGNORE，不遮挡下层点击。

## 三、修改文件列表

新增：
- `scripts/systems/touch_input.gd` — TouchInput 自动加载：模式检测/设置持久化（user://mobile_controls.cfg）、virtual_move/boost_held/focus_direction/calibration_vector 状态、interact/missions 信号。
- `scripts/ui/mobile_controls.gd` — 通用覆盖层：虚拟摇杆（触摸+鼠标回退可测试）、动作按钮列（普通/按住两种）。
- `tools/mobile_controls_test.gd` — 14 项手机验收测试。
- `tools/capture_mobile_ui.gd` — 4 张移动 UI 截图工具。

修改：
- `project.godot` — 注册 TouchInput 自动加载。
- `scripts/ui/observatory_room.gd` — 摇杆并入 _move_player；互动/任务按钮及就近状态更新；「触控」设置弹窗（模式/摇杆显示/俯仰反转/提示 4 开关 + 大小/灵敏度 2 滑杆）。
- `scripts/ui/sky_observation.gd` — 拖拽灵敏度与俯仰反转（仅移动模式生效）；双指捏合换档（跳过未安装档位）；Boost 按住合并；校准方向盘。
- `scripts/ui/telescope_view.gd` — 调焦 −/＋ 按住合并进 _handle_focus_input；漂移修正摇杆回退。

关卡数据、物理、坐标系统、剧情、通关判定、存档格式：零改动。

## 四、Android 导出设置

项目侧已就绪（无需再改）：分辨率 1024×768、`stretch/mode=canvas_items`、`stretch/aspect=keep`（16:9 屏幕左右信箱留黑边，UI 不变形）；Godot 触摸模拟鼠标默认开启（装配台等点击 UI 直接可用）。

导出预设建议（Project → Export → Android）：
- Screen → Orientation: `Sensor Landscape`（横屏优先，允许 180° 翻转）
- Screen → Immersive Mode: `On`（隐藏系统栏，避免遮挡底部提示栏）
- Architectures: `arm64-v8a`（可加 armeabi-v7a 兼容旧机）
- Min SDK 24 / Target SDK 按 Godot 4.7 默认
- 渲染：当前项目 rendering driver 为 D3D12（仅 Windows）；Android 端自动回退 Vulkan/GLES，无需改动，但建议真机验证 Forward+ 性能，低端机可切 `Mobile` 渲染器
- 权限：无需网络以外权限（AstronomyAPI 在线查询可选，离线自动回退推算位置）

## 五、手机测试结果（tools/mobile_controls_test.gd，14/14 通过）

1. 虚拟摇杆向量驱动 _move_player，角色移动（与键盘同一条路径、同速）✅
2. 「互动」按钮 == E：靠近任务板点亮、显示"Mission Board"、点击打开任务板 ✅
3. 单指拖动改变方位角；灵敏度 2.0 时位移约 2 倍；捏合张开进入下一可用档、捏拢返回肉眼 ✅
4. 调焦 ＋ 按住使焦距值上升（走 _handle_focus_input 同一路径）✅
5. 摇杆大小 / 俯仰反转设置写盘后重载仍生效 ✅
6. PC 模式下 virtual_move 被忽略（move_vector() 恒为零）✅

PC 回归：40 个既有测试套件全部 PASS（flow / timeline / v2 / teaching / story / auto-equip / debug-prepare / real-position / expansion / 观测 UI / 装配 / 牛顿系 / 模态层级 / 开发者控制台等）。

窗口截图（tools/shots/）：mobile_lobby / mobile_settings / mobile_sky / mobile_telescope — 摇杆与按钮无重叠，不遮挡底部提示栏与右侧面板。

## 六、仍不适合手机的高级功能清单

- 开发者调试控制台：可以触摸操作（滚动+点按），但文字小、面向开发者，不建议玩家在手机上使用。
- 准直（collimation）精调滑杆：可触摸拖动，但 1–2% 级精调在小屏上偏难，建议手机玩家依赖「一键装备/快速准备」或把滑杆再放大（后续可选优化）。
- 键盘数字快捷键 1/2/3 换视图：手机由捏合与模式按钮覆盖，无损失。
- 长文本学习卡在 5 寸以下小屏字号偏小（≥6 寸无问题）；如需支持小屏，后续可加全局字号缩放。
- 双指以上手势（三指等）未使用，无冲突风险。
