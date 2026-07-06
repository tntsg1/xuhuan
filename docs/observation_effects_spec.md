# 观测条件拟真效果系统 · 实现规格（2026-07-05）

需求来源：用户 2026-07-05 指令（九大类效果 + 十条验收）。核心原则：
**每种条件同时影响 ①画面 ②UI ③操作反馈 ④质量判定**；一切过渡渐进不硬切；
不破坏现有 STATE_TEXTURES 交叉淡化 / 平滑追赶系统；新贴图一律圆形遮罩不用黑阈值抠图。

分三个串行包：E1 望远镜视图效果核心 → E2 漂移与跟踪 → E3 观星台视图效果。

---

## 共享基础（E1 建立）

### conditions 快照（telescope_view 成员）
每帧可用的当前条件快照，全部走平滑追赶（复用 `_advance_visual_smoothing` 的模式）：
```
var cond_turbulence := 0.0     # 0-1，大气扰动强度（seeing × 倍率 × 高度）
var cond_cloud_atten := 0.0    # 0-1，当前瞬时云衰减（随云飘动实时变化）
var cond_sky_lift := 0.0       # 0-1，背景抬亮程度（city 1.0 / suburban 0.5 / dark 0）
```
- `cond_turbulence = seeing_severity * clampf(magnification / 55.0, 0.4, 1.6)`，
  其中 seeing_severity：Good=0.06（永远有一丝微动，真实感）/ Average=0.35 / Poor=0.8；
  再乘 `clampf(1.6 - altitude/60.0, 0.7, 1.3)`（低空更强）。无 environment 时 severity=0.06。
- 星云/星系（无锐边）：turbulence 不做 UV 扭曲，改为整体 alpha "呼吸"（见下）。

### 湍流 shader：`shaders/turbulence.gdshader`
```glsl
shader_type canvas_item;
uniform float turbulence : hint_range(0.0, 1.0) = 0.0;
void fragment() {
    vec2 uv = UV;
    float w = turbulence * 0.005;
    uv.x += (sin(uv.y * 42.0 + TIME * 3.3) + 0.6 * sin(uv.y * 11.0 - TIME * 1.9)) * w;
    uv.y += cos(uv.x * 31.0 + TIME * 2.4) * w * 0.7;
    vec4 c = texture(TEXTURE, uv);
    COLOR = c * COLOR;
}
```
挂在 main_sprite / blur_overlay / ghost（行星、月亮）。每次条件变化只更新 uniform。
补充动态：`blur_weight` 目标值加 `cond_turbulence * 0.18 * (0.5 + 0.5*sin(t*1.3+seed))`
的低频呼吸（忽清忽糊）；position 微抖 `cond_turbulence * 2.5px` 的双正弦漂移。

### 按天体类型分派（验收第九条）
- 恒星（type Star）：`_magnification_scale()` 强制 1.0（高倍不把星变圆盘）；
  湍流表现 = 闪烁（alpha 0.75-1.0 双正弦，频率×turbulence）+ 位置微抖，不挂 UV shader。
- 行星/月亮：UV shader + 呼吸模糊 + 微抖（月亮 w 减半，主要边缘轻微波动）。
- 星云/星系：无 shader；alpha 呼吸 `±0.05*turbulence`；对 sky_lift 加倍敏感（见对比度）。

### 质量颗粒层（替换白点噪点，验收第八条）
`shaders/grain.gdshader` 挂在覆盖镜筒圆的 ColorRect 上（在星点与目标之上、十字线之下）：
```glsl
shader_type canvas_item;
uniform float intensity = 0.0;   // Excellent 0.0 / Good 0.03 / Fair 0.08 / Poor 0.16 / Failed 0.30
uniform vec2 center; uniform float radius;
float rnd(vec2 p){ return fract(sin(dot(p, vec2(12.9898,78.233)) + floor(TIME*24.0)) * 43758.5453); }
void fragment() {
    float d = distance(FRAGCOORD.xy, center);
    float mask = 1.0 - smoothstep(radius - 8.0, radius, d);
    float g = rnd(FRAGCOORD.xy) - 0.5;
    COLOR = vec4(vec3(0.55, 0.62, 0.75), abs(g) * intensity * mask);
}
```
旧的 `_rebuild_quality_noise` 白点系统整体移除，改为按质量档位平滑更新 intensity
（沿用 0.35s 渐变思路，用 lerp 追赶）。Poor/Failed 另外把目标 modulate 的对比度压低
（modulate 乘 0.85 灰化）。

