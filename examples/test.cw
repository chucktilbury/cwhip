
start {

    # Deliberately read beyond an empty buffer to demonstrate a runtime diagnostic.
    buffer c = buffer(0)
    int64 ch
    ch = int64(c[0]) # << RT error: invalid buffer reference
    print(ch)
}