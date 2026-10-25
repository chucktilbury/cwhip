include "nested_value.cw"
class SearchTarget {
    int64 answer() {
        NestedValue nested = NestedValue()
        return(40 + nested.value())
    }
}
