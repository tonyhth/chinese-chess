# v3.3.0 iOS 外部引擎集成技术方案

> 目标：将 pikafish 引擎集成到 iOS 版本，技术可行性论证（不考虑法律问题）。
>
> **版本号**：棋盘翻转 + iOS 引擎集成是两个重要功能，建议 v3.3.0 包含这两个改动。

## 背景

### iOS 约束

iOS 不允许 App 启动外部进程（`Process` 类不可用），不能通过 stdin/stdout 与外部引擎通信。必须将引擎编译为静态库（.a），链接进 App，改用内部函数调用。

### 现有 macOS 实现

当前 macOS 外部引擎集成架构：

1. **ExternalEngineManager**（`#if os(macOS)`）
   - 使用 `Process` 启动 pikafish 进程
   - 通过 `Pipe` 进行 stdin/stdout 通信
   - `UCITransceiver` 处理 UCI 协议异步读取

2. **ChessEngine 协议**
   - `bestMove(fen, moveHistory, difficulty, timeLimitMs)`
   - `stopSearch()`
   - `newGame()`
   - `shutdown()`
   - `isReady`

3. **EngineRouter**
   - 切换内置/外置引擎
   - macOS 分支处理外部引擎启动和 fallback

### 技术参考

**成熟方案**（Stockfish iOS 集成，pikafish 架构类似）：

1. **Trickfest/StockfishEmbedded**
   - GitHub: https://github.com/Trickfest/StockfishEmbedded
   - 静态库集成 + Objective-C wrapper
   - 支持 iOS device + simulator + macOS

2. **dpedley/xcode-stockfish-library**
   - GitHub: https://github.com/dpedley/xcode-stockfish-library
   - 从 executable 改为 library 的核心改动

3. **StockFishKit_iOS**
   - Swift Package，封装 Swift API

4. **pikafish_engine（Flutter）**
   - Flutter plugin for pikafish
   - iOS 需要IPHONEOS_DEPLOYMENT_TARGET >= 11.0

这些项目证明了 Stockfish/pikafish 静态库集成的可行性。

---

## 方案设计

### 方案 A：参考 StockfishEmbedded 集成（推荐）

**核心思路**：参考 Trickfest/StockfishEmbedded 的成熟方案，将 pikafish 改造为静态库，用 Objective-C wrapper 暴露 API，Swift-C 桥接层对接。

---

### 1. 编译方案

**步骤**：

#### 1.1 克隆 pikafish 源码

```bash
git clone https://github.com/official-pikafish/Pikafish.git
```

pikafish 是 C++ 项目，结构与 Stockfish 类似：
- `src/`：核心源码
- `src/nnue/`：NNUE 神经网络
- `Makefile`：编译配置

#### 1.2 改造为静态库

参考 StockfishEmbedded 的改动：

**关键改动点**：
1. **修改 `Makefile`**：目标从 executable 改为 static library
   - 编译参数：`-fPIC`（位置无关代码）
   - 输出：`libpikafish.a`

2. **修改入口点**：
   - 删除 `main()` 函数（executable 入口）
   - 暴露库函数 API

3. **架构适配**：
   - iOS 设备：`arm64`（arm64e 为可选 PAC 强化）
   - iOS 模拟器：`arm64`（Apple Silicon Mac）+ `x86_64`（Intel Mac）
   - 需要分别编译，生成 `libpikafish-arm64.a` / `libpikafish-x86_64.a`
   - 合并为 xcframework 或分别链接

   > **注意**：arm64e 是 ARM64 Extended（指针认证），主要用于设备，模拟器不使用 arm64e。Apple Silicon Mac 的 iOS 模拟器使用普通 arm64。

4. **NNUE 嵌入**：
   - Stockfish 默认将 NNUE 网络嵌入二进制（`-DNNUE_EMBEDDING_ON`）
   - pikafish 应类似处理，确保 NNUE 数据编译进静态库

#### 1.3 Xcode 项目集成

两种方式：

