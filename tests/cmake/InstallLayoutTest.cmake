# Installs the configured build into a temporary prefix, then compiles and runs
# a package-importing fixture with only the installed compiler and resources.
foreach(required IN ITEMS BUILD_DIR SOURCE_DIR FIXTURE MODULE_FIXTURE EXPECTED_OUTPUT_FILE
        BINDIR LIBDIR INCLUDEDIR DATADIR DOCDIR MANDIR RUNTIME_LIBRARY_NAME CLANG)
    if(NOT DEFINED ${required})
        message(FATAL_ERROR "${required} is required")
    endif()
endforeach()

include("${CMAKE_CURRENT_LIST_DIR}/InstallLayoutPaths.cmake")

if(DEFINED ENV{TMPDIR} AND IS_DIRECTORY "$ENV{TMPDIR}")
    set(temporary_root "$ENV{TMPDIR}")
else()
    set(temporary_root "/tmp")
endif()
get_filename_component(temporary_root "${temporary_root}" REALPATH)
string(RANDOM LENGTH 12 random_suffix)
set(work_directory "${temporary_root}/cwhip-install-test-${random_suffix}")
require_external_install_directory("${work_directory}")
if(EXISTS "${work_directory}" OR IS_SYMLINK "${work_directory}")
    message(FATAL_ERROR "Install test work directory already exists: ${work_directory}")
endif()
file(MAKE_DIRECTORY "${work_directory}")

set(clean_environment
    --unset=CWHIP_SDK --unset=CWHIP_HOME --unset=CWHIP_RUNTIME_DIR --unset=CWHIP_INCLUDE_DIR
    --unset=CWHIP_BUILTIN_DIR --unset=CWHIP_STDLIB_MODULE_DIR --unset=CWHIP_MODULE_DIR
    --unset=CWHIP_PACKAGE_PATH --unset=CWHIP_MODULE_REGISTRY --unset=DESTDIR
    "HOME=${work_directory}/home" "XDG_CONFIG_HOME=${work_directory}/xdg")
file(MAKE_DIRECTORY "${work_directory}/home" "${work_directory}/xdg")

function(run_checked description)
    execute_process(COMMAND ${ARGN}
        WORKING_DIRECTORY "${work_directory}"
        RESULT_VARIABLE result OUTPUT_VARIABLE stdout ERROR_VARIABLE stderr)
    if(NOT result EQUAL 0)
        message(FATAL_ERROR "${description} failed (${result}):\n${stdout}${stderr}")
    endif()
    set(last_output "${stdout}${stderr}" PARENT_SCOPE)
endfunction()

function(require_installed_layout prefix)
    foreach(application IN ITEMS cedit cedit.bin cdbg)
        if(EXISTS "${prefix}/${BINDIR}/${application}")
            message(FATAL_ERROR "SDK must not install standalone application: ${application}")
        endif()
    endforeach()
    foreach(installed_file IN ITEMS
            "${BINDIR}/cwhip"
            "${BINDIR}/cwhip-pkg"
            "${LIBDIR}/cwhip/${RUNTIME_LIBRARY_NAME}"
            "${INCLUDEDIR}/cwhip/RuntimeGc.h"
            "${INCLUDEDIR}/cwhip/Stdlib.h"
            "${INCLUDEDIR}/cwhip/RuntimeThreads.h"
            "${INCLUDEDIR}/cwhip/RuntimeDemoShims.h"
            "${DATADIR}/cwhip/builtin/String.cw"
            "${DOCDIR}/README.md"
            "${DOCDIR}/CWHIP-LANGUAGE-NOTES.md"
            "${DOCDIR}/doc/DIAGNOSTICS.md"
            "${MANDIR}/man1/cwhip.1")
        if(NOT EXISTS "${prefix}/${installed_file}")
            message(FATAL_ERROR "Install is missing ${prefix}/${installed_file}")
        endif()
    endforeach()
    foreach(notes IN ITEMS CWHIP-LANGUAGE-NOTES.md doc/CWHIP-LANGUAGE-NOTES.md)
        set(notes_path "${prefix}/${DOCDIR}/${notes}")
        file(READ "${notes_path}" notes_content)
        get_filename_component(notes_directory "${notes_path}" DIRECTORY)
        string(REGEX MATCHALL "\\]\\([^)#]+\\.md(#[^)]*)?\\)" links "${notes_content}")
        if(NOT links)
            message(FATAL_ERROR "Installed notes have no Markdown links: ${notes_path}")
        endif()
        foreach(link IN LISTS links)
            string(REGEX REPLACE "^\\]\\(([^)#]+).*" "\\1" target "${link}")
            if(NOT EXISTS "${notes_directory}/${target}")
                message(FATAL_ERROR "Broken installed documentation link: ${notes_path} -> ${target}")
            endif()
        endforeach()
    endforeach()
    if(NOT IS_DIRECTORY "${prefix}/${DATADIR}/cwhip/modules")
        message(FATAL_ERROR "Install is missing ${prefix}/${DATADIR}/cwhip/modules")
    endif()
    file(GLOB_RECURSE cwhip_files_under_include "${prefix}/${INCLUDEDIR}/*.cw")
    if(cwhip_files_under_include)
        message(FATAL_ERROR "Found .cw files installed under include: ${cwhip_files_under_include}")
    endif()
