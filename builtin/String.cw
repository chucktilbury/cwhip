# Built-in String class. Literal creation is compiler-owned; no public constructor.
class String {
    private:
    buffer _bytes

    protected:
    String() {
        _bytes = buffer(0)
    }

    public:
    void append(String other)
    bool equals(String other)
    int64 toInt()
    uint64 toUnsigned()
    fp64 toFloat()

    uint64 byteAt(int64 index)
    String slice(int64 first, int64 last)
    void insert(int64 index, String other)
    void removeRange(int64 first, int64 last)
    void clear()
    int64 find(String needle)
    bool contains(String needle)
    bool startsWith(String prefix)
    bool endsWith(String suffix)
    list split(String separator)
    String replace(String target, String replacement)
    String trim()
    String strip()
    String toUpper()
    String toLower()
}

void String.append(String other) from "cwhip_string_append"
bool String.equals(String other) from "cwhip_string_equals"
int64 String.toInt() from "cwhip_string_method_to_int"
uint64 String.toUnsigned() from "cwhip_string_method_to_unsigned"
fp64 String.toFloat() from "cwhip_string_method_to_float"
uint64 String.byteAt(int64 index) from "cwhip_string_method_byte_at"
String String.slice(int64 first, int64 last) from "cwhip_string_method_slice"
void String.insert(int64 index, String other) from "cwhip_string_method_insert"
void String.removeRange(int64 first, int64 last) from "cwhip_string_method_remove_range"
void String.clear() from "cwhip_string_method_clear"
int64 String.find(String needle) from "cwhip_string_method_find"
bool String.contains(String needle) from "cwhip_string_method_contains"
bool String.startsWith(String prefix) from "cwhip_string_method_starts_with"
bool String.endsWith(String suffix) from "cwhip_string_method_ends_with"
list String.split(String separator) from "cwhip_string_method_split"
String String.replace(String target, String replacement) from "cwhip_string_method_replace"
String String.trim() from "cwhip_string_method_trim"
String String.strip() from "cwhip_string_method_trim"
String String.toUpper() from "cwhip_string_method_to_upper"
String String.toLower() from "cwhip_string_method_to_lower"
