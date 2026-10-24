# Rejects accessing a privately inherited field from a further-derived class.
class Base {
    int64 value
}

class PrivateChild : private Base {
}

class Grandchild : public PrivateChild {
    int64 readValue() {
        return value
    }
}

start {
}
