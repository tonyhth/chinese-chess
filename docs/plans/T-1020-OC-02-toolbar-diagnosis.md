# T-1020-OC-02 macOS 工具栏诊断（方案先行，批准随批修）

- **作者/日期**：Cody 2026-10-18 ｜ 派单：Luke（洪涛 18:55 批，丹妮转）｜ DDL 10-21 12:00（方案；实施候批）
- **性质**：诊断+方案（零代码，批准随批修）
- **规格锚**：派单三选（分组收纳 Menu／提权核心项／窗口最小宽）+ 洪涛 18:55 实证（学棋按钮折叠进溢出区找不到）

---

## 1. 现状结构勘察（ToolbarView macOS 分支，src/ChineseChess/Views/ToolbarView.swift L240-394）

内联工具栏（窗顶常驻）：

| 组 | 项 | 形态 | 静态宽估算 |
|---|---|---|---|
| 棋局控制组（spacing 8） | 新局（Label+⌘N）／悔棋（Label+⌘Z）／提示（Label+⌘I） | bordered 按钮×3 | ~76-96pt/项 ≈ **230-290pt** |
| — | Spacer（可压缩至 0） | — | ≥8 |
| 设置组（spacing 8） | 难度 Picker（定宽 70）＋执边圆点（12）＋⋯溢出 Menu（28） | menu/点/图标 | **~126pt** |
| — | 水平 padding | — | 32 |

**内联静态合计 ≈ 430-500pt**。

溢出菜单（⋯）：`p1OverflowItems()` **14 项平铺**（resign/replay/analysis/coach/record/puzzles/**studyHub**/dailyChallenge/stats/history/theme/achievements/rankPrivilege/settings）＋ 3 处 divider——学棋（studyHub）列**第 7 位**。

窗口约束：主窗 `minWidth = LayoutSpec.compactWindowMin = 900`（LayoutSpec L73，小窗退化带 900-1280）。

## 2. 诊断结论（两线证据）

**D1 宽度面：宽度驱动折叠在本配置下不会发生。** 内联最小 ~430-500pt << 主窗最小 900pt——合法窗宽区间内 Spacer 压缩至 0 后仍有 ≥400pt 余量，内联三钮+设置组无折叠压力。⻩涛所见「窗口宽度不足溢出折叠右上角」实为 **v6.4 C1 设计态**（LJ-2 根治：低频 14 项全部收编 ⋯ 菜单），非宽度 bug。

**D2 发现性面：真实问题=⋯ 菜单 14 项平铺的信息架构。** 学棋=核心学习流入口（§五.7 统计机制的数据源主路径），却埋于 14 项平铺菜单第 7 位；菜单无分组语义（3 处 divider 为对局/复盘局部切分，非功能域分组），扫视成本 O(14)。洪涛「学棋按钮折叠进溢出区找不到」= **可发现性/信息架构问题**，宽度option C 不对症。

**D3 实测面（诚实声明）**：本诊断宽度数为静态推算（Label/Button 固有尺寸×数量+spacing+padding）；动态实测可复用在案 LayoutDump 基础设施（P1 width sampling 管道，ChineseChessApp L390-402 同款）按窗宽 600/800/1000/1280 四点采样——列入选批后的实施首步（先测后改）。

## 3. 三选评估（按派单三选项）

### 选项 A：分组收纳 Menu（⋯ 菜单内功能域分组）
- 做法：14 项按功能域四组，组间 Divider（或 SwiftUI Menu Section 带标题）：**学棋域** studyHub/dailyChallenge/puzzles/coach ｜ **对局域** resign/replay/analysis/record ｜ **数据域** stats/history ｜ **外观与设置域** theme/achievements/rankPrivilege/settings
- 改动面：p1OverflowItems 数组重排+补 divider（~6 行）——零内联变化、零宽度影响
- 效果：扫视成本 14→4 组；学棋仍需点 ⋯（发现性部分改善）
- 风险：最低

### 选项 B：提权核心项（学棋入内联常驻）
- 做法：studyHub 从溢出提为内联 labeled Button（与 新局/悔棋/提示 同形态，+~90pt）；其余 13 项按 A 分组
- 改动面：内联加 1 按钮（~10 行）+ A 的数组重排
- 效果：学棋**常驻可见**（洪涛主诉直接解决）；内联合计 ~520-590pt << 900min，无挤压风险
- 风险：低（内联预算充裕；日常对局用户见新增钮的适应成本一次）

### 选项 C：窗口最小宽
- 做法：mainWindow minWidth 900→~720pt（现状内联已 <720，此项实际无变化空间——**900 已是现值**，提至更高反强制宽窗）
- 评估：**不对症**——D1 证明折叠非宽度驱动；C 无法改善 ⋯ 菜单发现性。不推荐单独采。

## 4. 推荐

**A+B 组合**：B 提权 studyHub 单项入内联（主诉直接解决）＋ A 分组收纳其余 13 项（扫视性根治）；C 不采（与根因无关）。dailyChallenge 是否同批提权候裁（+~100pt 预算仍充裕，但内联钮越多信息密度越低，建议学棋先行观察）。

影响面预估：ToolbarView macOS 分支 ~15 行 + p1OverflowItems 重排 ~10 行——零 enum/引擎/lvl6 触碰。

## 5. 验证方案（选批后实施首步）

1. LayoutDump 四点窗宽采样（600/800/1000/1280）留档改前改后
2. 手工 resize 矩阵：窗宽 900/1000/1280/1920 × 提权钮可见性/⋯ 菜单分组截图
3. 三套件回归（SelectionConsistency 等）+ BUILD rc=0

## 6. 候裁点

1. A+B 组合是否批准（或仅 A）
2. dailyChallenge 是否同批提权
3. 分组命名（学棋/对局/数据/外观与设置 四域命名候产品面微调）
