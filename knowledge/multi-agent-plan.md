# Multi-Agent 架构升级方案

> 制定日期：2026-04-06
> 最后更新：2026-04-06（v2，含改进审查）
> 状态：待实施

## 一、背景与目标

### 动机
把开发/写脚本等编程相关任务从丹妮分出来，提高编码质量。通过多 agent 协作，实现"有人写代码、有人 review、有人测试"的完整流水线。

### 目标
- 编码质量：通过 reviewer 和 tester 角色保障
- 职责清晰：丹妮专注日常助理，编码团队专注开发
- 架构简洁：5个独立 agent，飞书群协作，不过度设计

## 二、架构总览

```
洪涛(个人号) ─── 私聊 ─── 丹妮(main)
                          │
                          │ 识别到编码需求
                          │ message tool 发群消息 @lead
                          ▼
              飞书群「开发团队」
              ┌─────────────────────┐
              │  lead  coder        │
              │  reviewer  tester   │
              │                     │
              │  洪涛(个人号)       │
              └─────────────────────┘
                          │
                          │ lead 通过 sessions_send 通知丹妮
                          │ （不依赖丹妮观察群消息）
                          ▼
                    丹妮私聊通知洪涛
```

**关键设计决策：**
- 丹妮不进飞书群，避免群消息污染 context
- 丹妮通过 `message` tool 向群发消息（转需求）
- lead 通过 `sessions_send` 通知丹妮（报结果）
- 洪涛在群里可直接观察进度、@lead 插话

### 角色分工

| Agent | 职责 | 模型 | 边界 |
|-------|------|------|------|
| **丹妮 (main)** | 私人助理，日常对话，任务协调，邮件，OA | glm-5-turbo | 不写代码，编码需求转交团队 |
| **lead** | 架构师/调度者：拆解任务、定架构、汇总结果 | glm-5.1 | 不写具体代码，负责任务分配和质量把关 |
| **coder** | 编码者：写代码、实现功能 | glm-5.1 | 只负责写代码，不自审 |
| **reviewer** | 审查者：审查代码逻辑、边界风险、最佳实践 | glm-5.1 | 只提问题和建议，不直接改代码 |
| **tester** | 测试者：写测试、跑测试、汇报覆盖率 | glm-5-turbo | 跑测试和报告，不改产品代码 |

### 通信规则

- **需求转达**：丹妮 → `message` tool → 飞书群 @lead（丹妮不进群）
- **结果通知**：lead → `sessions_send` → 丹妮 → 私聊通知洪涛
- **进度查看**：洪涛直接在群里观察，或问丹妮→丹妮 `sessions_history` 查 lead session
- **例外通信**：发现影响丹妮职责的问题（如丹妮用到的脚本有 bug），lead 可直接 sessions_send 通知丹妮，同时记录到 lead memory
- **简单改动**（改一行代码、写简单脚本、修小 bug）→ 丹妮自己用 sessions_spawn 处理，不惊动团队
- **开发任务**（新功能、多文件重构、需要测试的项目）→ 转发飞书编码群 @lead
- **拿不准** → 问洪涛

## 三、模型分配

| 角色 | 主模型 | imageModel | 理由 |
|------|--------|------------|------|
| 丹妮 | zai/glm-5-turbo | aliyun/kimi-k2.5 | 日常场景速度优先 |
| lead | zai/glm-5.1 | aliyun/kimi-k2.5 | 最强综合能力，架构拆解 |
| coder | zai/glm-5.1 | aliyun/kimi-k2.5 | SWE-bench 77.8%，编程评测 45.3（Opus 4.6 的 94.6%），免费 |
| reviewer | zai/glm-5.1 | aliyun/kimi-k2.5 | 深度推理，审查需要最强能力 |
| tester | zai/glm-5-turbo | aliyun/kimi-k2.5 | 写测试不需要最强模型，速度优先 |

fallback 链：glm-5.1 → glm-5 → glm-4.7

**benchmark 参考**（2026-04 数据）：
- GLM-5.1：SWE-bench Verified 77.8%，编程评测 45.3，达 Opus 4.6 的 94.6%
- GLM-5：SWE-bench Verified 77.8%，编程评测 35.4
- GLM-5.1 比 GLM-5 实际工程能力提升 28%（同基础模型，后训练优化）

## 四、工具权限

### lead
✅ read, write, edit, exec, message, web_search, web_fetch, sessions_send, sessions_list, sessions_history, session_status, image, memory_search, memory_get
❌ cron, write/edit 丹妮脚本, apple_calendar_*, feishu_*, pdf, tts, canvas

