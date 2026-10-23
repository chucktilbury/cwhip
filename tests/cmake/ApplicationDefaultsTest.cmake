foreach(required IN ITEMS WORK_DIR HELPER)
    if(NOT DEFINED ${required})
        message(FATAL_ERROR "${required} is required")
    endif()
endforeach()

file(REMOVE_RECURSE "${WORK_DIR}")
set(config_home "${WORK_DIR}/xdg")
set(registered_prefix "${WORK_DIR}/sdk")
file(MAKE_DIRECTORY "${config_home}/cwhip" "${registered_prefix}")
file(WRITE "${config_home}/cwhip/sdk.toml"
    "sdk_prefix = \"${registered_prefix}\"\n\n[applications]\n"
    "install_prefix = \"/opt/cwhip-apps\"\nbuild_type = \"RelWithDebInfo\"\n")

set(project "${WORK_DIR}/project")
file(MAKE_DIRECTORY "${project}")
file(WRITE "${project}/CMakeLists.txt" [=[
cmake_minimum_required(VERSION 3.16)
set(Cwhip_PREFIX "${SELECTED_SDK}")
if(APPLY_DEFAULTS)
    include("${HELPER}")
    cwhip_apply_application_defaults()
    if(NOT "${Cwhip_APPLICATION_INSTALL_PREFIX}" STREQUAL "${EXPECTED_APPLICATION_PREFIX}")
        message(FATAL_ERROR
            "Application prefix '${Cwhip_APPLICATION_INSTALL_PREFIX}' != '${EXPECTED_APPLICATION_PREFIX}'")
    endif()
    if(NOT "${Cwhip_APPLICATION_BUILD_TYPE}" STREQUAL "${EXPECTED_APPLICATION_BUILD_TYPE}")
        message(FATAL_ERROR
            "Application build type '${Cwhip_APPLICATION_BUILD_TYPE}' != '${EXPECTED_APPLICATION_BUILD_TYPE}'")
    endif()
endif()
project(application_defaults C)
if(NOT "${CMAKE_INSTALL_PREFIX}" STREQUAL "${EXPECTED_INSTALL_PREFIX}")
    message(FATAL_ERROR
        "Install prefix '${CMAKE_INSTALL_PREFIX}' != '${EXPECTED_INSTALL_PREFIX}'")
endif()
if(NOT "${CMAKE_BUILD_TYPE}" STREQUAL "${EXPECTED_BUILD_TYPE}")
    message(FATAL_ERROR "Build type '${CMAKE_BUILD_TYPE}' != '${EXPECTED_BUILD_TYPE}'")
endif()
]=])

function(configure_case name)
    execute_process(COMMAND "${CMAKE_COMMAND}" -S "${project}" -B "${WORK_DIR}/${name}"
        "-DHELPER=${HELPER}" "-DSELECTED_SDK=${SELECTED_SDK}"
        "-DAPPLY_DEFAULTS=${APPLY_DEFAULTS}"
        "-DEXPECTED_APPLICATION_PREFIX=${EXPECTED_APPLICATION_PREFIX}"
        "-DEXPECTED_APPLICATION_BUILD_TYPE=${EXPECTED_APPLICATION_BUILD_TYPE}"
        "-DEXPECTED_INSTALL_PREFIX=${EXPECTED_INSTALL_PREFIX}"
        "-DEXPECTED_BUILD_TYPE=${EXPECTED_BUILD_TYPE}" ${ARGN}
        RESULT_VARIABLE result OUTPUT_VARIABLE output ERROR_VARIABLE error)
    if(NOT result EQUAL 0)
        message(FATAL_ERROR "${name} failed:\n${output}${error}")
    endif()
endfunction()

unset(ENV{CMAKE_INSTALL_PREFIX})
unset(ENV{CMAKE_BUILD_TYPE})
set(ENV{XDG_CONFIG_HOME} "${config_home}")
set(ENV{HOME} "${WORK_DIR}/home")
set(SELECTED_SDK "${registered_prefix}")
set(APPLY_DEFAULTS ON)
set(EXPECTED_APPLICATION_PREFIX "/opt/cwhip-apps")
set(EXPECTED_APPLICATION_BUILD_TYPE "RelWithDebInfo")
set(EXPECTED_INSTALL_PREFIX "/opt/cwhip-apps")
set(EXPECTED_BUILD_TYPE "RelWithDebInfo")
configure_case(fresh)