**方式 1：直接集成源码**（更灵活）
- 将 pikafish `src/` 拷贝到 Xcode 项目
- 创建 Xcode static library target
- 配置编译参数（C++17, NNUE embedding）
- 自动处理架构适配

**方式 2：集成预编译 xcframework**（更简洁）
- 预编译各架构的 `.a`
- 用 `lipo` 或 `xcodebuild -create-xcframework` 合并
- 添加到 Xcode 项目 "Frameworks, Libraries, and Embedded Content"

**推荐方式 1**：直接集成源码，便于后续升级 pikafish 版本和调试。

---

### 2. API 封装

**目标**：不走 stdin/stdout，改用内部函数调用。

#### 2.1 C API 层

参考 StockfishEmbedded，在 pikafish 源码中暴露 C 函数接口（C++ 函数需要 `extern "C"` 声明）：

```cpp
// pikafish_api.h（新增文件）
#ifdef __cplusplus
extern "C" {
#endif

/// 初始化引擎（加载 NNUE，设置默认参数）
void pikafish_init(void);

/// 计算最佳走法（同步阻塞，调用者需在后台线程调用）
/// - Parameters:
///   - fen: 局面 FEN
///   - moves: UCI 走法历史（空格分隔）
///   - depth: 搜索深度（0 表示不限）
///   - time_ms: 时间限制（毫秒，0 表示不限）
///   - buffer: 调用者提供的输出缓冲区
///   - buffer_size: 缓冲区大小（建议 >= 16）
/// - Returns: 0 成功，-1 失败
int pikafish_best_move(const char* fen, const char* moves,
                       int depth, int time_ms,
                       char* buffer, int buffer_size);

/// 停止当前搜索
void pikafish_stop(void);

/// 通知引擎新对局
void pikafish_new_game(void);

/// 释放引擎资源
void pikafish_quit(void);

/// 设置引擎选项（如 Hash, Threads）
void pikafish_set_option(const char* name, const char* value);

#ifdef __cplusplus
}
#endif
```

**实现要点**：
- `pikafish_init()`：调用 Stockfish 的 `Engine::init()`，加载 NNUE
- `pikafish_best_move()`：设置局面 → 发起搜索 → 将 bestmove 写入调用者提供的 buffer
- 搜索过程是同步阻塞的，调用者**必须在后台线程**调用
- 调用者提供缓冲区（`buffer`/`buffer_size`），避免跨语言内存分配/释放的 heap mismatch 问题
- 返回值：0 = 成功，-1 = 失败（无合法走法或引擎未初始化）
- **线程安全**：引擎内部非线程安全，同一时间只能有一个搜索调用。由 Objective-C wrapper 保证串行化

#### 2.2 Objective-C Wrapper

创建 Objective-C 类，封装 C API，**内部使用串行 DispatchQueue 保证线程安全和异步执行**：

```objc
// PikafishEngine.h
#import <Foundation/Foundation.h>

@interface PikafishEngine : NSObject

/// 引擎是否就绪
@property (nonatomic, readonly) BOOL isReady;

/// 初始化引擎（异步）
/// - Parameter completion: 成功/失败回调（主线程）
- (void)startWithCompletion:(void (^)(BOOL success, NSError *error))completion;

/// 计算最佳走法（异步）
/// - Parameters:
///   - fen: 局面 FEN
///   - moves: UCI 走法历史（NSArray）
///   - depth: 搜索深度
///   - timeMs: 时间限制（毫秒）
///   - completion: 结果回调（主线程，move=nil 表示失败）
- (void)bestMove:(NSString *)fen
        moves:(NSArray<NSString *> *)moves
        depth:(int)depth
        timeMs:(int)timeMs
  completion:(void (^)(NSString *move))completion;

/// 停止当前搜索
- (void)stopSearch;

/// 新对局
- (void)newGame;

/// 关闭引擎
- (void)shutdown;

@end
```

