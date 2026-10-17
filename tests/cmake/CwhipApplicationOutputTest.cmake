foreach(required IN ITEMS SOURCE_DIR WORK_DIR HELPER COMPILER PACKAGE_TOOL
        RUNTIME_LIBRARY STAGE_PREFIX INCLUDE_DIR BUILTIN_DIR MODULE_DIR
        HAS_SOURCEVIEW CLANG)
    if(NOT DEFINED ${required})
        message(FATAL_ERROR "Missing ${required}")
    endif()
endforeach()

set(project_dir "${WORK_DIR}/project")
set(build_dir "${WORK_DIR}/build with spaces")
file(REMOVE_RECURSE "${WORK_DIR}")
file(MAKE_DIRECTORY "${project_dir}")
file(WRITE "${project_dir}/CMakeLists.txt" [=[
cmake_minimum_required(VERSION 3.16)
project(cwhip_application_output_test NONE)
find_package(Python3 3.11 REQUIRED COMPONENTS Interpreter)
include("${HELPER}")
set(Cwhip_PREFIX "${STAGE_PREFIX}")
set(Cwhip_COMPILER "${COMPILER}")
set(Cwhip_PACKAGE_TOOL "${PACKAGE_TOOL}")
set(Cwhip_RUNTIME_LIBRARY "${RUNTIME_LIBRARY}")
set(Cwhip_INCLUDE_DIR "${INCLUDE_DIR}")
set(Cwhip_BUILTIN_DIR "${BUILTIN_DIR}")
set(Cwhip_MODULE_DIR "${MODULE_DIR}")
set(Cwhip_CLANG_EXECUTABLE "${CLANG}")
cwhip_add_program(overridden SOURCE "${SOURCE_DIR}/tests/cmake/application_output/program.cw"
    OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/application/bin")
cwhip_add_program(default_bin SOURCE "${SOURCE_DIR}/tests/cmake/application_output/program.cw")
if(HAS_SOURCEVIEW)
    set(Cwhip_GTK TRUE)
    set(Cwhip_SOURCEVIEW TRUE)
    cwhip_require_sourceview(RESOURCE_DIRECTORY
        "${CMAKE_CURRENT_BINARY_DIR}/application/bin/../share/cwhip/modules/sourceview/0.1.0/language-specs")
endif()
get_target_property(overridden_path overridden CWHIP_EXECUTABLE)
get_target_property(default_path default_bin CWHIP_EXECUTABLE)
if(NOT overridden_path STREQUAL "${CMAKE_CURRENT_BINARY_DIR}/application/bin/overridden")
    message(FATAL_ERROR "Unexpected overridden output path: ${overridden_path}")
endif()
if(NOT default_path STREQUAL "${CMAKE_CURRENT_BINARY_DIR}/bin/default_bin")
    message(FATAL_ERROR "Unexpected default output path: ${default_path}")
endif()
if(EXISTS "${CMAKE_CURRENT_BINARY_DIR}/application/bin"
   OR EXISTS "${CMAKE_CURRENT_BINARY_DIR}/bin"
   OR EXISTS "${CMAKE_CURRENT_BINARY_DIR}/application/share")
    message(FATAL_ERROR "Application output directories were created during configure")
endif()
install(PROGRAMS "${overridden_path}" DESTINATION bin)
]=])

execute_process(
    COMMAND "${CMAKE_COMMAND}" -S "${project_dir}" -B "${build_dir}"
        "-DHELPER=${HELPER}" "-DSOURCE_DIR=${SOURCE_DIR}"
        "-DSTAGE_PREFIX=${STAGE_PREFIX}" "-DCOMPILER=${COMPILER}"
        "-DPACKAGE_TOOL=${PACKAGE_TOOL}" "-DRUNTIME_LIBRARY=${RUNTIME_LIBRARY}"
        "-DINCLUDE_DIR=${INCLUDE_DIR}" "-DBUILTIN_DIR=${BUILTIN_DIR}"
        "-DMODULE_DIR=${MODULE_DIR}" "-DHAS_SOURCEVIEW=${HAS_SOURCEVIEW}"
        "-DCMAKE_INSTALL_PREFIX=${WORK_DIR}/install with spaces"
        "-DCLANG=${CLANG}"
    RESULT_VARIABLE configure_result
    OUTPUT_VARIABLE configure_output
    ERROR_VARIABLE configure_error)
if(NOT configure_result EQUAL 0)
    message(FATAL_ERROR "Application output configure failed:\n${configure_output}${configure_error}")
endif()
if(EXISTS "${build_dir}/application/bin" OR EXISTS "${build_dir}/bin"
   OR EXISTS "${build_dir}/application/share")
    message(FATAL_ERROR "Application output directories were created during configure")
endif()

execute_process(
    COMMAND "${CMAKE_COMMAND}" --build "${build_dir}" --parallel 2
    RESULT_VARIABLE build_result
    OUTPUT_VARIABLE build_output
    ERROR_VARIABLE build_error)
if(NOT build_result EQUAL 0)
    message(FATAL_ERROR "Application output build failed:\n${build_output}${build_error}")
endif()
foreach(output IN ITEMS "${build_dir}/application/bin/overridden" "${build_dir}/bin/default_bin")
    if(NOT EXISTS "${output}")
        message(FATAL_ERROR "Expected built executable is missing: ${output}")
    endif()
    execute_process(COMMAND "${output}"
        RESULT_VARIABLE run_result
        OUTPUT_VARIABLE run_output
        ERROR_VARIABLE run_error
        OUTPUT_STRIP_TRAILING_WHITESPACE)
    if(NOT run_result EQUAL 0 OR NOT run_output STREQUAL "42")
        message(FATAL_ERROR "Built executable failed (${output}): ${run_output}${run_error}")
    endif()
endforeach()

execute_process(
    COMMAND "${CMAKE_COMMAND}" --build "${build_dir}" --parallel 2
    RESULT_VARIABLE noop_result
    OUTPUT_VARIABLE noop_output
    ERROR_VARIABLE noop_error)
if(NOT noop_result EQUAL 0)
    message(FATAL_ERROR "No-op application rebuild failed:\n${noop_output}${noop_error}")
endif()
if(noop_output MATCHES "Generating|Building|Linking|Copying")
    message(FATAL_ERROR "A no-op application rebuild unexpectedly regenerated outputs:\n${noop_output}")
endif()

if(HAS_SOURCEVIEW)
    set(resource_file
        "${build_dir}/application/share/cwhip/modules/sourceview/0.1.0/language-specs/cwhip.lang")
    if(NOT EXISTS "${resource_file}")
        message(FATAL_ERROR "Expected GUI sidecar resource is missing: ${resource_file}")
    endif()
endif()

execute_process(
    COMMAND "${CMAKE_COMMAND}" --install "${build_dir}"
    RESULT_VARIABLE install_result
    OUTPUT_VARIABLE install_output
    ERROR_VARIABLE install_error)
if(NOT install_result EQUAL 0)
    message(FATAL_ERROR "Application install failed:\n${install_output}${install_error}")
endif()
if(NOT EXISTS "${WORK_DIR}/install with spaces/bin/overridden")
    message(FATAL_ERROR "Installed application executable is missing")
endif()
if(HAS_SOURCEVIEW AND NOT EXISTS
   "${WORK_DIR}/install with spaces/share/cwhip/modules/sourceview/0.1.0/language-specs/cwhip.lang")
    message(FATAL_ERROR "Installed GUI sidecar resource is missing")
endif()

execute_process(
    COMMAND "${CMAKE_COMMAND}" --build "${build_dir}" --target clean
    RESULT_VARIABLE clean_result
    OUTPUT_VARIABLE clean_output
    ERROR_VARIABLE clean_error)
if(NOT clean_result EQUAL 0)
    message(FATAL_ERROR "Application clean failed:\n${clean_output}${clean_error}")
endif()
foreach(output IN ITEMS "${build_dir}/application/bin/overridden" "${build_dir}/bin/default_bin")
    if(EXISTS "${output}")
        message(FATAL_ERROR "Clean left generated application output: ${output}")
    endif()
endforeach()
if(HAS_SOURCEVIEW AND EXISTS
   "${build_dir}/application/share/cwhip/modules/sourceview/0.1.0/language-specs")
    message(FATAL_ERROR "Clean left generated GUI sidecar resources")
endif()
