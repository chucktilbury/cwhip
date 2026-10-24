/**
 * @file NumericRuntimeType.hpp
 * @brief Stable dynamic-value tags for the exact Cwhip numeric types.
 */
#pragma once

#include "cwhip/RuntimeGc.h"

#include <cstdint>
#include <string_view>

namespace cwhip {

constexpr std::uint64_t numericRuntimeTag(std::string_view type) noexcept {
    if (type == "int8") return CWHIP_ARRAY_INT8;
    if (type == "uint8") return CWHIP_ARRAY_UINT8;
    if (type == "int16") return CWHIP_ARRAY_INT16;
    if (type == "uint16") return CWHIP_ARRAY_UINT16;
    if (type == "int32") return CWHIP_ARRAY_INT32;
    if (type == "uint32") return CWHIP_ARRAY_UINT32;
    if (type == "int64") return CWHIP_ARRAY_INT64;
    if (type == "uint64") return CWHIP_ARRAY_UINT64;
    if (type == "fp32") return CWHIP_ARRAY_FP32;
    if (type == "fp64") return CWHIP_ARRAY_FP64;
    return 0;
}

} // namespace cwhip