### coder
✅ read, write, edit, exec, message, web_search, web_fetch, sessions_send, sessions_list, sessions_history, session_status, image, memory_search, memory_get
❌ cron, apple_calendar_*, feishu_*, pdf, tts, canvas

### reviewer
✅ read, exec, message, web_search, web_fetch, sessions_send, sessions_list, sessions_history, session_status, image, memory_search, memory_get
❌ **write, edit**, cron, apple_calendar_*, feishu_*, pdf, tts, canvas

### tester
✅ read, write, edit, exec, message, web_search, web_fetch, sessions_send, sessions_list, sessions_history, session_status, image, memory_search, memory_get
❌ cron, apple_calendar_*, feishu_*, pdf, tts, canvas

> 注：reviewer 不给 write/edit，只提问题不改代码。tester 可以写测试文件。

## 五、目录结构

```
~/.openclaw/
├── openclaw.json                    # 主配置（agents.list + bindings）
├── secrets.json                     # 丹妮密钥（不动）
├── secrets-devteam.json             # 编码团队密钥（仅 github）
│
├── skills/                          # 共享 skill（所有 agent 自动可见）
│   ├── excel-xlsx/
│   ├── word-docx/
│   ├── markdown-converter/
│   ├── video-frames/
│   ├── weather/
│   └── ...其他真正通用的 skill
│
├── workspace/                       # 丹妮 workspace（不动）
│   ├── SOUL.md, AGENTS.md, USER.md, IDENTITY.md, MEMORY.md
│   ├── HEARTBEAT.md, TOOLS.md
│   ├── skills/                      # 丹妮专属 skill
│   │   ├── oa-todo/
│   │   ├── work-dir-manager/
│   │   ├── work-email/
│   │   ├── email-triage/
│   │   ├── daily-focus/
│   │   ├── task-manager/
│   │   ├── find-skills/
│   │   ├── skillhub-preference/
│   │   └── web-read/
│   ├── scripts/                     # 丹妮专用脚本（编码 agent 不执行）
│   ├── memory/                      # 丹妮记忆
│   ├── knowledge/                   # 丹妮知识库（业务相关）
│   └── avatar/
│
├── workspace-lead/                  # lead workspace（极简）
│   ├── SOUL.md
│   ├── AGENTS.md
│   ├── USER.md
│   └── memory/
│
├── workspace-coder/                 # coder workspace（极简）
│   ├── SOUL.md
│   ├── AGENTS.md
│   ├── USER.md
│   └── memory/
│
├── workspace-reviewer/              # reviewer workspace（极简）
│   ├── SOUL.md
│   ├── AGENTS.md
│   ├── USER.md
│   └── memory/
│
├── workspace-tester/                # tester workspace（极简）
│   ├── SOUL.md
│   ├── AGENTS.md
│   ├── USER.md
│   └── memory/
│
├── agents/
│   ├── main/                        # 丹妮（已存在，不动）
│   │   ├── agent/auth-profiles.json
│   │   └── sessions/
│   ├── lead/
│   │   ├── agent/auth-profiles.json
│   │   └── sessions/
│   ├── coder/
│   │   ├── agent/auth-profiles.json
│   │   └── sessions/
│   ├── reviewer/
│   │   ├── agent/auth-profiles.json
│   │   └── sessions/
│   └── tester/
│       ├── agent/auth-profiles.json
│       └── sessions/

~/DevTeam/                           # 编码团队共享工作目录
├── claude-code/                     # 从丹妮 workspace 迁移过来
├── instructkr-claude-code/          # 从丹妮 workspace 迁移过来
├── knowledge/                       # 共享技术知识
│   ├── coding-standards.md          # 编码规范
│   ├── review-checklist.md          # 审查清单
│   └── known-issues.md              # 已知坑/踩坑记录
├── standards/                       # 团队规范文档
└── (具体项目目录，按项目组织)
```

### 目录设计原则

- 编码 agent workspace 极简：只有 SOUL.md + AGENTS.md + USER.md + memory/
- 共享 skill 放 `~/.openclaw/skills/`（全局自动可见，已确认官方支持）
- 丹妮专属 skill 留在 `~/.openclaw/workspace/skills/`（不动）
- 共享代码和知识放 `~/DevTeam/`（绝对路径访问）
- 各 agent 独立 memory，不交叉
- secrets 最小权限：编码团队只有 GitHub token（独立文件）
- 丹妮 workspace 下的 claude-code 相关目录迁移到 ~/DevTeam/

