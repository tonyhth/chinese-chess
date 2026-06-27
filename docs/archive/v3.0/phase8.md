# Phase 8：可玩性 — 主题经济 + 开局库扩展 + 数据迁移 + QA 收尾

> 路线：**可玩性收尾层**
> 周次：Week 6-8（开局库如延后则 Week 7-8）
> 依赖：Phase 6（段位/成就）、Phase 7（每日挑战/残局库）

---

## 目标

1. 主题解锁经济：段位/成就关联的主题解锁系统
2. 开局库扩展：10000 位置 + 50 名称映射（如 Phase 7 未完成）
3. 数据迁移：v2.x → v3.0 用户数据平滑迁移
4. QA 收尾：v2.2.17 iOS bugs 修复 + 全量功能测试

---

## 具体实施内容

### 8.1 主题解锁经济

**设计**：将现有主题系统与段位/成就挂钩，形成"解锁经济"。

**解锁路径**：

| 主题 | 解锁条件 | 来源 |
|------|---------|------|
| 默认主题 | 初始可用 | 已有 |
| 秀才主题 | 升至秀才 | 新增 |
| 举人主题 | 升至举人 | 新增 |
| 进士主题 + 专属棋子 | 升至进士 | 新增 |
| 翰林主题 + 棋盘纹理 | 升至翰林 | 新增 |
| 国手主题（金色棋子 + 龙纹棋盘） | 升至国手 | 新增 |
| 棋圣主题（玉石质感 + 古典纹饰） | 升至棋圣 | 新增 |
| 连续登录主题 | 连续登录 30 天 | 新增 |
| 钻石成就主题 | 解锁钻石成就 | 新增 |

**实现**：
- `ThemeManager` 检查 `PlayerProfile` 段位 + 成就 → 决定可用主题列表
- 主题选择 UI 标注"解锁条件"
- 新增 2-3 个主题样式（复用现有主题系统，调整配色/纹理）

### 8.2 开局库扩展（如 Phase 7 未完成）

- 从公共领域大师对局记录提取开局变化
- 目标 10000 位置（现有 4602）
- 50 个常见开局名称映射
- 走法合法性自动验证

### 8.3 数据迁移（v2.x → v3.0）

**迁移映射**：

| v2.x 字段 | v3.0 字段 | 迁移逻辑 |
|-----------|----------|---------|
| `hasCompletedTutorial` | `completedTutorials` | true → 插入 `.basicRules` |
| `GameHistoryStore` 对局记录 | 不变 | 保持原有存储 |
| `chinesechess.notationFormat` | 不变 | key 不变 |
| `chinesechess.aiDifficulty` | `PlayerProfile.rank` | 根据历史胜场反算段位 |
| 残局通关进度 | `totalPuzzlesSolved` + 成就追溯 | 满足条件的成就自动解锁 |
| 无 | `joinDate` | 设为首次启动日期或当前日期 |

**迁移逻辑**：
```swift
func migrateIfNeeded() {
    let defaults = UserDefaults.standard
    guard !defaults.bool(forKey: "v3.0_migrated") else { return }
    
    // 1. 教程迁移
    if defaults.bool(forKey: "hasCompletedTutorial") {
        profile.completedTutorials.insert(.basicRules)
    }
    
    // 2. 段位反算
    let masterWins = profile.totalWins[.master] ?? 0
    let hardWins = profile.totalWins[.hard] ?? 0
    // ... 根据胜场反算初始段位
    
    // 3. 成就追溯
    // 检查历史数据，自动解锁满足条件的成就
    
    defaults.set(true, forKey: "v3.0_migrated")
}
```

**迁移时机**：App 启动时检测 `v3.0_migrated` 标记，不存在则执行一次性迁移。

**残局 ID 映射策略**：

v2.x 残局库（20 种）到 v3.0 新残局库（50 种）的映射：
- v2.x 旧残局保留原有 ID，作为新库的子集
- 新增的 30 种残局分配新 ID（不与旧 ID 冲突）
- 玩家通关记录映射规则：
  - 旧 ID 在新库中仍存在的 → 通关记录保留
  - 旧 ID 被重新设计的 → 通关记录保留（视为已通关），但允许玩家重玩新版
  - `totalPuzzlesSolved` 直接沿用旧值