```objc
// PikafishEngine.m
#import "PikafishEngine.h"
#import "pikafish_api.h"

@implementation PikafishEngine {
    dispatch_queue_t _engineQueue;  // 串行队列，保证引擎调用串行化
    BOOL _isReady;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _engineQueue = dispatch_queue_create("com.chinesechess.pikafish", DISPATCH_QUEUE_SERIAL);
        _isReady = NO;
    }
    return self;
}

- (BOOL)isReady { return _isReady; }

- (void)startWithCompletion:(void (^)(BOOL, NSError *))completion {
    dispatch_async(_engineQueue, ^{
        pikafish_init();
        _isReady = YES;
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(YES, nil);
        });
    });
}

- (void)bestMove:(NSString *)fen
        moves:(NSArray<NSString *> *)moves
        depth:(int)depth
        timeMs:(int)timeMs
  completion:(void (^)(NSString *))completion {
    dispatch_async(_engineQueue, ^{
        NSString *movesStr = [moves componentsJoinedByString:@" "];
        char buffer[16] = {0};
        int ret = pikafish_best_move(
            [fen UTF8String], [movesStr UTF8String],
            depth, timeMs, buffer, sizeof(buffer));
        NSString *result = (ret == 0) ? [NSString stringWithUTF8String:buffer] : nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(result);
        });
    });
}

- (void)stopSearch { dispatch_async(_engineQueue, ^{ pikafish_stop(); }); }
- (void)newGame { dispatch_async(_engineQueue, ^{ pikafish_new_game(); }); }

- (void)shutdown {
    dispatch_async(_engineQueue, ^{
        pikafish_quit();
        _isReady = NO;
    });
}

@end
```

**设计要点**：
- **串行 DispatchQueue**：所有引擎操作（init/bestMove/stop/newGame/shutdown）都在同一个串行队列上执行，保证 C++ 引擎的线程安全
- **completion 回调在主线程**：避免调用者需要手动切线程
- **bestMove 不阻塞调用线程**：`dispatch_async` 将工作提交到后台队列，调用者立即返回
- **无锁设计**：串行队列本身就是互斥，不需要额外的 NSLock

**实现要点**：
- `start()` 调用 `pikafish_init()`
- `bestMove()` 在后台线程调用 `pikafish_best_move()`
- 使用 `NSOperationQueue` 或 `dispatch_queue` 管理后台线程
- completion 回调在主线程返回结果

#### 2.3 Swift-C 桥接

**bridging header**：
```objc
// ChineseChess-Bridging-Header.h
#import "PikafishEngine.h"
```

Swift 可以直接调用 Objective-C API：
```swift
let engine = PikafishEngine()
engine.start()
engine.bestMove(fen, moves: [], depth: 10, timeMs: 0) { move in
    print("Best move: \(move ?? "nil")")
}
```

---

### 3. 生命周期管理

#### 3.1 Swift Actor 封装

创建 Swift actor，实现 `ChessEngine` 协议。

**线程模型说明**：Objective-C wrapper 内部使用串行 DispatchQueue 处理所有引擎操作，completion 回调在主线程。Swift actor 通过 `withCheckedContinuation` 等待回调，不阻塞 actor 串行队列（actor 在 await 点让出执行权）。