### 云层（telescope 视图）
- 资产：Pillow 生成 3 张软边云雾 PNG（`assets/telescope_view/cloud_wisp_a/b/c.png`，
  ~420×260，灰白 (0.72,0.75,0.80)，径向+噪声 alpha 渐变，边缘完全透明）。
- 节点：cloud_cover>0 时生成 2-4 个 TextureRect（数量随 cover），在镜筒圆内缓慢平移
  （速度 8-16 px/s，方向近水平，出界从另一侧重生成，位置由确定性种子+时间驱动）；
  alpha = cover 档位（Thin .28 / Moderate .5 / Heavy .75）。
- **实时衰减**：`cond_cloud_atten` = 各云与目标中心的重叠度加权（0-1，平滑），
  实际影响：目标/星点 modulate 亮度 × `(1 - 0.75*atten)`；
  评估联动：telescope_view 每 0.6s 重评估一次（仅 cloud_cover>0 时），
  `extra_context["cloud_attenuation"] = cond_cloud_atten`；observation_system 有该 key 时
  用 `light_ratio *= (1 - 0.75*atten)` 替代静态 `(1-0.5*cover)`——**等云隙识别是真策略**。
  GameManager 侧无该 key 时维持静态公式（flow_test 等纯数值路径不变、可通关）。
- 云档位（UI 与数值统一）：cover 0=Clear晴朗, <0.34 Thin薄云, <0.67 Moderate中云, else Heavy厚云。

### 天空亮度（telescope 视图）
- 背景：镜筒内圆填色随 sky 档位——dark=(0,0,0) / suburban=(0.020,0.024,0.036) /
  city=(0.045,0.052,0.075)（城市夜空的灰蓝底），星点数量：city 只画最亮 40%、suburban 70%。
- 评估：observation_system sky_brightness 增加 "suburban" ×0.85（city .7 / dark 1.08 不变）。
- Contrast 标签：dark=High高 / suburban=Medium中 / city=Low低；cloud≥Moderate 再降一档。
  星云/星系在 city 下额外 `base_alpha × 0.8`（对比度打击最重，验收第九条）。

### UI 条件行重构（右侧面板）
现 283/296/308 三个 12px 槽位改为**动态槽位分配**：从 y=283 起依次放置实际存在的行：
1. 装备行 "100mm · 10mm · 80.0x"（恒显）
2. 条件行A "Seeing视宁度: Poor·差  Cloud云: Thin·薄"（有 seeing 或 cloud 才显）
3. 条件行B "Sky天空: City·城市  Contrast对比: Low·低"（有 sky 才显）
4. 暗适应行（L18 类深空关）
最多 4 行（283/295/307/319…超出则 feedback 从 320 顺延到 332，同步把 feedback 高度
收到 1 行）。所有行单行双语内联（禁用 GameManager.text 堆叠）。

### 原因归因反馈（验收第八条）
`_current_feedback` / `_quality_shortfall_text` 按"当前最低的 ratio + 环境"命名主因，
优先级：焦点 > 云(atten>0.35) > seeing(label≠Good) > 天空(city且light最低) > 口径/稳定性。
每种一句双语，如云："Clouds are crossing the target. Wait for a gap." /
"云层正在遮挡目标。等云隙再观测。"

### 暗适应/侧视法打磨（已有基础）
- 暗适应改非线性：`ease(dark_adaptation, 0.6)`，效果继续=背景星减淡+淡目标 alpha 增益，
  增益上限保持 +0.10（"更容易察觉"而非"变高清"）。
- 侧视法：效果仅对 nebula/galaxy（已有）；数值改为轮廓增强——alpha +0.10 且
  modulate 提亮 ×1.06（微妙）；UI 行改 "Averted侧视: Active启用/Inactive未启用"。

---

## E2 漂移与跟踪（验收第六、七条）

