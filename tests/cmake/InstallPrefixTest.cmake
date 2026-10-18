foreach(required IN ITEMS CMAKE_COMMAND HELPER WORK_DIR)
    if(NOT DEFINED ${required})
        message(FATAL_ERROR "${required} is required")
    endif()
endforeach()

if(EXISTS "${WORK_DIR}" OR IS_SYMLINK "${WORK_DIR}")
    message(FATAL_ERROR "Install-prefix test directory already exists: ${WORK_DIR}")
endif()
file(MAKE_DIRECTORY "${WORK_DIR}/source")
file(WRITE "${WORK_DIR}/source/CMakeLists.txt"
    "cmake_minimum_required(VERSION 3.16)\n"
    "project(install_prefix_test NONE)\n"
    "include(\"\${HELPER}\")\n")

function(configure_and_check build_dir expected)
    execute_process(COMMAND ${ARGN}
        RESULT_VARIABLE result OUTPUT_VARIABLE stdout ERROR_VARIABLE stderr)
    if(NOT result EQUAL 0)
        message(FATAL_ERROR "Configuration failed (${result}):\n${stdout}${stderr}")
    endif()
    file(STRINGS "${build_dir}/CMakeCache.txt" prefix_line
        REGEX "^CMAKE_INSTALL_PREFIX:PATH=")
    if(NOT prefix_line STREQUAL "CMAKE_INSTALL_PREFIX:PATH=${expected}")
        message(FATAL_ERROR
            "Unexpected install prefix in ${build_dir}:\n"
            "actual: ${prefix_line}\nexpected: CMAKE_INSTALL_PREFIX:PATH=${expected}")
    endif()
endfunction()

function(expect_configure_failure)
    execute_process(COMMAND ${ARGN}
        RESULT_VARIABLE result OUTPUT_VARIABLE stdout ERROR_VARIABLE stderr)
    if(result EQUAL 0)
        message(FATAL_ERROR "Configuration unexpectedly succeeded:\n${stdout}${stderr}")
    endif()
    if(NOT "${stdout}${stderr}" MATCHES "HOME")
        message(FATAL_ERROR "Configuration failed without a HOME diagnostic:\n${stdout}${stderr}")
    endif()
endfunction()

set(source "${WORK_DIR}/source")
set(home "${WORK_DIR}/home with spaces")
file(MAKE_DIRECTORY "${home}")

configure_and_check("${WORK_DIR}/default" "${home}/opt/cwhip"
    "${CMAKE_COMMAND}" -E env "HOME=${home}" --unset=CMAKE_INSTALL_PREFIX
    "${CMAKE_COMMAND}" -S "${source}" -B "${WORK_DIR}/default" "-DHELPER=${HELPER}")

configure_and_check("${WORK_DIR}/default" "${home}/opt/cwhip"
    "${CMAKE_COMMAND}" -E env "HOME=${WORK_DIR}/another-home" --unset=CMAKE_INSTALL_PREFIX
    "${CMAKE_COMMAND}" -S "${source}" -B "${WORK_DIR}/default" "-DHELPER=${HELPER}")

configure_and_check("${WORK_DIR}/explicit" "/usr/local"
    "${CMAKE_COMMAND}" -E env --unset=HOME --unset=CMAKE_INSTALL_PREFIX
    "${CMAKE_COMMAND}" -S "${source}" -B "${WORK_DIR}/explicit"
    "-DHELPER=${HELPER}" -DCMAKE_INSTALL_PREFIX=/usr/local)

configure_and_check("${WORK_DIR}/explicit" "/usr/local"
    "${CMAKE_COMMAND}" -E env "HOME=${WORK_DIR}/another-home" --unset=CMAKE_INSTALL_PREFIX
    "${CMAKE_COMMAND}" -S "${source}" -B "${WORK_DIR}/explicit" "-DHELPER=${HELPER}")

configure_and_check("${WORK_DIR}/explicit-relative-home" "/chosen/cwhip"
    "${CMAKE_COMMAND}" -E env "HOME=relative/home" --unset=CMAKE_INSTALL_PREFIX
    "${CMAKE_COMMAND}" -S "${source}" -B "${WORK_DIR}/explicit-relative-home"
    "-DHELPER=${HELPER}" -DCMAKE_INSTALL_PREFIX=/chosen/cwhip)

expect_configure_failure(
    "${CMAKE_COMMAND}" -E env --unset=HOME --unset=CMAKE_INSTALL_PREFIX
    "${CMAKE_COMMAND}" -S "${source}" -B "${WORK_DIR}/missing-home"
    "-DHELPER=${HELPER}")

expect_configure_failure(
    "${CMAKE_COMMAND}" -E env "HOME=relative/home" --unset=CMAKE_INSTALL_PREFIX
    "${CMAKE_COMMAND}" -S "${source}" -B "${WORK_DIR}/relative-home"
    "-DHELPER=${HELPER}")

if(CMAKE_VERSION VERSION_GREATER_EQUAL 3.29)
    configure_and_check("${WORK_DIR}/environment" "/environment/cwhip"
        "${CMAKE_COMMAND}" -E env --unset=HOME "CMAKE_INSTALL_PREFIX=/environment/cwhip"
        "${CMAKE_COMMAND}" -S "${source}" -B "${WORK_DIR}/environment"
        "-DHELPER=${HELPER}")

    configure_and_check("${WORK_DIR}/command-over-environment" "/command/cwhip"
        "${CMAKE_COMMAND}" -E env "HOME=${home}" "CMAKE_INSTALL_PREFIX=/environment/cwhip"
        "${CMAKE_COMMAND}" -S "${source}" -B "${WORK_DIR}/command-over-environment"
        "-DHELPER=${HELPER}" -DCMAKE_INSTALL_PREFIX=/command/cwhip)
endif()

file(REMOVE_RECURSE "${WORK_DIR}")
