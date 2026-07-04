# Pixel Observatory — L10-L24 关卡设计（螺旋式重复练习结构）

设计原则：每章一个核心知识点，3-5 关反复变形练习。重复目标必须通过
`variation` + `repeat_target_reason` 在剧情里明确"这次变量变了"。

已有基础（L1-L9）：肉眼 → 折射镜 → 调焦 → 倍率代价 → 寻星镜 → 反射镜/口径 → 深空。

---

## 章节总表

| 关 | 章节 | 标题 | 目标 | 重复的概念 | 本关新变量 | 系统需求 |
|----|------|------|------|-----------|-----------|---------|
| L10 | Ch3 | Jupiter Revisited – Too Much Power | jupiter | 倍率代价(L5) | 三档目镜实际切换对比 | 🟡 新目镜 eyepiece_6mm + 倍率对比UI |
| L11 | Ch3 | Mars at Low Altitude | mars | 倍率选择 | 低空 seeing 惩罚 | 🟡 seeing(按目标高度扣清晰度) |
| L12 | Ch3 | Moon Detail Challenge | moon | 倍率+调焦(L4) | 亮目标承受高倍率、换倍率需重新调焦 | 🟢 现有系统 |
| L13 | Ch3 | Magnification Review Mission | 三选一 | 全章复习 | 玩家自主决策、无提示 | 🟡 目标选择UI(任务板三选一) |
| L14 | Ch4 | Find Mars by Coordinates | mars | Az/Alt 导航(已有DMS) | 只给坐标不给方向提示 | 🟢 现有系统(隐藏提示圈) |
| L15 | Ch4 | Finder Scope Alignment | sirius | 寻星镜(L6) | 寻星镜偏移校准小游戏 | 🔴 finder offset 校准玩法 |
| L16 | Ch4 | Narrow Field Problem | jupiter | Eye→Finder→Scope流程 | 强制体验跳过Finder的失败 | 🟢 流程标志位+文案 |
| L17 | Ch4 | Navigation Review Night | 随机亮目标 | 全流程复习 | 无剧情带路、随机目标 | 🟡 随机目标 |
| L18 | Ch5 | Orion Nebula – First Faint Smudge | orion_nebula | 深空(L7-8) | 接受 Fair 也算成功 | 🟢 minimum_success_quality 已有 |
| L19 | Ch5 | Better Aperture, Better Nebula | orion_nebula | 口径(L8) | 同目标换口径直接对比 | 🟢 现有系统 |
| L20 | Ch5 | Andromeda Under Bad Sky | andromeda | 深空+集光 | 光污染变量(sky_brightness) | 🟡 sky_brightness 评估因子 |
| L21 | Ch5 | Dark-Sky Attempt | andromeda | 同上 | 同设备暗天空对比 | 🟡 同上 |
| L22 | Ch6 | Star Drift | sirius | 居中保持 | 目标随时间漂移+保持8秒 | 🔴 漂移+驻留计时系统 |
| L23 | Ch6 | Tracking Mount | jupiter | 稳定性(L5) | tracking_mount 抵消漂移 | 🔴 追踪架零件+追踪速率 |
| L24 | Ch6 | Long Look at Andromeda | andromeda | 全课程综合 | 12秒持续观测+进度条 | 🔴 驻留进度系统 |

🟢 = 现有系统可直接做　🟡 = 轻量扩展(1个字段/小UI)　🔴 = 需要新机制

---

## 章节剧情主题

**Ch3 调焦与倍率掌握（L10-13）**：Maya 把"倍率不是越高越好"从一句话变成四次亲手体验——
亮的木星、低空的火星、明亮的月亮，最后放手让玩家自己选。章节情绪：从"听过"到"用对"。

**Ch4 寻星镜与星空导航（L14-17）**：导航训练营。同一套 Eye→Finder→Scope 流程，
提示逐关递减：给坐标→校准工具→体验走弯路→完全独立。章节情绪：从"跟着走"到"自己找"。

