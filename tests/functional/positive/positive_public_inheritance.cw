# Exercises public base access and confirms protected/private base members remain usable inside derived classes.
class Base {
    int64 value
}

class PublicChild : public Base {
}

class ProtectedChild : protected Base {
    int64 readValue() {
        return(value)
    }
}

class PrivateChild : private Base {
    int64 readValue() {
        return(value)
    }
}

class ProtectedGrandchild : public ProtectedChild {
    int64 readAgain() {
        return(value)
    }
}

start {
    PublicChild child = PublicChild()
    child.value = 42
    print(child.value)

    ProtectedChild protectedChild = ProtectedChild()
    print(protectedChild.readValue())

    PrivateChild privateChild = PrivateChild()
    print(privateChild.readValue())

    ProtectedGrandchild protectedGrandchild = ProtectedGrandchild()
    print(protectedGrandchild.readAgain())

}
