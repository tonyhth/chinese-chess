# Pikafish 外部引擎集成指南

## 简介

[Pikafish](https://github.com/official-pikafish/Pikafish) 是目前最强的开源中国象棋（象棋）UCI 引擎，由 Dragon API 团队开发，基于 NNUE 神经网络评估。本应用支持通过 UCI 协议接入 Pikafish 作为外部引擎。

## 系统要求

- macOS 12.0+ / iOS 17.0+
- Pikafish 引擎可执行文件（macOS）

## 安装 Pikafish

### 方式一：Homebrew 安装（推荐）

```bash
brew install pikafish
```

安装后，引擎路径通常为 `/opt/homebrew/bin/pikafish`（Apple Silicon）或 `/usr/local/bin/pikafish`（Intel）。

### 方式二：手动下载

1. 前往 [Pikafish Releases](https://github.com/official-pikafish/Pikafish/releases) 下载对应平台的预编译二进制
2. 解压后将可执行文件放到如 `/usr/local/bin/` 目录
3. 确保有执行权限：`chmod +x /usr/local/bin/pikafish`

## 在中国象棋中配置 Pikafish

### 步骤

1. 打开应用 → 设置 → 引擎设置
2. 引擎来源选择 **「外部引擎」**
3. 点击 **「添加引擎」**
4. 填写配置：
   - **名称**：Pikafish（或自定义名称）
   - **可执行文件路径**：点击「选择…」定位到 pikafish 可执行文件
   - **UCI 选项**（可选）：
     | 选项名 | 推荐值 | 说明 |
     |--------|--------|------|
     | Hash | 128 | 哈希表大小（MB），越大搜索越快 |
     | Threads | 2 | 搜索线程数，建议设为 CPU 核心数的一半 |
5. 点击 **「保存」**
6. 选中该引擎，点击 **「测试」** 验证连接

### 引擎切换

- **菜单栏**：通过「引擎」菜单切换内置/外部引擎
- **设置面板**：在引擎设置中直接选择
- 切换在**下一局开始时生效**

## UCI 选项说明

### 常用选项

| 选项 | 默认值 | 说明 |
|------|--------|------|
| `Hash` | 16 | 置换哈希表大小（MB）|
| `Threads` | 1 | 搜索线程数 |
| `MultiPV` | 1 | 输出多条主要变路（用于分析）|
| `Skill Level` | 20 | 棋力等级（0-20），调低可削弱引擎 |

### 进阶选项

| 选项 | 说明 |
|------|------|
| `EvalFile` | NNUE 评估文件路径（使用引擎自带即可）|
| `UCCI_UseBook` | 是否使用引擎自带开局库 |

## 常见问题

### Q: 测试连接失败？

- 检查可执行文件路径是否正确
- 确认文件有执行权限：`ls -la /path/to/pikafish`
- 尝试在终端运行：`/path/to/pikafish`，输入 `uci` 看是否返回 `uciok`

### Q: 引擎走法很慢？

- 增加 `Hash` 选项（128 或 256）
- 增加 `Threads` 选项（但不超过 CPU 核心数）
- 检查是否在残局阶段（残局搜索更深，耗时更长）

### Q: 内置引擎和 Pikafish 有什么区别？

- **内置引擎**：自研评估函数，无需安装，适合日常对弈
- **Pikafish**：NNUE 神经网络，棋力远超自研引擎，适合高级玩家训练

### Q: 引擎启动后 fallback 到内置引擎？

这通常意味着外部引擎启动失败。请在设置面板中测试连接查看具体错误信息。

## 技术细节

- 本应用通过 UCI（Universal Chess Interface）协议与 Pikafish 通信
- 支持 UCI 选项传递（Hash、Threads 等）
- 引擎启动失败时自动 fallback 到内置引擎，保证游戏不中断
- 引擎状态可通过菜单栏实时查看
