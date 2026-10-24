# Raises when a buffer index is below the negative length.
start {
    buffer values = buffer(2)
    uint64 value = values[-3]
}