**Ch5 集光与暗弱天体（L18-21）**：两个深空目标各看两次，变的不是目标而是条件
（口径、天空亮度）。教会玩家"淡淡的斑也是成功"和"失败可能是环境不是设备"。
章节情绪：管理期望，理解变量。

**Ch6 追踪与耐心（L22-24）**：地球在转，好观测是"保持"而不是"点一下"。
从手动追星到追踪架到长时间驻留，收束全部课程。章节情绪：从操作者到观测者。

---

## 每关详细设计

### L10 Jupiter Revisited – Too Much Power
- target: jupiter ｜ main_concept: magnification_tradeoff ｜ repeated: L5 倍率代价
- variation: 首次可在三档目镜(20/10/6mm)间实际切换对比同一目标
- player_action: 观测木星→按提示依次试 Low/Med/High 目镜→高倍率画面更大但更暗更抖→选合适档完成
- success: 用 Medium(10mm) 或 Low 档达到 Good+；High 档被封顶 Fair
- Maya intro: "You can see Jupiter now. Push the power higher — and watch what it costs." / "你已经能看到木星了。把倍率推高试试——看看代价是什么。"
- recap: "Bigger is not clearer. You proved it yourself tonight." / "更大不等于更清楚。今晚你亲手证明了。"
- repeat_target_reason: "Same Jupiter, new question: how much power is too much?" / "还是木星，但问题变了：多高的倍率算太高？"

### L11 Mars at Low Altitude
- target: mars ｜ main_concept: seeing_conditions ｜ repeated: 倍率选择
- variation: 火星位置被约束在低空(alt<20°)，新增 seeing 惩罚：目标高度越低，清晰度上限越低；高倍率放大了大气抖动
- player_action: 找到低空火星→尝试高倍失败→换低/中倍完成
- success: 低/中倍率 Good；高倍被 seeing 压到 Poor
- Maya intro: "Mars is low tonight. If it looks mushy, that's the air — not your telescope." / "今晚火星很低。如果看起来糊糊的，那是大气的问题——不是你的望远镜坏了。"
- recap: "Low targets swim in thick air. Less power, steadier view." / "低空目标泡在厚厚的大气里。倍率低一点，画面稳一点。"
- repeat_target_reason: "Mars again — but tonight it hugs the horizon." / "又是火星——但今晚它贴着地平线。"

### L12 Moon Detail Challenge
- target: moon ｜ main_concept: brightness_supports_power ｜ repeated: 倍率+L4调焦
- variation: 亮目标反例——月亮亮度足以支撑高倍率；但换目镜后 target_focus_value 重新生成，必须重新调焦
- player_action: 高倍观测月亮→发现换倍率后失焦→重新调焦→看到更多月面细节(telescope_view 高倍时月亮 sprite 放大 1.4x)
- success: High 档 + 重新对焦 + Good/Excellent
- Maya intro: "The Moon is bright enough to take the power. But every new eyepiece needs a new focus." / "月亮够亮，扛得住高倍率。但每换一个目镜，都要重新调焦。"
- recap: "Same rule, different target: brightness pays for power." / "同一条规则，不同的目标：亮度为倍率买单。"
- repeat_target_reason: "Back to the Moon — the one target that rewards high power." / "回到月亮——唯一奖励高倍率的目标。"

### L13 Magnification Review Mission
- target: jupiter/moon/mars 三选一（任务板选择） ｜ main_concept: 全章复习 ｜ repeated: L10-12 全部
- variation: 无引导小测验；Maya 不提示倍率
- player_action: 任务板选目标→自选目镜→观测识别
- success: 所选目标使用"合理倍率"(moon:高OK / jupiter:中 / mars:低中) + 正确识别；不合理倍率会因质量封顶自然失败
- Maya intro: "Your call tonight. Pick a target, pick the power. I'm just watching." / "今晚你说了算。选目标，选倍率。我只旁观。"
- recap: "You chose like an observer, not a beginner. Chapter logged." / "你的选择像个观测者，而不是新手了。本章记入日志。"
- 完成解锁 Journal「Magnification Mastery / 倍率掌握」章节徽章

