# Phase 10：v3.1 — Route A Pikafish 集成

> 路线：**Route A**（Pikafish 集成）
> 周次：v3.0 发布后，约 6 周
> 依赖：Phase 2 Spike 结论为"Route A 可行"（法律合规 + iOS C++ 可编译）

---

## ⚠️ 前置条件

本阶段执行的前提：
- ✅ Phase 2 Spike 确认 GPLv3 合规（或灰色地带按合规处理）
- ✅ Phase 2 Spike 确认 iOS C++ interop 可行
- ✅ Phase 2 Spike 确认编译体积可接受（≤ 50MB，或 ODR 方案可行）

**如果前置不满足**：转入兜底方案，本阶段不执行。参考 Phase 3 延伸（评估调优到 ~2800-3000）。

---

## 目标

通过 Pikafish C 静态库集成，将大师级 AI 棋力从 ~2200 提升至 Elo 3500+。

---

## 具体实施内容

### 10.1 Pikafish C 静态库编译（Week 1-2）

**任务**：
- 锁定 Pikafish release tag（如 v4.0.0）
- iOS arm64 编译（Xcode + C++ toolchain）
- macOS x86_64 + arm64 编译
- 暴露 v3.0 方案 §3.3 定义的完整 C API

**C API 接口**（详细规格见 v3.0-upgrade-plan.md §3.3）：

```c
// 生命周期
PFEngine* pf_engine_init(const char* model_path, int threads, int hash_mb);
void pf_engine_destroy(PFEngine* engine);
const char* pf_engine_get_version(PFEngine* engine);

// 位置管理
PFPosition* pf_position_from_fen(PFEngine* engine, const char* fen);
PFPosition* pf_position_startpos(PFEngine* engine);
int pf_position_make_move(PFPosition* pos, const char* move_uci);
void pf_position_destroy(PFPosition* pos);

// 搜索控制
char* pf_search_bestmove(PFPosition* pos, PFSearchLimits limits);
void pf_search_start(PFPosition* pos, PFSearchLimits limits);
void pf_search_stop(PFEngine* engine);

// 回调
void pf_set_bestmove_callback(PFEngine* engine, PFSearchCallback cb, void* userdata);
void pf_set_info_callback(PFEngine* engine, PFInfoCallback cb, void* userdata);

// Multi-PV
void pf_set_multipv(PFEngine* engine, int count);

// 内存管理
void pf_free_string(char* s);
void pf_free_multipv_result(PFMultipvResult* result, int count);
```

**验收标准**：
- iOS + macOS 双平台编译通过
- 上述全部接口可成功调用
- 版本号校验通过：`pf_engine_get_version()` 返回预期值
- **立即测量 App 体积增量**（如 >50MB 需评估 ODR）

### 10.2 Swift 桥接层（Week 2-3）

**双引擎架构**：

```
┌─────────────────────────────────────────────┐
│                 AIEngine                     │
│  ┌────────────────┐  ┌────────────────────┐ │
│  │  NativeEngine   │  │  PikafishBridge    │ │
│  │  (自研引擎)      │  │  (C++ interop)     │ │
│  │  depth 1-10     │  │  Direct C++ call   │ │
│  │  手写评估        │  │  NNUE 评估         │ │
│  └────────────────┘  └────────────────────┘ │
│         ↑                    ↑               │
│    beginner~medium      hard~master          │
│    快速模式             大师模式              │
└─────────────────────────────────────────────┘
```

**PikafishBridge 设计**：
```swift
actor PikafishBridge {
    private var engine: OpaquePointer?
    private var isLoaded = false
    
    func preload() async throws {
        guard !isLoaded else { return }
        engine = pf_engine_init(nil, ProcessInfo.coreCount - 1, 128)
        isLoaded = true
    }
    
    func unload() {
        guard isLoaded else { return }
        pf_engine_destroy(engine)
        engine = nil
        isLoaded = false
    }
    
    func bestMove(for fen: String, limits: PFSearchLimits) async -> String? {
        // 异步搜索实现
    }
    
    func stopSearch() {
        pf_search_stop(engine)
    }
}
```

**生命周期管理**：

| 阶段 | 行为 |
|------|------|
| App 启动 | 不加载 Pikafish（避免启动延迟） |
| 进入对局设置页 | 后台预热 |
| 首次使用大师级 | 如未加载完成，显示进度条 |
| 对局进行中 | 引擎常驻内存（~30MB） |
| iOS 内存警告 | 释放 Pikafish 资源 |

**关键设计点**：
- 搜索必须异步（iOS 主线程绝不能阻塞）
- Swift 侧用 `actor` 保证线程安全
- `Task { await }` 包装异步搜索
- 搜索信息回调（depth/nodes/score）供 UI 实时展示

### 10.3 难度映射与调优（Week 3-4）

**各难度的 Pikafish 配置**：

