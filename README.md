# 🔭 Pixel Observatory / 像素观测站

> **这不是选择题。这不是点击观星。**
>
> 你要亲手组装望远镜——拧上物镜、装上目镜、校准寻星镜、调焦——然后你看到的天体画面**真的会因为你装得好不好而变清晰或变模糊**。
>
> 地球在转，大气在抖，云层会飘过来。16-bit 像素风。纯本地。双语。
>
> *"The Moon is bright enough to take the power. But every new eyepiece needs a new focus."* — Maya

---

## 🎮 核心玩法

```
肉眼观测 → 组装折射望远镜 → 调焦 → 掌握倍率 → 寻星镜导航 → 深空观测 → 追踪天体
```

**三段式观星**：Naked Eye（120°×70° 广角扫天）→ Finder Scope（28°×18° 中视野对准）→ Telescope（6°×4° 窄视野识别）

---

## 🗺️ 24 关主线

| 章节 | 关卡 | 主题 | 核心知识点 |
|------|------|------|-----------|
| Ch1 入门 | L1-L2 | 肉眼观测月亮/北极星 | 人眼成像、肉眼极限 |
| Ch2 折射镜 | L3-L6 | 组装折射镜→调焦→倍率→寻星镜 | 光路、焦平面、倍率代价 |
| Ch3 倍率掌握 | L10-L13 | 三档目镜切换→低空seeing→月亮高倍→自主选择 | 倍率不是越高越好 |
| Ch4 导航 | L14-L17 | 坐标导航→寻星镜校准→窄视野困境→独立导航 | Eye→Finder→Scope |
| Ch5 深空 | L7-L9, L18-L21 | 反射镜→口径→暗适应→光污染 | 深空观测、期望管理 |
| Ch6 追踪 | L22-L24 | 地球自转漂移→追踪架→长时间驻留 | 从操作者到观测者 |

---

## 🏗️ 技术架构

```
Pixel Observatory (Godot 4.7, 1024×768)
├── Autoload (加载顺序)
│   ├── SaveManager          ── user://savegame.json 读写
│   ├── MissionManager       ── 关卡数据加载
│   ├── TeachingFlowManager  ── 概念预习卡状态机
│   ├── StoryManager         ── Maya 剧情层
│   └── GameManager          ── 中枢：场景切换、进度、评估、双语
├── scripts/ui/              ── 全部 UI 场景（程序化 Control 构建）
├── scripts/systems/         ── 核心系统（观测/组装/数学/星空）
├── data/                    ── JSON 数据（关卡/零件/天体/剧情/学习卡）
├── assets/                  ── 美术素材
│   ├── telescope_parts/     ── 11 张正式零件图
│   ├── telescope_view/      ── 天体三态贴图（clear/blurry/dim）
│   ├── learning_diagrams/   ── 教学图解
│   ├── reference/           ── 参考图与 UI 背景
│   └── ui_extracted/        ── 抠好的 UI 框架与道具
└── tools/                   ── 6 个自动化测试
```

---

## 🔧 系统详情

### 1. 双语语言系统
- 中文/英文/双语三模式切换
- UI、剧情、教学、任务、零件名称同步切换
- 全部文本统一通过 `GameManager.text()` 管理
- 所有 10 个 UI 场景连接 `language_changed` 信号自动重建

### 2. 主观测室
- 完整伪 3D 天文台背景替代错误的家具切片拼装
- 修复家具互相覆盖
- 调整零件柜、组装台、任务板、观测台、日志和统计终端位置

### 3. 主角系统
- 接入像素人物素材，上下左右四方向 + 行走动画
- 分离显示尺寸和碰撞尺寸
- 修正角色碰撞与实际脚底位置

### 4. 大厅交互和碰撞
- 缩小家具碰撞范围，修复碰到家具后无法左右移动
- 远距离点击不再直接进入界面，必须靠近后按 E
- 修复交互后返回错误位置

### 5. Mission Board 任务中心
- 显示当前目标、任务描述、设备需求、准备状态和任务步骤
- 增加 Show Route 大厅目标高亮、方向箭头、距离提示和奖励预览

### 6. 大厅路线引导
- 观测、组装、日志、任务板和统计终端均可作为下一步目标
- 靠近目标后切换为 E 提示
- 任务完成后自动设置下一步路线

### 7. StoryManager 剧情系统
- 引入 Maya 导师，New Game 开始时播放加入天文俱乐部剧情
- 增加观测前、组装前、调焦前剧情和任务完成后 Maya 复盘

### 8. TeachingFlowManager 教学状态机
- 教学、剧情和关卡完成状态分开记录
- 支持一关多个教学步骤，已看过的教学不重复弹出
- 增加 12 张像素风教学图解卡

