# Installed SDK for external projects

SDK 0.0.2 uses the incompatible **numeric-v2** source/native contract.
See [NUMERIC-MIGRATION.md](NUMERIC-MIGRATION.md) before rebuilding consumers.
`Cwhip_SDK_ABI` and the installed `CWHIP_SDK_ABI` macro expose this identifier;
every package must declare `[package] sdk-abi = "numeric-v2"`.

The installed Cwhip **0.0.2** prefix is the supported prototype distribution
boundary. It is not just a compiler executable. Install and move the **whole**
tree: `bin/cwhip`, `bin/cwhip-pkg`, `lib/cwhip/libcwhip_runtime.a`, public
`include/cwhip` headers, `share/cwhip/builtin`, standard package directories
under `share/cwhip/modules` (including manifests and native archives), and
`lib/cmake/Cwhip`. No compiler checkout is needed to consume it.

## Build, install and relocate

Linux/POSIX, CMake >= 3.24, C11/C++17 compilers, Clang, Python >= 3.11,
SQLite 3 development libraries and pthreads are prerequisites. Optional GUI
packages need pkg-config, GTK 4 >= 4.10 and GtkSourceView 5 development
libraries. Git is required for explicit package installation, not local SDK
builds. Nothing here automatically downloads or installs system dependencies.

