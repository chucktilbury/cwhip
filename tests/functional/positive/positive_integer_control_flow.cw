# Exercises integer comparison, modulo, branching, assignment, and repeated loop execution.
start {
    int64 counter = 0
    int64 total = 0
    while (counter < 5) {
        counter = counter + 1
        if (counter % 2 == 0) {
            total = total + counter
        } else {
            total = total + 1
        }
    }
    print(total)
}
