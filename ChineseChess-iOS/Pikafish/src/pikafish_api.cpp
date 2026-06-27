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
#include "engine.h"
#include "uci.h"
#include "thread.h"
#include <string>
#include <vector>
#include <mutex>
#include <condition_variable>
#include <atomic>
#include <cstring>

namespace {

// Global engine instance (singleton)
Stockfish::Engine* g_engine = nullptr;

// Synchronization primitives
std::mutex g_mutex;
std::condition_variable g_search_cv;

// Search state — all accessed under g_mutex unless noted
bool g_searching = false;
char g_bestmove_result[16] = {0};

// Last search info — written by set_on_update_full callback, read by API functions
int  g_last_eval = 0;       // centipawn (±100000 - plies for mate)
std::string g_last_pv;      // space-separated UCI moves

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
        // Already initialized
        return 0;
    }

    try {
        // Create engine (nullopt = use embedded NNUE or search default paths)
        g_engine = new Stockfish::Engine(std::nullopt);

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
            info.score.visit([](auto&& arg) {
                using T = std::decay_t<decltype(arg)>;
                if constexpr (std::is_same_v<T, Stockfish::Score::Mate>) {
                    // Mate: ±(100000 - plies) to distinguish from cp values
                    g_last_eval = arg.plies > 0
                        ? (100000 - arg.plies)
                        : -(100000 + arg.plies);
                } else if constexpr (std::is_same_v<T, Stockfish::Score::InternalUnits>) {
                    // InternalUnits.value is already in centipawn
                    g_last_eval = arg.value;
                }
            });
            g_last_pv = std::string(info.pv);
        });

        // Set default options
        g_engine->set_tt_size(64);  // 64MB hash table
        g_engine->resize_threads(); // Use default thread count (1)

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
        g_engine->go(limits);

    } // <-- mutex released here

    // ---- Phase 2: Wait for search completion (no mutex held) ----
    // This allows stop/quit/new_game to acquire mutex during search.
    {
        std::unique_lock<std::mutex> lock(g_mutex);
        g_search_cv.wait(lock, [] { return !g_searching; });

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

    // Step 3: Safe to delete engine — no callback will fire after this
    {
        std::lock_guard<std::mutex> lock(g_mutex);
        if (g_engine != nullptr) {
            delete g_engine;
            g_engine = nullptr;
        }
    }

    g_stopping = false;
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

} // extern "C"