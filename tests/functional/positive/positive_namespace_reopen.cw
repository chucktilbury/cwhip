# Reopens a namespace to add classes and verifies declarations share one namespace.
namespace Shared {
    class First {
        int64 value() {
            return(20)
        }
    }
}

namespace Shared {
    class Second {
        int64 value() {
            return(22)
        }
    }

    class Factory {
        First create() {
            return(First())
        }
    }
}

start {
    Shared.Factory factory = Shared.Factory()
    Shared.First first = factory.create()
    Shared.Second second = Shared.Second()
    print(first.value() + second.value())
}
