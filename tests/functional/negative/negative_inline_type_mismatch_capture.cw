# Rejects declaring a string variable as an int64 capture in inline C.
start {
    strg value = "text"
    inline (int64 value) {
        (void)value;
    }
}