### knowledge 分离

| 位置 | 内容 | 谁用 |
|------|------|------|
| `~/.openclaw/workspace/knowledge/` | 邮件分类、项目、联系人等业务知识 | 仅丹妮 |
| `~/DevTeam/knowledge/` | 编码规范、审查清单、已知问题 | 编码团队共享 |
| `~/.openclaw/workspace/memory/lessons.md` | 工具教训 | 仅丹妮 |

## 六、飞书配置

### 群结构
- 一个飞书群「开发团队」
- 使用飞书 Thread 组织不同任务
- 每个任务一个话题，lead 在话题里 @coder 派活

### 群成员
- 4 个编码飞书 bot（lead、coder、reviewer、tester）
- **洪涛个人号**
- **丹妮不进群**（避免群消息污染 context）

### 沟通模式
- 半开放：正常走丹妮转达，复杂需求洪涛可进群直接 @lead 或插话
- 结果通知：lead 通过 sessions_send 私信丹妮，丹妮私聊通知洪涛

### 群内路由
- 4 个 bot 统一 `mentionOnly` 模式，只有被 @ 才回复
- 不需要 mentionPatterns，飞书 @ 机制本身能区分

### 飞书应用创建清单

每个编码 bot 需要在飞书开放平台完成：
1. 创建新应用
2. 启用「机器人」能力
3. 配置消息事件订阅：`im.message.receive_v1`
4. 权限范围：`im:message`、`im:message.group_at_msg`、`im:chat:readonly`
5. 发布应用版本
6. 记录 appId 和 appSecret
7. 将 bot 拉入飞书群

**4 个应用分别创建：**
| 应用名 | Agent ID | 用途 |
|--------|----------|------|
| Dev Lead | lead | 架构师/调度者 |
| Dev Coder | coder | 编码者 |
| Dev Reviewer | reviewer | 审查者 |
| Dev Tester | tester | 测试者 |

## 七、agentToAgent 配置

```json5
{
  tools: {
    agentToAgent: {
      enabled: true,
      allow: ["main", "lead", "coder", "reviewer", "tester"]
    }
  }
}
```

### agentToAgent 使用场景
- **lead → main**：任务完成后 sessions_send 通知丹妮
- **丹妮 → lead**：（备用）丹妮需要直接跟 lead 确认细节时

## 八、openclaw.json 配置草案

