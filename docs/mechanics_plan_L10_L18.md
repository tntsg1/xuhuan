# L10-L18 机制落地实现规格（2026-07-05）

依据：`docs/audit_L10_L18_20260705.md`（用户审计）。原则：**剧情只描述真实存在的机制**；
每次重复必须改变一个真实变量。分三个串行包裹实现（P1 系统层 → P2 交互层 → P3 内容层）。

---

## 新增 levels.json 字段（最终 schema）

```jsonc
{
  "required_part_ids": ["eyepiece_10mm"],        // 硬性要求：未装齐则无法识别，UI 指明缺哪个
  "recommended_part_ids": ["stable_mount"],      // 软性推荐：引导文案，不装则质量偏低
  "mission_steps": [                             // 顺序检查表（可选）
    {"id": "low_power", "label_en": "Observe Jupiter with the 20mm", "label_zh": "用 20mm 目镜观测木星", "require_part_id": "eyepiece_20mm"},
    {"id": "high_power", "label_en": "Switch to 10mm and observe again", "label_zh": "换 10mm 目镜再观测一次", "require_part_id": "eyepiece_10mm"}
  ],
  "environment": {                               // 环境条件（可选，全部进入评估与画面）
    "seeing": "poor" | "average" | "good",
    "sky_brightness": "city" | "dark",
    "cloud_cover": 0.0,
    "target_altitude_bias": "low"                // 观星台把目标压到低空 (<20°)
  },
  "journal_summary_en": "...", "journal_summary_zh": "..."   // 本关实验结论（P3 日志用）
}
```

## P1 系统层（评估 + 装备 + 面板）

1. **seeing 机制**（ObservationSystem + GameManager）
   - `GameManager.evaluate_selected_object` 组装 `extra_context.environment`：关卡 environment +
     观测高度（用 `last_sky_aim.altitude`，无则 45°）+ 当前 magnification（TelescopeMath）。
   - 有效视宁度 `seeing_eff = base(good 1.0/average 0.88/poor 0.72) * altitude_factor`；
     `altitude_factor = clampf(alt / 30.0, 0.62, 1.0)`（低空大气更厚）。
   - 倍率超限惩罚：`useful_limit_eff = useful_magnification_limit * seeing_eff`；
     若 magnification > useful_limit_eff：clarity_ratio、stability_ratio 乘
     `useful_limit_eff / magnification`（放大了大气抖动）。
   - 结果里带出 `"seeing_eff"`、`"seeing_label"`（Good/Average/Poor 三档）供 UI。
   - 验收：L11（poor + 低空）用 10mm 时质量 ≤ Fair；用 20mm 可达 Good；L5 等旧关不受影响
     （无 environment 字段 = good seeing + 高度 45°+ 不触发惩罚）。
2. **sky_brightness / cloud_cover 进评估**
   - city：light_ratio × 0.62；dark：× 1.08（上限 clamp）；cloud_cover c：light_ratio × (1-0.5c)。
   - L20/L21 现有顶层 `sky_brightness` 字段迁入 `environment`（两处都兼容读取，优先 environment）。
3. **required_part_ids 硬门槛**（GameManager + telescope_view）
   - helper `GameManager.missing_required_parts() -> Array[String]`（比对 assembly/equipped 状态）。
   - telescope_view：缺件时 identify 拦截 + feedback 指明零件名（双语）+ 引导去零件柜。
4. **换目镜必须重新调焦**：`telescope_view._init_focus` 的 target_focus 哈希加入当前目镜 part id
   （`(id + stage + eyepiece_id).hash()`）→ 换目镜后焦点自然偏移。全关卡通用、零成本真实机制。
5. **倍率可视化**：telescope_view 里行星/月亮 sprite 按 magnification 相对基准缩放：
   `display_scale = clampf(mag / 35.0, 1.0, 1.4)`，高倍率 `base_alpha × 0.85`（更大更暗）。
6. **右侧面板装备/环境显示**：Objective 60/100mm、Eyepiece 20/10mm、Magnification ×N、
   Seeing 档位（有 environment 时）、Sky: City/Dark（有时）。双语。
