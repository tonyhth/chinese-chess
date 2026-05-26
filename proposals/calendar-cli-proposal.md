# Calendar CLI — 技术方案

> 版本: v2 (审查修订) · 作者: Alex · 日期: 2026-04-19
> v1 → v2 变更：修复 Vera 审查 P0-1~4、采纳 P1-5~9、改进 P2-10~13

---

## 1. 产品名

**`calcli`**

理由：
- **简短**：3 个字母，CLI 输入效率极高
- **语义清晰**：`calcli` = event，一看就知道是管事件的
- **无冲突**：不与系统 `cal`（日历显示）冲突，也不与 macOS 自带工具重名
- **命令直觉**：`calcli add`、`calcli list`、`calcli show` 读起来自然

## 2. 技术选型

| 项目 | 选型 | 理由 |
|------|------|------|
| 语言 | Swift 5.9+ | 与 remind-cli 一致，原生访问 EventKit |
| 框架 | EventKit (EKEventStore) | Apple 官方日历 API，完整读写能力 |
| CLI 解析 | swift-argument-parser 1.3+ | 同 remind-cli，Apple 维护，子命令支持好 |
| 异步模式 | DispatchSemaphore | 同 remind-cli，简单可靠 |
| 最低平台 | macOS 14 (Sonoma) | EventKit 新权限模型需要 |
| 构建 | SwiftPM，单可执行文件 | `swift build -c release`，产物拷贝到 `/usr/local/bin/calcli` |
| 终端输出 | ANSI 颜色码 + `--json` flag | 同 remind-cli 模式 |

## 3. 架构设计

沿用 remind-cli 的 RemCore/RemCLI 分层：

```
Sources/
├──EvtCore/                  # 核心业务层（无 CLI 依赖）
│   ├── EventStore.swift     # EKEventStore 封装，所有 EventKit 交互
│   ├── EventItem.swift      # 事件数据模型（Encodable）
│   ├── AlertItem.swift      # 提醒数据模型
│   ├── DateParser.swift     # 日期/时间解析（扩展 remind 版本）
│   ├── AlertParser.swift    # 提醒时间解析（相对/绝对）
│   └── EventError.swift     # 错误类型
├──EvtCLI/                   # CLI 表现层
│   ├── EvtCLI.swift         # @main 入口 + 输出工具函数
│   ├── AddCommand.swift
│   ├── ListCommand.swift
│   ├── ShowCommand.swift
│   ├── UpdateCommand.swift
│   ├── DeleteCommand.swift
│   └── AlertCommand.swift
```

### 分层职责

- **EvtCore**：封装 EventKit 操作，通过 protocol 暴露（便于测试 mock）。不关心终端输出格式。
- **EvtCLI**：解析命令行参数，调用 EvtCore，格式化输出。不含业务逻辑。

## 4. 数据模型

### EventItem

```swift
public struct EventItem: Encodable, Sendable {
    public let id: String           // calendarItemExternalIdentifier
    public let title: String
    public let calendar: String     // 日历名称
    public let calendarType: String // "Local" | "iCloud" | "Exchange" | "CalDAV"
    public let startDate: String    // "2026-04-19 09:00"
    public let endDate: String      // "2026-04-19 10:30"
    public let isAllDay: Bool
    public let location: String?
    public let notes: String?
    public let url: String?
    public let alerts: [AlertItem]
    public let creationDate: String?
}
```

### AlertItem

```swift
public struct AlertItem: Encodable, Sendable {
    public let index: Int           // 在 event.alarms 数组中的位置（删除用）
    public let type: String         // "relative" | "absolute"
    public let offset: String?      // "15m" / "1h" / "1d" (相对时间)
    public let absoluteDate: String? // "2026-04-19 08:30" (绝对时间)
}
```

## 5. 命令行接口设计

### 全局选项

```
calcli [--json] [--help] [--version] <subcommand>
```

| 选项 | 说明 |
|------|------|
| `--json` | JSON 输出（所有命令通用） |
| `--version` | 显示版本号 |