### L14 Find Mars by Coordinates
- target: mars ｜ main_concept: coordinate_navigation ｜ repeated: Az/Alt DMS(已有)
- variation: 关闭任务目标提示圈(assist frame)，只显示目标坐标数字
- player_action: 读 SELECTED 面板 Target Az/Alt→肉眼模式转到坐标→目标进入视野
- success: 目标进入肉眼视野中央区(±10°)即算首阶段完成，随后正常观测
- Maya intro: "No guessing tonight. Two numbers will take you to Mars: azimuth and altitude." / "今晚不用猜。两个数字就能带你找到火星：方位角和俯仰角。"
- recap: "Coordinates turned the whole sky into an address book." / "坐标把整个天空变成了一本地址簿。"
- repeat_target_reason: "Mars a third time — but tonight you navigate by numbers, not by luck." / "第三次找火星——但今晚靠数字导航，不靠运气。"

### L15 Finder Scope Alignment（🔴 新玩法：校准）
- target: sirius ｜ main_concept: finder_calibration ｜ repeated: L6 寻星镜
- variation: 寻星镜有随机偏移(offset ±3°)；新校准界面：把主镜中心的星拉回寻星镜十字中心（方向键微调 offset，类似调焦的第二轴玩法）
- player_action: 发现 Finder 十字与 Scope 中心不一致→进入校准→对齐→再正常找星
- success: offset 校准到 <0.5° 后完成天狼星观测
- Maya intro: "A finder fresh out of the box lies a little. Let's teach it to point true." / "刚装上的寻星镜会撒点小谎。我们来教它指准。"
- recap: "Now your wide eye and your narrow eye agree." / "现在你的'宽眼睛'和'窄眼睛'终于一致了。"

### L16 Narrow Field Problem
- target: jupiter（可选扩展：新增 saturn 天体更有新鲜感） ｜ main_concept: workflow_discipline ｜ repeated: 三段式流程
- variation: 剧情先怂恿玩家直接用 Scope 模式找(6°视野大海捞针)，体验挫败后 Maya 点破
- player_action: 直接 Scope 找 60 秒(或主动放弃)→Maya 插话→按 Eye→Finder→Scope 完成
- success: 完成观测且流程标志位记录经过了 Eye 和 Finder 模式
- Maya intro: "Feeling confident? Try finding it with the main scope alone." / "自信满满？那就试试只用主望远镜找它。"
- mid-story (触发于挫败): "Lost? Everyone gets lost in six degrees. Wide first, narrow last." / "迷路了吧？在 6 度的视野里谁都会迷路。先宽后窄。"
- recap: "The narrow field shows detail. The wide field shows the way." / "窄视野看细节，宽视野认路。"

### L17 Navigation Review Night
- target: 从 {jupiter, mars, sirius} 每次进入随机 ｜ main_concept: 全章复习 ｜ repeated: L14-16
- variation: 无 before 剧情带路；只有坐标；随机目标防背板
- player_action: 独立完成坐标定位→Eye→Finder→Scope→识别
- success: 全流程独立完成
- Maya intro: "Tonight I stay by the door. The sky is yours." / "今晚我就站在门口。天空交给你了。"
- recap: "You navigated alone. That's the real badge." / "你独立完成了导航。这才是真正的徽章。"
- 完成解锁 Journal「Sky Navigation / 星空导航」章节

### L18 Orion Nebula – First Faint Smudge
- target: orion_nebula ｜ main_concept: expectation_management ｜ repeated: L7-8 深空
- variation: `minimum_success_quality: "Fair"`（系统已支持）——淡斑即成功
- player_action: 用现有设备观测星云，Fair 质量即可识别完成
- success: Fair+ 即可；Maya 明确肯定"这就是深空观测"
- Maya intro: "A nebula never gives you sharp edges. Tonight, a faint smudge IS the victory." / "星云永远不会给你清晰的边缘。今晚，看到淡淡的一团就是胜利。"
- recap: "You saw light that traveled 1,300 years. Blurry, and still beautiful." / "你看到了跋涉 1300 年的光。虽然模糊，依然动人。"
- repeat_target_reason: "Same nebula as L7 — but tonight we change what 'success' means." / "还是那片星云——但今晚我们改变'成功'的定义。"

