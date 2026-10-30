include_guard(GLOBAL)

function(_cwhip_collect_sources directory output)
    file(GLOB entries LIST_DIRECTORIES TRUE CONFIGURE_DEPENDS "${directory}/*")
    set(result)
    foreach(entry IN LISTS entries)
        cmake_path(IS_PREFIX CMAKE_BINARY_DIR "${entry}" NORMALIZE generated)
        if(generated OR entry MATCHES "/\\.git(/|$)")
            continue()
        endif()
        if(IS_DIRECTORY "${entry}")
            if(NOT IS_SYMLINK "${entry}" AND NOT EXISTS "${entry}/CMakeCache.txt")
                _cwhip_collect_sources("${entry}" children)
                list(APPEND result ${children})
            endif()
        else()
            list(APPEND result "${entry}")
        endif()
    endforeach()
    set(${output} "${result}" PARENT_SCOPE)
endfunction()

# The prototype SDK is exact-versioned until its language/runtime ABI stabilizes.
function(cwhip_add_program target)
    cmake_parse_arguments(APP "" "SOURCE;OUTPUT_NAME;OUTPUT_DIRECTORY" "OBJECTS;DEPENDS" ${ARGN})
    if(APP_UNPARSED_ARGUMENTS OR APP_KEYWORDS_MISSING_VALUES)
        message(FATAL_ERROR "Invalid cwhip_add_program arguments: ${ARGN}")
    endif()
    if(NOT APP_SOURCE)
        message(FATAL_ERROR "cwhip_add_program(${target}) requires SOURCE")
    endif()
    if(NOT APP_OUTPUT_NAME)
        set(APP_OUTPUT_NAME "${target}")
    endif()
    get_filename_component(source "${APP_SOURCE}" ABSOLUTE)
    get_filename_component(source_dir "${source}" DIRECTORY)
    get_filename_component(source_name "${source}" NAME)
    if(CMAKE_SOURCE_DIR STREQUAL CMAKE_BINARY_DIR)
        message(FATAL_ERROR "Cwhip applications require an out-of-source CMake build")
    endif()
    cmake_path(IS_PREFIX CMAKE_BINARY_DIR "${source}" NORMALIZE generated_source)
    if(generated_source OR NOT EXISTS "${source}")
        message(FATAL_ERROR "cwhip_add_program requires an existing source file outside the binary tree: ${source}")
    endif()
    if(APP_OUTPUT_DIRECTORY)
        get_filename_component(output_directory "${APP_OUTPUT_DIRECTORY}" ABSOLUTE
            BASE_DIR "${CMAKE_CURRENT_BINARY_DIR}")
    else()
        set(output_directory "${CMAKE_CURRENT_BINARY_DIR}/bin")
    endif()
    set(work "${CMAKE_CURRENT_BINARY_DIR}/${target}-project")
    set(output "${output_directory}/${APP_OUTPUT_NAME}")
    file(MAKE_DIRECTORY "${work}/home" "${work}/xdg" "${work}/data"
        "${work}/cache" "${work}/state" "${work}/modules")
    _cwhip_collect_sources("${source_dir}" inputs)
    file(GLOB_RECURSE sdk_inputs CONFIGURE_DEPENDS
        "${Cwhip_INCLUDE_DIR}/*" "${Cwhip_MODULE_DIR}/*" "${Cwhip_BUILTIN_DIR}/*")
    file(GENERATE OUTPUT "${work}/inputs.txt" CONTENT "${inputs}\n${sdk_inputs}\n")
    file(GENERATE OUTPUT "${work}/source-inputs.cmake" CONTENT "set(inputs [==[${inputs}]==])\n")
    set(stage_sources "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/CwhipStageSources.cmake")
    get_filename_component(runtime_dir "${Cwhip_RUNTIME_LIBRARY}" DIRECTORY)
    set(environment "${CMAKE_COMMAND}" -E env
        --unset=CWHIP_MODULE_DIR --unset=CWHIP_PACKAGE_PATH --unset=CWHIP_MODULE_REGISTRY
        --unset=DESTDIR --unset=XDG_RUNTIME_DIR
        "HOME=${work}/home" "XDG_CONFIG_HOME=${work}/xdg" "PYTHONDONTWRITEBYTECODE=1"
        "XDG_DATA_HOME=${work}/data" "XDG_CACHE_HOME=${work}/cache"
        "XDG_STATE_HOME=${work}/state"
        "CWHIP_HOME=${Cwhip_PREFIX}"
        "CWHIP_INCLUDE_DIR=${Cwhip_INCLUDE_DIR}"
        "CWHIP_RUNTIME_DIR=${runtime_dir}"
        "CWHIP_BUILTIN_DIR=${Cwhip_BUILTIN_DIR}"
        "CWHIP_STDLIB_MODULE_DIR=${Cwhip_MODULE_DIR}" "CC=${Cwhip_CLANG_EXECUTABLE}")
    add_custom_command(OUTPUT "${work}/cwhip-pkg.toml" "${work}/cwhip-pkg.lock"
        COMMAND "${CMAKE_COMMAND}" -E make_directory "${work}/home" "${work}/xdg"
            "${work}/data" "${work}/cache" "${work}/state" "${work}/modules"
        COMMAND "${CMAKE_COMMAND}" -E rm -f "${work}/cwhip-pkg.toml" "${work}/cwhip-pkg.lock"
        COMMAND ${environment} "${Python3_EXECUTABLE}" "${Cwhip_PACKAGE_TOOL}" init "${work}"
        DEPENDS "${Cwhip_PACKAGE_TOOL}" ${sdk_inputs} "${work}/inputs.txt"
        VERBATIM)
    # Match CMAKE_BUILD_TYPE so Debug/RelWithDebInfo apps get DWARF for .cw
    # sources. Without -g, only linked C libraries have debug info and cdbg
    # opens Runtime*.c / gtk.c instead of the program's Cwhip sources.
    set(_cwhip_debug_flags)
    string(TOUPPER "${CMAKE_BUILD_TYPE}" _cwhip_build_type_upper)
    if(_cwhip_build_type_upper STREQUAL "DEBUG" OR
       _cwhip_build_type_upper STREQUAL "RELWITHDEBINFO")
        set(_cwhip_debug_flags -g)
    endif()
    add_custom_command(OUTPUT "${output}"
        COMMAND "${CMAKE_COMMAND}" -E make_directory "${output_directory}"
        COMMAND "${CMAKE_COMMAND}" "-Dsource_dir=${source_dir}"
            "-Doutput_dir=${work}/src" "-Dinventory=${work}/source-inputs.cmake"
            -P "${stage_sources}"
        COMMAND ${environment} "${Cwhip_COMPILER}" "${work}/src/${source_name}"
            -M "${Cwhip_MODULE_DIR}" ${_cwhip_debug_flags} -o "${output}" ${APP_OBJECTS}
        DEPENDS "${Cwhip_COMPILER}" "${Cwhip_RUNTIME_LIBRARY}" ${sdk_inputs}
            ${inputs} "${work}/inputs.txt" "${work}/source-inputs.cmake"
            "${stage_sources}" ${APP_OBJECTS} ${APP_DEPENDS}
            "${work}/cwhip-pkg.toml" "${work}/cwhip-pkg.lock"
        WORKING_DIRECTORY "${work}" COMMAND_EXPAND_LISTS VERBATIM)
    add_custom_target(${target} ALL DEPENDS "${output}")
    if(TARGET cwhip_language_resources)
        add_dependencies(${target} cwhip_language_resources)
    endif()
    set_property(TARGET ${target} PROPERTY CWHIP_EXECUTABLE "${output}")
    set_property(DIRECTORY APPEND PROPERTY ADDITIONAL_CLEAN_FILES
        "${work}/src" "${work}/home" "${work}/xdg" "${work}/data"
        "${work}/cache" "${work}/state" "${work}/modules")
