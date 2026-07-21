# Observation Expansion (L92-L131)

This expansion is loaded from `data/expansion/`; legacy L1-L91 data is not rewritten. Mission completion continues through the existing Club Logbook pipeline.

## Level Catalog

| Level | Mission | Target | Equipment | Real mechanic / failure gates | Teaching | Story |
|---:|---|---|---|---|---|---|
| 92 | Twilight Messenger<br>暮光信使 | mercury | basic_tripod, stable_mount, starter_tube, objective_100mm, eyepiece_20mm, basic_focus_knob | altitude_min=10, altitude_max=24, magnification_max=90, seeing_patience=0.55 | mercury_twilight | Maya introduction |
| 93 | Mercury's Best Window<br>水星最佳窗口 | mercury | basic_tripod, stable_mount, starter_tube, objective_100mm, eyepiece_20mm, basic_focus_knob | altitude_min=12, altitude_max=28, magnification_max=80, seeing_patience=0.7 | mercury_twilight | guided practice / 复练 |
| 94 | A Crescent Behind the Glare<br>强光中的弯月 | venus | basic_tripod, stable_mount, starter_tube, objective_100mm, eyepiece_20mm, basic_focus_knob | exposure_min=0.2, exposure_max=0.48, magnification_max=100 | venus_phase_exposure | Maya introduction |
| 95 | Compare the Phase<br>比较金星月相 | venus | basic_tripod, stable_mount, starter_tube, objective_100mm, eyepiece_20mm, basic_focus_knob | exposure_min=0.18, exposure_max=0.5, require_magnification_comparison=true | venus_phase_exposure | guided practice / 复练 |
| 96 | Rings in Restless Air<br>扰动大气中的土星环 | saturn | basic_tripod, stable_mount, starter_tube, objective_100mm, eyepiece_20mm, basic_focus_knob | stability_min=70, magnification_min=65, magnification_max=130, seeing_patience=0.7 | saturn_rings_seeing | Maya introduction |
| 97 | Cassini Patience<br>耐心寻找环缝 | saturn | basic_tripod, tracking_mount, starter_tube, objective_100mm, eyepiece_20mm, basic_focus_knob | stability_min=74, magnification_min=75, magnification_max=125, require_tracking=true, tracking_min=0.9, tracking_max=1.1, hold_seconds=8 | saturn_rings_seeing | guided practice / 复练 |
| 98 | A Disk, Not a Star<br>圆面而非星点 | uranus | basic_tripod, stable_mount, starter_tube, objective_100mm, eyepiece_20mm, basic_focus_knob | magnification_min=85, focus_multiplier=0.7, stability_min=68 | ice_giant_disks | Maya introduction |
| 99 | Color and Diameter<br>颜色与直径 | uranus | basic_tripod, stable_mount, starter_tube, objective_100mm, eyepiece_20mm, basic_focus_knob | magnification_min=90, focus_multiplier=0.65, stability_min=72 | ice_giant_disks | guided practice / 复练 |
| 100 | Star Hop to Neptune<br>跳星寻找海王星 | neptune | basic_tripod, tracking_mount, starter_tube, objective_100mm, eyepiece_20mm, basic_focus_knob, basic_finder_scope | magnification_min=70, light_min=80, require_finder=true, dark_adaptation_min=0.65, hold_seconds=10, require_tracking=true, tracking_min=0.85, tracking_max=1.15 | ice_giant_disks | Maya introduction |
| 101 | The Faint Blue World<br>暗蓝色世界 | neptune | basic_tripod, tracking_mount, starter_tube, objective_100mm, eyepiece_20mm, basic_focus_knob | magnification_min=80, light_min=84, dark_adaptation_min=0.8, require_averted_vision=true, hold_seconds=12, require_tracking=true, tracking_min=0.92, tracking_max=1.08 | ice_giant_disks | guided practice / 复练 |
| 102 | Map the Lunar Maria<br>绘制月海位置 | moon_mare_tranquillitatis | basic_tripod, stable_mount, starter_tube, objective_100mm, eyepiece_20mm, basic_focus_knob | magnification_max=60 | lunar_feature_scale | Maya introduction |
| 103 | Terraces of Copernicus<br>哥白尼环形山阶地 | moon_crater_copernicus | basic_tripod, stable_mount, starter_tube, objective_100mm, eyepiece_20mm, basic_focus_knob | magnification_min=70, focus_multiplier=0.75 | lunar_feature_scale | guided practice / 复练 |
| 104 | Shadows at the Terminator<br>终结线阴影 | moon_terminator | basic_tripod, tracking_mount, starter_tube, objective_100mm, eyepiece_20mm, basic_focus_knob | magnification_min=45, magnification_max=95, require_tracking=true, tracking_min=0.85, tracking_max=1.15, hold_seconds=7 | lunar_feature_scale | guided practice / 复练 |
| 105 | One Moon, Two Magnifications<br>同一月面，两种倍率 | moon_terminator | basic_tripod, stable_mount, starter_tube, objective_100mm, eyepiece_20mm, basic_focus_knob | require_magnification_comparison=true | lunar_feature_scale | guided practice / 复练 |
| 106 | Two Colors, Two Stars<br>双色双星 | albireo | basic_tripod, stable_mount, starter_tube, objective_100mm, eyepiece_20mm, basic_focus_knob | magnification_min=70, focus_multiplier=0.8 | double_cluster_framing | Maya introduction |
| 107 | Hold the Pair Apart<br>稳定分离双星 | albireo | basic_tripod, stable_mount, starter_tube, objective_100mm, eyepiece_20mm, basic_focus_knob | magnification_min=65, magnification_max=120, stability_min=68 | double_cluster_framing | guided practice / 复练 |
| 108 | The Cluster Does Not Fit<br>装不下的星团 | pleiades | basic_tripod, stable_mount, starter_tube, objective_100mm, eyepiece_20mm, basic_focus_knob | magnification_max=55 | double_cluster_framing | guided practice / 复练 |
| 109 | Resolve the Cluster Halo<br>分解球状星团外晕 | m13 | basic_tripod, stable_mount, starter_tube, objective_100mm, eyepiece_20mm, basic_focus_knob | light_min=72, magnification_min=45, magnification_max=95, dark_adaptation_min=0.55 | double_cluster_framing | guided practice / 复练 |
| 110 | A Ring in the Dark<br>黑暗中的星云环 | ring_nebula | basic_tripod, stable_mount, starter_tube, objective_100mm, eyepiece_20mm, basic_focus_knob | filter=nebula, dark_adaptation_min=0.8, require_averted_vision=true, light_min=78 | faint_object_techniques | Maya introduction |
| 111 | Direct vs Averted Vision<br>直视与侧视 | ring_nebula | basic_tripod, stable_mount, starter_tube, objective_100mm, eyepiece_20mm, basic_focus_knob | filter=nebula, dark_adaptation_min=0.9, require_averted_vision=true, hold_seconds=8 | faint_object_techniques | guided practice / 复练 |
| 112 | Keep the Lagoon Wide<br>保留礁湖全貌 | lagoon_nebula | basic_tripod, stable_mount, starter_tube, objective_100mm, eyepiece_20mm, basic_focus_knob | filter=nebula, magnification_max=60, dark_adaptation_min=0.75, light_min=80 | faint_object_techniques | guided practice / 复练 |
| 113 | The Dust Lane Appears<br>显现尘埃带 | sombrero_galaxy | basic_tripod, tracking_mount, starter_tube, objective_100mm, eyepiece_20mm, basic_focus_knob | filter=none, light_min=86, dark_adaptation_min=0.9, require_averted_vision=true, require_tracking=true, tracking_min=0.94, tracking_max=1.06, hold_seconds=12 | faint_object_techniques | guided practice / 复练 |
| 114 | Big Dipper: Recognize the Pattern<br>北斗七星：识别图形 | ursa_major | Naked-eye constellation deck | shape/order/season/Az-Alt navigation | constellation_ursa_major | Maya introduction |
| 115 | Big Dipper: Navigate by the Pattern<br>北斗七星：使用图形导航 | ursa_major | Naked-eye constellation deck | shape/order/season/Az-Alt navigation | constellation_ursa_major | guided practice / 复练 |
| 116 | Cassiopeia: Recognize the Pattern<br>仙后座：识别图形 | cassiopeia | Naked-eye constellation deck | shape/order/season/Az-Alt navigation | constellation_cassiopeia | Maya introduction |
| 117 | Cassiopeia: Navigate by the Pattern<br>仙后座：使用图形导航 | cassiopeia | Naked-eye constellation deck | shape/order/season/Az-Alt navigation | constellation_cassiopeia | guided practice / 复练 |
| 118 | Cygnus: Recognize the Pattern<br>天鹅座：识别图形 | cygnus | Naked-eye constellation deck | shape/order/season/Az-Alt navigation | constellation_cygnus | Maya introduction |
| 119 | Cygnus: Navigate by the Pattern<br>天鹅座：使用图形导航 | cygnus | Naked-eye constellation deck | shape/order/season/Az-Alt navigation | constellation_cygnus | guided practice / 复练 |
| 120 | Lyra: Recognize the Pattern<br>天琴座：识别图形 | lyra | Naked-eye constellation deck | shape/order/season/Az-Alt navigation | constellation_lyra | Maya introduction |
| 121 | Lyra: Navigate by the Pattern<br>天琴座：使用图形导航 | lyra | Naked-eye constellation deck | shape/order/season/Az-Alt navigation | constellation_lyra | guided practice / 复练 |
| 122 | Aquila: Recognize the Pattern<br>天鹰座：识别图形 | aquila | Naked-eye constellation deck | shape/order/season/Az-Alt navigation | constellation_aquila | Maya introduction |
| 123 | Aquila: Navigate by the Pattern<br>天鹰座：使用图形导航 | aquila | Naked-eye constellation deck | shape/order/season/Az-Alt navigation | constellation_aquila | guided practice / 复练 |
| 124 | Taurus: Recognize the Pattern<br>金牛座：识别图形 | taurus | Naked-eye constellation deck | shape/order/season/Az-Alt navigation | constellation_taurus | Maya introduction |
| 125 | Taurus: Navigate by the Pattern<br>金牛座：使用图形导航 | taurus | Naked-eye constellation deck | shape/order/season/Az-Alt navigation | constellation_taurus | guided practice / 复练 |
| 126 | Scorpius: Recognize the Pattern<br>天蝎座：识别图形 | scorpius | Naked-eye constellation deck | shape/order/season/Az-Alt navigation | constellation_scorpius | Maya introduction |
| 127 | Scorpius: Navigate by the Pattern<br>天蝎座：使用图形导航 | scorpius | Naked-eye constellation deck | shape/order/season/Az-Alt navigation | constellation_scorpius | guided practice / 复练 |
| 128 | Orion: Recognize the Pattern<br>猎户座：识别图形 | orion_constellation | Naked-eye constellation deck | shape/order/season/Az-Alt navigation | constellation_orion_constellation | Maya introduction |
| 129 | Orion: Navigate by the Pattern<br>猎户座：使用图形导航 | orion_constellation | Naked-eye constellation deck | shape/order/season/Az-Alt navigation | constellation_orion_constellation | guided practice / 复练 |
| 130 | Leo: Recognize the Pattern<br>狮子座：识别图形 | leo | Naked-eye constellation deck | shape/order/season/Az-Alt navigation | constellation_leo | Maya introduction |
| 131 | Leo: Navigate by the Pattern<br>狮子座：使用图形导航 | leo | Naked-eye constellation deck | shape/order/season/Az-Alt navigation | constellation_leo | guided practice / 复练 |