7. **L11 低空**：sky_observation `_ensure_target_observable` 尊重 `target_altitude_bias: "low"`
   （目标 alt 压到 12-18°）。
8. levels.json 数据：L10(mission_steps 20→10mm)、L11(environment poor+low、recommended 20mm)、
   L12(required eyepiece_10mm)、L18(recommended eyepiece_20mm)、L19(required objective_100mm)、
   L20/21(environment sky_brightness)、L17(environment cloud_cover 0.25)。

## P2 交互层（步骤/随机/校准/迷路/暗适应）

1. **mission_steps 追踪**：progress["mission_step_state"][level_id] = 已完成步骤 id 数组。
   步骤完成判定：telescope_view 达到 can_identify（或质量达标）且该步 require_part_id 已装。
   最后一步完成前 identify 拦截（提示当前步骤）。UI：sky_observation 引导条 + telescope_view
   面板显示 `Step 1/2: ...`。存档迁移 `_migrate_progress_schema` 补字段。new_game 清空。
2. **L13/L17 target_pool 真随机**：首次进入该关时 randi 从 pool 选目标，存
   progress["level_target_overrides"][level_id]；`current_target()` 优先读 override。
   稳定不刷新；new_game 清空。任务板显示实际选中目标。
3. **L15 寻星镜校准**：progress["finder_offset"] {az, alt}（L15 首次进入时初始化 ±2~3° 随机，
   之后持久）。sky_observation：finder 模式下所有天体渲染位置加 offset（telescope/eye 不加）。
   L15 期间 finder 模式出现 CALIBRATE 面板：方向键(IJKL 或方向键)微调 offset，实时显示
   Alignment %（offset 长度 → 0.5° 内为 100%）。校准到 <0.5° 才能完成本关观测。
   校准后 offset 永久归零（写档）。
4. **L16 迷路体验**：telescope 模式且未 visited finder 时启动计时；45 秒或大幅移动 25 次仍未
   居中目标 → 弹半屏 Maya 提示面板（level_16_mid 文案，按键关闭），引导先宽后窄。
5. **L18 暗适应 + 侧视法**（仅 nebula/galaxy 目标）：进 telescope_view 后 8 秒渐进
   "Dark adaptation 0→100%"（背景星点变暗、目标 alpha +0.10）；按住 Shift = Averted Vision
   （目标 alpha 再 +0.12，面板提示 "hold Shift"）。

## P3 内容层（日志/学习卡/文案/测试）

1. **日志改造**：`_add_journal_entry` 记录 level_number/title、装备（物镜/目镜/支架名）、
   seeing/sky（有则）、`journal_summary_en/zh`（优先，缺则退回 learning_text）。
   learning_journal.gd 新布局：`#N 关卡名` + Equipment + Result + Concept。旧条目容错。
2. **新学习卡 + Pillow 图解**（风格对齐 assets/learning_diagrams 现有 PNG）：
   - eyepiece_power_tradeoff（L10）、seeing_limits_magnification（L11）、
     refocus_after_eyepiece_swap（L12）、coordinate_navigation（L14）、
     finder_calibration（L15）、wide_to_narrow_workflow（L16）、faint_smudge_observation（L18）。
   - L13 沿用 magnification_field_of_view（复习）；L17 不弹新卡（required_concept_card 留空，
     确认 TeachingFlow 对空值安全）。
3. **剧情/板文案对齐**（audit 第七节原文）：L10 双目镜（删 Low/Med/High 三档说法）、
   L11 提空气抖动（机制已真实）、L15 校准、L17 独立考试、L18 期待管理。
4. **journal_summary_en/zh** 填入 L10-L21 全部。
5. **新测试 tools/mechanics_test.gd**：seeing 压质量、换目镜焦点变化、mission_steps 门槛、
   target override 稳定、finder offset 校准前后、journal summary 不重复。全回归照跑。

## 验收（audit 第十节）
每关有真实操作差异；剧情不描述不存在的机制；装备升级有用途；日志不重复。
