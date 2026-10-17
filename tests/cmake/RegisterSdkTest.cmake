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
set(settings "${root}/home/.config/cwhip/settings.toml")

# New file; parent directories are created.
cwhip_register_sdk("/opt/cwhip")
expect_file("${settings}" "sdk_prefix = \"/opt/cwhip\"\n")

# Explicit prefix update, trailing slash normalised, nothing else changes.
cwhip_register_sdk("/usr/local/cwhip/")
expect_file("${settings}" "sdk_prefix = \"/usr/local/cwhip\"\n")

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
")

# A file with only tables and no trailing newline gets a top-level key first.
file(WRITE "${settings}" "[editor]\nsize = 1")
cwhip_register_sdk("/opt/three")
expect_file("${settings}" "sdk_prefix = \"/opt/three\"\n\n[editor]\nsize = 1\n")

# TOML escaping of quotes and backslashes.
file(REMOVE "${settings}")
cwhip_register_sdk("/opt/we\"ird\\path")
expect_file("${settings}" "sdk_prefix = \"/opt/we\\\"ird\\\\path\"\n")

# XDG_CONFIG_HOME wins over HOME.
set(ENV{XDG_CONFIG_HOME} "${root}/xdg")
cwhip_register_sdk("/opt/xdg")
expect_file("${root}/xdg/cwhip/settings.toml" "sdk_prefix = \"/opt/xdg\"\n")

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

file(REMOVE_RECURSE "${root}")
