# Rejects initializing the same virtual base twice in one constructor.
class Root {
    Root(int64 value) {
    }
}

class Leaf : virtual Root {
    Leaf() {
        super virtual Root(1)
        super virtual Root(2)
    }
}

start {
}
