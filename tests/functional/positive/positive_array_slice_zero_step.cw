# A constant-looking zero step remains catchable at runtime.
start {
    list values = [1, 2, 3]
    try {
        list invalid = values[::1 - 1]
    } except () {
        print("caught")
    }
}