**迁移失败回滚**：
- 迁移前将旧 UserDefaults 完整备份到 `chinesechess.v2x_backup` key
- 迁移过程中任何异常 → 恢复备份 + 标记 `v3.0_migrated = false` + 记录错误日志
- 用户下次启动会重试迁移

### 8.4 异常路径与故障恢复

| 场景 | 处理策略 |
|------|----------|
| 自对弈中途崩溃 | SelfPlayRunner 记录已完成局数，崩溃后可从断点续跑（日志文件标记进度） |
| Pikafish 编译失败 | Phase 10 有明确的兜底方案（Phase 3 延伸），不阻塞 v3.0 交付 |
| 数据迁移中途失败 | 回滚到 v2.x 备份数据，下次启动重试（上方已详述） |
| NNUE 模型加载失败 | PikafishBridge 返回错误，UI 降级提示"大师模式暂时不可用，已切换至高级"，回退到 NativeEngine |
| 自对弈结果不可信 | 对局 FEN 序列全部保存，事后可审计异常对局 |

### 8.4 QA + Bug 修复

**v2.2.17 iOS Bug 清单**（参考 `knowledge/v2.2.17-ios-bug-analysis.md`）：
- 所有已知 iOS bugs 在本阶段全部修复
- 新增功能的全面测试

**测试范围**：
- 新手引导完整流程
- 段位升降正确性
- 成就解锁完整性
- 每日挑战日期逻辑
- 数据迁移正确性
- 主题切换与持久化
- AI 各难度级别可玩性
- iOS + macOS 双平台

### 8.5 App 图标设计

**强制项**：v3.0 必须交付新 App 图标。

- 输出：完整 `AppIcon.appiconset` 目录（含各尺寸）
- 风格：与项目中国风 UI 一致
- 集成：写入 Xcode 项目的 `Assets.xcassets/AppIcon.appiconset/`
- 规格：遵循 Apple Human Interface Guidelines

---

## 涉及文件

| 文件 | 操作 | 说明 |
|------|------|------|
| `Services/PlayerProfileStore.swift` | **修改** | 数据迁移逻辑 |
| 主题相关文件 | **修改** | ThemeManager 解锁逻辑 |
| 新增主题资源 | **新增** | 2-3 个新主题的配色/纹理 |
| `AI/OpeningBook.swift` | **修改** | 扩展位置（如未在 Phase 7 完成） |
| `Assets.xcassets/AppIcon.appiconset/` | **新增/更新** | 完整 App 图标 |
| `Info.plist` | **修改** | 版本号更新 |

---

## 验证标准

| 验收项 | 标准 | 验证方法 |
|--------|------|---------|
| 主题解锁 | 段位/成就正确解锁对应主题 | 逐级验证 |
| 主题切换 | 切换后正确应用，App 重启后保持 | 手动验证 |
| 数据迁移 | v2.x 数据正确映射到 v3.0 | 用旧版本数据测试迁移 |
| 迁移幂等 | 迁移只执行一次，不重复 | 多次启动验证 |
| iOS Bug 修复 | v2.2.17 所有 bugs 已修复 | 逐 bug 验证 |
| 全量功能测试 | 所有新功能 iOS + macOS 可用 | 手动 + 自动测试 |
| App 图标 | 完整 appiconset 集成到项目 | Xcode 资源验证 |
| `swift test` | 全部通过 | 测试报告 |

---

## 依赖关系

```
Phase 6（段位 + 成就）
Phase 7（每日挑战 + 残局库）
  └── Phase 8（本阶段：主题经济 + 迁移 + QA）
        ├── 输出 → v3.0 交付验收
        └── 输出 → Phase 9（v3.0.5：AI 教练等）
```

**并行标记**：
- Phase 8 依赖 Phase 6 + Phase 7 完成
- QA 是 v3.0 的最后关口，必须所有功能就绪后进行
- App 图标设计可与 QA 并行（设计工作，不依赖代码）
