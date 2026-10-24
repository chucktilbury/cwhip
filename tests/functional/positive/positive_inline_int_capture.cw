# Verifies inline C can mutate a captured integer and the change is visible to Cwhip code.
start {
    int64 value = 7
    inline (int64 value) {
        *value += 5;
    }
    print(value)
}
