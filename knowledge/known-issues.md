# known issues

> 待团队初始化后补充内容

## 2026-04-06 word_counter.py 返工根因
- P0：路径未校验 + --top 无下界 — 防御性编程不足，CLI 参数和文件路径必须做边界校验
- P1：大文件 OOM + 错误信息不明确 + 职责未拆分 — 新脚本应默认流式处理，函数拆分从开始就做
- P2（known）：预编译正则可优化性能，不阻塞

## csv_merger.py (2026-04-06)
- [P2] `parser.error` lambda 覆写方式不够安全，可能影响 argparse 内部行为
- [P2] `files_opened` 变量语义模糊，建议重命名
- [P2] `reconfigure` 放模块顶层会影响 import 行为
- [P2] 空文件触发不友好的 StopIteration 错误
