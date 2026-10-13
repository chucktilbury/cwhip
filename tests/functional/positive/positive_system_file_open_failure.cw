import system as System

start {
    bool caughtConstructor = false
    try {
        System.File file = System.File("nonexistent.txt", "r")
    } except(Exception) as err {
        caughtConstructor = err.message.contains("Cannot open file 'nonexistent.txt':")
    }
    print(caughtConstructor)

    bool caughtOpen = false
    try {
        System.File file = System.System().open("nonexistent.txt", "r")
    } except(Exception) as err {
        caughtOpen = err.message.contains("Cannot open file 'nonexistent.txt':")
    }
    print(caughtOpen)
}