### 5.1 `calcli add`

创建事件。

```
calcli add <title> [options]
```

| 参数/选项 | 类型 | 必填 | 说明 |
|-----------|------|------|------|
| `<title>` | 位置参数 | ✅ | 事件标题 |
| `--start` | String | ✅ | 开始时间（见 §6.9 DateParser 格式规格） |
| `--end` | String | 条件 | 结束时间，同上格式。全天事件可省略 |
| `--all-day` | Flag | - | 标记为全天事件（见 §6.10 全天事件 end 语义） |
| `--calendar` / `-c` | String | - | 目标日历（默认：系统默认日历） |
| `--location` / `-l` | String | - | 地点 |
| `--notes` / `-n` | String | - | 备注 |
| `--url` | String | - | 关联 URL |
| `--alert` | String | - | 提醒，可多次指定。格式见 §6.5 |

**示例**：
```bash
calcli add "团队周会" --start "2026-04-21 10:00" --end "2026-04-21 11:00" \
  --calendar "工作" --location "会议室A" --alert 15m --alert 1h

calcli add "假期" --start 2026-05-01 --all-day --end 2026-05-03
# 含义：5/1、5/2、5/3 三天（end inclusive，内部自动 +1day）
```

### 5.2 `calcli list`

列出/搜索事件。

> **v2 变更**：原 `search` 命令合并到 list，通过 `--keyword` + `--search-location` / `--search-notes` 扩展搜索范围。

```
calcli list [options]
```

| 选项 | 说明 |
|------|------|
| `--calendar` / `-c` | 按日历过滤 |
| `--from` | 起始日期（默认：今天） |
| `--to` | 截止日期（默认：from + 7 天） |
| `--days` | 显示天数（替代 --to，默认 7） |
| `--keyword` / `-k` | 按标题关键词过滤 |
| `--search-location` | 关键词同时匹配地点字段 |
| `--search-notes` | 关键词同时匹配备注字段 |
| `--limit` | 最大返回条数（默认 100，上限 500） |

**示例**：
```bash
calcli list                        # 本周事件
calcli list --days 30              # 未来 30 天
calcli list --from 2026-05-01 --to 2026-05-31
calcli list -c "工作" --days 14
calcli list -k "周会" --search-notes --days 90  # 搜索标题+备注
```

**输出格式**（Plain）：
```
📅 2026-04-19 (Sat)
  09:00-10:30  团队周会          [工作]
  14:00-15:00  1:1 with Alex     [个人]

📅 2026-04-20 (Sun)
  (no events)
```

**--json 示例**：
```json
{
  "events": [
    {
      "id": "ABC123...",
      "title": "团队周会",
      "calendar": "工作",
      "start_date": "2026-04-19 09:00",
      "end_date": "2026-04-19 10:30",
      "is_all_day": false,
      "location": "会议室A"
    }
  ],
  "count": 1,
  "truncated": false
}
```

### 5.3 `calcli show`

查看单个事件详情。

```
calcli show <query> [--id]
```

| 参数/选项 | 说明 |
|-----------|------|
| `<query>` | 默认按标题模糊匹配 |
| `--id` | 将 query 解析为事件 ID（精确/前缀匹配） |

多条匹配时列出候选项并报错。

**输出**：
```
Title:     团队周会
Calendar:  工作 (iCloud)
Start:     2026-04-21 10:00
End:       2026-04-21 11:00
Location:  会议室A
Notes:     讨论Q2规划
URL:       (none)

Alerts:
  🔔 15 minutes before
  🔔 1 hour before
```

### 5.4 `calcli update`

修改事件。

```
calcli update <query> [options]
```

| 参数/选项 | 说明 |
|-----------|------|
| `<query>` | 标题模糊匹配 |
| `--id` | 将 query 解析为事件 ID |
| `--title` | 新标题 |
| `--start` | 新开始时间 |
| `--end` | 新结束时间 |
| `--calendar` / `-c` | 移动到其他日历（见 §6.7 跨日历移动） |
| `--location` / `-l` | 新地点（传空字符串 `""` 清除） |
| `--notes` / `-n` | 新备注（传 `""` 清除） |
| `--url` | 新 URL（传 `""` 清除） |
| `--all-day` | 切换全天事件 |
| `--no-all-day` | 取消全天事件 |