| 难度 | 引擎 | 配置策略 |
|------|------|---------|
| 新手 | NativeEngine | 不变（depth 1 + 随机） |
| 初级 | NativeEngine | 不变（depth 3） |
| 中级 | NativeEngine | 不变（depth 5-7） |
| 高级 | Pikafish（限时模式） | depth 限制 / nodes 限制 / Multi-PV 选次优 |
| 大师 | Pikafish（全力模式） | 高 depth / 长 movetime |

**Pikafish 限时参数调优**：
- 高级：Pikafish depth 限制在 15-20，或 movetime 500ms
- 大师：Pikafish depth 30+，movetime 3000ms+

**验收**：各难度可玩，大师级棋力显著强于 v3.0。

### 10.4 开局库整合（Week 4-5）

- Pikafish 自对弈数据提取开局变化
- 扩展开局库到 50000 位置
- 走法合法性自动验证
- 开局名称映射表扩展

### 10.5 触觉反馈（Week 4）

- iOS 选子/移动/吃子/将军震动反馈
- 使用 `UIImpactFeedbackGenerator`

### 10.6 NNUE 模型分发策略

Pikafish NNUE 模型 ~30MB，分发方式需明确：

| 方案 | 优点 | 缺点 | 推荐度 |
|------|------|------|--------|
| 打包进 App Bundle | 简单可靠，离线可用 | App 下载体积 +30MB | **首选**（30MB 可接受） |
| 首次启动下载 | App 体积小 | 需下载服务器 + CDN，离线不可用 | 备选 |
| App Thinning / ODR | App Store 优化 | 仅限 App Store，实现复杂 | 仅当 >50MB 时考虑 |

**决策**：30MB 打包进 Bundle。App 总体积增量（静态库 + 模型）如 ≤ 50MB，用户可接受。如超 50MB，启动 ODR 评估。

### 10.7 外部基准验证

- 交叉对弈：与已知 Elo 引擎对弈 ≥ 50 局
- xiangqi.com 排位赛：≥ 50 局作为辅助验证

---

## 涉及文件

| 文件 | 操作 | 说明 |
|------|------|------|
| `AI/PikafishBridge.swift` | **新增** | C++ interop 核心封装 |
| `AI/AIEngine.swift` | **重大修改** | 双引擎路由逻辑 |
| `pikafish_capi.h` | **新增** | C header 桥接文件 |
| `pikafish_capi.c` / C++ wrapper | **新增** | C API wrapper 层 |
| Pikafish 静态库 (.a/.framework) | **新增** | 编译产物 |
| `Models/Enums.swift` | **修改** | 引擎选择枚举 |
| `Views/GameSettingsView.swift` | **修改** | 大师/高级难度标识 |
| 打谱相关 View | **移除**（移至 Phase 9 或独立 Phase） |
| 残局创作相关 View | **移除**（移至 Phase 9 或独立 Phase） |

---

## 验证标准

| 验收项 | 标准 | 验证方法 |
|--------|------|---------|
| C 库编译 | iOS + macOS 双平台通过 | 编译日志 |
| C API 可用 | 全部接口可调用 | 单元测试 |
| 双引擎切换 | 各难度正确路由到对应引擎 | 手动验证 |
| Pikafish 异步搜索 | 搜索不阻塞主线程 | UI 响应测试 |
| 内存安全 | 对局中无内存泄漏 | Instruments 检测 |
| 内存警告处理 | iOS 内存警告时正确释放 Pikafish | 模拟内存警告 |
| 大师级棋力 | **外部 Elo ≥ 3500**（交叉对弈 ≥ 50 局，95% CI ≤ ±150） | 交叉对弈 + xiangqi.com 排位赛 |
| App 体积 | ≤ 增量 50MB | Archive 后测量 |
| NNUE 模型分发 | 30MB 模型打包进 Bundle，离线可用 | Archive 验证 |
| 现有测试 | 全部通过 | `swift test` |

---

## 依赖关系

```
Phase 2 Spike（Route A 可行 → 法律合规 + 技术可行）
  └── Phase 10（本阶段：Pikafish 集成）
        ├── 输入 ← Phase 9（引擎分析能力，Pikafish 增强分析精度）
        ├── 输入 ← Phase 3/4（自研引擎作为低难度引擎）
        └── 输出 → v3.1 交付（Elo 3500+）
```

**不可行时的替代路径**：
```
Phase 2 Spike（Route A 不可行）
  └── Phase 3 延伸（兜底方案1：评估调优到 ~2800-3000，+2 周）
        └── Phase 11（远期 Route B NNUE 或持续调优）
```

**并行标记**：
- Week 1-2（C 库编译）与 Week 1-2（桥接层设计）可部分并行
- 外部基准验证贯穿全程
- **打谱功能和残局创作模式移出 Phase 10**——这两个是独立功能模块，工作量不小，放入 Phase 10 会让 Pikafish 集成本身的工期过于紧张。移至 Phase 9（v3.0.5）或 v3.1 的后续小版本。