endfunction()

function(cwhip_require_sourceview)
    cmake_parse_arguments(SOURCEVIEW "" "RESOURCE_DIRECTORY" "" ${ARGN})
    if(SOURCEVIEW_UNPARSED_ARGUMENTS OR SOURCEVIEW_KEYWORDS_MISSING_VALUES)
        message(FATAL_ERROR "Invalid cwhip_require_sourceview arguments: ${ARGN}")
    endif()
    if(NOT Cwhip_GTK OR NOT Cwhip_SOURCEVIEW)
        message(FATAL_ERROR "This application requires a Cwhip SDK built with GTK 4 >= 4.10 and GtkSourceView 5")
    endif()
    find_package(PkgConfig REQUIRED)
    pkg_check_modules(CWHIP_APP_GTK REQUIRED "gtk4>=4.10" gtksourceview-5)
    foreach(resource "gtk/0.1.0/lib/libcwhip_gtk.a"
                     "sourceview/0.1.0/language-specs/cwhip.lang")
        if(NOT EXISTS "${Cwhip_MODULE_DIR}/${resource}")
            message(FATAL_ERROR "Incomplete Cwhip GUI SDK: missing ${resource}")
        endif()
    endforeach()
    set(languages "${Cwhip_MODULE_DIR}/sourceview/0.1.0/language-specs")
    file(GLOB language_inputs CONFIGURE_DEPENDS "${languages}/*")
    if(SOURCEVIEW_RESOURCE_DIRECTORY)
        get_filename_component(language_output "${SOURCEVIEW_RESOURCE_DIRECTORY}" ABSOLUTE
            BASE_DIR "${CMAKE_CURRENT_BINARY_DIR}")
    else()
        set(language_output
            "${CMAKE_CURRENT_BINARY_DIR}/share/cwhip/modules/sourceview/0.1.0/language-specs")
    endif()
    add_custom_command(OUTPUT "${language_output}/cwhip.lang"
        COMMAND "${CMAKE_COMMAND}" -E make_directory "${language_output}"
        COMMAND "${CMAKE_COMMAND}" -E copy_directory "${languages}" "${language_output}"
        DEPENDS ${language_inputs} VERBATIM)
    add_custom_target(cwhip_language_resources ALL DEPENDS "${language_output}/cwhip.lang")
    set_property(DIRECTORY APPEND PROPERTY ADDITIONAL_CLEAN_FILES
        "${language_output}")
    install(DIRECTORY "${languages}" DESTINATION "share/cwhip/modules/sourceview/0.1.0")
endfunction()