至少指定一个修改项，否则报错。

### 5.5 `calcli delete`

删除事件。

```
calcli delete <query> [options]
```

| 参数/选项 | 说明 |
|-----------|------|
| `<query>` | 标题模糊匹配 |
| `--id` | 将 query 解析为事件 ID |
| `--force` | 跳过确认提示 |

### 5.6 `calcli alert`

管理事件的提醒。

```
calcli alert <action> <query> [options]
```

| 子动作 | 说明 |
|--------|------|
| `add` | 添加提醒 |
| `remove` | 删除提醒 |
| `list` | 列出提醒 |

**`calcli alert add`**：
```
calcli alert add <query> --time <alert-spec> [--id]
```
- `--time`：提醒规格，同 add 的 `--alert` 格式

**`calcli alert remove`**：
```
calcli alert remove <query> --index <N> [--id] [--force]
```
- `--index`：提醒序号（从 `calcli alert list` 或 `calcli show` 中获取，1-based）
- 删除前展示当前提醒列表，要求确认（`--force` 跳过确认）

**示例**：
```bash
calcli alert add "周会" --time 30m
calcli alert add "周会" --time @2026-04-21 09:00
calcli alert remove "周会" --index 2
calcli alert list "周会"
```

## 6. 关键技术决策

### 6.1 DispatchSemaphore 处理 EventKit 异步

同 remind-cli，EventKit 的 `fetchReminders` / `fetchEvents` 是异步回调，用信号量转同步。简单、可控。

### 6.2 事件查询

日历事件必须有明确的时间范围。查询通过 `predicateForEvents(withStart:end:calendars:)` 实现。

**list 默认行为**：
- 默认范围：今天起 7 天
- `--limit 100`（默认值），上限 500。超出截断并在输出中标记 `truncated: true`

### 6.3 事件匹配策略

> **v2 变更**：query 语义拆分，不再混合 ID 和标题匹配。

**标题模式**（默认）：
1. 标题模糊匹配（`localizedCaseInsensitiveContains`）→ 唯一结果返回，多条报错列出候选项

**ID 模式**（`--id` flag）：
1. 精确 ID 匹配 → 直接返回
2. ID 前缀匹配 → 直接返回
3. 无匹配 → 报错

这消除了 ID 前缀和标题内容冲突的边界情况。

### 6.4 ID 稳定性说明

`calendarItemExternalIdentifier` 的稳定性取决于日历类型：

| 日历类型 | ID 稳定性 | 说明 |
|----------|-----------|------|
| 本地 (Local) | ✅ 稳定 | 单机唯一，不变 |
| iCloud | ✅ 稳定 | 同步后保持一致 |
| Exchange / CalDAV (第三方) | ⚠️ 可能变化 | 同步后标识符可能改变 |

**策略**：
- 支持所有日历类型的读写
- `show` 输出中标注日历类型（`calendarType` 字段）
- `--id` 模式无匹配时，额外提示："如果使用 Exchange/CalDAV 日历，ID 同步后可能变化，建议用标题匹配"

### 6.5 提醒（EKAlarm）管理

EKAlarm 没有稳定 ID。管理策略：
- **添加**：创建新的 `EKAlarm(relativeOffset:)` 或 `EKAlarm(absoluteDate:)`
- **删除**：按序号索引（从 `event.alarms` 数组中移除指定位置）
- **删除前确认**：展示当前提醒列表，用户确认后执行（`--force` 跳过）
- **解析**：`relativeOffset` 为负数表示事件开始前 N 秒

AlertParser 支持格式：
| 输入 | 解析结果 |
|------|----------|
| `15m` | relativeOffset = -900 |
| `1h` | relativeOffset = -3600 |
| `1d` | relativeOffset = -86400 |
| `2h30m` | relativeOffset = -9000 |
| `@2026-04-19 08:30` | absoluteDate |

