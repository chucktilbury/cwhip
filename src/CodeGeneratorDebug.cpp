#include "cwhip/CodeGenerator.hpp"
#include "cwhip/NumericType.hpp"

#include <algorithm>
#include <filesystem>
#include <sstream>

namespace cwhip {

std::string CodeGenerator::debugQuote(const std::string& value) {
    std::string result = "\"";
    constexpr char digits[] = "0123456789ABCDEF";
    for (unsigned char c : value) {
        if (c == '"' || c == '\\' || c < 32 || c >= 127) {
            result += '\\';
            result += digits[c >> 4];
            result += digits[c & 15];
        } else {
            result += static_cast<char>(c);
        }
    }
    return result + "\"";
}

bool CodeGenerator::isOpaqueDebugClass(const std::string& name) {
    // Runtime-backed types keep dedicated pretty-printers in cdbg; emit forward
    // decls so those paths are unchanged.
    if (name == "String" || name == "list" || name == "dict" || name == "buffer") {
        return true;
    }
    return name.rfind("range<", 0) == 0;
}

std::string CodeGenerator::reserveDebugNode() {
    return "!" + std::to_string(nextDebugNode_++);
}

void CodeGenerator::defineDebugNode(const std::string& id, const std::string& contents) {
    debugNodes_ += id + " = " + contents + "\n";
}

std::string CodeGenerator::debugNode(const std::string& contents) {
    const auto id = reserveDebugNode();
    defineDebugNode(id, contents);
    return id;
}

std::string CodeGenerator::debugFile(const std::string& path) {
    const auto absolute = std::filesystem::absolute(
        path.empty() ? std::filesystem::path("cwhip") : std::filesystem::path(path)
    ).lexically_normal();
    const auto key = absolute.string();
    const auto found = debugFiles_.find(key);
    if (found != debugFiles_.end()) return found->second;
    const auto id = debugNode("!DIFile(filename: " + debugQuote(absolute.filename().string()) +
                              ", directory: " + debugQuote(absolute.parent_path().string()) +
                              ")");
    debugFiles_.emplace(key, id);
    return id;
}

uint64_t CodeGenerator::debugAbiAlignBits(const std::string& llvmOrClassType,
                                          bool embeddedClass) const {
    if (embeddedClass) {
        const auto found = debugClassSizesBits_.find(llvmOrClassType);
        if (found != debugClassSizesBits_.end()) {
            // Align to the largest member alignment; for our layouts that is 64 bits.
            return 64;
        }
        return 64;
    }
    if (llvmOrClassType == "ptr" || llvmOrClassType == "i64" || llvmOrClassType == "double" ||
        llvmOrClassType == "%CwhipArrayValue" || llvmOrClassType == "%CwhipString" ||
        llvmOrClassType == "%CwhipRange") {
        return 64;
    }
    if (llvmOrClassType == "i32" || llvmOrClassType == "float") return 32;
    if (llvmOrClassType == "i16") return 16;
    if (llvmOrClassType == "i8" || llvmOrClassType == "i1") return 8;
    return 64;
}

uint64_t CodeGenerator::debugAbiSizeBits(const std::string& llvmOrClassType,
                                         bool embeddedClass) const {
    if (embeddedClass) {
        const auto found = debugClassSizesBits_.find(llvmOrClassType);
        if (found != debugClassSizesBits_.end()) return found->second;
        return 64;
    }
    if (llvmOrClassType == "ptr") return 64;
    if (llvmOrClassType == "i64" || llvmOrClassType == "double") return 64;
    if (llvmOrClassType == "i32" || llvmOrClassType == "float") return 32;
    if (llvmOrClassType == "i16") return 16;
    if (llvmOrClassType == "i8" || llvmOrClassType == "i1") return 8;
    if (llvmOrClassType == "%CwhipArrayValue") return 256; // {i64,i64,ptr,i64}
    if (llvmOrClassType == "%CwhipString") return 128;     // {ptr,i64}
    if (llvmOrClassType == "%CwhipRange") return 256;      // {ptr,i64,i64,i64}
    return 64;
}

std::string CodeGenerator::debugEmbeddedClassType(const std::string& className) {
    return debugClassStructure(className);
}

std::string CodeGenerator::debugClassStructure(const std::string& className) {
    const auto existing = debugClassStructs_.find(className);
    if (existing != debugClassStructs_.end()) return existing->second;

    const auto classFound = classes_.find(className);
    if (classFound == classes_.end() || isOpaqueDebugClass(className)) {
        const auto structure = debugNode("!DICompositeType(tag: DW_TAG_structure_type, name: " +
                                         debugQuote(className) + ", flags: DIFlagFwdDecl)");
        debugClassStructs_.emplace(className, structure);
        return structure;
    }

    const ClassDeclaration& owner = *classFound->second;
    // Reserve both ids up front so recursive class pointers can forward-reference
    // the structure, and define the complete composite before its pointer type so
    // LLVM/GDB do not keep a permanent forward declaration.
    const auto structureId = reserveDebugNode();
    const auto pointerId = reserveDebugNode();
    debugClassStructs_.emplace(className, structureId);
    debugTypes_[className] = pointerId;

    struct Member {
        std::string name;
        std::string baseTypeId;
        uint64_t sizeBits = 0;
        uint64_t alignBits = 0;
        uint64_t offsetBits = 0;
    };
    std::vector<Member> members;
    uint64_t offset = 0;
    uint64_t maxAlign = 8;

    const auto appendMember = [&](const std::string& name, const std::string& baseTypeId,
                                  uint64_t sizeBits, uint64_t alignBits) {
        if (alignBits == 0) alignBits = 8;
        offset = (offset + alignBits - 1) / alignBits * alignBits;
        members.push_back({name, baseTypeId, sizeBits, alignBits, offset});
        offset += sizeBits;
        maxAlign = std::max(maxAlign, alignBits);
    };

    const auto voidPtrType =
        debugNode("!DIDerivedType(tag: DW_TAG_pointer_type, baseType: null, size: 64)");
    appendMember("__metadata", voidPtrType, 64, 64);
    appendMember("__owner", voidPtrType, 64, 64);

    for (const auto& baseName : owner.baseClassNames) {
        const auto baseStruct = debugClassStructure(baseName);
        const auto sizeBits = debugAbiSizeBits(baseName, true);
        const auto alignBits = debugAbiAlignBits(baseName, true);
        appendMember(baseName, baseStruct, sizeBits, alignBits);
    }

    const auto virtualBases = virtualBaseNames(owner);
    for (const auto& baseName : virtualBases) {
        appendMember("__vbase_ptr_" + baseName, voidPtrType, 64, 64);
    }

    for (const auto& field : owner.fields) {
        const auto* numeric = numericType(field.type);
        std::string baseTypeId;
        uint64_t sizeBits = 0;
        uint64_t alignBits = 0;
        if (numeric || field.type == "bool" || field.type == "c_int") {
            baseTypeId = debugType(field.type);
            sizeBits = numeric ? numeric->width : field.type == "bool" ? 8U : 32U;
            alignBits = sizeBits < 8 ? 8 : sizeBits;
            if (field.type == "bool") {
                sizeBits = 8;
                alignBits = 8;
            }
        } else if (field.type == "any") {
            baseTypeId = debugType(field.type);
            sizeBits = debugAbiSizeBits("%CwhipArrayValue", false);
            alignBits = debugAbiAlignBits("%CwhipArrayValue", false);
        } else if (field.type == "type") {
            baseTypeId = debugType(field.type);
            sizeBits = debugAbiSizeBits("%CwhipString", false);
            alignBits = debugAbiAlignBits("%CwhipString", false);
        } else {
            // Class / String / list / etc. references are pointers.
            baseTypeId = debugType(field.type);
            sizeBits = 64;
            alignBits = 64;
        }
        appendMember(field.name, baseTypeId, sizeBits, alignBits);
    }

    for (const auto& baseName : virtualBases) {
        const auto baseStruct = debugClassStructure(baseName);
        const auto sizeBits = debugAbiSizeBits(baseName, true);
        const auto alignBits = debugAbiAlignBits(baseName, true);
        appendMember("__vbase_" + baseName, baseStruct, sizeBits, alignBits);
    }

    if (maxAlign > 0) {
        offset = (offset + maxAlign - 1) / maxAlign * maxAlign;
    }
    debugClassSizesBits_[className] = offset;

    std::string elementList;
    const auto file = debugFile(owner.location.file);
    for (std::size_t index = 0; index < members.size(); ++index) {
        const auto& member = members[index];
        const auto memberId = debugNode(
            "!DIDerivedType(tag: DW_TAG_member, name: " + debugQuote(member.name) +
            ", scope: " + structureId + ", file: " + file +
            ", line: " + std::to_string(owner.location.line) +
            ", baseType: " + member.baseTypeId +
            ", size: " + std::to_string(member.sizeBits) +
            ", offset: " + std::to_string(member.offsetBits) + ")");
        if (index != 0) elementList += ", ";
        elementList += memberId;
    }
    const auto elementsId = debugNode("!{" + elementList + "}");
    defineDebugNode(structureId,
                    "!DICompositeType(tag: DW_TAG_structure_type, name: " +
                        debugQuote(className) + ", file: " + file +
                        ", line: " + std::to_string(owner.location.line) +
                        ", size: " + std::to_string(offset) +
                        ", elements: " + elementsId + ")");
    defineDebugNode(pointerId,
                    "!DIDerivedType(tag: DW_TAG_pointer_type, baseType: " + structureId +
                        ", size: 64)");
    return structureId;
}

std::string CodeGenerator::debugType(const std::string& type) {
    if (type == "void") return "null";
    const auto found = debugTypes_.find(type);
    if (found != debugTypes_.end()) return found->second;
    std::string id;
    const auto* numeric = numericType(type);
    if (numeric || type == "c_int" || type == "bool") {
        const auto size = numeric ? numeric->width : type == "bool" ? 8U : 32U;
        const auto encoding = isFloatingType(type) ? "DW_ATE_float" :
                              type == "bool" ? "DW_ATE_boolean" :
                              numeric && numeric->category == NumericCategory::UnsignedInteger
                                  ? "DW_ATE_unsigned" : "DW_ATE_signed";
        id = debugNode("!DIBasicType(name: " + debugQuote(type) + ", size: " +
                       std::to_string(size) + ", encoding: " + encoding + ")");
        debugTypes_.emplace(type, id);
    } else if (type == "any" || type == "type") {
        id = debugNode("!DICompositeType(tag: DW_TAG_structure_type, name: " +
                       debugQuote(type) + ", size: " +
                       (type == "any" ? "256" : "128") + ")");
        debugTypes_.emplace(type, id);
    } else if (classes_.find(type) != classes_.end() && !isOpaqueDebugClass(type)) {
        debugClassStructure(type);
        id = debugTypes_.at(type);
    } else {
        const auto structure = debugClassStructure(type);
        id = debugNode("!DIDerivedType(tag: DW_TAG_pointer_type, baseType: " + structure +
                       ", size: 64)");
        debugTypes_.emplace(type, id);
    }
    return id;
}

std::string CodeGenerator::debugBeginFunction(const SourceLocation& location,
                                               const std::string& name,
                                               const std::string& symbol,
                                               const std::string& returnType,
                                               bool artificial) {
    if (!debug_) return {};
    const auto file = debugFile(location.file);
    const auto signature = debugNode("!DISubroutineType(types: !{" +
                                      debugType(returnType) + "})");
    debugSubprogram_ = debugNode("distinct !DISubprogram(name: " + debugQuote(name) +
        ", linkageName: " + debugQuote(symbol.front() == '@' ? symbol.substr(1) : symbol) +
        ", scope: " + file + ", file: " + file +
        ", line: " + std::to_string(location.line) + ", type: " + signature +
        ", scopeLine: " + std::to_string(location.line) +
        (artificial ? ", flags: DIFlagArtificial | DIFlagThunk" : "") +
        ", spFlags: DISPFlagDefinition, unit: " + debugUnit_ + ")");
    debugScopes_.clear();
    debugLocations_.clear();
    debugCurrentLocation_ = debugLocation(location);
    return " !dbg " + debugSubprogram_;
}

std::string CodeGenerator::debugLocation(const SourceLocation& location) {
    if (!debug_) return {};
    const auto file = debugFile(location.file);
    auto scope = debugSubprogram_;
    const auto subprogramFile = debugScopes_.find("");
    if (subprogramFile == debugScopes_.end()) {
        debugScopes_[""] = file;
    } else if (file != subprogramFile->second) {
        const auto found = debugScopes_.find(file);
        if (found == debugScopes_.end()) {
            scope = debugNode("!DILexicalBlockFile(scope: " + debugSubprogram_ +
                              ", file: " + file + ", discriminator: 0)");
            debugScopes_.emplace(file, scope);
        } else {
            scope = found->second;
        }
    }
    const auto key = scope + ":" + std::to_string(location.line) + ":" +
                     std::to_string(location.column);
    const auto found = debugLocations_.find(key);
    if (found != debugLocations_.end()) return found->second;
    const auto id = debugNode("!DILocation(line: " + std::to_string(location.line) +
                              ", column: " + std::to_string(location.column) +
                              ", scope: " + scope + ")");
    debugLocations_.emplace(key, id);
    return id;
}

std::string CodeGenerator::debugDeclaration(const std::string& name,
                                            const std::string& type,
                                            const std::string& pointer,
                                            const SourceLocation& location,
                                            unsigned argument) {
    if (!debug_) return {};
    const auto file = debugFile(location.file);
    const auto variable = debugNode("!DILocalVariable(name: " + debugQuote(name) +
        ", arg: " + std::to_string(argument) + ", scope: " + debugSubprogram_ +
        ", file: " + file + ", line: " + std::to_string(location.line) +
        ", type: " + debugType(type) + ")");
    return "  call void @llvm.dbg.declare(metadata ptr " + pointer +
           ", metadata " + variable + ", metadata !DIExpression())\n";
}

std::string CodeGenerator::debugAnnotate(const std::string& body,
                                         const SourceLocation& fallback) {
    if (!debug_) return body;
    std::istringstream input(body);
    std::string result;
    std::string line;
    auto location = debugLocation(fallback);
    while (std::getline(input, line)) {
        constexpr char marker[] = "; cwhip.debug.location ";
        if (line.compare(0, sizeof(marker) - 1, marker) == 0) {
            location = line.substr(sizeof(marker) - 1);
            continue;
        }
        if (line.compare(0, 2, "  ") == 0 && !line.empty() &&
            line.find_first_not_of(' ') != std::string::npos) {
            line += ", !dbg " + location;
        }
        result += line + "\n";
    }
    return result;
}

void CodeGenerator::debugMetadata(const SourceLocation& source) {
    if (!debug_) return;
    const auto file = debugFile(source.file);
    debugUnit_ = debugNode("distinct !DICompileUnit(language: DW_LANG_C, file: " +
                          file + ", producer: \"cwhip\", isOptimized: false, runtimeVersion: 0, emissionKind: FullDebug)");
}

} // namespace cwhip
