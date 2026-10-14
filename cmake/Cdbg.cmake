set(CDBG_EXECUTABLE "${CWHIP_RUNTIME_OUTPUT_DIRECTORY}/cdbg${CMAKE_EXECUTABLE_SUFFIX}")
if(NOT CWHIP_GTK_SOURCEVIEW)
    add_custom_target(cdbg
        COMMAND "${CMAKE_COMMAND}" -P "${CMAKE_CURRENT_LIST_DIR}/CdbgUnavailable.cmake"
        VERBATIM)
    return()
endif()

set(cdbg_source "${CMAKE_CURRENT_SOURCE_DIR}/../tools/cdbg")
set(cdbg_project "${CMAKE_CURRENT_BINARY_DIR}/cdbg-project")
file(GLOB_RECURSE cdbg_inputs CONFIGURE_DEPENDS "${cdbg_source}/*")
file(MAKE_DIRECTORY "${cdbg_project}/home" "${cdbg_project}/xdg")
add_library(cdbg_terminal OBJECT EXCLUDE_FROM_ALL "${cdbg_source}/terminal.c")
add_custom_command(
    OUTPUT "${cdbg_project}/values.h"
    COMMAND "${Python3_EXECUTABLE}" "${cdbg_source}/embed_values.py"
        "${cdbg_source}/values.py" "${cdbg_project}/values.h"
    DEPENDS "${cdbg_source}/embed_values.py" "${cdbg_source}/values.py"
    VERBATIM)
target_sources(cdbg_terminal PRIVATE "${cdbg_project}/values.h")
target_include_directories(cdbg_terminal PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/../include" "${cdbg_project}")
set(cdbg_environment
    "${CMAKE_COMMAND}" -E env
    --unset=CWHIP_PACKAGE_PATH --unset=CWHIP_MODULE_REGISTRY --unset=CWHIP_MODULE_DIR
    --unset=DESTDIR
    "HOME=${cdbg_project}/home" "XDG_CONFIG_HOME=${cdbg_project}/xdg"
    "CWHIP_HOME=${CWHIP_STAGE_PREFIX}"
    "CWHIP_RUNTIME_DIR=${CWHIP_STAGE_RUNTIME_DIRECTORY}"
    "CWHIP_INCLUDE_DIR=${CWHIP_STAGE_PREFIX}/${CWHIP_RELATIVE_INCLUDEDIR}"
    "CWHIP_BUILTIN_DIR=${CWHIP_STAGE_BUILTIN_DIRECTORY}"
    "CWHIP_STDLIB_MODULE_DIR=${CWHIP_STAGE_MODULE_DIRECTORY}"
    "CC=${CWHIP_CLANG_EXECUTABLE}")
add_custom_command(
    OUTPUT "${cdbg_project}/cwhip-pkg.toml" "${cdbg_project}/cwhip-pkg.lock"
    COMMAND "${CMAKE_COMMAND}" -E remove -f
        "${cdbg_project}/cwhip-pkg.toml" "${cdbg_project}/cwhip-pkg.lock"
    COMMAND ${cdbg_environment} "${Python3_EXECUTABLE}"
        "${CWHIP_RUNTIME_OUTPUT_DIRECTORY}/cwhip-pkg" init "${cdbg_project}"
    DEPENDS cwhip_resources "${CWHIP_RESOURCE_STAMP}"
        "${CMAKE_CURRENT_LIST_FILE}" "${CWHIP_RUNTIME_OUTPUT_DIRECTORY}/cwhip-pkg"
        "$<TARGET_FILE:cwhip_sqlite_native>" "$<TARGET_FILE:cwhip_gtk_native>"
    COMMENT "Locking cdbg's staged standard packages"
    VERBATIM)
add_custom_command(
    OUTPUT "${CDBG_EXECUTABLE}"
    COMMAND "${CMAKE_COMMAND}" -E copy_directory "${cdbg_source}" "${cdbg_project}/debugger"
    COMMAND ${cdbg_environment} "$<TARGET_FILE:cwhip>"
        "${cdbg_project}/debugger/cdbg.cw"
        -M "${CWHIP_STAGE_MODULE_DIRECTORY}" -o "${CDBG_EXECUTABLE}"
        $<TARGET_OBJECTS:cdbg_terminal>
    DEPENDS cwhip cwhip_runtime cwhip_resources cdbg_terminal "${CMAKE_CURRENT_LIST_FILE}"
        $<TARGET_OBJECTS:cdbg_terminal>
        "$<TARGET_FILE:cwhip_runtime>" "$<TARGET_FILE:cwhip_gtk_native>"
        "${CWHIP_RESOURCE_STAMP}" ${cdbg_inputs}
        "${cdbg_project}/cwhip-pkg.toml" "${cdbg_project}/cwhip-pkg.lock"
    COMMENT "Building cdbg"
    VERBATIM)
add_custom_target(cdbg DEPENDS "${CDBG_EXECUTABLE}")
set_property(TARGET cdbg PROPERTY CDBG_EXECUTABLE "${CDBG_EXECUTABLE}")