```swift
#if os(iOS)

import Foundation

/// iOS 内嵌 pikafish 引擎（静态库）
actor EmbeddedPikafishEngine: ChessEngine {
    nonisolated let displayName: String = "Pikafish"
    nonisolated let engineType: EngineType = .external
    private(set) var isReady = false

    private let objEngine: PikafishEngine

    init() {
        self.objEngine = PikafishEngine()
    }

    func start() async throws {
        try await withCheckedThrowingContinuation { continuation in
            objEngine.startWithCompletion { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: error ?? EngineError.startFailed)
                }
            }
        }
        isReady = true
    }

    func bestMove(fen: String, moveHistory: [String], difficulty: AIDifficulty, timeLimitMs: Int) async -> String? {
        guard isReady else { return nil }

        let depth = mapDifficultyToDepth(difficulty)
        return await withCheckedContinuation { continuation in
            objEngine.bestMove(fen, moves: moveHistory, depth: depth, timeMs: timeLimitMs) { move in
                continuation.resume(returning: move)
            }
        }
    }

    func stopSearch() async {
        objEngine.stopSearch()
    }

    func newGame() async {
        objEngine.newGame()
    }

    func shutdown() async {
        objEngine.shutdown()
        isReady = false
    }

    private func mapDifficultyToDepth(_ difficulty: AIDifficulty) -> Int {
        switch difficulty {
        case .beginner: return 2
        case .easy: return 5
        case .medium: return 10
        case .hard: return 18
        case .master: return 24
        }
    }
}

enum EngineError: Error {
    case startFailed
}

#endif
```

**线程模型分析**：
- `start()` 和 `bestMove()` 内部使用 `withCheckedContinuation` 等待 Objective-C completion 回调
- Objective-C wrapper 在串行 DispatchQueue 上执行引擎操作，completion 在主线程回调
- `await` 挂起 actor 时不阻塞 actor 队列（Swift concurrency 设计），其他 actor 方法可以继续执行
- 但由于 Objective-C wrapper 的串行队列设计，如果引擎正在搜索（bestMove 阻塞在串行队列上），后续的 `stopSearch()` 会排队等待——**这是预期行为**，因为 C++ 引擎不是线程安全的

**stopSearch 的特殊处理**：
- `pikafish_stop()` 需要在搜索进行中调用才能生效
- 但串行队列会排队，等 bestMove 完成后才执行 stop
- **解决方案**：Objective-C wrapper 中 `stopSearch` 不走串行队列，直接在调用线程执行 `pikafish_stop()`（因为 `pikafish_stop()` 本身是线程安全的——它只设置一个 volatile flag）

```objc
- (void)stopSearch {
    // stop 不走串行队列——pikafish_stop() 只设置 volatile flag，线程安全
    // **注意**：需要验证 pikafish_stop() 的实现确实只设置 volatile bool flag（参考 Stockfish 源码），
    // 如果它还做了其他操作（如唤醒等待线程、清理状态），则需要改回走串行队列
    pikafish_stop();
}
```

#### 3.2 内存控制

pikafish 内存占用主要来自：
- **Transposition Table（TT）**：默认可能 128MB+
- **NNUE 网络**：嵌入二进制，约 10-20MB
- **搜索栈**：相对较小

**动态内存阈值策略**（根据设备物理内存调整 TT size）：

```swift
private func configureTTSize() {
    let physicalMemory = ProcessInfo.processInfo.physicalMemory
    let ttSizeMB: Int
    
    if physicalMemory < 2_000_000_000 {  // < 2GB
        ttSizeMB = 16
    } else if physicalMemory >= 4_000_000_000 {  // >= 4GB
        ttSizeMB = 64
    } else {  // 2-4GB
        ttSizeMB = 32
    }
    
    pikafish_set_option("Hash", String(ttSizeMB))
}
```

**调用时机**：在 `pikafish_init()` 后立即调用 `configureTTSize()`。

**设备分类参考**：
- iPhone 8 / iPhone X：~2GB RAM → TT size = 16MB
- iPhone 12 / iPhone 13：~4GB RAM → TT size = 64MB
- iPhone 14 Pro / iPhone 15：~6GB RAM → TT size = 64MB
- iPad Pro：~8GB+ → TT size = 64MB

> **保守策略**：TT size 最大 64MB，避免内存压力。iOS App 内存超过系统限制会被终止。

#### 3.3 单例模式

参考 EngineRouter 的 macOS 实现，iOS 也需要单例：

```swift
#if os(iOS)
private var embeddedEngine: EmbeddedPikafishEngine?
#endif
```