### 漂移（telescope_view，`level.drift_enabled == true` 时激活）
- `drift_offset: Vector2` 每帧 += 漂移速度：`Vector2(1,0).rotated(0.08) * 6.0px/s ×
  (magnification/35)`（高倍视野窄→漂得快，方向近水平带一点斜）。
- 目标（target_center 附加 drift_offset）与镜筒星点层（同一 offset 施加到星层容器）
  **一起移动**——是天空在转。
- 玩家校正：方向键/WASD 反向推 `drift_offset`（速度 90px/s），Q/E 仍是调焦
  （drift 关卡里取消 A/D 的调焦映射，避免冲突；无 drift 关卡维持现状）。
- 出视野：|offset| > 250px 时目标移出，评估 quality 封 Failed（extra_context 传
  `target_off_center: true`），提示"目标已漂出视野，重新居中"。
- **Center Hold**：`hold_seconds = level.hold_seconds`（>0 才启用门槛）。
  |offset| < 46px 时 hold_timer += delta；出圈暂停不清零（宽松版；若
  `level.hold_strict == true` 则按 2×delta 倒扣，L24 用）。识别门槛：hold 未满时
  `_identify` 拦截（"再稳住 x 秒"）。
- UI（放视野下方、镜筒外左下区域，不挤右面板）：
  "Drift漂移: On开启   Hold居中: 3.2/8.0s" + 74px 进度条；无 hold_seconds 时只显 Drift。

### 跟踪支架
- 新零件 `tracking_mount`（data/telescope_parts.json）：type "mount"，
  name "Tracking Mount / 追踪支架"，stability 高于 stable_mount 一档，新属性
  `"tracking": true`，`unlock_level: 23`。
- telescope_view：装备 tracking 支架且 drift 激活时，面板 focus 滑条上方加
  追踪速率滑条（0-2x，step 0.05，persist `progress["tracking_rate"]`，默认 0）：
  实际漂移速度 × `(1 - tracking_rate)`（1x 完全抵消，过头反向漂）。
- UI 状态行（并入 Drift 行）："Track追踪: Off关 / 1x / Misaligned未对准"
  （|rate-1|≤0.1 → "1x"；rate<0.05 → Off；其余 Misaligned）+ 误差数字 `Δ0.35x`。
- 存档迁移补 `tracking_rate`；new_game 重置。
- L22（sirius 无跟踪件也可手动完成）/L23（解锁+推荐 tracking_mount）/L24（hold_strict）
  的 levels.json 字段补齐：L23 `unlock_parts` 或靠 unlock_level 自动、
  `recommended_part_ids: ["tracking_mount"]`；L24 `hold_strict: true`。
- flow_test 兼容：hold 门槛只存在于 telescope_view 交互层，纯评估路径不受影响。

## E3 观星台视图效果（sky_observation）

- **天空亮度**：背景基色按 sky 档位抬亮（city 加 (0.030,0.034,0.050) 的底色叠层）；
  真实星表按 apparent magnitude 过滤：city 只显 mag≤3.6，suburban ≤4.5，dark 全部
  （深空暗斑目标在 city 下 alpha ×0.6）。
- **云层**：cloud_cover>0 时 2-5 块大软云（同 E1 贴图放大 1.8x）缓慢横移，
  盖住的星点变暗（云节点 z 序在星之上、刻度带之下）；纯视觉不改寻星判定。
- **星点闪烁**：只对视野内最亮 ~40 颗，alpha 双正弦微闪，幅度 × seeing severity。
- 全部效果在三种视角（Eye/Finder/Scope）一致渲染，参数随 FOV 缩放。

## 验收清单（对照用户十条）
1. 不看文字能分辨条件差异（截图对比：poor seeing vs good / thin vs heavy cloud /
   city vs dark / drift on-off）。
2-3. 每效果均有画面+UI+反馈+判定四件套；UI 与画面一致。
4. 反馈永远指向真实主因。
5. 七种效果视觉特征互不混淆（扰动=游动、云=飘过变暗、光污染=灰底少星、
   漂移=整体平移、暗适应=渐显、侧视=轮廓微增、跟踪=平移停止）。
6. 一切用平滑追赶/低频正弦，无硬切。
7-8. STATE_TEXTURES 系统保持；新贴图圆形遮罩。
