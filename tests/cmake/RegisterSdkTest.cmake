# Exercises cwhip_register_sdk() against temporary config homes.
include("${HELPER}")

if(DEFINED ENV{TMPDIR} AND IS_DIRECTORY "$ENV{TMPDIR}")
    set(root "$ENV{TMPDIR}")
else()
    set(root "/tmp")
endif()
string(RANDOM LENGTH 12 suffix)
set(root "${root}/cwhip-register-sdk-${suffix}")
file(MAKE_DIRECTORY "${root}")

function(expect_file path expected)
    file(READ "${path}" actual)
    if(NOT actual STREQUAL expected)
        message(FATAL_ERROR "Unexpected ${path}:\n--- actual\n${actual}\n--- expected\n${expected}")
    endif()
endfunction()

set(ENV{DESTDIR} "")
set(ENV{HOME} "${root}/home")
set(ENV{XDG_CONFIG_HOME} "")
set(settings "${root}/home/.config/cwhip/sdk.toml")
set(preferences "${root}/home/.config/cwhip/settings.toml")

# New file; parent directories are created.
cwhip_register_sdk("/opt/cwhip")
expect_file("${settings}"
    "sdk_prefix = \"/opt/cwhip\"\n\n[applications]\ninstall_prefix = \"/opt/cwhip\"\nbuild_type = \"\"\n")
if(EXISTS "${preferences}")
    message(FATAL_ERROR "SDK registration must not create preferences")
endif()

# Preferences may be replaced by apps, including legacy SDK registrations.
file(WRITE "${preferences}" "# legacy preferences\nsdk_prefix = \"/old/sdk\"\n[editor]\nsize = 10\n")
cwhip_register_sdk("/opt/cwhip")
expect_file("${preferences}" "# legacy preferences\nsdk_prefix = \"/old/sdk\"\n[editor]\nsize = 10\n")
file(WRITE "${preferences}" "version = 1\n[editor]\nsize = 14\n")
expect_file("${settings}"
    "sdk_prefix = \"/opt/cwhip\"\n\n[applications]\ninstall_prefix = \"/opt/cwhip\"\nbuild_type = \"\"\n")

# Explicit prefix update, trailing slash normalised, nothing else changes.
cwhip_register_sdk("/usr/local/cwhip/")
expect_file("${settings}"
    "sdk_prefix = \"/usr/local/cwhip\"\n\n[applications]\ninstall_prefix = \"/usr/local/cwhip\"\nbuild_type = \"\"\n")

