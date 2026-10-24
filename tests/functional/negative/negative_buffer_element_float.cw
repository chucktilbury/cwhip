# Rejects writing a fp64 into a byte buffer.
start {
    buffer bytes = buffer(1)
    bytes[0] = 1.5
}
