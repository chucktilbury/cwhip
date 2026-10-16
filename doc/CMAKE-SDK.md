# Installed SDK for external projects

The installed Cwhip **0.0.1** prefix is the supported prototype distribution
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
project(example LANGUAGES C)
find_package(Cwhip 0.0.1 EXACT CONFIG REQUIRED)
add_library(native OBJECT native.c)
target_include_directories(native PRIVATE "${Cwhip_INCLUDE_DIR}")
cwhip_add_program(hello SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/hello.cw"
    OBJECTS $<TARGET_OBJECTS:native> DEPENDS native)
get_target_property(hello_binary hello CWHIP_EXECUTABLE)
install(PROGRAMS "${hello_binary}" DESTINATION bin)
```

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
`Cwhip_GTK` and `Cwhip_SOURCEVIEW`. Missing required resources, unavailable
Python/Clang, wrong package version or a mismatched compiler executable fail
configuration. Native bindings include public `cwhip/Stdlib.h`; applications
do not include compiler implementation or package-private headers.

`cwhip_add_program(name SOURCE file [OUTPUT_NAME file] [OBJECTS objects...]
[DEPENDS dependencies...])` creates an ALL custom target with executable
`<current-binary-dir>/bin/name` (or OUTPUT_NAME). `CWHIP_EXECUTABLE` is its
path; this is not a CMake native executable target or a custom language
toolchain file. The helper copies the source file's directory as a private
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

## GUI application resources

Call `cwhip_require_sourceview()` before `cwhip_add_program` to require GUI
bindings and host development libraries. It creates the
`cwhip_language_resources` build target and installs the SDK's language
definitions under `share/cwhip/modules/sourceview/0.1.0/language-specs`.
Applications install executable files in `bin` and this resource tree in
the same prefix; move the whole application prefix. GTK native code finds
these definitions relative to the running executable, never through a
compiler checkout or configured absolute SDK prefix. Flat test programs can
instead carry the same `share` tree alongside the executable.

Compiler-integrated editor/debugger targets remain legacy development
examples, not the external application interface. Standalone cedit and cdbg
consume only this installed contract and own their tests/install rules.
They remain proof-of-concept applications. GNU/Clang builds retain runtime
type debug metadata even with Release optimization so the debugger can inspect
runtime-private layouts without source files. Do not strip that metadata from
the runtime archive if those inspection features are needed. Other native
compilers must provide equivalent debug information. Source-line stepping
inside the compiler runtime is not a source-free application regression.