## New Objects

- **Mercury / 水星** (`mercury`): Mercury never strays far from the Sun, so low altitude and twilight turbulence are the real challenge. / 水星离太阳的角距始终不大，因此低高度和暮光大气扰动才是真正难点。
- **Venus / 金星** (`venus`): Venus shows phases. Lower power and controlled exposure preserve the crescent edge. / 金星具有月相；降低倍率并控制曝光才能保留弯月边缘。
- **Saturn / 土星** (`saturn`): Saturn's rings need steady air and a stable mount; excessive power magnifies turbulence instead of detail. / 土星环需要稳定大气和支架；过高倍率只会放大扰动，而不会增加细节。
- **Uranus / 天王星** (`uranus`): Uranus is resolved only with high power and precise focus. Its color and disk separate it from field stars. / 天王星需要高倍率与精准调焦才能分辨圆面；颜色和圆面可把它与背景恒星区分开。
- **Neptune / 海王星** (`neptune`): Neptune rewards finder-scope star hopping, large aperture, careful focus, and a long steady look. / 海王星需要寻星镜跳星定位、大口径、细致调焦和长时间稳定观察。
- **Copernicus Crater / 哥白尼环形山** (`moon_crater_copernicus`): High power reveals the terraced rim, but only when focus and seeing remain stable. / 高倍率能显示阶梯状环壁，但焦点和视宁度必须稳定。
- **Mare Tranquillitatis / 静海** (`moon_mare_tranquillitatis`): Low power gives the context needed to compare a lunar mare with brighter highlands. / 低倍率提供整体背景，便于比较暗色月海与明亮高地。
- **Lunar Terminator / 月球终结线** (`moon_terminator`): Near the terminator, low sunlight makes crater walls and mountains appear three-dimensional. / 终结线附近太阳高度低，环形山壁和山脉会呈现立体阴影。
- **Albireo / 辇道增七** (`albireo`): Double stars test angular resolution: low power blends the pair, high power separates their colors. / 双星检验角分辨率：低倍率下两星混合，高倍率下可分辨颜色。
- **Pleiades / 昴星团** (`pleiades`): The Pleiades teach framing: too much power loses the cluster's overall shape. / 昴星团用于学习取景：倍率过高会失去星团的整体形状。
- **Hercules Globular Cluster / 武仙座球状星团 M13** (`m13`): Aperture gathers enough light to resolve the halo while moderate power preserves brightness. / 口径收集足够光线以分解外晕，中等倍率则保留亮度。
- **Ring Nebula / 环状星云 M57** (`ring_nebula`): A narrowband filter increases contrast, while dark adaptation and averted vision reveal the faint ring. / 窄带滤镜能提高对比度，暗适应和侧视法可显出微弱环状结构。
- **Lagoon Nebula / 礁湖星云 M8** (`lagoon_nebula`): Low power, a wide field, a nebula filter, and dark adaptation preserve its extended shape. / 低倍率、宽视野、星云滤镜和暗适应能保留它的延展形状。
- **Sombrero Galaxy / 草帽星系 M104** (`sombrero_galaxy`): Large aperture and averted vision reveal the bright nucleus and edge-on dust lane during a long observation. / 大口径和侧视法在长时间观察中显出亮核与侧向尘埃带。
- **Big Dipper / 北斗七星** (`ursa_major`): Big Dipper is learned as a complete sky pattern and a navigation tool, not as one isolated star. / 北斗七星要作为完整天空图形和导航工具来学习，而不是一颗孤立恒星。
- **Cassiopeia / 仙后座** (`cassiopeia`): Cassiopeia is learned as a complete sky pattern and a navigation tool, not as one isolated star. / 仙后座要作为完整天空图形和导航工具来学习，而不是一颗孤立恒星。
- **Cygnus / 天鹅座** (`cygnus`): Cygnus is learned as a complete sky pattern and a navigation tool, not as one isolated star. / 天鹅座要作为完整天空图形和导航工具来学习，而不是一颗孤立恒星。
- **Lyra / 天琴座** (`lyra`): Lyra is learned as a complete sky pattern and a navigation tool, not as one isolated star. / 天琴座要作为完整天空图形和导航工具来学习，而不是一颗孤立恒星。
- **Aquila / 天鹰座** (`aquila`): Aquila is learned as a complete sky pattern and a navigation tool, not as one isolated star. / 天鹰座要作为完整天空图形和导航工具来学习，而不是一颗孤立恒星。
- **Taurus / 金牛座** (`taurus`): Taurus is learned as a complete sky pattern and a navigation tool, not as one isolated star. / 金牛座要作为完整天空图形和导航工具来学习，而不是一颗孤立恒星。
- **Scorpius / 天蝎座** (`scorpius`): Scorpius is learned as a complete sky pattern and a navigation tool, not as one isolated star. / 天蝎座要作为完整天空图形和导航工具来学习，而不是一颗孤立恒星。
- **Orion / 猎户座** (`orion_constellation`): Orion is learned as a complete sky pattern and a navigation tool, not as one isolated star. / 猎户座要作为完整天空图形和导航工具来学习，而不是一颗孤立恒星。
- **Leo / 狮子座** (`leo`): Leo is learned as a complete sky pattern and a navigation tool, not as one isolated star. / 狮子座要作为完整天空图形和导航工具来学习，而不是一颗孤立恒星。

## Constellation Interaction

Every constellation mission requires four verified stages: identify the complete silhouette, click key stars in the configured order, navigate to the catalog Az/Alt using A/D/W/S, and satisfy the configured seasonal visibility before recording the observation.

## Visual Assets

Implemented distinct in-game vector studies: `mercury.svg`, `venus.svg`, `saturn.svg`, `uranus.svg`, `neptune.svg`, `moon_crater.svg`, `moon_mare.svg`, `moon_terminator.svg`, `albireo.svg`, `pleiades.svg`, `m13.svg`, `ring_nebula.svg`, `lagoon_nebula.svg`, `sombrero.svg`. They are transparent and remain sharp at the compressed gameplay scale.

### Art still worth replacing with final painted assets

- Mercury surface and twilight atmospheric dispersion states.
- Venus phase variants (crescent, quarter, gibbous) and exposure-specific bloom masks.
- Saturn ring tilt and Cassini Division variants.
- Uranus and Neptune subtle banding at multiple seeing states.
- Copernicus, Mare Tranquillitatis, and terminator photo-grade crops.
- Albireo, Pleiades, M13, M57, M8, and M104 clear/dim/defocused raster triplets.
- Optional constellation line-art plates; current star geometry is generated dynamically and already playable.
