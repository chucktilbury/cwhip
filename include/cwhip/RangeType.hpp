#pragma once

#include "cwhip/NumericType.hpp"

#include <string>

namespace cwhip {

inline bool isRangeType(const std::string& type) {
    return type.compare(0, 6, "range<") == 0 && type.back() == '>';
}

inline std::string rangeElementType(const std::string& type) {
    return type.substr(6, type.size() - 7);
}

inline std::string rangeType(const std::string& element) {
    return "range<" + element + ">";
}

} // namespace cwhip
