# Remind CLI 重构方案

> 版本: v2 | 作者: Alex | 日期: 2026-04-15 | 审查: Vera

## v1→v2 变更记录（响应 Vera 审查）

| # | 优先级 | 问题 | 处理 |
|---|--------|------|------|
| 1 | P1 | `DeleteCommand.swift` 笔误 | 修正为 `DeleteCommand.self` |
| 2 | P2 | RemItem Codable vs Encodable | 改为 Encodable only |
| 3 | P2 | 模糊去重子串包含误报 | 去掉模糊匹配，只保留精确匹配 |
| 4 | P2 | RemStore 无 protocol，CLI 不可测 | 新增 RemStoreProtocol |
| 5 | P3 | 默认列表硬编码中文 | 改用系统默认列表 |
| 6 | P3 | 二进制体积预估未验证 | 去掉具体数字，改为"实测确认" |

---

## 1. 项目定位

Apple Reminders 的命令行工具，替代 remindctl。Swift 编写，调用 EventKit，零第三方运行时依赖。

## 2. 架构

### 2.1 模块分层

```
┌─────────────────────────────┐
│  CLI 层 (ArgumentParser)     │  命令定义、参数解析、输出格式化
│  RemCLI target              │
├─────────────────────────────┤
│  业务逻辑层                  │  RemStore / RemItem
│  RemCore target             │  EventKit 封装、去重、匹配、日期解析
├─────────────────────────────┤
│  EventKit (系统框架)         │
└─────────────────────────────┘
```

### 2.2 SPM 项目结构

```
remind-cli/
├── Package.swift
├── Sources/
│   ├── RemCore/
│   │   ├── RemItem.swift
│   │   ├── RemStoreProtocol.swift  # protocol + 默认实现
│   │   ├── RemStore.swift          # EventKit 实现
│   │   ├── DateParser.swift
│   │   ├── Priority.swift
│   │   ├── MatchResult.swift
│   │   └── RemError.swift
│   └── RemCLI/
│       ├── RemCLI.swift
│       ├── ListCommand.swift
│       ├── ListsCommand.swift
│       ├── AddCommand.swift
│       ├── CompleteCommand.swift
│       ├── UncompleteCommand.swift
│       ├── UpdateCommand.swift
│       ├── DeleteCommand.swift
│       └── SearchCommand.swift
├── Tests/
│   └── RemCoreTests/
│       ├── DateParserTests.swift
│       ├── PriorityTests.swift
│       ├── MatchResultTests.swift
│       └── DedupTests.swift
├── README.md
├── Makefile
├── LICENSE (MIT)
└── .gitignore
```

