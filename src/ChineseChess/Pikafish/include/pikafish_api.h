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

#ifdef __cplusplus
}
#endif

#endif // PIKAFISH_API_H