endfunction()

# DESTDIR staging must place every file below DESTDIR.
set(destdir "${work_directory}/destdir")
set(destdir_prefix "/opt/cwhip-install-test")
set(sdk_configuration "${work_directory}/xdg/cwhip/sdk.toml")
set(preferences "${work_directory}/xdg/cwhip/settings.toml")
file(MAKE_DIRECTORY "${work_directory}/xdg/cwhip")
set(original_preferences "# keep app preferences\nsdk_prefix = \"/legacy/sdk\"\n[editor]\nsize = 14\n")
file(WRITE "${preferences}" "${original_preferences}")
run_checked("DESTDIR install" "${CMAKE_COMMAND}" -E env ${clean_environment} "DESTDIR=${destdir}"
    "${CMAKE_COMMAND}" --install "${BUILD_DIR}" --prefix "${destdir_prefix}")
require_installed_layout("${destdir}${destdir_prefix}")
if(EXISTS "${sdk_configuration}")
    message(FATAL_ERROR "DESTDIR install registered an SDK")
endif()
if(EXISTS "${destdir_prefix}")
    message(FATAL_ERROR "DESTDIR install wrote outside DESTDIR: ${destdir_prefix}")
endif()

set(prefix "${work_directory}/prefix")
run_checked("install" "${CMAKE_COMMAND}" -E env ${clean_environment}
    "${CMAKE_COMMAND}" --install "${BUILD_DIR}" --prefix "${prefix}")
require_installed_layout("${prefix}")
if(REGISTER_SDK)
    file(READ "${sdk_configuration}" registration)
    string(REPLACE "\\" "\\\\" encoded_prefix "${prefix}")
    string(REPLACE "\"" "\\\"" encoded_prefix "${encoded_prefix}")
    string(CONCAT expected_registration
        "sdk_prefix = \"${encoded_prefix}\"\n\n[applications]\n"
        "install_prefix = \"${encoded_prefix}\"\nbuild_type = \"${BUILD_TYPE}\"\n")
    if(NOT registration STREQUAL expected_registration)
        message(FATAL_ERROR "Install did not register its --prefix in sdk.toml: ${registration}")
    endif()
elseif(EXISTS "${sdk_configuration}")
    message(FATAL_ERROR "CWHIP_REGISTER_SDK=OFF install registered an SDK")
endif()
file(READ "${preferences}" actual_preferences)
if(NOT actual_preferences STREQUAL original_preferences)
    message(FATAL_ERROR "Install changed app preferences")
endif()
if(NOT REGISTER_SDK)
    file(WRITE "${sdk_configuration}"
        "sdk_prefix = \"${prefix}\"\n\n[applications]\n"
        "install_prefix = \"${prefix}\"\nbuild_type = \"${BUILD_TYPE}\"\n")
endif()

