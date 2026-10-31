# cwhip

`cwhip` is the Cwhip compiler: a statically typed language with classes,
inheritance, managed strings and collections, exceptions, and native bindings.
The frontend is C++17 and the runtime is C. Source files use the `.cw`
extension. Source: [github.com/chucktilbury/cwhip](https://github.com/chucktilbury/cwhip).
The project website is [cwhip.org](https://cwhip.org).

This directory contains the compiler in `src/`, runtime headers in `include/`,
the built-in `String` class in `builtin/`, standard-library packages in
`stdlib/`, runnable examples in `examples/`, tests in `tests/`, and user
documentation in `doc/`. Local CMake outputs use `build/`, `bin/`, `lib/`, and
`share/`.

With a current checkout, run `scripts/setup [--clean] [debug|release|profile]`
from the repository, then `build` in the project shell. Use `rebuild` for a
clean-first build, or `clean` to remove generated outputs; exit the shell before
running setup again. The compiler is `bin/cwhip`.

```sh
scripts/setup debug
build
./bin/cwhip path/to/program.cw -o build/program
./build/program
ctest --output-on-failure
exit
```

- [Your first program](doc/FIRST-PROGRAM.md)
- [Getting started](doc/GETTING_STARTED.md)
- [Documentation index](doc/README.md)
- [Language reference](doc/LANGUAGE-REFERENCE.md)
- [Standard library](doc/STDLIB.md)
- [Build and installation](doc/INSTALLATION.md)
- [Installed CMake SDK](doc/CMAKE-SDK.md)
- [Package manifests](doc/PACKAGES.md)
- [Compiler man page](doc/cwhip.1)
- [Testing](doc/TESTING.md)

The [cedit editor](https://github.com/chucktilbury/cedit) and
[cdbg debugger](https://github.com/chucktilbury/cdbg) are standalone
applications built against the installed SDK, not compiler targets.

Without an explicit prefix, a fresh configuration installs to `$HOME/opt/cwhip`.
See [installation](doc/INSTALLATION.md) for layout, `cwhip-pkg`, and breaking
path changes. This is a clean naming break: old executable, path, and package
names are not aliases.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE).