```json5
{
  agents: {
    defaults: {
      // 保留现有 defaults（model、imageModel、memorySearch 等）
      // 所有 agent（包括编码团队）自动继承
      model: { /* 不变 */ },
      imageModel: { /* 不变 */ },
      memorySearch: { /* 不变，全开 */ },
    },
    list: [
      {
        id: "main",
        default: true,
        workspace: "~/.openclaw/workspace"
        // 不变
      },
      {
        id: "lead",
        name: "Lead",
        workspace: "~/.openclaw/workspace-lead",
        model: {
          primary: "zai/glm-5.1",
          fallbacks: ["zai/glm-5", "zai/glm-4.7"]
        },
        tools: {
          allow: ["read", "write", "edit", "exec", "message", "web_search", "web_fetch", "sessions_send", "sessions_list", "sessions_history", "session_status", "image", "memory_search", "memory_get"],
          deny: ["cron", "feishu_doc", "feishu_wiki", "feishu_drive", "feishu_chat", "feishu_bitable_get_meta", "feishu_bitable_list_fields", "feishu_bitable_list_records", "feishu_bitable_get_record", "feishu_bitable_create_record", "feishu_bitable_update_record", "feishu_bitable_create_app", "feishu_bitable_create_field", "feishu_app_scopes", "pdf", "tts", "canvas", "apple_calendar_create", "apple_calendar_delete", "apple_calendar_events", "apple_calendar_read", "apple_calendar_search", "apple_calendar_update", "apple_calendar_list"]
        }
      },
      {
        id: "coder",
        name: "Coder",
        workspace: "~/.openclaw/workspace-coder",
        model: {
          primary: "zai/glm-5.1",
          fallbacks: ["zai/glm-5", "zai/glm-4.7"]
        },
        tools: {
          allow: ["read", "write", "edit", "exec", "message", "web_search", "web_fetch", "sessions_send", "sessions_list", "sessions_history", "session_status", "image", "memory_search", "memory_get"],
          deny: ["cron", "feishu_doc", "feishu_wiki", "feishu_drive", "feishu_chat", "feishu_bitable_get_meta", "feishu_bitable_list_fields", "feishu_bitable_list_records", "feishu_bitable_get_record", "feishu_bitable_create_record", "feishu_bitable_update_record", "feishu_bitable_create_app", "feishu_bitable_create_field", "feishu_app_scopes", "pdf", "tts", "canvas", "apple_calendar_create", "apple_calendar_delete", "apple_calendar_events", "apple_calendar_read", "apple_calendar_search", "apple_calendar_update", "apple_calendar_list"]
        }
      },
      {
        id: "reviewer",
        name: "Reviewer",
        workspace: "~/.openclaw/workspace-reviewer",
        model: {
          primary: "zai/glm-5.1",
          fallbacks: ["zai/glm-5", "zai/glm-4.7"]
        },
        tools: {
          allow: ["read", "exec", "message", "web_search", "web_fetch", "sessions_send", "sessions_list", "sessions_history", "session_status", "image", "memory_search", "memory_get"],
          deny: ["write", "edit", "cron", "feishu_doc", "feishu_wiki", "feishu_drive", "feishu_chat", "feishu_bitable_get_meta", "feishu_bitable_list_fields", "feishu_bitable_list_records", "feishu_bitable_get_record", "feishu_bitable_create_record", "feishu_bitable_update_record", "feishu_bitable_create_app", "feishu_bitable_create_field", "feishu_app_scopes", "pdf", "tts", "canvas", "apple_calendar_create", "apple_calendar_delete", "apple_calendar_events", "apple_calendar_read", "apple_calendar_search", "apple_calendar_update", "apple_calendar_list"]
        }
      },
      {
        id: "tester",
        name: "Tester",
        workspace: "~/.openclaw/workspace-tester",
        model: {
          primary: "zai/glm-5-turbo",
          fallbacks: ["zai/glm-5.1", "zai/glm-5", "zai/glm-4.7"]
        },
        tools: {
          allow: ["read", "write", "edit", "exec", "message", "web_search", "web_fetch", "sessions_send", "sessions_list", "sessions_history", "session_status", "image", "memory_search", "memory_get"],
          deny: ["cron", "feishu_doc", "feishu_wiki", "feishu_drive", "feishu_chat", "feishu_bitable_get_meta", "feishu_bitable_list_fields", "feishu_bitable_list_records", "feishu_bitable_get_record", "feishu_bitable_create_record", "feishu_bitable_update_record", "feishu_bitable_create_app", "feishu_bitable_create_field", "feishu_app_scopes", "pdf", "tts", "canvas", "apple_calendar_create", "apple_calendar_delete", "apple_calendar_events", "apple_calendar_read", "apple_calendar_search", "apple_calendar_update", "apple_calendar_list"]
        }
      }
    ]
  },
  bindings: [
    // 编码团队 → 飞书群（mentionOnly，只有被 @ 才回复）
    {
      agentId: "lead",
      match: { channel: "feishu", peer: { kind: "group", id: "<飞书群ID>" } },
      groupChat: { mentionOnly: true }
    },
    {
      agentId: "coder",
      match: { channel: "feishu", peer: { kind: "group", id: "<飞书群ID>" } },
      groupChat: { mentionOnly: true }
    },
    {
      agentId: "reviewer",
      match: { channel: "feishu", peer: { kind: "group", id: "<飞书群ID>" } },
      groupChat: { mentionOnly: true }
    },
    {
      agentId: "tester",
      match: { channel: "feishu", peer: { kind: "group", id: "<飞书群ID>" } },
      groupChat: { mentionOnly: true }
    },
    // 丹妮 → 现有通道（不变），不绑定编码群
  ],
  channels: {
    feishu: {
      // 丹妮的 default account（已有，不变）
      // 新增 4 个编码 team accounts
      accounts: {
        default: { /* 不变 */ },
        lead: {
          appId: "<lead appId>",
          appSecret: { /* 从 secrets-devteam 读取 */ }
        },
        coder: {
          appId: "<coder appId>",
          appSecret: { /* 从 secrets-devteam 读取 */ }
        },
        reviewer: {
          appId: "<reviewer appId>",
          appSecret: { /* 从 secrets-devteam 读取 */ }
        },
        tester: {
          appId: "<tester appId>",
          appSecret: { /* 从 secrets-devteam 读取 */ }
        }
      },
      // 群 allowlist 需加入编码群 ID
      allowlist: [
        /* 现有群... */,
        "<飞书编码群ID>"
      ]
    }
  },
  tools: {
    agentToAgent: {
      enabled: true,
      allow: ["main", "lead", "coder", "reviewer", "tester"]
    }
  }
}
```