# Discover the installed package and inherit its registered app defaults.
set(defaults_project "${work_directory}/application-defaults-project")
set(defaults_build "${work_directory}/application-defaults-build")
file(MAKE_DIRECTORY "${defaults_project}")
file(WRITE "${defaults_project}/CMakeLists.txt" [=[
cmake_minimum_required(VERSION 3.16)
find_package(Cwhip 0.0.2 EXACT CONFIG REQUIRED)
cwhip_apply_application_defaults()
project(installed_application_defaults C)
if(NOT "${CMAKE_INSTALL_PREFIX}" STREQUAL "${EXPECTED_INSTALL_PREFIX}")
    message(FATAL_ERROR
        "Unexpected inherited install prefix: ${CMAKE_INSTALL_PREFIX}; "
        "registered=${Cwhip_APPLICATION_INSTALL_PREFIX}, selected=${Cwhip_PREFIX}, "
        "default=${CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT}, "
        "build-type=${CMAKE_BUILD_TYPE}, env=$ENV{CMAKE_INSTALL_PREFIX}")
endif()
if(NOT "${CMAKE_BUILD_TYPE}" STREQUAL "${EXPECTED_BUILD_TYPE}")
    message(FATAL_ERROR "Unexpected inherited build type: ${CMAKE_BUILD_TYPE}")
endif()
if(NOT "${Cwhip_GTK}" STREQUAL "${EXPECTED_GTK}"
   OR NOT "${Cwhip_SOURCEVIEW}" STREQUAL "${EXPECTED_SOURCEVIEW}")
    message(FATAL_ERROR
        "Installed feature metadata differs: GTK=${Cwhip_GTK} (expected ${EXPECTED_GTK}), "
        "SOURCEVIEW=${Cwhip_SOURCEVIEW} (expected ${EXPECTED_SOURCEVIEW})")
endif()
]=])
run_checked("installed application defaults" "${CMAKE_COMMAND}"
    -E env ${clean_environment} "${CMAKE_COMMAND}"
    -S "${defaults_project}" -B "${defaults_build}"
    "-DCMAKE_PREFIX_PATH=${prefix}"
    "-DEXPECTED_INSTALL_PREFIX=${prefix}" "-DEXPECTED_BUILD_TYPE=${BUILD_TYPE}"
    "-DEXPECTED_GTK=${EXPECTED_GTK}" "-DEXPECTED_SOURCEVIEW=${EXPECTED_SOURCEVIEW}")

# Relocate the installed tree to prove nothing depends on the install prefix.
set(relocated_prefix "${work_directory}/relocated")
file(RENAME "${prefix}" "${relocated_prefix}")
require_installed_layout("${relocated_prefix}")
set(compiler "${relocated_prefix}/${BINDIR}/cwhip")
run_checked("installed cwhip version" "${compiler}" --version)
set(project_directory "${work_directory}/project")
file(MAKE_DIRECTORY "${project_directory}/modules")
file(WRITE "${project_directory}/canonical.cw" "start {}\n")
run_checked("installed .cw compilation" "${compiler}"
    "${project_directory}/canonical.cw" --check-only)
file(COPY "${MODULE_FIXTURE}/" DESTINATION "${project_directory}/modules")
get_filename_component(fixture_name "${FIXTURE}" NAME)
file(COPY "${FIXTURE}" DESTINATION "${project_directory}")

execute_process(
    COMMAND "${CMAKE_COMMAND}" -E env ${clean_environment} "${compiler}" --print-paths
    WORKING_DIRECTORY "${project_directory}"
    RESULT_VARIABLE print_result OUTPUT_VARIABLE print_output ERROR_VARIABLE print_error)
if(NOT print_result EQUAL 0)
    message(FATAL_ERROR "--print-paths failed (${print_result}):\n${print_error}")
endif()
string(REGEX REPLACE "([][+.*()^$?|\\\\{}])" "\\\\\\1" relocated_pattern "${relocated_prefix}")
if(NOT print_output MATCHES "prefix: ${relocated_pattern} \\(executable-relative\\)")
    message(FATAL_ERROR "Installed compiler did not derive its prefix:\n${print_output}")
endif()
if(print_output MATCHES
   "(runtime directory|runtime library|include directory|builtin directory|builtin source|standard modules): [^\n]*\\[not found\\]")
    message(FATAL_ERROR "Installed resources were not found:\n${print_output}")
endif()
string(FIND "${print_output}"
    "builtin directory: ${relocated_prefix}/${DATADIR}/cwhip/builtin (executable-relative)"
    builtin_directory_position)
string(FIND "${print_output}"
    "builtin source: ${relocated_prefix}/${DATADIR}/cwhip/builtin/String.cw"
    builtin_source_position)
if(builtin_directory_position EQUAL -1 OR builtin_source_position EQUAL -1)
    message(FATAL_ERROR "Installed builtin paths were not reported:\n${print_output}")
endif()
require_no_tree_references("${print_output}" "--print-paths")

# Compile the facade in isolation: no private headers are present on this path.
file(MAKE_DIRECTORY "${project_directory}/public/cwhip")
file(COPY "${relocated_prefix}/${INCLUDEDIR}/cwhip/Stdlib.h"
    DESTINATION "${project_directory}/public/cwhip")
