# From no Cwhip installation to a first program

Build a user-local SDK, build the standalone cedit editor against it, then
write, compile, and run hello world outside either checkout. This Linux/POSIX
source-install route needs no umbrella repository, submodules, website build,
project generator, or packaged Cwhip release. Cwhip and its applications are
prototypes; use current sources together for the **0.0.2 numeric-v2** SDK.
Older numeric-v2 installations may lack current language syntax, so updating
an application checkout alone is not an SDK upgrade.

Run commands in order in one terminal, using new source, build, install, and
hello-world directories so existing work is not overwritten. No build/install
command below requires `sudo` or changes shell startup files.
For the broader compiler-only/project/package workflow, see
[Getting started](GETTING_STARTED.md).

## Check prerequisites

You need Git, Make (or another CMake build tool), CMake **3.24+**, Python
**3.11+**, a C11/C++17 toolchain, **Clang** on PATH, SQLite 3 development
files, pkg-config, **GTK 4.10+**, and **GtkSourceView 5** development files.
Clang is needed for generated LLVM IR even when GCC builds the compiler.
A working graphical session is required to use cedit interactively.

On Ubuntu 24.04 or Debian 13, the relevant distribution packages are:

```text
git build-essential cmake clang python3 pkg-config libsqlite3-dev
libgtk-4-dev libgtksourceview-5-dev
```

Install missing prerequisites with your distribution's package manager.
Check versions rather than relying on package names: Debian 12's GTK 4.8
does not meet the editor's requirement.

```sh
cmake --version
python3 --version
clang --version
pkg-config --modversion sqlite3 gtk4 gtksourceview-5
pkg-config --atleast-version=4.10 gtk4
```

