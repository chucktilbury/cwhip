# Rejects reading a private field through an external object reference.
class Hidden {
    private:
    int64 value
    int64 read() {
        return value
    }
}

start {
    Hidden hidden = Hidden()
    print(hidden.value)
}