### 9. 组装台系统
- 修复 Unlocked 和 Installed 状态分离
- 增加 11 张正式零件图标，修复安装顺序和错误零件安装
- 增加调焦旋钮和寻星镜，安装后性能实时计算

### 10. 调焦系统
- 调焦旋钮必须实际安装后才允许观测
- 失焦产生重影、模糊和清晰度下降
- Q/E 或滑条调焦，不同天体使用不同调焦容差

### 11. 观星界面
- 肉眼、寻星镜和主望远镜三模式，支持视角切换
- 方位角/俯仰角 + DMS 显示，目标选择与任务目标比较

### 12. 天体视觉表现
- 月球、火星、木星、恒星、星云和星系使用不同贴图
- 木星和火星增加清晰/模糊/变暗三态
- 圆形遮罩、倍率适配

### 13. 环境拟真效果
- 大气扰动（turbulence shader）、视宁度（seeing）、云层移动和遮挡
- 光污染（sky_brightness）、暗适应（dark adaptation）、侧视法（averted vision）
- 地球自转漂移（drift）、追踪架和追踪速率

### 14. 观测完成和日志系统
- Mission Complete 界面：奖励、徽章和概念知识
- Club Logbook 替代百科式日志
- 日志保存设备、倍率、环境、操作和结果

### 15. 统计终端
- 望远镜性能显示、观测历史、社团积分
- 发现数量和已解锁设备/知识卡

### 16. 24 关基础教学主线
- L1-L2 肉眼观测 → L3-L6 折射镜 → L7-L9 深空入门
- L10-L13 倍率和目镜比较 → L14-L17 坐标导航和寻星镜校准
- L18-L21 星云、口径、暗适应和光污染 → L22-L24 追踪和长时间观测

### 17. L25-L45 高级内容框架
- 牛顿反射式、多布森式、卡塞格林式、格里高利式
- 空间分段反射镜、红外观测、FAST 射电观测和多波段综合观测
- 高级零件数据和场景框架（部分仍是占位素材）

### 18. 高级组装和子蓝图
- 高级主组装台和光学镜筒子蓝图
- 准直界面、FAST 射电观测界面、多波段证据选择界面
- 正在修正：接入正式牛顿反射式蓝图替代 Agent 占位图

---

## 版本进度记录

### v0.1 - 项目初始化

- 建立 Godot 4.7 项目
- 建立主菜单、观测室、组装台、观测界面、学习卡基础场景
- 建立 GameManager、SaveManager、TelescopeMath、AssemblyManager、ObservationSystem
- 支持本地 JSON 存档

### v0.2 - 第一版观测流程

- 任务系统和关卡数据雏形
- 组装台按顺序安装基础零件
- Telescope View 支持识别目标
- Learning Journal 记录观测结果

### v0.3 - UI 大厅与日志重构

- Observatory Room 改成更完整的像素天文台大厅
- 学习日志改成卡片式记录
- 主菜单和组装台视觉初步优化
- 增加更多任务和基础升级零件

### v0.4 - SkyPositionService 与真实天空数据

- 增加 SkyPositionService
- Moon / Mars / Jupiter 支持 AstronomyAPI 在线位置
- Polaris / Sirius / Betelgeuse / Orion Nebula / Andromeda 使用本地 RA/Dec 计算

### v0.5 - Finder Scope / 局部视野

- Sky Observation 从全天固定星图改成可旋转望远镜视野
- 支持 azimuth / altitude 控制和 FOV 判定
- 使用 shortest_angle_degrees 处理 0/360 度跨界

### v0.6 - Telescope View 视觉与识别修复

- Telescope View Back 返回 Observatory，不再错误返回 Assembly
- Identify 选项限制为最多 4 个
- 星体显示改用 PNG 图像，不再用几何图形拼

### v0.7 - 玩家比例与大厅交互修复

- 修正 Observatory Room 玩家角色比例
- 保持脚底锚点和交互范围稳定

### v1.0 - Pixel Observatory v2 教学主线

- 重新规划 L1-L9，加入 naked eye observation、equipment_stage、focus training
- 学习卡支持图解

### v1.1 - Teaching Flow State Machine

- 新增 TeachingFlowManager，使用 teaching_steps 数据驱动教学卡
- 区分 seen brief 和 completed concept card

### v1.2 - Focus Knob 成为真实零件

- basic_focus_knob 加入 telescope_parts.json
- L4 之后需要安装 Focus Knob 才能调焦

### v1.3 - Story System / Maya 剧情框架

- 新增 StoryManager 和 story_dialogues.json
- 引入 Maya 作为天文俱乐部导师

### v1.4 - 三段式 Sky Observation

- 支持 Naked Eye / Finder Scope / Telescope Alignment 三模式
- Guidance 显示具体转动角度

