# Compound integer division by zero must use the ordinary arithmetic runtime check.
start {
    int64 value = 1
    value /= 0
}