### 6.6 并发冲突处理

EventKit 的 `EKEvent` 在 save 时会检查事件是否已被外部修改。

**策略**：
1. 每次写操作前，通过 `store.event(withIdentifier:)` 重新 fetch 最新版本
2. 如果 fetch 到的事件属性与预期不一致，说明被外部修改
3. **不做自动合并**（CLI 工具不适合自动解决冲突）
4. 检测到冲突时报错：`❌ Event was modified externally. Re-fetch and retry.`
5. 用户重新执行命令即可拿到最新数据

### 6.7 跨日历移动

`calcli update <query> -c "其他日历"` 的实现：

EKEvent 不支持直接跨日历移动，需要 remove + save 两步操作。

**安全策略**：
1. 读取原事件，记录完整快照
2. 创建新事件，复制所有属性，设新 calendar
3. `store.save(newEvent, commit: false)`
4. `store.remove(oldEvent, commit: false)`
5. `store.commit()` — 原子提交

使用 `commit: false` + 最终 `commit()` 实现伪原子操作。如果中间任一步失败，不调用 commit，事务整体回滚，不会出现"删了旧的、新建失败"的情况。

### 6.8 JSON 输出 Schema

`--json` 输出格式：

**list 输出**：
```json
{
  "events": [EventItem...],
  "count": 3,
  "truncated": false
}
```

**show / add / update 输出**：单个 EventItem 对象

**delete 输出**：
```json
{"deleted": true, "title": "团队周会"}
```

**错误输出**：
```json
{"error": "Calendar \"工作\" not found."}
```

### 6.9 DateParser 格式规格

DateParser 同时处理日期和时间，是核心组件。完整格式表：

| 输入 | 解析结果 | 说明 |
|------|----------|------|
| `2026-04-19` | 2026-04-19 00:00 | 纯日期 |
| `2026-04-19 14:30` | 2026-04-19 14:30 | 日期+时间 |
| `2026/04/19` | 2026-04-19 00:00 | 斜杠分隔 |
| `2026/04/19 14:30` | 2026-04-19 14:30 | 斜杠+时间 |
| `today` | 当天 00:00 | 基于当天日期 |
| `tomorrow` | 明天 00:00 | 当天+1天 |
| `now` | 当前时刻 | 精确到分钟 |
| `+3` / `+3d` | 当天+3天 00:00 | 从**当天日期**起算（非当前时刻） |
| `+1w` | 当天+7天 00:00 | 周数支持 |

不带时间的日期默认为 00:00，由 `--all-day` 决定是否只取日期部分。

### 6.10 全天事件 end 语义

> **v2 新增**：明确全天事件的 inclusive vs exclusive 语义。

EKEvent 的全天事件 `endDate` 是 **exclusive**（不含最后一天）。用户直觉是 **inclusive**（"5/1 到 5/3" = 三天）。

**策略**：用户侧 inclusive，内部自动转换。
- 用户输入：`--start 2026-05-01 --end 2026-05-03`
- 用户理解：5/1、5/2、5/3 三天
- 内部存储：`endDate = 2026-05-04 00:00`（+1 day）
- 输出显示：`2026-05-01 ~ 2026-05-03`（-1 day 还原用户语义）

如果用户不传 `--end`，全天事件默认 1 天。

### 6.11 中文支持

- 日历名、事件标题、地点、备注均使用 String，天然支持 UTF-8/中文
- 终端输出使用 ANSI 颜色码，无 locale 依赖
- 日期格式统一 `yyyy-MM-dd HH:mm`，避免 locale 歧义

### 6.12 彩色输出

使用 ANSI escape code：
- 日期标题：加粗 `\u{001B}[1m`
- 日历名：青色 `\u{001B}[36m`
- 时间范围：绿色 `\u{001B}[32m`
- 错误：红色 `\u{001B}[31m`
- 成功标记：绿色 ✓