For compiler development use `scripts/setup [--clean] [debug|release|profile]`
then `build`/`rebuild` in its child shell; see
[the developer shell](INSTALLATION.md#developer-shell).
The direct CMake commands here intentionally support SDK producers/packagers
without a project shell, separate staging/install prefixes, and external SDK
consumers (which do not need this checkout's setup script).

```sh
cmake -S . -B build -DCMAKE_BUILD_TYPE=Debug \
  -DCWHIP_STAGE_PREFIX="$PWD/build/stage" \
  -DCMAKE_INSTALL_PREFIX="$PWD/build/sdk" -DCMAKE_INSTALL_LIBDIR=lib
cmake --build build --target cwhip --parallel 4
cmake --install build
cp -a build/sdk /chosen/relocated-sdk
/chosen/relocated-sdk/bin/cwhip --print-paths
```

Keep build staging and installation prefixes distinct. `--prefix` on install
is supported; GNU install subdirectories must remain within the prefix as
enforced by the compiler. The default public CMake config is found at
`lib/cmake/Cwhip` (`lib64` or another configured library directory is possible).
The compiler and package tool resolve their real paths, so whole-prefix
relocation and executable symlinks work without CWHIP environment overrides.
Shared system libraries and external Clang/Python/Git are not bundled.

## CMake discovery and a native binding

Use exact-version config discovery; the prototype language/runtime/native ABI
has no cross-version compatibility guarantee:

```cmake
cmake_minimum_required(VERSION 3.24)
find_package(Cwhip 0.0.2 EXACT CONFIG REQUIRED)
cwhip_apply_application_defaults()
project(example LANGUAGES C)
if(NOT Cwhip_APPLICATION_OUTPUT_DIRECTORIES)
  message(FATAL_ERROR "This Cwhip SDK lacks application output-directory support")
endif()
set(CWHIP_BIN_DIR "${CMAKE_CURRENT_BINARY_DIR}/bin" CACHE PATH "Application executable directory")
set(CWHIP_LIB_DIR "${CMAKE_CURRENT_BINARY_DIR}/lib" CACHE PATH "Application library directory")
add_library(native OBJECT native.c)
target_include_directories(native PRIVATE "${Cwhip_INCLUDE_DIR}")
cwhip_add_program(hello SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/hello.cw"
    OUTPUT_DIRECTORY "${CWHIP_BIN_DIR}"
    OBJECTS $<TARGET_OBJECTS:native> DEPENDS native)
get_target_property(hello_binary hello CWHIP_EXECUTABLE)
install(PROGRAMS "${hello_binary}" DESTINATION bin)
```

Call `find_package(Cwhip ...)` and `cwhip_apply_application_defaults()` before
`project()` and before defining application cache defaults. Doing so lets the
helper distinguish absent cache entries from explicit empty values. A real
Cwhip install records its actual install prefix and selected build
configuration in the `[applications]` table of `sdk.toml`; this helper exposes
them as `Cwhip_APPLICATION_INSTALL_PREFIX` and
`Cwhip_APPLICATION_BUILD_TYPE`, and initializes `CMAKE_INSTALL_PREFIX` and
`CMAKE_BUILD_TYPE` only when they have not already been selected. Explicit
`-D` values, `CMAKE_INSTALL_PREFIX` and `CMAKE_BUILD_TYPE` environment
settings, and existing cache choices (including an empty build type) win.
The defaults apply only when the selected package's `Cwhip_PREFIX` matches the
registered top-level `sdk_prefix`; selecting a different SDK does not inherit
another installation's defaults. Multi-configuration generators continue to
select their build configuration through the normal CMake configuration
selection.

```sh
cmake -S example -B example-build -DCMAKE_PREFIX_PATH=/chosen/relocated-sdk
cmake --build example-build
example-build/bin/hello
cmake --build example-build --target clean
cmake --install example-build --prefix /chosen/example
```

The config exposes `Cwhip_VERSION`, `Cwhip_PREFIX`, `Cwhip_COMPILER`,
`Cwhip_PACKAGE_TOOL`, `Cwhip_INCLUDE_DIR`, `Cwhip_RUNTIME_LIBRARY`,
`Cwhip_BUILTIN_DIR`, `Cwhip_MODULE_DIR`, `Cwhip_CLANG_EXECUTABLE`,
`Cwhip_GTK`, `Cwhip_SOURCEVIEW`, `Cwhip_APPLICATION_OUTPUT_DIRECTORIES`,
`Cwhip_APPLICATION_INSTALL_PREFIX` and `Cwhip_APPLICATION_BUILD_TYPE`.
Missing required resources, unavailable Python/Clang, wrong package version
or a mismatched compiler executable fail configuration. Native bindings include
public `cwhip/Stdlib.h`; applications do not include compiler implementation
or package-private headers.

`cwhip_add_program(name SOURCE file [OUTPUT_NAME file] [OUTPUT_DIRECTORY dir]
[OBJECTS objects...] [DEPENDS dependencies...])` creates an ALL custom target
with executable `<current-binary-dir>/bin/name` by default, or in the supplied
output directory. When `CMAKE_BUILD_TYPE` is `Debug` or `RelWithDebInfo`, the
helper passes `-g` so the linked image includes DWARF for `.cw` sources (needed
by cdbg). `CWHIP_EXECUTABLE` is its path; this is not a CMake native
executable target or a custom language toolchain file. Consumers that use the
new `OUTPUT_DIRECTORY` and `RESOURCE_DIRECTORY` arguments must check
`Cwhip_APPLICATION_OUTPUT_DIRECTORIES` after `find_package`; older installed
0.0.1 SDKs do not advertise or implement them. Define cache-overridable
`CWHIP_BIN_DIR` and `CWHIP_LIB_DIR` in the application project, and pass the
executable directory to `OUTPUT_DIRECTORY`. The library directory is for
application-owned native libraries; it does not change the compiler SDK's
runtime-library location. CMake may create native target output directories
during generation, so if the final `bin` and `lib` directories must not exist
until a build runs, direct native targets to private build directories and use
build-time copy commands to stage their outputs in `CWHIP_BIN_DIR` or
`CWHIP_LIB_DIR`.

The helper copies the source file's directory as a private
source project and locks the SDK's bundled standard packages with
`cwhip-pkg init`. It sets private HOME/XDG configuration, clears legacy module
overrides and selects this SDK's resources/Clang explicitly. There is no
network dependency resolution. This small helper supports one source-root
directory and local native object inputs, not arbitrary package-fetching or
release frameworks; projects with additional package graphs must manage
their explicit package workflow rather than assume automatic downloads.

Source/header/package/archive changes participate in dependencies. Ordinary
CMake clean removes outputs/private work and the next build recreates them;
configuration caches/input inventories remain. Changing SDK prefixes requires
reconfiguration (a new binary directory is simplest).

### Refreshing generated application locks

After an intentional, verified SDK rebuild at the same prefix/version, an old
application build can retain a private `cwhip-pkg.lock` whose bundled package
hashes no longer match. Installation preserves file timestamps, so a newer
generated lock is not proof that it describes the current SDK bytes. Merely
rerunning configuration need not regenerate that lock.
See [integrity mismatch diagnosis](PACKAGES.md#integrity-mismatch-after-an-sdk-rebuild)
before trusting the changed SDK.

Use a new, unused binary directory to explicitly create fresh generated locks
without removing or editing the old ones. For standalone cedit/cdbg, select the
verified SDK explicitly with `CWHIP_SDK` (which takes precedence over saved SDK
settings) and keep the new outputs inside that binary directory:

```sh
# Run from the application's source directory, once for cedit and once for cdbg.
CWHIP_SDK=/chosen/verified-sdk cmake -S . -B build-sdk-refresh \
  -DCWHIP_BIN_DIR="$PWD/build-sdk-refresh/bin" \
  -DCWHIP_LIB_DIR="$PWD/build-sdk-refresh/lib"
cmake --build build-sdk-refresh --parallel 4
```

Choose another new directory if `build-sdk-refresh` already exists. This is a
deliberate snapshot of the selected SDK, not an integrity bypass or a package
version/ABI migration. It does not update a manually maintained source-project
lock, install applications, or rewrite SDK settings. Subsequent unexpected
package edits still fail the content check.

## GUI application resources

For a complete SDK-first installation followed by each standalone app's own
`scripts/setup` and build/install commands, see
[Your first program](FIRST-PROGRAM.md). No multi-repository orchestration is
needed; compiler and app tests are owned and run by their respective projects.

Call `cwhip_require_sourceview([RESOURCE_DIRECTORY dir])` before
`cwhip_add_program` to require GUI bindings and host development libraries.
It creates the `cwhip_language_resources` build target and installs the SDK's
language definitions under `share/cwhip/modules/sourceview/0.1.0/language-specs`.
By default, the build copy is under `<current-binary-dir>/share`; when the
executable directory is overridden, pass a `RESOURCE_DIRECTORY` under the
parent of that directory so the resource tree remains a sibling of `bin`.
For example, `${CWHIP_BIN_DIR}/../share/cwhip/modules/sourceview/0.1.0/language-specs`
places it beside an executable directory named `bin`. Both output directories
are created by their build targets, not during CMake configuration. Applications
install executable files in `bin` and this resource tree in the same prefix;
move the whole application prefix. GTK native code finds these definitions
relative to the running executable, never through a compiler checkout or
configured absolute SDK prefix. Flat test programs can instead carry the same
`share` tree alongside the executable.

The standalone [cedit](https://github.com/chucktilbury/cedit) and
[cdbg](https://github.com/chucktilbury/cdbg) applications consume only this
installed contract and own their sources, build targets, tests and install rules.
No copies or application targets remain in the compiler repository.
They remain proof-of-concept applications. GNU/Clang builds retain runtime
type debug metadata even with Release optimization so the debugger can inspect
runtime-private layouts without source files. Do not strip that metadata from
the runtime archive if those inspection features are needed. Other native
compilers must provide equivalent debug information. Source-line stepping
inside the compiler runtime is not a source-free application regression.
