# Rejects calling a method absent from the Counter class.
class Counter {
    int64 value
}

start {
    Counter counter = Counter()
    print(counter.missing())
}
