# Passes constructor arguments to one shared virtual base from the most-derived diamond class.
class Root {
    int64 value

    Root(int64 initial) {
        value = initial
        print(format("Root:{}", initial))
    }
}

class Left : virtual Root {
    Left() {
        print("Left+")
    }
}

class Right : virtual Root {
    Right() {
        print("Right+")
    }
}

class Diamond : Left, Right {
    Diamond(int64 initial) {
        virtual super Root(initial)
        super Left()
        super Right()
        print("Diamond+")
    }
}

start {
    Diamond diamond = Diamond(42)
    print(diamond.Left.Root.value)
    print(diamond.Right.Root.value)
}