file(COPY "${SOURCE_DIR}/tests/functional/cli/inline_stdlib.c"
    DESTINATION "${project_directory}")
set(instrumentation_flags)
if(COVERAGE)
    list(APPEND instrumentation_flags -fprofile-instr-generate -fcoverage-mapping)
endif()
if(SANITIZER_LIST)
    list(APPEND instrumentation_flags "-fsanitize=${SANITIZER_LIST}")
endif()
run_checked("standalone public C header"
    "${CLANG}" ${instrumentation_flags} -std=c11 -Wall -Wextra -Werror
    "-I${project_directory}/public" "${project_directory}/inline_stdlib.c"
    "${relocated_prefix}/${LIBDIR}/cwhip/${RUNTIME_LIBRARY_NAME}"
    -lm -pthread -o "${project_directory}/public-api")
run_checked("public C API executable" "${project_directory}/public-api")

set(executable "${project_directory}/installed-program")
execute_process(
    COMMAND "${CMAKE_COMMAND}" -E env ${clean_environment}
        "${compiler}" -vv "${fixture_name}" -o "${executable}"
    WORKING_DIRECTORY "${project_directory}"
    RESULT_VARIABLE compile_result OUTPUT_VARIABLE compile_stdout ERROR_VARIABLE compile_stderr)
if(NOT compile_result EQUAL 0)
    message(FATAL_ERROR "Installed compiler failed (${compile_result}):\n${compile_stderr}")
endif()
if(NOT compile_stderr MATCHES "\\[command\\] [^\n]*${relocated_pattern}/[^\n]*/cwhip/${RUNTIME_LIBRARY_NAME}")
    message(FATAL_ERROR "Installed compiler did not link the installed runtime:\n${compile_stderr}")
endif()
require_no_tree_references("${compile_stdout}${compile_stderr}" "Installed compilation")

execute_process(COMMAND "${executable}"
    RESULT_VARIABLE run_result OUTPUT_VARIABLE program_output ERROR_VARIABLE run_stderr)
file(READ "${EXPECTED_OUTPUT_FILE}" expected_output)
if(NOT run_result EQUAL 0 OR NOT program_output STREQUAL expected_output)
    message(FATAL_ERROR
        "Installed program returned ${run_result} with '${program_output}':\n${run_stderr}")
endif()

# Initialize a project using relocated standard modules, keeping String out of
# the package allowlist while exercising its automatic availability/inheritance.
set(string_project "${work_directory}/string-project")
run_checked("relocated cwhip-pkg init" "${CMAKE_COMMAND}" -E env ${clean_environment}
    "${relocated_prefix}/${BINDIR}/cwhip-pkg" init "${string_project}")
if(NOT EXISTS "${string_project}/cwhip-pkg.toml"
   OR EXISTS "${string_project}/modules/modules.toml")
    message(FATAL_ERROR "Initialized project did not use the manifest/lock workflow")
endif()
file(READ "${string_project}/cwhip-pkg.lock" lock)
if(NOT lock MATCHES "^schema = 1\n"
   OR NOT lock MATCHES "\n\\[modules\\]\n"
   OR NOT lock MATCHES "\nmath = \\[\"0.1.0\"\\]"
   OR NOT lock MATCHES "\nsystem = \\[\"0.1.0\"\\]"
   OR lock MATCHES "\nString[ \t]*="
   OR lock MATCHES "\n\\[packages\\.String\\]")
    message(FATAL_ERROR "Initialized lock did not lock standard modules without String:\n${lock}")
endif()
file(COPY "${SOURCE_DIR}/tests/functional/positive/positive_string_class.cw"
    DESTINATION "${string_project}")
set(string_source "${string_project}/positive_string_class.cw")
set(string_executable "${string_project}/string-program")
run_checked("installed String compilation" "${CMAKE_COMMAND}" -E env ${clean_environment}
    "${compiler}" "${string_source}" -o "${string_executable}")
run_checked("installed String executable" "${string_executable}")
file(READ "${SOURCE_DIR}/tests/cases/cwhip_compile_and_run_string_class.stdout"
    expected_string_output)
if(NOT last_output STREQUAL expected_string_output)
    message(FATAL_ERROR "Installed String output differs:\n${last_output}")
endif()

# Compile and run the asynchronous process consumer against only the relocated
# installation's public process package and runtime library.
set(process_project "${work_directory}/process-project")
file(MAKE_DIRECTORY "${process_project}")
file(COPY "${SOURCE_DIR}/tests/functional/positive/positive_stdlib_async_process.cw"
    DESTINATION "${process_project}")
