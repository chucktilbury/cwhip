# Rejects listing the same variable more than once in an inline capture list.
start {
    int64 value = 1
    inline (int64 value, int64 value) {
        (void)value;
    }
}
