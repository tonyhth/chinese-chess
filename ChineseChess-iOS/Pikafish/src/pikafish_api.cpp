// pikafish_api.cpp - C API implementation for embedding pikafish engine
//
//  Concurrency model (v2 - CV + two-phase lock):
//
//  1. pikafish_best_move: Phase 1 holds mutex to set position + start search,
//     then releases mutex. Phase 2 waits on condition variable (no mutex held),
//     allowing stop/quit/new_game to proceed during search.
//
//  2. pikafish_stop: Sets atomic g_stopping flag + calls engine->stop() under
//     mutex. Safe to call during search (mutex not held by best_move phase 2).
//
//  3. pikafish_quit: Calls stop first, waits for search to end (CV), then
//     deletes engine. Prevents use-after-free.
//
//  4. g_bestmove_result is only read/written under mutex protection, eliminating
//     the data race between callback thread and best_move caller.
//
//  License: GPLv3 (same as pikafish)

#include "pikafish_api.h"
#include "bitboard.h"
#include "position.h"
#include "engine.h"
#include "uci.h"
#include "thread.h"
#include <string>
#include <vector>
#include <mutex>
#include <condition_variable>
#include <atomic>
#include <cstring>

#if defined(__APPLE__) && defined(__MACH__)
#include <CoreFoundation/CoreFoundation.h>
#include <climits>
#endif

namespace {

// Global engine instance (singleton)
Stockfish::Engine* g_engine = nullptr;

// Synchronization primitives
std::mutex g_mutex;
std::condition_variable g_search_cv;

// Search state — all accessed under g_mutex unless noted
bool g_searching = false;
char g_bestmove_result[16] = {0};
std::string g_last_error;

// Last search info — written by set_on_update_full callback, read by API functions
int  g_last_eval = 0;       // centipawn (±100000 - plies for mate)
std::string g_last_pv;      // space-separated UCI moves

// MultiPV results — collected from update_full callback
struct MultiPVEntry {
    int score_cp;
    std::string pv;
};
std::vector<MultiPVEntry> g_multi_pv_results;

// Stop flag — atomic, no mutex needed
std::atomic<bool> g_stopping{false};

// Engine info string (set during init, read-only after)
std::string g_engine_info;

// Convert space-separated moves string to vector
std::vector<std::string> parse_moves(const char* moves) {
    if (!moves || moves[0] == '\0') return {};

    std::vector<std::string> result;
    std::string moves_str(moves);
    size_t start = 0;
    size_t end = moves_str.find(' ');

    while (start < moves_str.size()) {
        if (end == std::string::npos) end = moves_str.size();
        if (end > start) {
            result.push_back(moves_str.substr(start, end - start));
        }
        start = end + 1;
        end = moves_str.find(' ', start);
    }

    return result;
}

} // anonymous namespace