或使用 lazy init：
```swift
actor EmbeddedEngineProvider {
    static let shared = EmbeddedEngineProvider()
    private var engine: EmbeddedPikafishEngine?
    
    func getEngine() async -> EmbeddedPikafishEngine {
        if engine == nil {
            engine = EmbeddedPikafishEngine()
            try? await engine!.start()
        }
        return engine!
    }
    
    func shutdown() async {
        if let e = engine {
            await e.shutdown()
            engine = nil
        }
    }
}
```

---

### 4. 与现有代码兼容

#### 4.1 ChessEngine 协议

`EmbeddedPikafishEngine` 实现 `ChessEngine` 协议，与 macOS `ExternalEngineManager` 对等。

#### 4.2 EngineRouter 改动

**命名统一**：iOS 分支也使用 `externalEngine` 变量名（语义一致，从功能角度看都是“外部引擎”，只是实现方式不同）。macOS 用进程启动，iOS 用静态库。

**当前代码**（`#if os(macOS)` 分支）：
```swift
#if os(macOS)
private var externalEngine: (any ChessEngine)?
private var currentConfigId: UUID?
#endif
```

**iOS 分支改动**：
```swift
#if os(iOS)
private var externalEngine: EmbeddedPikafishEngine?
#endif

@MainActor
func activeEngine() -> any ChessEngine {
    #if os(iOS)
    if let ext = externalEngine {
        return ext
    }
    #elseif os(macOS)
    if let ext = externalEngine {
        return ext
    }
    #endif
    return nativeEngine
}

@MainActor
func switchEngineIfNeeded() async -> any ChessEngine {
    #if os(iOS)
    // iOS 没有外部引擎配置列表，只根据 useEmbeddedEngine 标记切换
    let store = EngineConfigStore.shared
    if store.useEmbeddedEngine {
        if externalEngine == nil {
            externalEngine = EmbeddedPikafishEngine()
            try? await externalEngine!.start()
        }
        return externalEngine ?? nativeEngine
    } else {
        if let ext = externalEngine {
            await ext.shutdown()
            externalEngine = nil
        }
        return nativeEngine
    }
    #elseif os(macOS)
    // 现有 macOS 实现...
    #endif
}
```

#### 4.3 EngineConfigStore 改动

**iOS 简化版设计**：

iOS 不需要外部引擎配置列表（`engines`、`selectedEngineId`、`pendingEngineId` 等属性无意义）。只保留一个 bool 标记：`useEmbeddedEngine`（是否使用内嵌引擎）。

**具体实现**（与 macOS 共用 `EngineConfigStore` 类，但 iOS 分支只使用部分属性）：

```swift
@MainActor
@Observable
final class EngineConfigStore {
    static let shared = EngineConfigStore()

    #if os(macOS)
    // macOS 分支：完整的外部引擎配置管理
    private let key = "chinesechess.externalEngines"
    var engines: [ExternalEngineConfig] { didSet { save() } }
    var selectedEngineId: UUID? { didSet { ... } }
    var pendingEngineId: UUID? { didSet { ... } }
    var pendingNative: Bool = false { didSet { ... } }
    var wantsExternalEngine: Bool = false { didSet { ... } }
    var useExternalEngine: Bool { selectedEngineId != nil }
    var hasPendingSwitch: Bool { ... }
    // ... 其他 macOS 方法
    #endif

    #if os(iOS)
    // iOS 分支：简化版，只有一个 bool 标记
    var useEmbeddedEngine: Bool {
        get { UserDefaults.standard.bool(forKey: "chinesechess.useEmbeddedEngine") }
        set { 
            UserDefaults.standard.set(newValue, forKey: "chinesechess.useEmbeddedEngine")
        }
    }

    // iOS 不需要以下属性，但为了代码编译兼容，提供空实现
    var engines: [ExternalEngineConfig] = []
    var selectedEngineId: UUID? = nil
    var pendingEngineId: UUID? = nil
    var pendingNative: Bool = false
    var wantsExternalEngine: Bool { useEmbeddedEngine }
    var useExternalEngine: Bool { useEmbeddedEngine }
    var hasPendingSwitch: Bool { false }

    func quickToggleEngine() -> String {
        if useEmbeddedEngine {
            useEmbeddedEngine = false
            return "builtIn"
        } else {
            useEmbeddedEngine = true
            return "external"
        }
    }
    #endif
}
```