# Existing settings, comments, tables, arrays, and semicolons are preserved.
file(WRITE "${settings}"
"# my settings
theme = \"dark; blue\"
fonts = [
  \"a\",
  \"[b]\"
]

[editor]
# keep
size = 12

[applications]
install_prefix = \"/opt/one\"
build_type = \"\"
channel = \"preserve-me\"
")
cwhip_register_sdk("/opt/one")
expect_file("${settings}"
"# my settings
theme = \"dark; blue\"
fonts = [
  \"a\",
  \"[b]\"
]

sdk_prefix = \"/opt/one\"

[editor]
# keep
size = 12

[applications]
install_prefix = \"/opt/one\"
build_type = \"\"
channel = \"preserve-me\"
")
cwhip_register_sdk("/opt/two")
expect_file("${settings}"
"# my settings
theme = \"dark; blue\"
fonts = [
  \"a\",
  \"[b]\"
]

sdk_prefix = \"/opt/two\"

[editor]
# keep
size = 12

[applications]
install_prefix = \"/opt/two\"
build_type = \"\"
channel = \"preserve-me\"
")

# Missing application fields are inserted inside the existing table.
file(WRITE "${settings}"
"sdk_prefix = \"/old/sdk\"
[applications]
channel = \"keep\"
[editor]
size = 1
")
cwhip_register_sdk("/opt/table" "Debug")
expect_file("${settings}"
"sdk_prefix = \"/opt/table\"
[applications]
channel = \"keep\"
install_prefix = \"/opt/table\"
build_type = \"Debug\"
[editor]
size = 1
")

# A file with only tables and no trailing newline gets a top-level key first.
file(WRITE "${settings}" "[editor]\nsize = 1")
cwhip_register_sdk("/opt/three")
expect_file("${settings}"
    "sdk_prefix = \"/opt/three\"\n\n[editor]\nsize = 1\n\n[applications]\ninstall_prefix = \"/opt/three\"\nbuild_type = \"\"\n")

# TOML escaping of quotes and backslashes.
file(REMOVE "${settings}")
cwhip_register_sdk("/opt/we\"ird\\path")
expect_file("${settings}"
    "sdk_prefix = \"/opt/we\\\"ird\\\\path\"\n\n[applications]\ninstall_prefix = \"/opt/we\\\"ird\\\\path\"\nbuild_type = \"\"\n")

# XDG_CONFIG_HOME wins over HOME.
set(ENV{XDG_CONFIG_HOME} "${root}/xdg")
cwhip_register_sdk("/opt/xdg")
expect_file("${root}/xdg/cwhip/sdk.toml"
    "sdk_prefix = \"/opt/xdg\"\n\n[applications]\ninstall_prefix = \"/opt/xdg\"\nbuild_type = \"\"\n")

# DESTDIR installs never write the setting.
set(ENV{XDG_CONFIG_HOME} "${root}/xdg-destdir")
set(ENV{DESTDIR} "${root}/stage")
cwhip_register_sdk("/opt/staged")
if(EXISTS "${root}/xdg-destdir")
    message(FATAL_ERROR "DESTDIR install must not write settings")
endif()
set(ENV{DESTDIR} "")

# Errors are surfaced.
execute_process(COMMAND "${CMAKE_COMMAND}" "-DCWHIP_SDK_PREFIX=relative/path"
    "-P" "${HELPER}" RESULT_VARIABLE relative_result ERROR_QUIET)
if(relative_result EQUAL 0)
    message(FATAL_ERROR "Relative prefix must fail")
endif()
file(WRITE "${root}/blocker" "file")
execute_process(COMMAND "${CMAKE_COMMAND}" -E env "XDG_CONFIG_HOME=${root}/blocker"
    "${CMAKE_COMMAND}" "-DCWHIP_SDK_PREFIX=/opt/x" -P "${HELPER}"
    RESULT_VARIABLE blocked_result ERROR_QUIET OUTPUT_QUIET)
if(blocked_result EQUAL 0)
    message(FATAL_ERROR "Unwritable config directory must fail")
endif()
set(ENV{XDG_CONFIG_HOME} "${root}/invalid")
file(MAKE_DIRECTORY "${root}/invalid/cwhip/sdk.toml")
execute_process(COMMAND "${CMAKE_COMMAND}" "-DCWHIP_SDK_PREFIX=/opt/x" -P "${HELPER}"
    RESULT_VARIABLE directory_result ERROR_QUIET OUTPUT_QUIET)
if(directory_result EQUAL 0)
    message(FATAL_ERROR "Directory at SDK configuration path must fail")
endif()
file(REMOVE_RECURSE "${root}/invalid/cwhip/sdk.toml")
file(WRITE "${root}/invalid/cwhip/sdk.toml" "sdk_prefix = \"\"\"\n/old/prefix\n\"\"\"\n")
execute_process(COMMAND "${CMAKE_COMMAND}" "-DCWHIP_SDK_PREFIX=/opt/x" -P "${HELPER}"
    RESULT_VARIABLE multiline_result ERROR_QUIET OUTPUT_QUIET)
if(multiline_result EQUAL 0)
    message(FATAL_ERROR "Multi-line SDK prefix must fail without rewriting the file")
endif()
expect_file("${root}/invalid/cwhip/sdk.toml" "sdk_prefix = \"\"\"\n/old/prefix\n\"\"\"\n")

file(REMOVE_RECURSE "${root}")
