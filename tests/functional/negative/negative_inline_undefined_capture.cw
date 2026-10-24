# Rejects capturing a name that is not defined in the surrounding function.
start {
    inline (int64 missing) {
        (void)missing;
    }
}
