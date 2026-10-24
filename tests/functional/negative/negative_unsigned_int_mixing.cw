# Rejects arithmetic between unsigned and signed 64-bit values with no common type.
start {
    uint64 unsignedValue = 1u
    int64 signedValue = 1
    uint64 invalid = unsignedValue + signedValue
}