### L19 Better Aperture, Better Nebula
- target: orion_nebula ｜ main_concept: aperture(L8) ｜ repeated: 口径
- variation: 紧接 L18 的直接对比：换 100mm 物镜再看同一目标，要求 Good
- player_action: 零件柜换大口径→重装→同一星云明显更亮
- success: Good+
- Maya intro: "Same sky, same nebula. Only one thing changes tonight: how much light you collect." / "同样的天空，同样的星云。今晚只改变一件事：你收集多少光。"
- recap: "Last night a smudge, tonight a shape. That difference is aperture." / "昨晚是一团斑，今晚有了形状。这个差别，就叫口径。"
- repeat_target_reason: "Third visit to Orion — this time as a controlled experiment." / "第三次看猎户座星云——这次是一场对照实验。"

### L20 Andromeda Under Bad Sky（🟡 新变量：光污染）
- target: andromeda ｜ main_concept: sky_brightness ｜ repeated: 深空集光
- variation: 关卡字段 `sky_brightness: "city"` → evaluate 扣 light_ratio；同设备质量上限 Fair
- player_action: 观测→发现怎么调都暗→Maya 解释是天空太亮→记录一次"困难观测"
- success: `minimum_success_quality: "Fair"`，剧情承认这是受限观测
- Maya intro: "Andromeda is huge — and the city lights are eating it alive." / "仙女座星系很大——但城市的灯光正在活活吞掉它。"
- recap: "Nothing was broken tonight. The sky itself was the problem. Log it honestly." / "今晚没有任何设备坏掉。问题出在天空本身。如实记录下来。"
- repeat_target_reason: "Andromeda again — but the enemy tonight is streetlights, not distance." / "又是仙女座——但今晚的敌人是路灯，不是距离。"

### L21 Dark-Sky Attempt
- target: andromeda ｜ main_concept: sky_brightness 对照 ｜ repeated: L20
- variation: `sky_brightness: "dark"` → 无惩罚；同设备直接对比
- player_action: 同样流程再观测一次，效果显著提升
- success: Good+
- Maya intro: "The club drove out past the hills tonight. Same gear. Darker sky. Try again." / "今晚俱乐部开车到了山那边。设备没变，天更暗了。再试一次。"
- recap: "Your telescope didn't improve overnight — your sky did." / "你的望远镜一夜之间没有变好——变好的是你的天空。"
- 完成解锁 Journal「Deep Sky Observer / 深空观测者」章节

### L22 Star Drift（🔴 新系统：漂移）
- target: sirius ｜ main_concept: earth_rotation ｜ repeated: 望远镜模式居中
- variation: 观星界面中目标以 ~0.25°/s 缓慢漂移(方位角方向)；需保持在望远镜容差内累计 8 秒
- player_action: 居中→发现漂移→持续微调→驻留计时条充满
- success: 累计居中 8 秒（出圈进度暂停不清零，宽松版）
- Maya intro: "Watch closely. The star is running away — no, the Earth is turning under you." / "盯紧了。星星在慢慢逃——不，是地球在你脚下转。"
- recap: "You just fought the planet's spin by hand. Feel the workout?" / "你刚才在徒手对抗地球自转。感觉到工作量了吧？"
- 学习卡：earth_rotation_drift（需新图解：地球自转→星轨）