## 九、各角色 SOUL.md / AGENTS.md 要点

### lead
- SOUL.md：架构师人格，严谨、全局视角，善于拆解复杂问题
- AGENTS.md：
  - 工作目录 ~/DevTeam
  - 任务分配规则：收到需求 → 拆解为子任务 → @coder 分配
  - 结果汇总格式：完成后 sessions_send 通知丹妮
  - 不写具体代码，负责任务分配和质量把关
  - 发现影响丹妮职责的问题 → sessions_send 通知丹妮

### coder
- SOUL.md：务实高效的编码者，注重代码质量和可维护性
- AGENTS.md：
  - 工作目录 ~/DevTeam
  - 写完代码在群内 @reviewer
  - 不自审
  - 遵循 ~/DevTeam/knowledge/coding-standards.md

### reviewer
- SOUL.md：严格的审查者，不表扬、不安慰，只提问题，输出"问题-影响-建议"三段式
- AGENTS.md：
  - 只读代码不改代码（工具层面已限制）
  - 发现严重问题直接 @lead
  - 遵循 ~/DevTeam/knowledge/review-checklist.md

### tester
- SOUL.md：细致的测试者，追求覆盖率，关注边界情况
- AGENTS.md：
  - 写测试 → 跑测试 → 在群内报告结果和覆盖率
  - 不改产品代码
  - 测试完成后 @lead

### USER.md（编码团队共用模板）
```markdown
- Name: 黄洪涛
- What to call them: 洪涛
- Timezone: Asia/Shanghai (UTC+8)
- 语言：中文为主，技术内容可中英混用
```

## 十、secrets-devteam.json

```json
{
  "github": {
    "token": "<从 secrets.json 复制>"
  },
  "channels": {
    "feishu": {
      "accounts": {
        "lead": { "appSecret": "<lead appSecret>" },
        "coder": { "appSecret": "<coder appSecret>" },
        "reviewer": { "appSecret": "<reviewer appSecret>" },
        "tester": { "appSecret": "<tester appSecret>" }
      }
    }
  }
}
```

维护规则：
- GitHub token 更新时，同步更新此文件
- 飞书 appSecret 更新时，同步更新此文件

## 十一、实施步骤

### 第一步：离线准备（不动生产环境）

1. 备份 `~/.openclaw/openclaw.json` → `~/.openclaw/openclaw.json.bak.2026-04-06`
2. 迁移 claude-code 相关目录：
   - `mv ~/.openclaw/workspace/claude-code ~/DevTeam/claude-code`
   - `mv ~/.openclaw/workspace/instructkr-claude-code ~/DevTeam/instructkr-claude-code`
3. 创建共享目录：
   - `mkdir -p ~/DevTeam/{knowledge,standards}`
4. 初始化知识库文件：
   - `~/DevTeam/knowledge/coding-standards.md`
   - `~/DevTeam/knowledge/review-checklist.md`
   - `~/DevTeam/knowledge/known-issues.md`
5. 创建 `~/.openclaw/secrets-devteam.json`
6. 创建 4 个 agent workspace（SOUL.md + AGENTS.md + USER.md）
7. 创建 `~/.openclaw/skills/` 目录，移入通用 skill（从 workspace/skills/ 或系统 bundled）
8. 编写 openclaw.json 配置草案
9. 全面 Review 所有配置文件

### 第二步：飞书配置

1. 在飞书开放平台创建 4 个应用（Dev Lead / Dev Coder / Dev Reviewer / Dev Tester）
2. 每个应用：启用机器人 → 配置事件订阅 → 配置权限 → 发布版本
3. 记录 4 组 appId + appSecret，写入 secrets-devteam.json
4. 创建飞书群「开发团队」
5. 将 4 个 bot 拉进群
6. 在 openclaw.json 中配置 4 个 feishu accounts + 群 allowlist + bindings

### 第三步：一次性上线 + 验证

1. 写入新的 openclaw.json 配置
2. 重启 gateway：`openclaw gateway restart`
3. 验证：
   - `openclaw agents list --bindings` — 5 个 agent + bindings 正确
   - `openclaw channels status --probe` — 飞书 5 个 bot 都在线（丹妮 default + 4 个编码 bot）
   - 在飞书群里 @lead 发测试消息，确认只 lead 回复
   - @coder 发消息，确认只 coder 回复

