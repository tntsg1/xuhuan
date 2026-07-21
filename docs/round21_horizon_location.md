# Round 21 — 地平线以下目标的观测流程与世界地图

日期：2026-07-20。当目标此刻在观测点地平线以下时,不再强行放回教学坐标,而是**真实计算高度角 → 阻止直接观测 → 推荐并前往目标已升起的观测点 → 携带新坐标进入观星界面**。不改动调焦/倍率/寻星镜/云层/视宁度/地球自转机制,不破坏 L1-L24 与装配流程。

## 一、核心规则实现

| 规则 | 实现 |
| --- | --- |
| 不再把地平线以下目标放回教学坐标 | 观测入口新增可见性闸门,低于地平线且有可达地点时改走世界地图,不再进入观星强塞教学坐标 |
| 按日期/时间/地点/RA/Dec 真实算高度角 | `SkyPositionService.visibility_at(ra,dec,lat,lon,utc)` → {altitude, azimuth, below_horizon, visible} |
| 高度<0° 禁止观测并提示 | 世界地图顶部红字 **"TARGET BELOW THE HORIZON / 目标位于地平线以下"** |
| 自动推荐可见观测点 | `recommend_location(ra,dec,sites)` 扫描 14 个真实台址,取目标最高且天空最暗者 |
| 推荐信息 | 地点名/国家/纬度/经度/目标高度角/方位角/当地时间/可见时长/Bortle/观测条件 全部显示 |
| 玩家可接受或改选 | Continue 接受推荐;点击地图任意地点改选,弧线与信息即时更新 |
| 高于最低高度才进观星 | Continue 调 `set_observing_location` 后进 sky;`target_requires_relocation()` 复检 |
| 不动既有机制 | 仅新增位置层,`get_sky_positions` 增加可选 lat/lon 参数,默认仍为主基地 |

## 二、世界地图界面（scenes/world_map.tscn）

- 深蓝像素风世界地图:大陆(经纬盒栅格化的方块大陆)、海洋、经纬线、昼夜分界带、星空背景。
- **主基地**=金色标记;**推荐点**=金色脉冲高亮 + 青色选中环;**可见地点**=绿色;**不可见地点**=暗色。
- 从当前地点到推荐点绘制**发光金色弧线**(二次贝塞尔),落点**金色定位标记下坠**并显示地点名。
- 支持鼠标拖动平移、触摸拖动/点击选点。
- 右侧信息面板列出全部推荐字段 + "★ Above the horizon - ready to observe"。

## 三、转场动画

进入世界地图时:相机式拉远(page_enter 淡入)→ 弧线飞向推荐点(easing)→ 定位标记下坠(ease-out)→ 信息落定。全程像素风、深蓝/金/青配色,昼夜带与星体带缓动。**减少动画模式**下弧线/下坠速度×3~4,保留地图/路线/地点变化但缩短时长。

## 四、教学与日志

- 首次遇到地平线以下目标,先播放 **Maya 大屏教学**(`first_below_horizon`,4 行):说明地球自转与纬度决定可见性,明确 **"什么都没坏。地球在自转……目标此刻还没升起来"**,再打开世界地图。只播一次,不重复。
- 首次完成地点选择后,Club Logbook 记录 **"地平线、纬度与观测地点 / Horizons, Latitude & Location"**(field_note 类型)。

## 五、返回与地点状态（规则 11/12）

- 进入观星界面沿用新的观测地点/日期/时间/Az/Alt/目标位置(`get_sky_positions` 用当前地点 lat/lon)。
- 返回大厅时,若不在主基地,顶部显示 **"Observing from: <地点> / 当前观测点：X"** 金色提示条 + **"Return Home / 返回主基地"** 按钮,一键回到主基地。

## 六、数据与文件

新增：
- `data/world_locations.json` — 主基地 + 14 个真实台址(莫纳克亚/帕瑞纳/拉帕尔马/赛丁泉/萨瑟兰/特卡波/阿里/甘斯山…),含名/国/纬经/Bortle/条件,横跨纬度 −55°~+78°,保证任意目标都有可见点。
- `scenes/world_map.tscn` + `scripts/ui/world_map.gd` — 世界地图界面。
- `tools/horizon_location_test.gd` — 18 项验收。

修改：
- `scripts/systems/sky_position_service.gd` — `visibility_at` / `visible_duration_hours` / `local_time_string` / `recommend_location` / `datetime_from_julian`;`get_sky_positions` 增加 lat/lon 覆盖。
- `scripts/systems/game_manager.gd` — 世界地点加载 + `observing_location`/`set_observing_location`/`reset_observing_location`/`current_target_radec`/`target_visibility`/`recommend_observation_location`/`target_requires_relocation`/`record_horizon_lesson_if_first`;注册 world_map 场景。
- `scripts/ui/observatory_room.gd` — `_enter_sky_or_relocate` 闸门 + 地点提示条/返回主基地。
- `scripts/ui/sky_observation.gd` — 用当前观测地点计算天空。
- `data/story_dialogues.json` — 新增 `first_below_horizon` Maya 教学。

## 七、验证

`tools/horizon_location_test.gd`（18 项全过）：
- 天极目标高度角=纬度(确定性几何);南/北站可见性相反 ✅
- 远南目标在主基地地平线以下、推荐南半球台址 ✅
- 下沉目标 requires_relocation=true;迁移后可见、Az/Alt 重算、不再需要迁移 ✅
- 观测地点存档往返保持;返回主基地复位 ✅
- L1 不会死锁(要么在本地可见,要么有可达地点) ✅
- 世界地图加载 14 地点并绑定目标 ✅

截图:`tools/shots/r21_world_map.png`(地平线以下 + 弧线 + 推荐面板)、`r21_lobby_relocated.png`(地点提示条 + 返回主基地)。

## 八、仍存在/已知不足

1. 大陆为经纬盒栅格化方块,识别度足够但非精细海岸线。
2. 推荐取"目标最高"的几何最优,可能落在当地白天(当地时间仅作说明;游戏观星视图本就不建模日光,与既有最低高度模型一致)。
3. 迁移仅按地平线可见性,不强制当地夜晚。
4. `local_time` 按经度粗算(15°/时),非时区数据库。
