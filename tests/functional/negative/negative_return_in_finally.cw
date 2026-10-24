class InvalidReturn {
    int64 value() {
        try {
            return 1
        } finally {
            if (true) {
                { return 2 }
            }
        }
    }
}

start {}
