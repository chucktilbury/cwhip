# Signed minimum divided by negative one must use the ordinary overflow check.
start {
    int64 value = -9223372036854775808
    value /= -1
}
