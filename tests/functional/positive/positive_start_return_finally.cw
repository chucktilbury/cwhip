start {
    try {
        print("body")
        return(5)
    } finally {
        print("cleanup")
    }
}