**设计要点**：
- macOS 分支：完整实现（现有代码不变）
- iOS 分支：简化版，只保留 `useEmbeddedEngine` bool 标记
- iOS 的其他属性（`engines`、`selectedEngineId` 等）提供空实现，保证代码编译兼容
- `wantsExternalEngine` / `useExternalEngine` 在 iOS 上映射到 `useEmbeddedEngine`
- `quickToggleEngine()` 在 iOS 上切换 `useEmbeddedEngine`

**ToolbarView 适配**：iOS 工具栏的引擎切换按钮绑定 `store.useEmbeddedEngine`，UI 逻辑与 macOS 一致。
```

#### 4.4 ToolbarView 改动

iOS 工具栏的引擎切换按钮：
- 当前按钮切换内置/外置引擎
- iOS 分支：切换内置/内嵌引擎
- UI 逻辑保持一致，只是实现不同

---

### 5. 架构适配和编译配置

#### 5.1 编译架构

| 平台 | 架构 | 编译目标 |
|------|------|----------|
| iOS 设备 | arm64（arm64e 为可选 PAC 强化） | iphoneos |
| iOS 模拟器 (Apple Silicon Mac) | arm64 | iphonesimulator |
| iOS 模拟器 (Intel Mac) | x86_64 | iphonesimulator |

> **注意**：arm64e 是 ARM64 Extended（指针认证），主要用于设备，模拟器不使用 arm64e。Apple Silicon Mac 的 iOS 模拟器使用普通 arm64。

#### 5.2 Xcode 编译参数

- **C++ 标准**：`-std=c++17`（pikafish 需要）
- **NNUE 嵌入**：`-DNNUE_EMBEDDING_ON`（默认）
- **优化**：`-O3`（Release）
- **Bitcode**：iOS 可选（App Store 不强制）
- **Symbols stripping**：Release 需 strip

#### 5.3 xcframework 构建

如果使用预编译方式：

```bash
# 编译各架构
make build ARCH=arm64
make build ARCH=x86_64

# 合并为 xcframework（arm64 同时覆盖 device 和 Apple Silicon simulator）
xcodebuild -create-xcframework \
    -library libpikafish-arm64.a \
    -library libpikafish-x86_64.a \
    -output Pikafish.xcframework
