# Reference and string conversions are not scalar casts.
start {
    strg text = "1"
    fp64 invalid = fp64(text)
}
