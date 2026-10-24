# Rejects arithmetic between signed and unsigned 64-bit values with no common type.
start {
    int64 signedValue = 1
    uint64 unsignedValue = 1u
    int64 invalid = signedValue + unsignedValue
}