set(process_executable "${process_project}/process-consumer")
execute_process(
    COMMAND "${CMAKE_COMMAND}" -E env ${clean_environment}
        "${compiler}" -vv positive_stdlib_async_process.cw -o "${process_executable}"
    WORKING_DIRECTORY "${process_project}"
    RESULT_VARIABLE process_compile_result OUTPUT_VARIABLE process_compile_stdout
    ERROR_VARIABLE process_compile_stderr)
if(NOT process_compile_result EQUAL 0)
    message(FATAL_ERROR
        "Installed process consumer failed to compile:\n${process_compile_stdout}${process_compile_stderr}")
endif()
require_no_tree_references("${process_compile_stdout}${process_compile_stderr}"
    "Installed process compilation")
execute_process(COMMAND "${process_executable}" TIMEOUT 60
    RESULT_VARIABLE process_run_result OUTPUT_VARIABLE process_output
    ERROR_VARIABLE process_run_stderr)
file(READ "${SOURCE_DIR}/tests/cases/cwhip_stdlib_async_process.stdout" expected_process_output)
if(NOT process_run_result EQUAL 0 OR NOT process_output STREQUAL expected_process_output)
    message(FATAL_ERROR
        "Installed process consumer returned ${process_run_result} with '${process_output}':\n${process_run_stderr}")
endif()

# Resolve the installed SQL/SQLite packages into a fresh project lock, then
# compile and execute a consumer using only the relocated installation.
set(sqlite_project "${work_directory}/sqlite-project")
file(MAKE_DIRECTORY "${sqlite_project}")
run_checked("installed SQLite cwhip-pkg init" "${CMAKE_COMMAND}" -E env ${clean_environment}
    "${relocated_prefix}/${BINDIR}/cwhip-pkg" init "${sqlite_project}")
set(sqlite_source
    "${SOURCE_DIR}/tests/functional/positive/positive_installed_sqlite_consumer.cw")
get_filename_component(sqlite_fixture_name "${sqlite_source}" NAME)
file(COPY "${sqlite_source}" DESTINATION "${sqlite_project}")
run_checked("installed SQLite cwhip-pkg install" "${CMAKE_COMMAND}" -E chdir "${sqlite_project}"
    "${CMAKE_COMMAND}" -E env ${clean_environment}
    "${relocated_prefix}/${BINDIR}/cwhip-pkg" install --yes)
file(READ "${sqlite_project}/cwhip-pkg.lock" sqlite_lock)
if(NOT sqlite_lock MATCHES "(^|\n)sqlite = \\[\"0\\.1\\.0\"\\]"
   OR NOT sqlite_lock MATCHES "(^|\n)sql = \\[\"0\\.1\\.0\"\\]"
   OR NOT sqlite_lock MATCHES "dependencies = \\[\"sql=0\\.1\\.0\"\\]")
    message(FATAL_ERROR "Installed SQLite project lock is missing its package graph:\n${sqlite_lock}")
endif()
set(sqlite_executable "${sqlite_project}/sqlite-consumer")
execute_process(
    COMMAND "${CMAKE_COMMAND}" -E env ${clean_environment}
        "${compiler}" -vv "${sqlite_fixture_name}" -o "${sqlite_executable}"
    WORKING_DIRECTORY "${sqlite_project}"
    RESULT_VARIABLE sqlite_compile_result OUTPUT_VARIABLE sqlite_compile_stdout
    ERROR_VARIABLE sqlite_compile_stderr)
if(NOT sqlite_compile_result EQUAL 0)
    message(FATAL_ERROR
        "Installed SQLite consumer failed to compile:\n${sqlite_compile_stdout}${sqlite_compile_stderr}")
endif()
require_no_tree_references("${sqlite_compile_stdout}${sqlite_compile_stderr}"
    "Installed SQLite compilation")
execute_process(COMMAND "${sqlite_executable}"
    RESULT_VARIABLE sqlite_run_result OUTPUT_VARIABLE sqlite_output
    ERROR_VARIABLE sqlite_run_stderr)
