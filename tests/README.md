# Tests

This directory contains C++ unit/structural tests, CTest case definitions, and
functional Cwhip programs. From the repository root, start the project shell,
then build and run the full suite in its `build/` working directory:

```sh
scripts/setup debug
build
ctest --output-on-failure
exit
```

`cwhip_gc_runtime_lifecycle` covers precise roots, interior pointers, adaptive
collection, finalizers, and heap-index updates. It also checks that a caught
message is borrowed from the exception frame rather than retained until
process exit. `cwhip_gc_runtime_stress` runs the same checks with collection
before every allocation. To stress generated programs too, run
`CWHIP_GC_STRESS=1 ctest --test-dir build --output-on-failure -R
'gc|finalizer|inherited_destructors|transitive_virtual_bases'`.
`cwhip_compile_and_run_string_bytes_across_collection` sets that variable
itself: a finalizer rewrites a live string during a range copy, `trim`, and
`split`, and the results must still be the bytes from the start of each call.
Fixtures that assert finalizer output order force collection explicitly
instead of depending on the allocation budget.

## Adding an integration test

Integration tests are discovered from individual
`cases/*.cmake` files. Add a `positive_*.cw` or `negative_*.cw` source
under `functional/positive/` or `functional/negative/`, then add a case file setting
`CASE_NAME` (the CTest name) and `CASE_FIXTURE` (the source basename).

For a successful compile-and-run case, set `CASE_EXPECTED_OUTPUT_FILE` to a
neighboring `.stdout` file containing the exact output, including its final
newline. For a rejected program, set `CASE_EXPECTED_DIAGNOSTIC` to the expected
diagnostic regular expression. Optional flags include
`CASE_REQUIRE_GC_ROOTS`, `CASE_REQUIRE_VIRTUAL_DISPATCH`,
`CASE_EXPECT_WARNING`, `CASE_EXPECT_RUNTIME_FAILURE`,
and `CASE_EXPECT_RUNTIME_DIAGNOSTIC`.

Module tests set `CASE_MODULE_ROOT` to a fixture directory under
`functional/modules/`, copied into a private module root. Set
`CASE_MODULE_ROOT_SOURCE` to choose how the root is selected: `cli` (the
default, via `-M`), `env`, `default`, `home`, or `stdlib`.
`CASE_MODULE_ROOT_MISSING` leaves the selected root absent.
`CASE_MODULE_DECOY` copies a fixture into lower-priority roots to verify
precedence. `CASE_MODULE_PACKAGES` populates the discovered project's package directory
from the shared package fixtures and compiles the source from that isolated
project, keeping project lock discovery out of the developer's working tree.

Other useful options are `CASE_ARGUMENTS`, `CASE_NO_RUN`,
`CASE_NO_SOURCE`, `CASE_EXPECT_COMPILE_OUTPUT`, and
`CASE_REJECT_COMPILE_OUTPUT`. Output expectations may use `<MODULE_ROOT>`,
`<PROJECT_DIR>`, and `<WORK_DIR>` placeholders. Every case runs in its own
work directory with the `CWHIP_*` path variables cleared. `CASE_DEBUG_INFO`
adds a `-g` case that checks generated DWARF data and, when GDB or LLDB is
installed, exercises a breakpoint and local-variable inspection. See a
neighboring case file and its runner for details. Reconfigure after adding a
case so CMake discovers it; no central test list needs editing.

## Unit and CLI tests

`test_switch_cases.cpp` covers switch syntax/AST, compile-time labels,
representability, overlap diagnostics, scopes, reachability, and control-flow
restrictions. `cwhip_switch_execution` compiles and runs dispatch across all
eight integer types at both `-O0` and `-O2`, including ascending/descending
full-width intervals, grouped/mixed ranges, cross-class enum endpoints,
single selector evaluation, `next` chains, nested control flow, and
return/exception/finally/destruction behavior. Run these with
`ctest --test-dir build --output-on-failure -R
'cwhip_(unit_and_functional|switch_execution)$'`.
`CWHIP_GC_STRESS=1` can also be used with the switch execution test.

`test_range_cases.cpp` covers first-class `range<T>` types, all integer
endpoint-type pairs, precedence, read-only bindings (including inline aliases),
and rejected endpoints/consumers. `cwhip_range_execution` runs all eight
integer widths at both `-O0` and `-O2`, each normally and with
`CWHIP_GC_STRESS=1`. It covers full-width membership, safe terminal steps,
snapshot evaluation order/count, variable mutation, parameter/field/return/
callback and collection round trips, cleanup and nested control flow,
inclusive list/String/buffer copies, reversal, singleton/empty/bounds errors,
UTF-8 failures, and preservation of colon slices and switch grouping.
When GDB is available it also verifies direct and boxed range debugger displays
against a real generated program.
`cwhip_gc_runtime_lifecycle`/`cwhip_gc_runtime_stress` also check direct range
payload tracing and stable numeric-v2 tags.

