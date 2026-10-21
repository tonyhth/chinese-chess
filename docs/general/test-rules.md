# 项目测试规则

## 统一测试入口（现行真相源）
本项目一切测试批通过 `scripts/run-tests-mutex.sh` 执行（flock 全局互斥 + AppleLanguages 语言锁 + 资产预检内置）。

```bash
# 专项测试（多 suite 逐个串行、独立进程）
RUNNER_OWNER=<owner> RUNTESTS_SANDBOX_EXEMPT=1 \
bash scripts/run-tests-mutex.sh <SuiteName> [Suite2 ...] \
  > ~/DevTeam/logs/<task>-tests-<mmdd>.log 2>&1; echo "TESTS_RC=$?"
```

## 禁止事项
- **禁止裸 `xcodebuild test`**（哨兵 RunnerHygieneTests 判红；全量不带过滤 Intel Mac 必超时）
- **禁止 `swift test` / `swift build`**（Package.swift 已删除，SPM 已废弃）

## 真相源
- 测试命令规约：**DEVTEAM.md 测试命令节**（本文件仅入口指引，与 DEVTEAM.md 冲突时以 DEVTEAM.md 为准）
- skip 名单：**docs/test/skip-registry.md**（单源，勿在命令行手抄）
- 双环境变量必设：RUNNER_OWNER / RUNTESTS_SANDBOX_EXEMPT，缺一拒起跑
- 计数门：Swift Testing `Test run with N tests passed` / XCTest `Executed N tests, with 0 failures`——无 count 行批次作废

> 历史：本文件 v6.4 前指引 `scripts/test-runner.sh`+`swift test`——该路径已随 SPM 废弃失效（T-1023-OC-01 P4-B1 改指现行入口，2026-10-22）。
