# Rejects an ambiguous overloaded call. 'null' is assignable to any class
# type, so a bare null argument matches both class-typed overloads and the
# call cannot be resolved.
class Left {
    Left() {}
}

class Right {
    Right() {}
}

class Chooser {
    Chooser() {}

    int64 pick(Left value) {
        return 1
    }

    int64 pick(Right value) {
        return 2
    }
}

start {
    Chooser c = Chooser()
    print(c.pick(null))
}