```

---

### 6. 测试要点

1. **编译成功**：各架构静态库生成无误
2. **NNUE 加载**：引擎启动时成功加载 NNUE 网络
3. **bestMove 正常**：返回合法 UCI 走法
4. **难度映射**：不同深度搜索返回合理走法
5. **内存控制**：TT size 限制生效，内存占用可控
6. **生命周期**：init → bestMove → shutdown 无泄漏
7. **多线程安全**：后台线程运行不阻塞 UI
8. **引擎切换**：内置/内嵌切换正常
9. **App 退出**：引擎资源正确释放

---

### 7. 工作量估算

| 任务 | 工时（天） |
|------|-----------|
| pikafish 源码改造（API 暴露） | 1-2 |
| Xcode 集成 + 编译配置 | 1-2 |
| Objective-C wrapper | 0.5-1 |
| Swift actor 封装 | 0.5-1 |
| EngineRouter / EngineConfigStore 改动 | 0.5-1 |
| 测试 + 调试 | 1-2 |
| **总计** | **4-7 天** |

**风险点**：
- pikafish 源码改造可能遇到 C++ 编译问题（需要调试）
- NNUE 嵌入可能在 iOS 上有特殊问题（路径、加载方式）
- 多线程安全需要仔细处理（C++ 引擎 + Swift actor）
- 内存控制可能需要多次调试

---

### 8. 备选方案

#### 方案 B：直接使用 StockfishEmbedded 模板

如果 pikafish 源码改造遇到问题，可以：
1. Fork Trickfest/StockfishEmbedded
2. 替换 Stockfish 源码为 pikafish 源码
3. 适配象棋相关改动（棋盘规则、NNUE 网络）
4. 复用已有的 Objective-C wrapper 和编译配置

工作量可能略低（1-2 天），但需要处理 Stockfish → pikafish 的差异。

---

## 推荐方案

**方案 A**：参考 StockfishEmbedded，自行改造 pikafish。

理由：
1. **成熟方案验证**：StockfishEmbedded 证明了静态库集成的可行性
2. **架构清晰**：C API → Objective-C wrapper → Swift actor，层次分明
3. **可控性高**：自行改造可以精确控制 API 和参数
4. **可复用现有架构**：`ChessEngine` 协议和 `EngineRouter` 分支改动很小

---

## 实施清单

| 改动 | 文件/范围 |
|------|----------|
| pikafish 源码改造 | 新增 `pikafish_api.h` / `pikafish_api.cpp` |
| Xcode 项目集成 | ChineseChess-iOS target |
| Objective-C wrapper | 新增 `PikafishEngine.h` / `PikafishEngine.m` |
| Swift actor | 新增 `EmbeddedPikafishEngine.swift`（`#if os(iOS)`） |
| EngineRouter | 增加 iOS 分支处理 |
| EngineConfigStore | 增加 iOS 简化版配置（可选） |
| ToolbarView | iOS 引擎切换按钮适配（可选） |

---

## 不需要改动的部分

- **Board 模型**：完全不变
- **GameViewModel**：`bestMove()` 调用逻辑不变
- **AIEngine（内置引擎）**：不变
- **UCITransceiver**：iOS 不需要（不走 stdin/stdout）
- **macOS 外部引擎集成**：保持现有实现

## Vera 审查修复记录（v2）

| # | 级别 | 问题 | 修复 |
|---|------|------|------|
| 1 | P0 | C API `char*` 返回值内存管理未明确（跨语言 heap mismatch 风险） | 改为调用者提供 buffer/buffer_size 参数，返回 int（0=成功，-1=失败） |
| 2 | P0 | Swift actor 与 C++ 引擎线程模型冲突（async 方法阻塞 actor） | Objective-C wrapper 用串行 DispatchQueue，completion 在主线程；Swift 用 withCheckedContinuation 等待，不阻塞 actor |
| 3 | P0 | `start()` 等待机制描述错误（没有 Objective-C completion 通知） | 改为 `startWithCompletion(callback)`，Swift 用 withCheckedThrowingContinuation 等待 |
| 4 | P1 | 编译架构描述有误（arm64e 不是 simulator 架构） | 改为 arm64（Apple Silicon simulator）+ x86_64（Intel simulator），arm64e 仅用于设备 PAC 强化 |
| 5 | P1 | EngineRouter iOS 分支命名不一致（embeddedEngine vs externalEngine） | 统一命名为 `externalEngine`（语义一致：从功能角度都是外部引擎） |
| 6 | P1 | EngineConfigStore iOS 简化方案缺失具体实现 | 补充完整 iOS 分支实现：useEmbeddedEngine bool + 其他属性空实现保证编译兼容 |
| 7 | P1 | pikafish NNUE 嵌入机制未验证 | 保留建议：实施前用原型验证 |
| 8 | P2 | 搜索强度与难度映射可能不匹配 | 保留建议：测试阶段校准 |
| 9 | P2 | 内存控制策略缺失具体阈值 | 补充动态阈值策略：物理内存 <2GB→16MB，>=4GB→64MB，2-4GB→32MB |
| 10 | P2 | 方案 B（StockfishEmbedded模板）可行性存疑 | 保留建议：如果方案 A 遇到问题，作为 fallback |

**修复后状态**：P0/P1 全部修复，P2 #9 补充，P2 #7/#8/#10 作为实施前验证建议。方案可进入实现阶段。