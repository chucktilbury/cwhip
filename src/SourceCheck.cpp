/**
 * @file SourceCheck.cpp
 * @brief In-memory frontend check shared by the compiler driver and language server.
 */
#include "cwhip/SourceCheck.hpp"

#include "cwhip/ModuleRegistry.hpp"
#include "cwhip/Parser.hpp"
#include "cwhip/PathResolution.hpp"
#include "cwhip/SemanticAnalyzer.hpp"
#include "cwhip/SourceLoader.hpp"
#include "cwhip/Token.hpp"

#include <exception>
#include <unordered_set>
#include <utility>

namespace cwhip {

void checkSource(const std::filesystem::path& path, const std::string& text,
                 DiagnosticList& diagnostics) {
    const std::string name = path.empty() ? std::string("untitled.cw") : path.string();
    try {
        std::unordered_set<std::string> includedFiles;
        auto tokens = tokenizeWithIncludes(text, name, includedFiles, 0, true);
        tokens.push_back({TokenType::End, "", {name, 1, 1}});
        Parser parser(std::move(tokens));
        parser.setDiagnostics(&diagnostics);
        Program program = parser.parseProgram(false);
        if (!program.imports.empty()) {
            ModuleSearchRequest request;
            request.sourcePaths.push_back(name);
            std::error_code error;
            const auto parent = std::filesystem::absolute(path, error).parent_path();
            request.currentDirectory = parent.empty() ? std::filesystem::current_path() : parent;
            const auto& resources = processResourcePaths();
            const auto moduleSearchPaths =
                resolveModuleSearchPaths(request, resources, processEnvironment);
            validateModuleSearchPaths(moduleSearchPaths);
            ModuleLoadOptions moduleOptions;
            moduleOptions.packageSearchRoots = moduleSearchPaths.packageRoots();
            moduleOptions.projectLockFile = moduleSearchPaths.projectLockFile.path;
            loadImportedModules(program, moduleOptions);
        }
        SemanticAnalyzer semanticAnalyzer;
        semanticAnalyzer.setBuiltinSource(processResourcePaths().builtinSource);
        semanticAnalyzer.setDiagnostics(&diagnostics);
        semanticAnalyzer.analyze(program);
    } catch (const DiagnosticError& error) {
        if (!diagnostics.full()) diagnostics.add(error);
    } catch (const std::exception& error) {
        if (!diagnostics.full()) {
            diagnostics.add(DiagnosticError({name, 1, 1}, error.what()));
        }
    }
}

} // namespace cwhip
