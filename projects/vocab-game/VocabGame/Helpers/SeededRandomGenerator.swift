import Foundation

/// Simple seeded random number generator for deterministic daily challenges
struct SeededRandomGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: Int) {
        state = (seed == 0) ? 1 : UInt64(abs(seed))
    }

    mutating func next() -> UInt64 {
        // xorshift64
        state ^= state &<< 13
        state ^= state &>> 7
        state ^= state &<< 17
        return state
    }
}