set(EXPECTED_INSTALL_PREFIX "${WORK_DIR}/explicit-prefix")
set(EXPECTED_BUILD_TYPE "MinSizeRel")
configure_case(explicit
    "-DCMAKE_INSTALL_PREFIX=${EXPECTED_INSTALL_PREFIX}"
    "-DCMAKE_BUILD_TYPE=${EXPECTED_BUILD_TYPE}")

# Explicit default-looking paths and an explicit empty build type stay intact.
set(EXPECTED_INSTALL_PREFIX "/usr/local")
set(EXPECTED_BUILD_TYPE "RelWithDebInfo")
configure_case(explicit-default-prefix -DCMAKE_INSTALL_PREFIX=/usr/local)
set(EXPECTED_INSTALL_PREFIX "/opt/cwhip-apps")
set(EXPECTED_BUILD_TYPE "")
configure_case(explicit-empty-build-type "-DCMAKE_BUILD_TYPE=")

# CMake's install-prefix environment override is also an explicit choice.
set(ENV{CMAKE_INSTALL_PREFIX} "${WORK_DIR}/environment-prefix")
set(EXPECTED_INSTALL_PREFIX "${WORK_DIR}/environment-prefix")
set(EXPECTED_BUILD_TYPE "RelWithDebInfo")
configure_case(environment-prefix)
unset(ENV{CMAKE_INSTALL_PREFIX})

# The standard CMake environment setting takes priority over the SDK default.
set(ENV{CMAKE_BUILD_TYPE} "MinSizeRel")
set(EXPECTED_INSTALL_PREFIX "/opt/cwhip-apps")
set(EXPECTED_BUILD_TYPE "MinSizeRel")
configure_case(environment-build-type)
unset(ENV{CMAKE_BUILD_TYPE})

# Existing caches keep even default-looking values and an explicit empty type.
set(existing_build "${WORK_DIR}/existing-cache")
execute_process(COMMAND "${CMAKE_COMMAND}" -S "${project}" -B "${existing_build}"
    "-DHELPER=${HELPER}" "-DSELECTED_SDK=${registered_prefix}"
    -DAPPLY_DEFAULTS=OFF -DCMAKE_INSTALL_PREFIX=/usr/local -DCMAKE_BUILD_TYPE=
    -DEXPECTED_INSTALL_PREFIX=/usr/local -DEXPECTED_BUILD_TYPE=
    RESULT_VARIABLE initial_result OUTPUT_VARIABLE initial_output
    ERROR_VARIABLE initial_error)
if(NOT initial_result EQUAL 0)
    message(FATAL_ERROR "Initial cache setup failed:\n${initial_output}${initial_error}")
endif()
execute_process(COMMAND "${CMAKE_COMMAND}" -S "${project}" -B "${existing_build}"
    "-DHELPER=${HELPER}" "-DSELECTED_SDK=${registered_prefix}"
    -DAPPLY_DEFAULTS=ON -DEXPECTED_INSTALL_PREFIX=/usr/local -DEXPECTED_BUILD_TYPE=
    "-DEXPECTED_APPLICATION_PREFIX=/opt/cwhip-apps"
    -DEXPECTED_APPLICATION_BUILD_TYPE=RelWithDebInfo
    RESULT_VARIABLE existing_result OUTPUT_VARIABLE existing_output
    ERROR_VARIABLE existing_error)
if(NOT existing_result EQUAL 0)
    message(FATAL_ERROR
        "Existing default-valued cache was changed:\n${existing_output}${existing_error}")
endif()

# A different SDK selected by CMake must not inherit another SDK's defaults.
set(SELECTED_SDK "${WORK_DIR}/alternate-sdk")
file(MAKE_DIRECTORY "${SELECTED_SDK}")
set(EXPECTED_APPLICATION_PREFIX "")
set(EXPECTED_APPLICATION_BUILD_TYPE "")
set(EXPECTED_INSTALL_PREFIX "/usr/local")
set(EXPECTED_BUILD_TYPE "")
configure_case(alternate)

file(REMOVE_RECURSE "${WORK_DIR}")
