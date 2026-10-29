# Built-in String class. Literal creation is compiler-owned; no public constructor.
# `_bytes` is private storage owned by this object, not a collected buffer.
# The runtime allocates that array with malloc and frees it when the string
# is swept. `_length` and `_capacity` are the runtime's byte count and
# allocation size; `.length` reads `_length`.
class String {
    private:
    buffer _bytes
    uint64 _length
    uint64 _capacity

    protected:
    String() {
    }

    public:
    void append(String other)
    bool equals(String other)
    int8 toInt8()
    uint8 toUint8()
    int16 toInt16()
    uint16 toUint16()
    int32 toInt32()
    uint32 toUint32()
    int64 toInt64()
    uint64 toUint64()
    fp32 toFp32()
    fp64 toFp64()

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
int8 String.toInt8() from "cwhip_string_method_to_int8"
uint8 String.toUint8() from "cwhip_string_method_to_uint8"
int16 String.toInt16() from "cwhip_string_method_to_int16"
uint16 String.toUint16() from "cwhip_string_method_to_uint16"
int32 String.toInt32() from "cwhip_string_method_to_int32"
uint32 String.toUint32() from "cwhip_string_method_to_uint32"
int64 String.toInt64() from "cwhip_string_method_to_int64"
uint64 String.toUint64() from "cwhip_string_method_to_uint64"
fp32 String.toFp32() from "cwhip_string_method_to_fp32"
fp64 String.toFp64() from "cwhip_string_method_to_fp64"
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
