import shared as Shared

class Alpha {
    int64 version() {
        Shared shared = Shared()
        return(shared.version())
    }
}
