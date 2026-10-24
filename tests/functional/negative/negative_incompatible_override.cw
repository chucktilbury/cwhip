# Rejects an override that changes the inherited method return type.
class Base {
    Base() {}

    int64 value(int64 input) {
        return input
    }
}

class Child : Base {
    Child() {
        super Base()
    }

    strg value(int64 input) {
        return "wrong"
    }
}

start {}