The last check must exit successfully (success is silent). GDB is not needed
for this tutorial. Xvfb and dbus-daemon are optional automated GUI-test tools,
not interactive editor prerequisites. Without suitable GTK libraries, use
the [compiler-only route](GETTING_STARTED.md#build-and-install-the-sdk) and
your existing text editor instead.

## Build and install the SDK first

Choose an unused installation prefix; do not mix files from different SDKs:

This SDK installation deliberately uses direct CMake: it needs separate
build/staging/install directories, explicit GUI options and registration
opt-out without a project shell. For ordinary compiler development, prefer
`scripts/setup [--clean] [debug|release|profile]` then `build` or `rebuild`;
see [the developer shell](INSTALLATION.md#developer-shell).

```sh
mkdir -p "$HOME/Src"
git clone https://github.com/chucktilbury/cwhip.git "$HOME/Src/cwhip"
cd "$HOME/Src/cwhip"
export CWHIP_PREFIX="$HOME/.local/opt/cwhip-first"

cmake -S . -B build-first -DCMAKE_BUILD_TYPE=Debug \
  -DCWHIP_STAGE_PREFIX="$PWD/build-first/stage" \
  -DCMAKE_INSTALL_PREFIX="$CWHIP_PREFIX" -DCMAKE_INSTALL_LIBDIR=lib \
  -DBUILD_TESTING=OFF -DCWHIP_REGISTER_SDK=OFF \
  -DCWHIP_GTK=ON -DCWHIP_GTK_SOURCEVIEW=ON
cmake --build build-first --target cwhip --parallel 4
cmake --install build-first

export CWHIP_SDK="$CWHIP_PREFIX"
export PATH="$CWHIP_PREFIX/bin:$PATH"
unset CWHIP_HOME CWHIP_RUNTIME_DIR CWHIP_INCLUDE_DIR CWHIP_BUILTIN_DIR
unset CWHIP_STDLIB_MODULE_DIR CWHIP_MODULE_DIR CC
command -v cwhip
cwhip --version
cwhip --print-paths
cwhip-pkg doctor
```

Explicit GUI options fail configuration if required libraries are missing;
they do not silently produce a compiler-only SDK. Build staging and the
persistent installation are separate. Keep the **whole installed prefix**:
`bin/`, `lib/`, `include/`, and `share/`, not just the compiler executable.
Resource paths should resolve under that prefix, not an old installation.

`CWHIP_REGISTER_SDK=OFF` avoids writing SDK configuration during installation.
`CWHIP_SDK` explicitly selects this installation for standalone consumers;
PATH selects its tools. A normal install without the opt-out registers
`sdk_prefix` and application defaults in `cwhip/sdk.toml`; see
[SDK selection and configuration](GETTING_STARTED.md#sdk-selection-and-configuration).
These exports last only for this shell; set them again in a new terminal.
The compiler install does not build cedit or cdbg.

## 3. Build the standalone editor against the installed SDK

cedit owns its CMake project and setup script. Clone it independently:

```sh
git clone https://github.com/chucktilbury/cedit.git "$HOME/Src/cedit"
cd "$HOME/Src/cedit"
./scripts/setup debug
```

Setup configures the app using `CWHIP_SDK`, then opens a child Bash shell
initially in `cedit/build/`. In that child shell, run:

```sh
build cedit
cmake --install . --prefix "$HOME/.local/opt/cedit-first"
exit
```

`exit` returns to the original terminal shell. There:

```sh
export PATH="$HOME/.local/opt/cedit-first/bin:$PATH"
command -v cedit
```

Setup is a project-shell convenience, not a compiler/dependency installer.
It reads your existing Bash startup file but does not rewrite it.
Use `rebuild [TARGET...]` inside the shell to clean and build again, or exit
and run `./scripts/setup --clean debug` to remove all default generated output
before reconfiguring. `clean` remains available as a script; after using it,
exit and rerun setup.
If you prefer not to open a project shell, use the app's
[direct CMake instructions](https://github.com/chucktilbury/cedit/blob/main/doc/BUILD.md).
Keep the installed `cedit` executable and its `share/` resources together.
The installed editor does not need either source checkout to open files.

## Write and save hello world

Create a new empty project directory outside the checkouts:

```sh
mkdir -p "$HOME/Src/cwhip-hello"
cd "$HOME/Src/cwhip-hello"
cedit
```

In cedit, choose **File > New**, enter the following, then **File > Save As...**
and save it as `hello.cw` in that directory:

```cwhip
// test: {"stdout": "Hello, world!\n"}
start {
    print("Hello, world!\n")
}
```

The `// test:` line is an executable-documentation expectation; it is an
ordinary comment and you may omit it. The `.cw` suffix enables Cwhip syntax
highlighting. **Ctrl+S** saves, **Ctrl+O** opens, and **Ctrl+Q** quits with
unsaved-change protection. You do not need **Project > New Project**:
editor `.cwhip/project.toml` metadata is not a compiler manifest or CMake
build file. cedit has no integrated compile/run action; use the terminal.

## Compile, run, edit, and rebuild

From the same project directory:

```sh
cwhip hello.cw -o hello && ./hello
```

Expected output:

```text
Hello, world!
```

In cedit, change the printed text to `Hello from Cwhip!`, save with **Ctrl+S**
(the modified-tab marker disappears), and repeat the compile/run command.
The output becomes `Hello from Cwhip!`. Running an old executable without
recompiling does not test an edit. The `&&` prevents running stale output
after a failed compilation. No packages are imported, so `cwhip-pkg init`
is unnecessary for this direct compiler command.

### Optional: build the same file with CMake

Save this as `CMakeLists.txt` beside `hello.cw`:

```cmake
cmake_minimum_required(VERSION 3.24)
project(hello_world LANGUAGES C)
find_package(Cwhip 0.0.2 EXACT CONFIG REQUIRED)
cwhip_add_program(hello SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/hello.cw")
```

Then select the **whole SDK prefix**, not its `bin/` directory:

```sh
cmake -S . -B build -DCMAKE_PREFIX_PATH="$CWHIP_PREFIX"
cmake --build build --parallel 4 && ./build/bin/hello
```

After saving source edits, repeat the build/run command. This helper tracks
source changes and uses private generated package locks; its executable is
`build/bin/hello`, distinct from the earlier `./hello`. Use a new binary
directory when changing SDKs. The exact-version requirement is intentional:
the prototype does not promise cross-version source/native compatibility.
See [the CMake SDK contract](CMAKE-SDK.md) for native bindings and relocation.

## Optional: add the standalone debugger

[cdbg](https://github.com/chucktilbury/cdbg) consumes the same GUI-enabled SDK.
It owns its setup/build/install interface too. With `CWHIP_SDK` still exported:

```sh
git clone https://github.com/chucktilbury/cdbg.git "$HOME/Src/cdbg"
cd "$HOME/Src/cdbg"
./scripts/setup debug
```

In the child shell, initially in `cdbg/build/`:

```sh
build cdbg
cmake --install . --prefix "$HOME/.local/opt/cdbg-first"
exit
```

Back in the original shell:

```sh
export PATH="$HOME/.local/opt/cdbg-first/bin:$PATH"
cd "$HOME/Src/cwhip-hello"
cdbg hello.cw
```

Install GDB separately; friendly Cwhip value inspection requires Python-enabled
GDB with `gdb.MICommand`. cdbg can compile the source with debug information
using `cwhip` on PATH; `CDBG_COMPILER` overrides that compiler. See
[debugger controls and limits](https://github.com/chucktilbury/cdbg/blob/main/CDBG.md)
and its [standalone build/test guide](https://github.com/chucktilbury/cdbg/blob/main/doc/BUILD.md).
Compiler tests and each app's own tests remain separate; building the SDK
does not exercise the standalone app suites.

## Troubleshooting

| Symptom | Remedy |
| --- | --- |
| GTK/SourceView configuration fails | Check development packages and GTK >=4.10, then rebuild the SDK with both GUI options ON. |
| `cwhip` or `cedit` is not found | Export the matching installed `bin/` paths in this terminal; check `command -v`. |
| Resource paths point elsewhere | Clear the overrides in step 2 and inspect `cwhip --print-paths`; retain the whole prefix. |
| App rejects the SDK or current syntax | Rebuild and reinstall current compiler/GUI packages together, then rebuild the app in a fresh build directory. |
| Editor cannot open a display | Run in a working graphical session, not a bare SSH/headless terminal. |
| Output does not change | Save the intended file and rebuild successfully before running the matching executable. |
| CMake cannot find Cwhip 0.0.2 | Pass the installed prefix containing `lib/cmake/Cwhip`, not the checkout or `bin/`. |
| Package integrity mismatch after an SDK rebuild | Verify the SDK change and use a fresh app build directory; do not hand-edit generated lock hashes. |

This is a source installation, not a claim that a Cwhip `.deb`, apt repository,
desktop entry, or binary release exists. System package names above are host
prerequisites, not Cwhip packages.
