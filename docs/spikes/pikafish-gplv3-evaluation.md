# Pikafish Spike 可行性报告

> **⚠️ 决策更新（2026-06-27，洪涛确认）**
>
> **GPLv3 决策：继续使用 Pikafish，静态库链接方式不构成衍生作品。**
>
> 依据：我们通过 C API（pikafish_api.h）接口调用 Pikafish，Pikafish 代码独立编译为 .a 静态库，是接口层面的使用，不构成版权意义上的衍生作品。下方 Cody 的「NO-GO」评估结论**不适用**，仅作为法律背景参考保留。
>
> **影响**：规范化批次 3-5 前置阻塞解除，全部按原方案执行。

## 概述

Pikafish 是目前最强的开源中国象棋引擎，源自 Stockfish 架构，采用 NNUE 神经网络评估，GPLv3 许可证。

## 基本信息

| 项目 | 信息 |
|------|------|
| 仓库 | https://github.com/official-pikafish/Pikafish |
| 许可证 | GNU General Public License v3 (GPLv3) |
| 语言 | C++ (Stockfish 架构) |
| 评估 | NNUE 神经网络 |
| 官网 | https://www.pikafish.org |
| 社区 | Discord 活跃 |

## 法律评估：**❌ NO-GO**（当前商业模式下）

### GPLv3 核心要求

1. **传染性条款**：任何链接（静态或动态）GPLv3 代码的软件，必须整体以 GPLv3 开源
2. **源代码披露**：必须向用户提供完整源代码（包括你自己的应用代码）
3. **修改自由**：用户有权修改、重新分发软件

### 与 iOS/Android 商业应用的冲突

| 冲突点 | 详情 |
|--------|------|
| **App Store DRM** | Apple 的 DRM 与 GPLv3 的"反 DRM"条款（anti-tivoization）直接冲突 |
| **静态链接** | iOS 不支持动态链接第三方库，静态链接触发 GPLv3 传染 |
| **闭源要求** | 我们的应用是闭源商业软件，GPLv3 要求开源全部代码 |
| **App Store 条款** | Apple 的许可条款与 GPLv3 的"用户自由"理念根本矛盾 |

### 即使动态链接也不行

GPLv3 的传染性覆盖动态链接场景。Quora/StackOverflow 法律讨论一致认为：
> "GPL infects your code even when you dynamically link to it."

对比 LGPL 有 static linking exception，GPLv3 没有此例外。

## 替代方案

### 方案 A：参考算法，不引用代码（推荐）✅

- 阅读 Pikafish 源码学习其搜索算法和评估技术
- 在自己的 Swift 代码中独立实现类似算法
- 不构成"衍生作品"（idea/expression dichotomy）
- **风险**：低。算法思想不受版权保护，实现方式不同即可

### 方案 B：将 AI 引擎拆分为独立 GPL 模块 ⚠️

- 把 Pikafish 集成为独立进程（非链接）
- 通过 UCI 协议（stdin/stdout）通信
- AI 引擎部分单独开源 GPLv3，GUI 保持闭源
- **风险**：中。需要法律审查"独立进程"是否真的切断 GPL 传染

### 方案 C：放弃 Pikafish，自研引擎（当前路线）✅

- 继续自研 Swift AI 引擎
- 参考 Stockfish/Pikafish 公开的算法论文和 wiki
- 学习其优化技巧（PVS、TT、NNUE 原理）后在 Swift 中实现
- **风险**：无法律风险。棋力上限低于 Pikafish，但可控

## 结论

**Pikafish 直接集成 = NO-GO。** GPLv3 与 App Store 商业模式根本冲突。

**推荐路线（方案 C）**：继续自研引擎。从 Pikafish 中可借鉴的技术方向：
1. NNUE 评估（用浅层神经网络替代手工评估函数）
2. 更深的迭代加深 + 时间管理策略
3. Symmetric/Asymmetric reduction 的 LMR 参数调优
4. History heuristic 的更精细设计

这些算法思想可自由实现，无许可风险。

---

报告日期: 2026-06-20
作者: Cody (编码)
