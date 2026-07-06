# Starlight Observatory / Pixel Observatory

一款使用 Godot 4.7 制作的 2D 天文观测教学游戏。玩家扮演学校天文社的新成员，在导师 Maya 的引导下，从肉眼观测开始，逐步学习望远镜组装、寻星镜定位、调焦、倍率、口径、稳定性、深空目标观测和学习记录。

项目目标不是做一个静态星图按钮页，而是让玩家通过真实的操作流程理解天文观测：

- 先在主观测室查看任务和设备状态。
- 再到零件柜查看装备，到组装台安装望远镜部件。
- 进入星空观测界面，用肉眼、寻星镜、主镜逐步对准目标。
- 在望远镜视野里观察、调焦、识别目标。
- 完成任务后进入学习卡，并把观测结果写入学习日志。

## 当前状态

当前版本已经具备一条可玩的教学主线，并逐步从早期 MVP 发展成完整的天文社观测体验。

已完成的核心模块：

- Main Menu：沉浸式 Starlight Observatory 标题页，使用整图背景和透明按钮热区。
- Observatory Room：完整背景图 + 透明交互层的学校天文社主观测室。
- Mission Board：显示当前任务目标和下一步提示。
- Parts Cabinet：查看零件库存、解锁状态和装备属性。
- Telescope Assembly Table：按顺序安装三脚架、支架、镜筒、物镜、目镜、寻星镜、调焦旋钮等部件。
- Sky Observation：三段式观测流程，支持 Naked Eye、Finder、Scope 模式。
- Telescope View：圆形望远镜视野、目标识别、调焦、质量反馈。
- Learning Card / Concept Brief：在任务前后讲解天文原理。
- Learning Journal：保存已完成观测记录和学习内容。
- SaveManager：本地 JSON 存档。
- StoryManager：Maya 导师剧情与任务前后对话。
- TeachingFlowManager：管理教程触发时机，避免学习内容只在任务完成后出现。
- SkyPositionService：支持本地 RA/Dec 计算，并为 Moon、Mars、Jupiter 接入 AstronomyAPI 的在线位置数据。

## 游戏主流程

```text
Main Menu
  -> New Game / Continue
  -> Observatory Room
  -> Mission Board
  -> Parts Cabinet / Assembly Table
  -> Sky Observation
  -> Telescope View
  -> Identify Target
  -> Mission Complete / Learning Card
  -> Learning Journal
  -> Next Mission
```

## 教学章节

当前关卡结构覆盖从入门观测到深空挑战的完整学习线：

| 章节 | 主题 | 教学重点 |
|---|---|---|
| Chapter 1 | Naked Eye Observation | 肉眼能看到什么，为什么先从月亮和亮星开始 |
| Chapter 2 | First Telescope | 基础折射望远镜、物镜、目镜、镜筒、调焦 |
| Chapter 3 | Focus and Magnification | 高倍率的代价、视野变窄、图像变暗 |
| Chapter 4 | Finder and Sky Navigation | 方位角、俯仰角、寻星镜、主镜对准 |
| Chapter 5 | Light Gathering and Faint Objects | 大口径、暗弱目标、星云和星系 |
| Chapter 6 | Tracking and Patience | 地球自转、目标漂移、追踪支架 |

## 关键系统

### Telescope Assembly

组装台不只是点击按钮，而是让玩家理解望远镜由哪些部件组成：

- Tripod / 三脚架：支撑整台望远镜。
- Mount / 支架：影响稳定性和追踪能力。
- Tube / 镜筒：保持光路结构。
- Objective Lens / 物镜：决定集光能力和清晰度。
- Eyepiece / 目镜：影响倍率和视野。
- Finder Scope / 寻星镜：帮助从大范围天空中定位目标。
- Focus Knob / 调焦旋钮：让焦平面对准目镜，图像才会清楚。

### Sky Observation

星空观测界面支持三个模式：

- Naked Eye：超宽视野，用来寻找亮目标和大致方向。
- Finder：中等视野，用来把目标放进寻星镜中心。
- Scope：窄视野，用来精确对准主望远镜。

界面显示目标的 Azimuth / Altitude，并以 DMS 度分秒格式提示玩家该往哪个方向转动。

### Telescope View

望远镜视野会根据观测质量显示不同效果：

- Clear：目标清楚。
- Blurry：失焦或质量一般。
- Dim：设备集光不足或目标过暗。
- Shaky：支架不稳或倍率过高。
- Noise：低质量观测中出现噪点。

Jupiter、Moon、Mars、恒星、星云和星系都使用不同视觉素材；Jupiter 现在支持清晰、模糊、过暗三套贴图。

### Learning Flow

教学内容分为两类：

- Concept Brief：任务前的原理预习。
- Mission Complete Card：任务完成后的总结和学习卡。

这样玩家在实际操作前就知道要观察什么，不会只在完成后才看到原理说明。

## 当前重点问题

仍在持续打磨的方向：

- 修复旧 Starfall / shooter 模板残留资源和插件报错。
- 继续统一 UI 风格和交互反馈。
- 调整所有关卡的难度曲线。
- 增加更多目标的清晰 / 模糊 / 过暗状态贴图。
- 优化中文编码和中英文排版。
- 为 Godot 导出做资源清理。

## 版本历史

完整版本进度记录见：

[docs/VERSION_HISTORY.md](docs/VERSION_HISTORY.md)

## 运行方式

推荐使用 Godot 4.7 stable 打开项目：

```powershell
C:/Users/tntsg/Downloads/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64_console.exe --path E:/godot/ai-game-0628
```

常用场景验证：

```powershell
C:/Users/tntsg/Downloads/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64_console.exe --headless --path E:/godot/ai-game-0628 --scene res://scenes/main_menu.tscn --quit-after 5
```

## 本地凭证说明

AstronomyAPI 凭证只应放在本地文件：

```text
data/local_api_keys.json
```

该文件已在 `.gitignore` 中忽略，不应该提交到 GitHub。

## Repository

GitHub: [tntsg1/xuhuan](https://github.com/tntsg1/xuhuan)
