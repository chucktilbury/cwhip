# Rejects exposing a private base subobject through a qualified member access.
class Base {
    int64 value
}

class PrivateChild : private Base {
}

start {
    PrivateChild child = PrivateChild()
    print(child.Base.value)
}