```sh
ctest --test-dir build --output-on-failure \
  -R 'cwhip_(unit_and_functional|range_execution|switch_execution|numeric_execution|gc_runtime_.*)$'
```

`cwhip_cli_diagnostics` checks the compiler/package
[diagnostic contract](../doc/DIAGNOSTICS.md): coded errors, preserved source and
backend detail, stdout/stderr, exit status, and plain text on redirected output
and a PTY with/without `NO_COLOR`. `cwhip-pkg_cli` includes offline Git failure
detail and package rollback checks. Run the targeted checks with
`ctest --test-dir build --output-on-failure -R 'cwhip_cli_diagnostics|cwhip-pkg_cli'`.

`cwhip_developer_setup` runs `test_setup.py` for `scripts/setup`,
`.project_env`, the `build`/`rebuild` Bash functions, and the retained `clean`
script. It copies the shell files to a temporary checkout path with spaces,
uses private HOME/XDG/TMPDIR without inheriting caller project variables, stubs
CMake/Git/cdbg, and drives a real interactive shell through stdin.
It checks clean ordering/failure, argument rejection, cached/default build
types, function targets/exit status and shell survival. With `--cmake`, it
also configures/builds/rebuilds a tiny real CMake fixture in that private copy.
Run it directly with
`python3 tests/test_setup.py [--cmake "$(command -v cmake)"]`.

With GTK tests enabled, `cwhip_gtk` checks widgets (including tree models),
callbacks, single-instance forwarding and SDK consumers under private Xvfb/dbus
and isolated HOME/XDG directories.
`cwhip_gtk_bindings` checks all four `GtkFileDialog` operations,
callback-root release under GC and native finalization after late cancellation
completions, chooser accept/cancel/overwrite, SourceView language highlighting,
editing/search/undo/redo, file round trips, notebook buffers, allocations and
shortcut disposal. Application-level tests live in the standalone
[cedit](https://github.com/chucktilbury/cedit) and
[cdbg](https://github.com/chucktilbury/cdbg) repositories.
Direct binding fixtures also check native view settings and TOML parsing/merging,
atomic saves, concurrent-edit rejection and pending-save shutdown behavior.

Parser and semantic fixtures consumed by `cwhip_tests` use a
`<fixture>.cw.json` file beside the `.cw` file with `friendly_name`,
`expected_diagnostic` (empty for accepted input), and an `enabled` boolean.
Focused C++ structural assertions belong in a `test_*_cases.cpp` group using
`TestGroupRegistration` from `test_cases.hpp`; CMake discovers these groups.
Command-line integration fixtures live under `functional/cli/`; the shared
runner accepts a `CASE` selector so each scenario has an independent CTest
result.

The install-layout tests stage with `DESTDIR`, relocate an installed prefix,
and exercise installed package imports, `cwhip-pkg init`, and automatic `String`
availability and inheritance. They also move `share/cwhip/builtin/` out of the
prefix to verify `CWHIP_BUILTIN_DIR` lookup and missing-resource diagnostics.
Initialized projects are checked for `cwhip-pkg.toml` and a generated `cwhip-pkg.lock`
that locks standard modules without listing `String` as a package. Tests use
isolated HOME/XDG directories and exercise home-package lookup without relying
on the developer's configuration.
The install-prefix test checks the fresh `$HOME/opt/cwhip` default (including
HOME paths with spaces), explicit and cached prefix preservation, CMake's
`CMAKE_INSTALL_PREFIX` environment selection where supported, and invalid
HOME diagnostics. The install-layout test verifies that a real install using
`--prefix` registers that actual prefix, not the configured default.

`cwhip_install_path_boundaries` checks canonical source/build containment before
temporary directories are created, including symlinks and normalized paths.
Install tests require `TMPDIR` (or `/tmp`) outside both trees; similarly prefixed
sibling directories such as `cwhip` and `cwhip-consumer` are allowed. Their
output checks still reject references to the source/build roots or their files.

`cwhip_install_incompatible_packages` checks the install-time handling of
packages left in the SDK module directory by other projects. It exercises the
checker directly (report-only default, opt-in quarantine, collision-safe
backups, shell-quoted restore commands, refused repairs through symlinked
packages or backup paths, malformed/unreadable manifests, failed moves, and invalid opt-in
values) and, in complete project builds, performs real installs into private
temporary prefixes and `DESTDIR` trees with stale CVM-like packages, verifying
the warning, the `cwhip-pkg init` failure and its hint, the opted-in repair,
preserved compatible packages, and repeated installs.
