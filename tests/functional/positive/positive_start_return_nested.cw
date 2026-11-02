start {
    int32 value = 0
    while (value < 10) {
        value = value + 1
        if (value == 3) {
            print("leaving")
            return(40 + value)
        }
    }
    print("not reached")
}
