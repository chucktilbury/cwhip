# Rejects calling a private method through an external object reference.
class Hidden {
    private:
    int64 read() {
        return(1)
    }
}

start {
    Hidden hidden = Hidden()
    print(hidden.read())
}
