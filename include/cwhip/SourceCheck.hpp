/**
 * @file SourceCheck.hpp
 * @brief Parse and check one in-memory Cwhip translation unit.
 */
#pragma once

#include "cwhip/Diagnostic.hpp"

#include <filesystem>
#include <string>

namespace cwhip {

/// Checks `text` as the contents of `path`. Recoverable errors are appended to
/// `diagnostics`. A missing `start` block is allowed so an editor can check a
/// fragment. Imports are loaded from the project and SDK that contain `path`.
void checkSource(const std::filesystem::path& path, const std::string& text,
                 DiagnosticList& diagnostics);

} // namespace cwhip