file(STRINGS "${sqlite_source}" sqlite_assertions REGEX "^[ \t]*print\\(")
list(LENGTH sqlite_assertions sqlite_assertion_count)
string(REPEAT "true" ${sqlite_assertion_count} sqlite_expected_output)
if(NOT sqlite_run_result EQUAL 0 OR NOT sqlite_output STREQUAL sqlite_expected_output)
    message(FATAL_ERROR
        "Installed SQLite consumer returned ${sqlite_run_result} with '${sqlite_output}':\n${sqlite_run_stderr}")
endif()

# A program with no SQLite import must not receive the SQLite package's native
# link flags or a runtime dependency on libsqlite3.
set(plain_project "${work_directory}/no-sqlite-project")
file(MAKE_DIRECTORY "${plain_project}")
set(plain_source "${plain_project}/no-sqlite.cw")
file(WRITE "${plain_source}" "start {\n    print(true)\n}\n")
set(plain_executable "${plain_project}/no-sqlite")
execute_process(
    COMMAND "${CMAKE_COMMAND}" -E env ${clean_environment}
        "${compiler}" -vv "${plain_source}" -o "${plain_executable}"
    WORKING_DIRECTORY "${plain_project}"
    RESULT_VARIABLE plain_compile_result OUTPUT_VARIABLE plain_compile_stdout
    ERROR_VARIABLE plain_compile_stderr)
if(NOT plain_compile_result EQUAL 0)
    message(FATAL_ERROR
        "No-SQLite application failed to compile:\n${plain_compile_stdout}${plain_compile_stderr}")
endif()
set(plain_link_output "${plain_compile_stdout}${plain_compile_stderr}")
if(plain_link_output MATCHES "(-lsqlite3|libcwhip_sqlite)")
    message(FATAL_ERROR "No-SQLite application received SQLite link flags:\n${plain_link_output}")
endif()
run_checked("No-SQLite application" "${plain_executable}")
if(NOT last_output STREQUAL "true")
    message(FATAL_ERROR "No-SQLite application output differs: '${last_output}'")
endif()
find_program(LDD_EXECUTABLE ldd)
if(LDD_EXECUTABLE)
    execute_process(COMMAND "${LDD_EXECUTABLE}" "${plain_executable}"
        RESULT_VARIABLE ldd_result OUTPUT_VARIABLE ldd_output ERROR_VARIABLE ldd_stderr)
    if(NOT ldd_result EQUAL 0)
        message(FATAL_ERROR "Could not inspect no-SQLite runtime dependencies:\n${ldd_stderr}")
    endif()
    if(ldd_output MATCHES "libsqlite3")
        message(FATAL_ERROR "No-SQLite application has a SQLite runtime dependency:\n${ldd_output}")
    endif()
endif()

# Remove the default resource so compilation can succeed only via the override.
set(builtin_override "${work_directory}/custom-builtin")
file(RENAME "${relocated_prefix}/${DATADIR}/cwhip/builtin" "${builtin_override}")
run_checked("builtin override paths" "${CMAKE_COMMAND}" -E env ${clean_environment}
    "CWHIP_BUILTIN_DIR=${builtin_override}" "${compiler}" --print-paths)
string(FIND "${last_output}"
    "builtin directory: ${builtin_override} (CWHIP_BUILTIN_DIR)" override_position)
if(override_position EQUAL -1)
    message(FATAL_ERROR "Builtin override was not reported:\n${last_output}")
endif()
require_no_tree_references("${last_output}" "Builtin override paths")
run_checked("overridden String compilation" "${CMAKE_COMMAND}" -E env ${clean_environment}
    "CWHIP_BUILTIN_DIR=${builtin_override}" "${compiler}" "${string_source}"
    -o "${string_executable}")
run_checked("overridden String executable" "${string_executable}")
if(NOT last_output STREQUAL expected_string_output)
    message(FATAL_ERROR "Overridden String output differs:\n${last_output}")
endif()
execute_process(
    COMMAND "${CMAKE_COMMAND}" -E env ${clean_environment}
        "CWHIP_BUILTIN_DIR=${work_directory}/missing-builtin"
        "${compiler}" --check-only "${string_source}"
    RESULT_VARIABLE missing_result OUTPUT_VARIABLE missing_stdout
    ERROR_VARIABLE missing_stderr)
if(missing_result EQUAL 0 OR NOT missing_stderr MATCHES
   "cannot load String builtin[^\n]*; set CWHIP_BUILTIN_DIR or CWHIP_HOME")
    message(FATAL_ERROR
        "Missing builtin override did not fail explicitly:\n${missing_stdout}${missing_stderr}")
endif()
file(REMOVE_RECURSE "${work_directory}")
