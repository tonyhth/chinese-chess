// pikafish_api.h - C API for embedding pikafish engine in iOS/macOS apps
//
//  This file provides a C interface to the pikafish engine,
//  allowing it to be called from Swift/Objective-C code.
//
//  License: GPLv3 (same as pikafish)

#ifndef PIKAFISH_API_H
#define PIKAFISH_API_H

#ifdef __cplusplus
extern "C" {
#endif

/// Initialize the engine (load NNUE, set default parameters)
/// Must be called before any other API functions.
/// Returns 0 on success, -1 on failure (e.g., NNUE load failed)
int pikafish_init(void);

/// Compute the best move (synchronous blocking, caller should invoke on background thread)
///
/// Parameters:
///   - fen: Position FEN string (e.g., starting position)
///   - moves: UCI move history (space-separated, e.g., "h2e2 h9g7")
///   - depth: Search depth limit (0 means no depth limit)
///   - time_ms: Time limit in milliseconds (0 means no time limit)
///   - buffer: Caller-provided output buffer for the best move
///   - buffer_size: Buffer size (recommended >= 16 bytes for UCI move like "h2e2")
///
/// Returns 0 on success (buffer contains best move like "h2e2"), -1 on failure
///
/// Note: This function blocks until search completes. Caller must invoke
///       on a background thread to avoid blocking UI.
int pikafish_best_move(const char* fen, const char* moves,
                       int depth, int time_ms,
                       char* buffer, int buffer_size);

/// Stop the current search (sets volatile flag, thread-safe, non-blocking)
/// Can be called from any thread at any time.
void pikafish_stop(void);

/// Notify the engine of a new game (clears caches, resets state)
void pikafish_new_game(void);

/// Release engine resources and shutdown
/// After calling this, pikafish_init() must be called again before use.
void pikafish_quit(void);

/// Set an engine option (UCI-style)
/// Common options: "Hash" (TT size in MB), "Threads" (search threads)
/// Returns 0 on success, -1 if option name/value invalid
int pikafish_set_option(const char* name, const char* value);

/// Get engine info (name and version)
/// Returns string like "Pikafish 4.0.0"
/// WARNING: Returned pointer is valid until pikafish_quit() is called.
/// Caller must copy the string if it needs to persist beyond quit().
const char* pikafish_get_info(void);

/// Get the evaluation score from the last search (centipawn)
/// Positive = red side advantage, negative = black side advantage.
/// For mate scores: returns ±(100000 - plies) to distinguish from cp values.
/// Returns 0 if no search has been completed yet.
int pikafish_last_eval(void);

/// Set the number of principal variations (MultiPV) to search
/// n: 1~10 (number of PV lines)
/// Returns 0 on success, -1 on failure (engine not initialized or n out of range)
int pikafish_set_multipv(int n);

/// Get the principal variation (PV) line from the last search
/// Returns space-separated UCI moves (e.g. "h2e2 h9g7 i9h9")
/// Returns the number of bytes written (excluding null terminator), -1 on failure.
/// If buffer is too small, output is truncated but still null-terminated.
int pikafish_get_pv_line(char* buffer, int buffer_size);

// MARK: - v3.6.0 新增：评估与多线索分析

/// 评估结果结构体
/// 用于 pikafish_eval 和 pikafish_multi_pv
typedef struct {
    int score_cp;        // 厘兵值（正=红方优势，负=黑方优势）
    int depth;           // 搜索深度
    char best_move[16];  // 最佳走法（UCI 格式，如 "h2e2"）
    char pv[256];        // 主变路径（空格分隔 UCI 走法）
} PikafishEvalResult;

/// 评估当前局面（单 PV）
/// 在后台线程调用（阻塞函数）。
///
/// Parameters:
///   - fen: 局面 FEN 字符串
///   - moves: UCI 走法历史（空格分隔，可为 NULL）
///   - depth: 搜索深度限制（0 表示不限）
///   - time_ms: 时间限制（毫秒，0 表示不限）
///   - result: 输出参数，填充评估结果
///
/// Returns 0 on success, -1 on failure.
int pikafish_eval(const char* fen, const char* moves,
                  int depth, int time_ms,
                  PikafishEvalResult* result);

/// 多 PV 分析（返回多条候选走法）
/// 调用前可通过 pikafish_set_multipv() 设置 PV 数量。
///
/// Parameters:
///   - fen: 局面 FEN 字符串
///   - moves: UCI 走法历史（空格分隔，可为 NULL）
///   - num_lines: 期望返回的 PV 线数（1-10）
///   - depth: 搜索深度限制
///   - time_ms: 时间限制（毫秒）
///   - results: 输出数组，调用方分配
///   - max_results: results 数组容量
///
/// Returns: 实际填充的 result 数量，-1 on failure.
int pikafish_multi_pv(const char* fen, const char* moves,
                      int num_lines, int depth, int time_ms,
                      PikafishEvalResult* results, int max_results);

#ifdef __cplusplus
}
#endif

#endif // PIKAFISH_API_H