# Rejects constructing a class through its private constructor from start code.
class Hidden {
    private:
    Hidden(int64 value) {
    }
}

start {
    Hidden hidden = Hidden(1)
}
