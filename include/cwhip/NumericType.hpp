/**
 * @file NumericType.hpp
 * @brief Shared description and classification of Cwhip numeric types.
 */
#pragma once

#include <array>
#include <optional>
#include <string>
#include <string_view>

namespace cwhip {

enum class NumericCategory { SignedInteger, UnsignedInteger, FloatingPoint };
enum class NumericSignedness { Signed, Unsigned, NotApplicable };

struct NumericRange {
    std::string_view minimum;
    std::string_view maximum;
};

struct NumericTypeDescription {
    std::string_view name;
    NumericCategory category;
    unsigned width;
    NumericSignedness signedness;
    NumericRange range;
    std::string_view llvmType;
    unsigned precision;
};

inline constexpr std::array<NumericTypeDescription, 10> numericTypes{{
    {"int8", NumericCategory::SignedInteger, 8, NumericSignedness::Signed,
     {"-128", "127"}, "i8", 7},
    {"uint8", NumericCategory::UnsignedInteger, 8, NumericSignedness::Unsigned,
     {"0", "255"}, "i8", 8},
    {"int16", NumericCategory::SignedInteger, 16, NumericSignedness::Signed,
     {"-32768", "32767"}, "i16", 15},
    {"uint16", NumericCategory::UnsignedInteger, 16, NumericSignedness::Unsigned,
     {"0", "65535"}, "i16", 16},
    {"int32", NumericCategory::SignedInteger, 32, NumericSignedness::Signed,
     {"-2147483648", "2147483647"}, "i32", 31},
    {"uint32", NumericCategory::UnsignedInteger, 32, NumericSignedness::Unsigned,
     {"0", "4294967295"}, "i32", 32},
    {"int64", NumericCategory::SignedInteger, 64, NumericSignedness::Signed,
     {"-9223372036854775808", "9223372036854775807"}, "i64", 63},
    {"uint64", NumericCategory::UnsignedInteger, 64, NumericSignedness::Unsigned,
     {"0", "18446744073709551615"}, "i64", 64},
    {"fp32", NumericCategory::FloatingPoint, 32, NumericSignedness::NotApplicable,
     {"-3.4028234663852886e+38", "3.4028234663852886e+38"}, "float", 24},
    {"fp64", NumericCategory::FloatingPoint, 64, NumericSignedness::NotApplicable,
     {"-1.7976931348623157e+308", "1.7976931348623157e+308"}, "double", 53},
}};

inline const NumericTypeDescription* numericType(std::string_view name) noexcept {
    for (const auto& type : numericTypes) {
        if (type.name == name) return &type;
    }
    return nullptr;
}

inline bool isIntegerType(std::string_view name) noexcept {
    const auto* type = numericType(name);
    return type != nullptr && type->category != NumericCategory::FloatingPoint;
}

inline bool isFloatingType(std::string_view name) noexcept {
    const auto* type = numericType(name);
    return type != nullptr && type->category == NumericCategory::FloatingPoint;
}

inline bool isNumericType(std::string_view name) noexcept {
    return numericType(name) != nullptr;
}

inline std::optional<std::string> commonIntegerType(std::string_view left,
                                                     std::string_view right) {
    const auto* leftType = numericType(left);
    const auto* rightType = numericType(right);
    if (leftType == nullptr || rightType == nullptr ||
        leftType->category == NumericCategory::FloatingPoint ||
        rightType->category == NumericCategory::FloatingPoint) {
        return std::nullopt;
    }
    if (leftType->category == rightType->category) {
        const auto width = leftType->width > rightType->width
                               ? leftType->width : rightType->width;
        return std::string(leftType->category == NumericCategory::SignedInteger ? "int" : "uint") +
               std::to_string(width);
    }
    const auto* signedType = leftType->category == NumericCategory::SignedInteger
                                 ? leftType : rightType;
    const auto* unsignedType = leftType->category == NumericCategory::UnsignedInteger
                                   ? leftType : rightType;
    for (const auto& candidate : numericTypes) {
        if (candidate.category == NumericCategory::SignedInteger &&
            candidate.width >= signedType->width &&
            candidate.width > unsignedType->width) {
            return std::string(candidate.name);
        }
    }
    return std::nullopt;
}

inline std::optional<std::string> commonNumericType(std::string_view left,
                                                     std::string_view right) {
    const auto* leftType = numericType(left);
    const auto* rightType = numericType(right);
    if (leftType == nullptr || rightType == nullptr) return std::nullopt;
    if (leftType->category != NumericCategory::FloatingPoint &&
        rightType->category != NumericCategory::FloatingPoint) {
        return commonIntegerType(left, right);
    }
    if (leftType->category == NumericCategory::FloatingPoint &&
        rightType->category == NumericCategory::FloatingPoint) {
        return std::string(leftType->width >= rightType->width ? leftType->name
                                                               : rightType->name);
    }
    const auto* floating = leftType->category == NumericCategory::FloatingPoint
                               ? leftType : rightType;
    const auto* integer = leftType->category == NumericCategory::FloatingPoint
                              ? rightType : leftType;
    if (floating->width == 32 && integer->precision <= 24) return "fp32";
    return "fp64";
}

inline bool isLosslessNumericConversion(std::string_view target,
                                       std::string_view source) noexcept {
    if (target == source) return true;
    const auto* targetType = numericType(target);
    const auto* sourceType = numericType(source);
    if (targetType == nullptr || sourceType == nullptr) return false;
    if (sourceType->category == NumericCategory::FloatingPoint) {
        return targetType->category == NumericCategory::FloatingPoint &&
               targetType->width >= sourceType->width;
    }
    if (targetType->category == NumericCategory::FloatingPoint) {
        return targetType->precision >= sourceType->precision;
    }
    if (targetType->category == sourceType->category) {
        return targetType->width >= sourceType->width;
    }
    return targetType->category == NumericCategory::SignedInteger &&
           sourceType->category == NumericCategory::UnsignedInteger &&
           targetType->width > sourceType->width;
}

} // namespace cwhip