### v1.5 - Focus 与 Quality 判定拆分

- is_focus_acceptable() 只判断调焦
- is_quality_acceptable() 只判断观测质量
- 修复 Orion Nebula 永远像无法对焦的问题

### v1.6 - 流程体验修复

- 修复剧情/教学从设备触发后又退回大厅的问题
- 大厅增加下一步引导和目标高亮
- 远距离点击家具不再直接进入界面

### v1.7 - Main Menu 重做

- 主菜单替换为 Starlight Observatory 风格标题画面

### v1.8 - L10-L24 章节规划与数据扩展

- L10-L24 螺旋式重复练习结构
- 新增 chapter_id、lesson_thread、practice_step、variation 等数据字段

### v1.9 - Parts Cabinet 与 Telescope Assembly 视觉升级

- 零件柜重做为可滚动装备列表
- 新增 11 张正式零件图
- 组装台使用正式零件图，删除粗糙几何零件图

---

## 📋 详细更新日志

| 日期 | 更新内容 |
|------|---------|
| 2026-07-06 | 开始加入全局中英文切换，改造主菜单、观测室、组装台、零件柜、观星界面和学习日志 |
| 2026-07-06 | 修复语言切换后界面不刷新、硬编码英文、中文乱码和部分编译错误 |
| 2026-07-06 | 完成主要 UI 的双语文本统一，改用 `GameManager.text()` |
| 2026-07-06 | 观测界面加入双语标题、识别按钮、质量等级、模式按钮和返回按钮 |
| 2026-07-06 | 零件柜、组装台、日志和统计界面完成双语化 |
| 2026-07-06 | 学习日志重新设计，加入双语标题、质量标签和知识内容 |
| 2026-07-07 ~ 08 | 修复大厅家具比例、主角大小、碰撞箱、人物方向和交互位置 |
| 2026-07-07 ~ 08 | 主观测室改为完整伪 3D 背景，减少家具切片覆盖和错误交互区域 |
| 2026-07-08 | 加入大厅路线高亮、目标暗化、箭头和靠近设备后的 E 提示 |
| 2026-07-08 ~ 09 | 完成剧情系统、Maya 导师、教学拦截和任务完成后的下一步引导 |
| 2026-07-09 | Git 提交确认完整国际化完成，所有主要 UI 场景支持语言切换 |
| 2026-07-09 ~ 10 | 完成 Mission Board 任务中心，加入任务目标、设备需求、检查清单、奖励预览和显示路线 |
| 2026-07-10 | 完成核心流程测试：任务板 → 大厅路线 → 设备交互 → 观测 → 结算 → 下一关路线 |
| 2026-07-10 | 增加任务板动态内容：倍率比较、寻星镜校准、深空观测、暗适应、追踪支架和地球自转 |
| 2026-07-10 | 增加环境拟真机制：大气扰动、云层、光污染、暗适应、侧视法、漂移和追踪 |
| 2026-07-10 | 新增 L25-L45 高级关卡数据框架 |
| 2026-07-10 | 新增高级组装台、准直界面、FAST 射电观测界面和多波段证据选择界面 |
| 2026-07-10 | 新增高级零件数据和 placeholder 图集 |
| 2026-07-10 ~ 11 | 加入光学镜筒子蓝图概念，实现"主组装台 → 镜筒子蓝图 → 完整镜筒组件" |
| 2026-07-11 | 生成高级望远镜组装台概念图 |
| 2026-07-11 | 抠出牛顿式支架、主镜、副镜蜘蛛、调焦座、准直盖、目镜等独立零件 PNG |
| 2026-07-11 | 生成格里高利赤道仪支架和 18mm 高对比目镜 |
| 2026-07-11 | 生成新版牛顿反射式蓝图界面，补齐主镜、副镜、镜座、蜘蛛支架、调焦座、准直盖等槽位 |
| 2026-07-11 | 正在修正 Agent 使用错误占位图、蓝图图片过大、主蓝图裁切、动态 UI 覆盖和子蓝图接入问题 |

---

## 📊 当前开发阶段

```
✅ 已完成：
- 双语系统
- 基础大厅
- 基础组装
- 24 关基础关卡
- 教学和剧情框架
- 观测环境机制
- Mission Board
- 任务路线引导
- 高级关卡数据框架
- FAST 和多波段玩法初版

⚠️ 正在完善：
- 牛顿反射式正式蓝图
- 独立零件 PNG 接入
- 镜筒子蓝图
- 高级望远镜真实组装
- 大气扰动和云层的实机视觉效果
- L25-L45 的完整主流程接入

❌ 尚未完成：
- 完整牛顿式反射镜零件组装体验
- 多布森、卡塞格林、格里高利的正式独立零件
- 韦伯红外正式素材和完整玩法
- FAST 完整射电任务流程
- Web 版本正式导出和浏览器测试
```

