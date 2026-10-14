class Number {
    int double(int value) {
        int doubled = value * 2
        return doubled
    }
}
start {
    int debugger_local = 42
    print(debugger_local)
    Number number = Number()
    int answer = number.double(21)
    answer = answer + 1
    answer = answer + 1
}
