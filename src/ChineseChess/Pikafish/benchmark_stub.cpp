// benchmark_stub.cpp - Stub for missing Benchmark symbols in libpikafish.a
// The build script excludes benchmark.cpp but UCIEngine::bench() references it.
// This stub provides the missing symbols so the test executable can link.

#include <string>
#include <istream>

namespace Stockfish {
namespace Benchmark {

// Stub implementation for setup_bench
void setup_bench(const std::string& fen, std::istream& is) {
    // No-op stub - bench functionality is not used in the app
}

// Stub implementation for setup_benchmark  
void setup_benchmark(std::istream& is) {
    // No-op stub - bench functionality is not used in the app
}

} // namespace Benchmark
} // namespace Stockfish