### 第四步：最小闭环测试（不接丹妮）

1. 洪涛直接在飞书群里 @lead 提一个简单任务
2. 验证完整流程：
   - lead 拆解任务 → @coder
   - coder 写代码 → @reviewer
   - reviewer 审查 → @coder（如有问题）或 @tester
   - tester 测试 → @lead
   - lead 汇总结果
3. 验证结果通知：lead sessions_send → 丹妮 → 丹妮私聊通知洪涛
4. 发现问题就地修，改配置后重启

### 第五步：接通丹妮 + 固化

1. 在丹妮的 AGENTS.md 加编码分流规则
2. 测试完整流程：洪涛跟丹妮说需求 → 丹妮 message tool 发群 @lead → 团队完成 → sessions_send 通知丹妮 → 丹妮私聊告知洪涛
3. 调优各角色的 SOUL.md，固化风格
4. 总结最佳实践，更新 knowledge 文件

## 十二、丹妮 AGENTS.md 需要新增的规则

```markdown
## 编码需求分流

- 简单改动（改一行代码、写个简单脚本、修个小 bug）
  → 自己用 sessions_spawn 处理
- 开发任务（新功能、多文件重构、需要测试的项目）
  → 转发到飞书编码群 @lead
- 拿不准 → 问洪涛

转发方式：用 message tool 发消息到飞书群「开发团队」，@lead 并描述需求
结果接收：lead 完成后会通过 sessions_send 通知，收到后私聊告知洪涛
```

## 十三、风险与注意事项

1. **飞书 bot 创建**：4 个飞书应用由洪涛自行创建和管理
2. **gateway 重启**：会中断丹妮的所有服务（邮件 cron、心跳等），选择低峰期操作
3. **secrets 安全**：编码 agent 的 secrets 最小化（仅 GitHub token + 飞书 appSecret）。exec 权限意味着可运行任意命令，通过 AGENTS.md 硬规则约束不执行非编码脚本
4. **模型限流**：4 个 agent 同时用 GLM-5.1 可能触发智谱限流，需要观察。如有问题，部分角色降级到 glm-5 或 glm-4.7
5. **记忆积累**：编码 agent 全新，没有历史记忆。memorySearch 全开，但初期记忆为空。随着使用逐步积累
6. **回滚方案**：保留 `openclaw.json.bak.2026-04-06`，出问题时恢复后重启 gateway
7. **丹妮不进群**：确保 bindings 中丹妮不绑定编码群。丹妮通过 message tool 发群消息（需要知道群 ID）
8. **mentionOnly**：4 个编码 bot 统一 mentionOnly，避免群内消息误触发

## 十四、成功标准

- [ ] 4 个编码 agent 在飞书群里能独立响应（mentionOnly 模式）
- [ ] lead 能正确拆解任务并分配给 coder
- [ ] coder 写完代码后 @reviewer 触发审查
- [ ] reviewer 能给出有质量的审查意见
- [ ] tester 能写测试并报告结果
- [ ] lead 能汇总结果并通过 sessions_send 通知丹妮
- [ ] 丹妮能通过 message tool 向编码群转发需求
- [ ] 丹妮不进群，context 不被群消息污染
- [ ] 完整流程：洪涛 → 丹妮 → 飞书群 → 团队协作 → 结果 → 洪涛

## 附录：改进审查记录（v1 → v2）

| # | 问题 | 改进 | 采纳 |
|---|------|------|------|
| 1 | 飞书配置缺创建清单和 accounts 配置 | 补上飞书应用创建清单和 openclaw.json accounts 配置 | ✅ |
| 2 | 丹妮进群会污染 context | 丹妮不进群，通过 message tool + sessions_send 通信 | ✅ |
| 3 | 丹妮怎么知道"结果回来了"无机制 | lead 通过 sessions_send 通知丹妮 | ✅ |
| 4 | 群内多 bot 可能误回复 | 4 个 bot 统一 mentionOnly | ✅ |
| 5 | ~/.openclaw/skills/ 是否生效未验证 | 已确认官方支持，创建后自动生效 | ✅ |
| 6 | imageModel 未分配 | 全部统一配 aliyun/kimi-k2.5 | ✅ |
| 7 | memorySearch 未考虑 | 全开，从 agents.defaults 继承 | ✅ |
| 8 | claude-code 目录占用丹妮 workspace | 迁移到 ~/DevTeam/ | ✅ |
