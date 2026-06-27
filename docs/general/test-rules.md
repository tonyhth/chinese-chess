# 项目测试规则

## 统一测试入口
本项目所有测试通过 `scripts/test-runner.sh` 执行，**不直接调用 `swift test`**。

```bash
# 全量测试
bash scripts/test-runner.sh

# 快速测试（跳过慢测试）
bash scripts/test-runner.sh --quick
```

## 为什么不直接 swift test？
- 768 tests 需要 ~130-240 秒，直接调用容易 timeout
- `swift test | grep` 管道会吞掉中间输出，失败信息在输出中间（`Issue recorded at file:line`），汇总在末尾只说"1 issue"
- test-runner.sh 自动 tee 全量输出，并把失败项追加到末尾，`tail -20` 就能看到结果

## 遇到失败时
1. 末尾会自动显示失败项
2. 读 `/tmp/swift-test-result.txt` 搜索 `Issue recorded` 定位具体文件和行号
3. 不要反复重跑同一命令试图"grep 到失败"——信息已经在末尾了
