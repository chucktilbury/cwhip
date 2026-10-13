# Allocation-heavy GC benchmark. Compile with bin/cwhip -o bench gc_throughput.cw.
class Tree {
    Tree left
    Tree right
    Tree(int depth) {
        if (depth > 0) {
            left = Tree(depth - 1)
            right = Tree(depth - 1)
        }
    }
    int count() {
        if (left == null) { return 1 }
        return 1 + left.count() + right.count()
    }
}

start {
    int total = 0
    int round = 0
    while (round < 40) {
        Tree tree = Tree(12 + round % 5)
        total = total + tree.count()
        strg text = ""
        list values = []
        int index = 0
        while (index < 2000) {
            text.append(format("{}", index))
            values.append(index)
            index = index + 1
        }
        round = round + 1
    }
    print(total)
}