### 2.3 Package.swift

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "remind-cli",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "rem", targets: ["RemCLI"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0")
    ],
    targets: [
        .executableTarget(
            name: "RemCLI",
            dependencies: ["RemCore", .product(name: "ArgumentParser", package: "swift-argument-parser")],
            path: "Sources/RemCLI"
        ),
        .target(
            name: "RemCore",
            path: "Sources/RemCore"
        ),
        .testTarget(
            name: "RemCoreTests",
            dependencies: ["RemCore"],
            path: "Tests/RemCoreTests"
        )
    ]
)
```

## 3. 核心类型设计

### 3.1 RemItem（纯输出模型，Encodable only）

```swift
public struct RemItem: Encodable, Sendable {
    public let id: String
    public let title: String
    public let list: String
    public let completed: Bool
    public let dueDate: String?
    public let dueDateFull: String?
    public let priority: Int
    public let priorityName: String
    public let notes: String?
    public let creationDate: String?
}
```

单向编码，不支持解码。JSON 输出用 `keyEncodingStrategy = .convertToSnakeCase`。

### 3.2 RemStoreProtocol（可测试性）

```swift
public protocol RemStoreProtocol {
    func allReminders(in list: String?) throws -> [RemItem]
    func allLists() throws -> [ListInfo]
    func search(keyword: String, includeCompleted: Bool) throws -> [RemItem]
    func match(_ query: String, completed: Bool?) throws -> MatchResult<RemItem>
    func add(title: String, list: String?, due: String?, priority: String?, notes: String?) throws -> RemItem
    func complete(_ item: RemItem) throws
    func uncomplete(_ item: RemItem) throws
    func update(_ item: RemItem, title: String?, due: String?, list: String?, priority: String?) throws -> RemItem
    func delete(_ item: RemItem) throws
    func findDuplicate(title: String, in list: String?) throws -> [RemItem]
    func defaultListName() -> String?
}
```

- `RemStore` 实现 `RemStoreProtocol`，封装 EventKit
- CLI 命令通过 init 注入 store（生产环境传 `RemStore()`，测试传 mock）
- `defaultListName()` 返回系统默认列表名（`EKEventStore.defaultCalendarForNewReminders().title`）

### 3.3 MatchResult

```swift
public enum MatchResult<T> {
    case found(T)
    case multiple([T])
    case none
}
```

所有命令遇到 `.multiple` 时列出候选 + 提示用 ID 精确指定，exit 1。

### 3.4 DateParser

```swift
public enum DateParser {
    /// 支持: YYYY-MM-DD, YYYY/MM/DD, today, tomorrow, +Nd
    public static func parse(_ input: String) -> DateComponents?
}
```

### 3.5 Priority

```swift
public enum Priority: Int, CaseIterable, ExpressibleByArgument {
    case none = 0, low = 9, medium = 5, high = 1
}
```

### 3.6 RemError

```swift
public enum RemError: Error, CustomStringConvertible {
    case accessDenied
    case calendarNotFound(name: String)
    case noMatch(query: String)
    case multipleMatch(query: String, items: [RemItem])
    case invalidDate(input: String)
    case invalidPriority(input: String)
    case saveFailed(underlying: Error)
    case noChanges
    case duplicateFound(count: Int)
}
```

## 4. 去重策略

**只做精确匹配**（响应 Vera 审查 #3）。

- 添加时检查同列表下是否有**完全相同标题**的未完成条目
- 匹配到则提示 `--force` 跳过
- 不做模糊匹配——用户需要查相似项用 `search` 命令

```swift
public func findDuplicate(title: String, in list: String?) throws -> [RemItem] {
    try allReminders(in: list)
        .filter { !$0.completed && $0.title == title }
}
```

## 5. 默认列表

使用系统默认列表（响应 Vera 审查 #5）：

```swift
// RemStore.defaultListName()
public func defaultListName() -> String? {
    store.defaultCalendarForNewReminders()?.title
}
```

`add` 命令的 `--list` 参数为 nil 时，调用 `store.defaultListName()` 获取。

## 6. CLI 层设计

```swift
@main
struct RemCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "rem",
        abstract: "Apple Reminders CLI",
        version: "1.0.0",
        subcommands: [
            ListCommand.self, ListsCommand.self, AddCommand.self,
            CompleteCommand.self, UncompleteCommand.self,
            UpdateCommand.self, DeleteCommand.self, SearchCommand.self
        ]
    )
}
```

命令示例（AddCommand）：

```swift
struct AddCommand: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "添加待办（自动去重）")

    @Argument(help: "待办标题")
    var title: String

    @Option(name: .long, help: "目标列表（默认: 系统默认列表）")
    var list: String?

    @Option(name: .long, help: "截止日期 (YYYY-MM-DD / today / tomorrow / +Nd)")
    var due: String?

    @Option(name: .long, help: "优先级 (high/medium/low/none)")
    var priority: Priority?

    @Option(name: .long, help: "备注")
    var notes: String?

    @Flag(name: .long, help: "跳过去重检查")
    var force: Bool = false

    func run() throws {
        let store: RemStoreProtocol = RemStore()
        if !force {
            let dups = try store.findDuplicate(title: title, in: list)
            if !dups.isEmpty {
                throw RemError.duplicateFound(count: dups.count)
            }
        }
        let item = try store.add(title: title, list: list, due: due, priority: priority?.rawValue, notes: notes)
        print("✓ \(item.title) [\(item.list)]\(item.dueDate.map { " \($0)" } ?? "")")
    }
}
```

## 7. 输出格式

### Plain

```
⬜ ABC12345 | 工作待办 | 买牛奶 [low] 2026-04-15
✅ DEF45678 | 个人     | 健身         -无日期-
```

ID 截断前 8 字符，完整 ID 用 `--json`。

### JSON

snake_case，pretty printed。

## 8. 测试计划

| 测试文件 | 覆盖内容 |
|----------|----------|
| DateParserTests | 标准日期、today/tomorrow/+Nd、无效输入 |
| PriorityTests | 字符串→枚举、枚举→显示名、边界值 |
| MatchResultTests | found/multiple/none 状态 |
| DedupTests | 精确匹配、空结果、多条匹配 |

RemStore 不写集成测试。CLI 层通过 `RemStoreProtocol` 可注入 mock，但当前优先级低，先覆盖纯逻辑层。

## 9. Makefile

```makefile
PREFIX ?= /usr/local

.PHONY: build install uninstall clean test

build:
	swift build -c release

install: build
	cp .build/release/rem $(PREFIX)/bin/rem

uninstall:
	rm -f $(PREFIX)/bin/rem

test:
	swift test

clean:
	swift package clean
```

`-static-stdlib` 效果需要实测确认，不预设。构建后确认产物体积，必要时加上。

## 10. README 大纲

1. 一句话介绍
2. 安装（make install / 手动编译）
3. 命令参考
4. JSON 输出示例
5. 与 remindctl 的差异
6. 开发（swift build / swift test）
7. MIT 协议

## 11. 工期估算

| 任务 | 时间 |
|------|------|
| SPM 骨架 + Package.swift | 0.5h |
| RemCore（所有类型） | 2h |
| RemCLI（8 个子命令） | 2h |
| 测试 | 1h |
| README + Makefile + LICENSE | 0.5h |
| **合计** | **6h** |

## 12. 风险

| 风险 | 等级 | 缓解 |
|------|------|------|
| EventKit 权限在 SSH 环境不可用 | 低 | README 注明首次需 GUI 环境授权 |
| ArgumentParser 版本兼容 | 低 | 锁定 1.3.0+，Swift 5.9+ |
| 编译产物体积超预期 | 低 | 构建后实测，必要时调优编译选项 |
