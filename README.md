# Cwhip compiler

New to Cwhip? Start with the [getting started guide](doc/GETTING_STARTED.md)
for a source-first SDK install, a working project, language basics, packages,
and the optional standalone editor/debugger.

External projects can consume the [installed, relocatable CMake SDK](doc/CMAKE-SDK.md)
without a compiler checkout. The complete prefix, not just its executables,
is the supported prototype distribution boundary.

Cwhip is a statically typed language with classes, inheritance, managed strings
and collections, exceptions, and native bindings. The name comes from the
coachwhip snake: fast and nonvenomous, a fitting image for a small, nimble
compiler. The bug-eating reference is a playful metaphor for the snake's prey
and finding software bugs, not the goad/punishment or violent sense of “whip.”
The compiler frontend is C++17 and the runtime is written in C. The compiler
command is `cwhip`; CPL and CWPL are optional informal shorthands. This
repository contains the compiler, runtime, standard-library packages, and tests.
The canonical project website is [cwhip.org](https://cwhip.org).
The user documentation is indexed in [`doc/README.md`](doc/README.md); the
[language reference](doc/LANGUAGE-REFERENCE.md) and [grammar](doc/GRAMMAR.md)
describe the implemented language.

## Build and test

Configure and build the compiler and runtime with CMake, then run the test
suite with CTest:

```sh
cmake -S . -B build -DCMAKE_BUILD_TYPE=Debug
cmake --build build -j4
ctest --test-dir build --output-on-failure
```

The build places the compiler at `bin/cwhip`. It stages the runtime, String
builtin, and standard modules beside it in the repository's `lib/`, `include/`,
and `share/` directories. Cwhip source files use the `.cw` extension. To
compile and run a program:

```sh
./bin/cwhip path/to/program.cw -o build/program
./build/program
```

The compiler, runtime API, headers, resources, package tooling, and GTK
application IDs consistently use Cwhip names. This is a clean naming break:
previously named executables, build targets, source extensions, package
manifests, environment variables, and editor/project paths are not aliases.
Existing user files are left in place and are not migrated automatically; see
[`doc/INSTALLATION.md`](doc/INSTALLATION.md#breaking-path-changes) before
upgrading. See
[`doc/cwhip.1`](doc/cwhip.1) for compiler options and
[`doc/README.md`](doc/README.md) for all language and library documentation.
The compiler's [test guide](tests/README.md) explains the functional fixtures
and how to add cases; runnable language examples are in
[`doc/EXAMPLES.md`](doc/EXAMPLES.md).
See [testing infrastructure](doc/TESTING.md) for sanitizers, documentation
programs, CI, coverage, and fuzzing.

## Install

```sh
cmake -S . -B build
cmake --build build
cmake --install build
```

Without an explicit prefix, a fresh compiler/SDK configuration installs to
`$HOME/opt/cwhip`. Use `-DCMAKE_INSTALL_PREFIX=/usr/local` (or another
absolute path) to select a different location; for new build directories,
CMake 3.29 and newer also honors the `CMAKE_INSTALL_PREFIX` environment
variable. Existing build directories keep their cached prefix on reconfigure.
An install-time `cmake --install build --prefix /path` overrides the configured
prefix for that installation.

The installed compiler locates its runtime, builtin, standard modules, and
documentation relative to its installation prefix. CMake install rules honor
`DESTDIR` for staged installations. See
[`doc/INSTALLATION.md`](doc/INSTALLATION.md) for the complete installed layout,
resource overrides, package search order, and
[project version policies](doc/INSTALLATION.md#project-module-version-selection).
The `cwhip-pkg` package manager provides direct dependencies, a reproducible
lockfile, and complete dependency installation with explicit network consent:

```sh
cwhip-pkg init
cwhip-pkg add OWNER/REPO --yes
cwhip src/app.cw
```

Use `cwhip-pkg doctor` for read-only SDK/host checks and
`cwhip-pkg new MyApp` to download the public project template without Git
history, rename its project/executable, and create a ready-to-build starter.
`new` supports `--ref` and offline `--source` archives/directories; see
[project creation](doc/INSTALLATION.md#create-a-project).

No environment activation is needed. The manifest schema is in
[`doc/PACKAGES.md`](doc/PACKAGES.md), and command behavior is documented in
[`doc/INSTALLATION.md`](doc/INSTALLATION.md#project-package-manager-cwhip-pkg).

## Repository layout

| Path | Contents |
| --- | --- |
| `src/` | Compiler front end, LLVM IR generator, command-line driver, and runtime |
| `include/` | Runtime C headers and compiler headers |
| `builtin/` | Built-in `String` class source |
| `stdlib/` | Versioned standard-library packages |
| `examples/` | Runnable `.cw` examples, including the [cedit and its build targets](doc/CEDIT.md) |
| `tools/cdbg/` | [Local GDB-backed cdbg prototype](doc/CDBG.md), written in Cwhip with GTK |
| `tests/` | Compiler and editor tests |
| `doc/` | User documentation |
| `build/`, `bin/`, `lib/`, `share/` | Local CMake build outputs |

The standard library's package layout and contribution process are described
in [`stdlib/README.md`](stdlib/README.md); its public APIs are in
[`doc/STDLIB.md`](doc/STDLIB.md).

## Implemented language highlights

- Signed integer types are `int8`, `int16`, `int32`, and `int64`; unsigned
  types are `uint8`, `uint16`, `uint32`, and `uint64`; floating types are
  `fp32` and `fp64`. Integer literals support decimal and `0x` hexadecimal
  forms with checked ranges. The string type keyword is `strg`; double-quoted
  strings support `\e`. `format("value {}", value)` returns `strg`, and
  `print("{value:08X}", value=42)` formats directly. Literal templates support
  positional/named fields, alignment, width, decimal/hex integers, and
  ASCII-only `c`; string-literal calls are no longer supported.
- Numeric variables and fields support `+=`, `-=`, `*=`, and `/=`; integer
  types also support `%=` compound assignment.
- Anonymous class enums declare immutable signed 64-bit `int64` constants
  accessible as `Class.NAME` or `object.NAME`, without creating a new type or
  per-instance storage.
- Integral `switch` statements support constant alternatives, inclusive ranges,
  a final optional `default`, and explicit `next` continuation without implicit
  fallthrough. See [constant switches](doc/LANGUAGE-REFERENCE.md#constant-switches).
- Base constructors use dotless `super Base(args)` syntax; virtual bases use
  `super virtual Base(args)` or `virtual super Base(args)`.
- Collection type keywords are `list` and `dict`; `array` and `map` are
  ordinary identifiers. The `system` standard package includes `Sys.Glob`.

These are brief feature summaries, not a substitute for the references linked
above.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE).
