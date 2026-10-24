# Rejects a most-derived constructor that omits a required virtual-base initializer.
class Root {
    Root(int64 value) {
    }
}

class Leaf : virtual Root {
    Leaf() {
    }
}

start {
    Leaf leaf = Leaf()
}