extern "C" {

int pikafish_init(void) {
    std::lock_guard<std::mutex> lock(g_mutex);

    if (g_engine != nullptr) {
        return 0;
    }

    try {
        // P0 fix: 在 macOS/iOS 上从 app bundle 中发现 NNUE 文件路径
        std::optional<std::string> pathOpt;

#if defined(__APPLE__) && defined(__MACH__)
        // Core Foundation: 查找 bundle 中的 pikafish.nnue
        // 优先用 app bundle（xctest 中 CFBundleGetMainBundle 返回 test bundle）
        CFBundleRef appBundle = CFBundleGetBundleWithIdentifier(CFSTR("com.chinesechess.app"));
        if (!appBundle) {
            appBundle = CFBundleGetMainBundle();
        }
        CFURLRef nnueURL = CFBundleCopyResourceURL(
            appBundle,
            CFSTR("pikafish"),
            CFSTR("nnue"),
            NULL
        );
        if (nnueURL) {
            UInt8 buf[PATH_MAX];
            if (CFURLGetFileSystemRepresentation(nnueURL, true, buf, sizeof(buf))) {
                std::string fullPath(reinterpret_cast<const char*>(buf));
                size_t lastSlash = fullPath.find_last_of("/");
                if (lastSlash != std::string::npos) {
                    pathOpt = fullPath.substr(0, lastSlash + 1);
                }
            }
            CFRelease(nnueURL);
        } else {
            // P1 fix: NNUE 文件缺失时安全返回，避免空指针 SIGSEGV（xctest 环境）
            fprintf(stderr, "[pikafish_api] NNUE file not found in bundle\n");
            g_last_error = "NNUE file not found";
            return -1;
        }
#endif

        // P0 fix: 全局查找表初始化（Pikafish main() 中必须先调）
        static bool s_initialized = false;
        if (!s_initialized) {
            Stockfish::Bitboards::init();
            Stockfish::Position::init();
            s_initialized = true;
        }

        g_engine = new Stockfish::Engine(pathOpt);

        // Set bestmove callback — writes result under mutex, then notifies CV
        g_engine->set_on_bestmove([](std::string_view bestmove, std::string_view ponder) {
            {
                std::lock_guard<std::mutex> lock(g_mutex);
                std::strncpy(g_bestmove_result, std::string(bestmove).c_str(),
                             sizeof(g_bestmove_result) - 1);
                g_bestmove_result[sizeof(g_bestmove_result) - 1] = '\0';
                g_searching = false;
            }
            g_search_cv.notify_one();
        });

        // Set update_full callback — captures eval score and PV from each search iteration
        g_engine->set_on_update_full([](const Stockfish::Engine::InfoFull& info) {
            std::lock_guard<std::mutex> lock(g_mutex);
            // Convert Score variant to int centipawn
            int eval_cp = 0;
            info.score.visit([&](auto&& arg) {
                using T = std::decay_t<decltype(arg)>;
                if constexpr (std::is_same_v<T, Stockfish::Score::Mate>) {
                    eval_cp = arg.plies > 0
                        ? (100000 - arg.plies)
                        : -(100000 + arg.plies);
                } else if constexpr (std::is_same_v<T, Stockfish::Score::InternalUnits>) {
                    eval_cp = arg.value;
                }
            });
            g_last_eval = eval_cp;
            g_last_pv = std::string(info.pv);

            // Collect MultiPV entries (1-indexed)
            size_t pvIdx = info.multiPV > 0 ? info.multiPV - 1 : 0;
            if (pvIdx < 32) {  // safety cap
                if (g_multi_pv_results.size() <= pvIdx) {
                    g_multi_pv_results.resize(pvIdx + 1);
                }
                g_multi_pv_results[pvIdx] = { eval_cp, std::string(info.pv) };
            }
        });

        // Set on_update_no_moves callback (prevent bad_function_call)
        g_engine->set_on_update_no_moves([](const Stockfish::Engine::InfoShort& info) {
            // No-op — only update_full is used for eval capture
        });

        // Set on_iter callback (prevent bad_function_call)
        g_engine->set_on_iter([](const Stockfish::Engine::InfoIter& info) {
            // No-op — only update_full is used for eval capture
        });

        // Set default options
        g_engine->set_tt_size(64);  // 64MB hash table
        g_engine->resize_threads(); // Use default thread count (1)

        // P0 fix: 设置 verify_network 回调（否则 Engine::go() 调 verify_network 会 throw bad_function_call）
        g_engine->set_on_verify_network([](std::string_view message) {
            fprintf(stderr, "[pikafish_api] verify_network: %.*s\n", (int)message.size(), message.data());
        });

        // P0 fix: NNUE 加载后设置起始局面
        // pos.set() 已从 Engine 构造函数移出，这里显式调用
        g_engine->set_start_position();

        // Build engine info string
        g_engine_info = "Pikafish ";
        g_engine_info += "4.0.0"; // Placeholder — update when version is queryable

        return 0;
    } catch (...) {
        if (g_engine) {
            delete g_engine;
            g_engine = nullptr;
        }
        return -1;
    }
}

int pikafish_best_move(const char* fen, const char* moves,
                       int depth, int time_ms,
                       char* buffer, int buffer_size) {
    if (!fen || !buffer || buffer_size < 5) {
        return -1;
    }

    // ---- Phase 1: Set position + start search (holds mutex) ----
    {
        std::lock_guard<std::mutex> lock(g_mutex);

        if (g_engine == nullptr) {
            return -1;
        }

        // Reset result and state
        g_bestmove_result[0] = '\0';
        g_searching = true;
        g_stopping = false;
        g_multi_pv_results.clear();

        // Set position
        auto move_vec = parse_moves(moves);
        auto err = g_engine->set_position(std::string(fen), move_vec);
        if (err.has_value()) {
            g_searching = false;
            return -1;
        }

        // Build search limits
        Stockfish::Search::LimitsType limits;
        if (depth > 0) {
            limits.depth = depth;
        }
        if (time_ms > 0) {
            limits.movetime = Stockfish::TimePoint(time_ms);
        }
        if (depth <= 0 && time_ms <= 0) {
            // No limits set, use reasonable defaults
            limits.depth = 20;
        }

        // Start search (non-blocking — search runs on engine's internal threads)
        try {
            g_engine->go(limits);
        } catch (const std::exception& e) {
            g_searching = false;
            return -1;
        }

    } // <-- mutex released here

    // ---- Phase 2: Wait for search completion (no mutex held) ----
    // This allows stop/quit/new_game to acquire mutex during search.
    {
        std::unique_lock<std::mutex> lock(g_mutex);

        // v3.7.2 P1 fix: 只在无限制搜索时加兜底超时（正常对弈/分析有 depth/time_ms 限制，不会无限等）
        if (depth <= 0 && time_ms <= 0) {
            bool completed = g_search_cv.wait_for(lock, std::chrono::seconds(60),
                [] { return !g_searching; });
            if (!completed) {
                // 超时：请求停止搜索
                g_stopping = true;
                if (g_engine) { g_engine->stop(); }
                // 等 2 秒让引擎清理（不强制设 g_searching=false，避免竞态）
                g_search_cv.wait_for(lock, std::chrono::seconds(2),
                    [] { return !g_searching; });
                return -1;
            }
        } else {
            // 正常搜索：有 depth 或 time_ms 限制，继续用无限等待
            g_search_cv.wait(lock, [] { return !g_searching; });
        }

        // Search complete — read result under mutex
        if (g_bestmove_result[0] == '\0') {
            return -1;
        }

        int copy_len = std::min((int)std::strlen(g_bestmove_result), buffer_size - 1);
        std::memcpy(buffer, g_bestmove_result, copy_len);
        buffer[copy_len] = '\0';
        g_bestmove_result[0] = '\0'; // Clear for next search
    }

    return 0;
}

void pikafish_stop(void) {
    // Set atomic stop flag first (no mutex needed for this)
    g_stopping = true;

    // Then call engine stop under mutex to safely access g_engine pointer
    std::lock_guard<std::mutex> lock(g_mutex);
    if (g_engine && g_searching) {
        g_engine->stop(); // Non-blocking: only sets atomic threads.stop = true
    }
}

void pikafish_new_game(void) {
    std::lock_guard<std::mutex> lock(g_mutex);

    if (g_engine != nullptr) {
        g_engine->search_clear();
    }
}

void pikafish_quit(void) {
    // Step 1: Stop any active search
    pikafish_stop();

    // Step 2: Wait for search to fully complete (so callback won't access g_engine after delete)
    {
        std::unique_lock<std::mutex> lock(g_mutex);
        g_search_cv.wait(lock, [] { return !g_searching; });
    }

    // Step 3: Explicitly wait for ALL engine threads to finish before delete.
    // ~Engine() only calls wait_for_search_finished() (main_thread join),
    // which may leave worker threads running. These zombie workers can interfere
    // with condition variables when a new engine is created via pikafish_init().
    {
        std::lock_guard<std::mutex> lock(g_mutex);
        if (g_engine != nullptr) {
            g_engine->wait_for_search_finished();
            delete g_engine;
            g_engine = nullptr;
        }
    }

    // Step 4: Reset ALL global state to ensure clean slate for next pikafish_init()
    g_stopping = false;
    g_searching = false;
    g_bestmove_result[0] = '\0';
    g_multi_pv_results.clear();
    g_engine_info.clear();
    g_last_eval = 0;
    g_last_pv.clear();
}

int pikafish_set_option(const char* name, const char* value) {
    std::lock_guard<std::mutex> lock(g_mutex);

    if (g_engine == nullptr || !name || !value) {
        return -1;
    }

    try {
        std::string name_str(name);
        std::string value_str(value);

        if (name_str == "Hash") {
            int mb = std::stoi(value_str);
            if (mb < 1 || mb > 1024) return -1;
            g_engine->set_tt_size(mb);
            return 0;
        }
        else if (name_str == "Threads") {
            // Thread count change requires resize_threads()
            // For now, log warning and accept
            fprintf(stderr, "[pikafish_api] Threads option not fully implemented, ignoring\n");
            return 0;
        }
        else if (name_str == "Skill Level") {
            int level = std::stoi(value_str);
            if (level < 0 || level > 20) return -1;
            std::istringstream iss("name Skill Level value " + std::to_string(level));
            g_engine->get_options().setoption(iss);
            return 0;
        }
        else {
            // Accept unknown options silently
            return 0;
        }
    } catch (...) {
        return -1;
    }
}

const char* pikafish_get_info(void) {
    // Note: Returned pointer is valid until pikafish_quit() is called.
    // Caller must not hold this pointer across quit().
    return g_engine_info.c_str();
}

int pikafish_last_eval(void) {
    std::lock_guard<std::mutex> lock(g_mutex);
    return g_last_eval;
}

int pikafish_set_multipv(int n) {
    std::lock_guard<std::mutex> lock(g_mutex);

    if (g_engine == nullptr) {
        return -1;
    }

    if (n < 1 || n > 10) {
        return -1;
    }

    try {
        std::istringstream iss("name MultiPV value " + std::to_string(n));
        g_engine->get_options().setoption(iss);
        return 0;
    } catch (...) {
        return -1;
    }
}

int pikafish_get_pv_line(char* buffer, int buffer_size) {
    if (!buffer || buffer_size <= 0) {
        return -1;
    }

    std::lock_guard<std::mutex> lock(g_mutex);

    int copy_len = std::min((int)g_last_pv.size(), buffer_size - 1);
    std::memcpy(buffer, g_last_pv.c_str(), copy_len);
    buffer[copy_len] = '\0';

    return copy_len;
}

// MARK: - v3.6.0 新增：评估与多 PV 分析

int pikafish_eval(const char* fen, const char* moves,
                  int depth, int time_ms,
                  PikafishEvalResult* result) {
    if (!fen || !result) {
        return -1;
    }

    // 确保使用单 PV
    {
        std::lock_guard<std::mutex> lock(g_mutex);
        if (g_engine == nullptr) return -1;
        std::istringstream iss("name MultiPV value 1");
        g_engine->get_options().setoption(iss);
    }

    // 使用 best_move 的搜索流程（复用现有逻辑）
    char move_buf[16];
    int ret = pikafish_best_move(fen, moves, depth, time_ms, move_buf, sizeof(move_buf));
    if (ret != 0) {
        return -1;
    }

    // 读取搜索结果
    {
        std::lock_guard<std::mutex> lock(g_mutex);
        result->score_cp = g_last_eval;
        result->depth = 0;  // depth 从 update_full callback 中获取（简化：不单独追踪）
        std::strncpy(result->best_move, move_buf, sizeof(result->best_move) - 1);
        result->best_move[sizeof(result->best_move) - 1] = '\0';
        std::strncpy(result->pv, g_last_pv.c_str(), sizeof(result->pv) - 1);
        result->pv[sizeof(result->pv) - 1] = '\0';
    }

    return 0;
}

int pikafish_multi_pv(const char* fen, const char* moves,
                      int num_lines, int depth, int time_ms,
                      PikafishEvalResult* results, int max_results) {
    if (!fen || !results || num_lines < 1 || max_results < 1) {
        return -1;
    }

    int actual_lines = num_lines > max_results ? max_results : num_lines;
    if (actual_lines > 10) actual_lines = 10;

    // 设置 MultiPV
    {
        std::lock_guard<std::mutex> lock(g_mutex);
        if (g_engine == nullptr) return -1;
        std::istringstream iss("name MultiPV value " + std::to_string(actual_lines));
        g_engine->get_options().setoption(iss);
    }

    // 运行搜索
    char move_buf[16];
    int ret = pikafish_best_move(fen, moves, depth, time_ms, move_buf, sizeof(move_buf));
    if (ret != 0) {
        // 搜索失败，重置 MultiPV 为 1
        std::lock_guard<std::mutex> lock(g_mutex);
        std::istringstream iss("name MultiPV value 1");
        g_engine->get_options().setoption(iss);
        return -1;
    }

    // P2 fix: 从 g_multi_pv_results 收集多条 PV（由 update_full callback 填充）
    {
        std::lock_guard<std::mutex> lock(g_mutex);

        int filled = 0;
        int result_count = std::min((int)g_multi_pv_results.size(), actual_lines);

        for (int i = 0; i < result_count && i < max_results; i++) {
            const auto& entry = g_multi_pv_results[i];
            results[i].score_cp = entry.score_cp;
            results[i].depth = 0;

            // 从 PV 中提取第一步作为 best_move
            std::string pv = entry.pv;
            std::string bestMv = pv.substr(0, pv.find(' '));
            std::strncpy(results[i].best_move, bestMv.c_str(), sizeof(results[i].best_move) - 1);
            results[i].best_move[sizeof(results[i].best_move) - 1] = '\0';
            std::strncpy(results[i].pv, pv.c_str(), sizeof(results[i].pv) - 1);
            results[i].pv[sizeof(results[i].pv) - 1] = '\0';
            filled++;
        }

        // Fallback: 如果 callback 没收集到，用 best_move 结果
        if (filled == 0) {
            results[0].score_cp = g_last_eval;
            std::strncpy(results[0].best_move, move_buf, sizeof(results[0].best_move) - 1);
            results[0].best_move[sizeof(results[0].best_move) - 1] = '\0';
            std::strncpy(results[0].pv, g_last_pv.c_str(), sizeof(results[0].pv) - 1);
            results[0].pv[sizeof(results[0].pv) - 1] = '\0';
            results[0].depth = 0;
            filled = 1;
        }

        // 重置 MultiPV 为 1（恢复默认）
        std::istringstream iss("name MultiPV value 1");
        g_engine->get_options().setoption(iss);

        return filled;
    }
}

} // extern "C"