---

## 🧪 测试与验证

```bash
# 编译检查
C:/Users/tntsg/Downloads/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64.exe --headless --quit

# 自动回归测试
C:/Users/tntsg/Downloads/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64.exe --headless --script res://tools/flow_test.gd
C:/Users/tntsg/Downloads/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64.exe --headless --script res://tools/v2_progression_test.gd
C:/Users/tntsg/Downloads/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64.exe --headless --script res://tools/teaching_flow_test.gd
C:/Users/tntsg/Downloads/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64.exe --headless --script res://tools/story_flow_test.gd
C:/Users/tntsg/Downloads/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64.exe --headless --script res://tools/sky_view_test.gd
C:/Users/tntsg/Downloads/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64.exe --headless --script res://tools/focus_nebula_test.gd
```

---

## 🛠 技术栈

| 项目 | 内容 |
|------|------|
| 引擎 | Godot 4.7 |
| 语言 | GDScript |
| 分辨率 | 1024 × 768 |
| 存档 | JSON 本地存档 |
| 图像风格 | Pixel Art |
| 星体位置 | AstronomyAPI + 本地 RA/Dec fallback |
| UI | Godot Control 节点程序化构建 |
| 测试 | Headless scene smoke tests + GDScript flow tests |

---

## ⚠️ 开发约定

1. `Dictionary.get()` 返回 Variant，必须显式标类型
2. float 取模用 `fmod()`，`%` 只能整数
3. autoload 脚本不用 `class_name`
4. 面向玩家的字符串走 `GameManager.text("EN", "中文")`
5. `TextureRect.expand_mode` / `Label.autowrap_mode` 必须在设 `size` 之前设置
6. 分辨率 1024×768，像素图用 `TEXTURE_FILTER_NEAREST`
7. 改完必须编译检查 + 跑相关测试
8. 不要把 `data/local_api_keys.json` 提交到仓库


---

## 📌 2026-07-12 Web 发布与稳定性更新

### Web 浏览器版本

- 完成 Godot Web 导出，支持直接在现代浏览器中运行。
- Web 版本使用单线程构建，兼容 GitHub Pages 等普通静态网站托管。
- 修复 Tama / Bullet GDExtension 的 Web 侧模块加载、入口导出和资源路径问题。
- 修复浏览器运行时的 `AudioManager`、`BulletManager` 自动加载问题。
- 修复宽屏浏览器中的画面偏移，游戏内容保持在屏幕中央。
- 修复大厅路线提示箭头在 Web 版本中出现乱码的问题。
- 天空观测界面的 EYE / FINDER / SCOPE 三个模式卡统一为相同尺寸和形态。
- 模式卡从 PCK 资源中加载，避免导出后浏览器找不到图片。
- 当前选中的观测模式使用青色边框和半透明高亮提示。

### 星空观测灰屏修复

- 修复进入星空观测界面时的灰屏问题。
- 根因是观测脚本使用了未声明的 `CYAN` 颜色常量，导致 Godot Web 运行时脚本解析失败。
- 已补充颜色常量并重新导出。
- 为游戏数据分片增加版本标识，避免浏览器继续使用旧缓存。
- 已在浏览器中验证：主菜单、教学流程和星空观测界面可以正常打开。

### 大文件与网页加载方案

- 原始 `index.pck` 约 112MB，超过部分 Git 静态托管服务的单文件限制。
- 将游戏包拆分为 5 个约 22MB 的分片。
- 网页启动时自动下载并合并分片，Godot 仍按完整游戏包运行。
- 该方案不改变游戏内容，只解决网页托管和浏览器缓存问题。

### 公开访问地址

当前版本由 GitHub Pages 托管：

- 游戏地址：[https://tntsg1.github.io/Pixel-Observatory/](https://tntsg1.github.io/Pixel-Observatory/)
- GitHub 仓库：[https://github.com/tntsg1/Pixel-Observatory](https://github.com/tntsg1/Pixel-Observatory)
- 网页发布分支：`gh-pages`

GitHub Pages 不需要本地电脑保持开机，世界各地可以通过公开网址访问。后续重新导出并更新 `gh-pages` 分支后，网页会自动重新构建。

### 公共演示注意事项

- 这是公开演示版本，任何拿到网址的人都可以访问。
- 当前进度只保存在访问者自己的浏览器中。
- 清除浏览器数据、更换浏览器或更换设备，可能会丢失本地进度。
- 当前没有账号系统、云端存档和多人联机功能。
- 不要在游戏中输入个人隐私、账号密码或其他敏感信息。
