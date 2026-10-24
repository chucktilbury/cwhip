# Rejects using an internal dynamic collection value as an arithmetic operand.
start {
    list values = [1]
    int64 sum = values[0] + 1
}