颜色启用条件：`isatty(STDOUT_FILENO) == true` **且** 环境变量 `NO_COLOR` 未设置。尊重 [no-color.org](https://no-color.org/) 规范。

`--json` 模式下无颜色。

### 6.13 权限模型

macOS 14+ 使用 `requestFullAccessToEvents()`。

首次运行时系统弹出权限对话框。拒绝后给出明确提示：
```
❌ Calendar access denied. Grant permission in System Settings > Privacy & Security > Calendars.
```

## 7. 错误处理策略

```swift
public enum EventError: Error, CustomStringConvertible {
    case accessDenied
    case calendarNotFound(name: String)
    case noMatch(query: String)
    case multipleMatch(query: String, items: [EventItem])
    case invalidDate(input: String)
    case invalidTime(input: String)
    case invalidAlert(input: String)
    case noChanges
    case saveFailed(underlying: Error)
    case alertIndexOutOfRange(index: Int, count: Int)
    case eventModifiedExternally
    case exchangeCalendarUnstable(calendar: String)
}
```

**错误输出格式**：
- Plain 模式：`❌ <错误描述>` + 退出码 1
- JSON 模式：`{"error": "<错误描述>"}` + 退出码 1

## 8. Package.swift

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "calendar-cli",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "calcli", targets: ["EvtCLI"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0")
    ],
    targets: [
        .executableTarget(
            name: "EvtCLI",
            dependencies: ["EvtCore", .product(name: "ArgumentParser", package: "swift-argument-parser")],
            path: "Sources/EvtCLI"
        ),
        .target(
            name: "EvtCore",
            path: "Sources/EvtCore"
        ),
        .testTarget(
            name: "EvtCoreTests",
            dependencies: ["EvtCore"],
            path: "Tests/EvtCoreTests"
        )
    ]
)
```

## 9. 项目目录

```
~/DevTeam/projects/calendar-cli/
├── Package.swift
├── Sources/
│   ├── EvtCore/
│   │   ├── EventStore.swift          # EKEventStore 封装
│   │   ├── EventStoreProtocol.swift  # Protocol 定义（测试 mock 用）
│   │   ├── EventItem.swift           # 事件模型
│   │   ├── AlertItem.swift           # 提醒模型
│   │   ├── DateParser.swift          # 日期时间解析
│   │   ├── AlertParser.swift         # 提醒时间解析
│   │   ├── MatchResult.swift         # 匹配结果枚举
│   │   └── EventError.swift          # 错误类型
│   └── EvtCLI/
│       ├── EvtCLI.swift              # @main 入口 + 输出工具
│       ├── AddCommand.swift
│       ├── ListCommand.swift
│       ├── ShowCommand.swift
│       ├── UpdateCommand.swift
│       ├── DeleteCommand.swift
│       └── AlertCommand.swift        # alert add/remove/list 子命令
├── Tests/
│   └── EvtCoreTests/
│       ├── DateParserTests.swift
│       ├── AlertParserTests.swift
│       └── MatchResultTests.swift
├── docs/
│   └── archive/
└── README.md
```

## 10. 安装

```bash
cd ~/DevTeam/projects/calendar-cli
swift build -c release
cp .build/release/calcli /usr/local/bin/calcli
```

**首次运行**：macOS 会弹出日历权限对话框，选择「允许」。如未弹出或被拒绝，在「系统设置 > 隐私与安全性 > 日历」中手动授权。

## 11. 分期计划

| 阶段 | 内容 | 交付物 |
|------|------|--------|
| P1 | 核心骨架 + add / list / show + DateParser/AlertParser 单元测试 | 可编译运行的基础版本 + 测试 |
| P2 | update（含跨日历移动） / delete + 集成测试 | 完整 CRUD + 测试 |
| P3 | alert 子命令 + 多提醒 + 测试 | 提醒管理 + 测试 |
| P4 | 彩色输出 + --json + NO_COLOR + 错误润色 | 产品化 |

每阶段交付包含对应测试。EvtCoreTests 覆盖 DateParser、AlertParser、MatchResult 的纯逻辑测试。
