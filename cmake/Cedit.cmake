set(CEDIT_EXECUTABLE "${CWHIP_RUNTIME_OUTPUT_DIRECTORY}/cedit${CMAKE_EXECUTABLE_SUFFIX}")
set(CEDIT_BINARY "${CWHIP_RUNTIME_OUTPUT_DIRECTORY}/cedit.bin")
if(NOT CWHIP_GTK_SOURCEVIEW)
    add_custom_target(cedit
        COMMAND "${CMAKE_COMMAND}" -P "${CMAKE_CURRENT_LIST_DIR}/CeditUnavailable.cmake"
        VERBATIM)
    message(STATUS "cedit unavailable: requires CWHIP_GTK=ON and CWHIP_GTK_SOURCEVIEW=ON with GTK 4 and GtkSourceView 5 development files")
    return()
endif()

set(cedit_source "${CMAKE_CURRENT_SOURCE_DIR}/../examples/editor")
set(cedit_project "${CMAKE_CURRENT_BINARY_DIR}/cedit-project")
file(GLOB_RECURSE cedit_inputs CONFIGURE_DEPENDS "${cedit_source}/*")
file(MAKE_DIRECTORY "${cedit_project}/modules"
    "${cedit_project}/home" "${cedit_project}/xdg")
# Use only this build's resources and package roots, never user overrides.
set(cedit_environment
    "${CMAKE_COMMAND}" -E env
    --unset=CWHIP_PACKAGE_PATH --unset=CWHIP_MODULE_REGISTRY --unset=CWHIP_MODULE_DIR
    --unset=DESTDIR
    "HOME=${cedit_project}/home" "XDG_CONFIG_HOME=${cedit_project}/xdg"
    "CWHIP_HOME=${CWHIP_STAGE_PREFIX}"
    "CWHIP_RUNTIME_DIR=${CWHIP_STAGE_RUNTIME_DIRECTORY}"
    "CWHIP_INCLUDE_DIR=${CWHIP_STAGE_PREFIX}/${CWHIP_RELATIVE_INCLUDEDIR}"
    "CWHIP_BUILTIN_DIR=${CWHIP_STAGE_BUILTIN_DIRECTORY}"
    "CWHIP_STDLIB_MODULE_DIR=${CWHIP_STAGE_MODULE_DIRECTORY}"
    "CC=${CWHIP_CLANG_EXECUTABLE}")
add_custom_command(
    OUTPUT "${cedit_project}/cwhip-pkg.toml" "${cedit_project}/cwhip-pkg.lock"
    COMMAND "${CMAKE_COMMAND}" -E remove -f
        "${cedit_project}/cwhip-pkg.toml" "${cedit_project}/cwhip-pkg.lock"
    COMMAND ${cedit_environment} "${Python3_EXECUTABLE}"
        "${CWHIP_RUNTIME_OUTPUT_DIRECTORY}/cwhip-pkg" init "${cedit_project}"
    DEPENDS cwhip_resources "${CWHIP_RESOURCE_STAMP}"
        "${CMAKE_CURRENT_LIST_FILE}"
        "${CWHIP_RUNTIME_OUTPUT_DIRECTORY}/cwhip-pkg"
        "$<TARGET_FILE:cwhip_sqlite_native>" "$<TARGET_FILE:cwhip_gtk_native>"
    COMMENT "Locking cedit's staged standard packages"
    VERBATIM)
add_custom_command(
    OUTPUT "${CEDIT_BINARY}"
    COMMAND "${CMAKE_COMMAND}" -E copy_directory
        "${cedit_source}" "${cedit_project}/editor"
    COMMAND ${cedit_environment} "$<TARGET_FILE:cwhip>"
        "${cedit_project}/editor/cedit.cw"
        -M "${CWHIP_STAGE_MODULE_DIRECTORY}" -o "${CEDIT_BINARY}"
    DEPENDS cwhip cwhip_runtime cwhip_resources
        "${CMAKE_CURRENT_LIST_FILE}"
        "$<TARGET_FILE:cwhip_runtime>" "$<TARGET_FILE:cwhip_gtk_native>"
        "$<TARGET_FILE:cwhip_sqlite_native>"
        "${CWHIP_RESOURCE_STAMP}" ${cedit_inputs}
        "${cedit_project}/cwhip-pkg.toml" "${cedit_project}/cwhip-pkg.lock"
    COMMENT "Building cedit"
    VERBATIM)
add_executable(cedit_launcher EXCLUDE_FROM_ALL "${cedit_source}/launcher.c")
set_target_properties(cedit_launcher PROPERTIES
    OUTPUT_NAME cedit
    RUNTIME_OUTPUT_DIRECTORY "${CWHIP_RUNTIME_OUTPUT_DIRECTORY}")
add_custom_target(cedit DEPENDS cedit_launcher "${CEDIT_BINARY}")
set_property(TARGET cedit PROPERTY CEDIT_EXECUTABLE "${CEDIT_EXECUTABLE}")