### L23 Tracking Mount（🔴 新零件：追踪架）
- target: jupiter ｜ main_concept: tracking ｜ repeated: L22 漂移 + 稳定性
- variation: 解锁 `tracking_mount` 零件；装上后设置追踪速率(滑条 0-2x，1x 抵消漂移)，速率不对仍会漂
- player_action: 组装台装追踪架→观星→调追踪速率到 ~1x→目标自动保持
- success: 追踪速率调到 0.9-1.1x，目标自动驻留 8 秒
- Maya intro: "Tired arms? This mount turns at exactly the speed of the sky." / "手酸了吧？这个支架会以和天空完全相同的速度转动。"
- recap: "Now the machine fights the spin, and you just watch." / "现在由机器对抗自转，你只管看。"
- repeat_target_reason: "Jupiter, fourth time — but tonight you don't touch the keys." / "第四次看木星——但今晚你的手可以离开按键。"

### L24 Long Look at Andromeda
- target: andromeda ｜ main_concept: 全课程综合 ｜ repeated: 深空+追踪+暗空+口径
- variation: 需要连续稳定观测 12 秒（漂移开启，追踪架可用）；漂出中心进度按 2x 倒扣（严格版）
- player_action: 最佳配置(大口径+追踪架+暗空)→长时间驻留→进度满
- success: 12 秒进度条充满→最终识别→Maya 全课程复盘剧情(level_24_after 多行)
- Maya intro: "One last lesson: deep sky rewards the patient. Stay with her." / "最后一课：深空回报有耐心的人。陪着她，别走开。"
- recap: "From naked eyes to a tracked deep-sky watch — you finished the whole path. Senior Observer." / "从肉眼到追踪深空——整条路你走完了。高级观测员。"
- 完成解锁最终徽章「Senior Observer / 高级观测员」+ Maya 结业剧情

---

## 建议的 levels.json 新字段

```jsonc
{
  "chapter_id": "ch3_magnification",        // 章节分组（Journal 章节页用）
  "lesson_thread": "magnification",          // 知识主线（同线关卡共享复习提示）
  "practice_step": 2,                        // 本线第几次练习（1=引入 2/3=变形 4=复习）
  "variation": "low_altitude_seeing",        // 本关变量标签（驱动特殊机制开关）
  "repeat_target_reason_en": "Mars again — but tonight it hugs the horizon.",
  "repeat_target_reason_zh": "又是火星——但今晚它贴着地平线。",
  "next_action": "sky",                      // 完成后大厅引导目标（复用 room guidance）
  "next_guidance_en": "Head back to the pad — Jupiter is waiting.",
  "next_guidance_zh": "回到观星台——木星在等你。",
  // 机制开关字段（按关启用）
  "magnification_choice": true,              // L10/12/13：三档目镜切换
  "seeing_penalty": true,                    // L11：低空清晰度惩罚
  "sky_brightness": "city" | "dark",         // L20/21
  "drift_enabled": true,                     // L22-24
  "hold_seconds": 8,                         // L22-24：驻留时长
  "minimum_success_quality": "Fair",         // L18/20（已有支持）
  "target_pool": ["jupiter","moon","mars"],  // L13/17：可选/随机目标
  "hide_target_hint": true                   // L14/17：关闭提示圈
}
```

`repeat_target_reason` 的用法：Mission Board 弹窗和 before 剧情第一句必须展示它，
让玩家进关前就知道"这次哪里不一样"——这是防止重复感的核心手段。

## 实现优先级建议

1. **第一批（全部🟢，1 轮可完成）**：L12, L14, L16, L18, L19 —— 纯数据+文案
2. **第二批（🟡 轻量）**：L10/L13(目镜三档+选择UI), L11(seeing), L17(随机), L20/L21(sky_brightness)
3. **第三批（🔴 新机制）**：L15(校准玩法), L22-24(漂移/追踪/驻留 —— 一个系统三关复用)

新学习卡需求：seeing_conditions, finder_calibration(已有 finder_scope_alignment 可复用),
light_pollution, earth_rotation_drift, tracking_mount —— 4 张新图解。
新零件：eyepiece_6mm, tracking_mount(数据已有同名者需核对), 可选 saturn 天体。
