# Verifies public access, protected subclass access, private self-access, and protected construction.
class AccessBase {
    public:
    int64 publicValue
    int64 publicMethod() {
        return(publicValue)
    }

    protected:
    int64 protectedValue
    int64 protectedMethod() {
        return(protectedValue)
    }

    private:
    int64 privateValue
    int64 privateMethod() {
        return(privateValue)
    }

    public:
    int64 readPrivate() {
        return(privateValue)
    }

    int64 readPrivateMethod(AccessBase self) {
        return(self.privateMethod())
    }
}

class AccessChild : public AccessBase {
    public:
    int64 readProtected(AccessChild self) {
        self.protectedValue = 7
        return(self.protectedMethod())
    }
}

class ProtectedCtorBase {
    protected:
    ProtectedCtorBase() {
    }
}

class ProtectedCtorChild : public ProtectedCtorBase {
    public:
    ProtectedCtorChild() {
        super ProtectedCtorBase()
    }
}

start {
    AccessBase base = AccessBase()
    base.publicValue = 42
    print(base.publicMethod())
    print(base.readPrivate())
    print(base.readPrivateMethod(base))

    AccessChild child = AccessChild()
    print(child.readProtected(child))

    ProtectedCtorChild constructed = ProtectedCtorChild()
    print(1)
}
