# Selects and dispatches to a method from a specifically qualified secondary base.
class Primary {
    int64 read() {
        return(1)
    }
}

class Secondary {
    int64 read() {
        return(2)
    }
}

class QualifiedCombined : Primary, Secondary {
}

start {
    QualifiedCombined combined = QualifiedCombined()
    print(combined.Secondary.read())
}
