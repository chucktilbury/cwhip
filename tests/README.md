# Tests

The separate `cdbg_*` cases cover the local GDB-backed GTK debugger prototype,
its structured MI parser, source compilation, controls/inspection, failure
paths and child-process cleanup. See [debugger checks](../doc/CDBG.md#checks).

This directory contains C++ unit/structural tests, CTest case definitions, and
functional Cwhip programs. Build the repository with CMake, then run the full
suite from the repository root:

```sh
cmake -S . -B build
cmake --build build
ctest --test-dir build --output-on-failure
```

`cwhip_gc_runtime_lifecycle` covers precise roots, interior pointers, adaptive
collection, finalizers, and heap-index updates. `cwhip_gc_runtime_stress` runs
the same checks with collection before every allocation. To stress generated
programs too, run `CWHIP_GC_STRESS=1 ctest --test-dir build --output-on-failure -R
'gc|finalizer|inherited_destructors|transitive_virtual_bases'`. Fixtures that
assert finalizer output order force collection explicitly instead of depending
on the allocation budget.

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

`cwhip_cli_diagnostics` checks the compiler/package
[diagnostic contract](../doc/DIAGNOSTICS.md): coded errors, preserved source and
backend detail, stdout/stderr, exit status, and plain text on redirected output
and a PTY with/without `NO_COLOR`. `cwhip-pkg_cli` includes offline Git failure
detail and package rollback checks. Run the targeted checks with
`ctest --test-dir build --output-on-failure -R 'cwhip_cli_diagnostics|cwhip-pkg_cli'`.

`cwhip_developer_setup` runs `test_setup.py` for `scripts/setup`,
`.project_env`, and the `build`/`rebuild`/`clean` helpers. It copies them to a
temporary checkout path with spaces, uses an isolated `HOME`, stubs CMake, Git
and debuggers, and drives the interactive project shell through stdin so it
exits at EOF. It also configures the real source tree once into a temporary
compiler-only build directory. Run it directly with
`python3 tests/test_setup.py [--cmake "$(command -v cmake)"]`.

With GTK tests enabled, `cedit_project_explorer` drives the actual cedit model,
native parented folder chooser and GTK tree activation under private Xvfb/dbus
and isolated HOME/XDG directories. It covers lazy expansion, duplicate focus,
hidden entries, refresh, read errors, non-UTF-8 filenames, symlink loops, stale
results and teardown during enumeration. Its 20,000-file case requires every
entry to arrive, fewer than 1,000 live row widgets and a GUI heartbeat gap below
300ms; it prints measured latency rather than just asserting small-tree output.
The same fixture is used by sanitizer configurations. The permission-denied
case expects an ordinary unprivileged test user.
Folder chooser regressions include acceptance/cancellation, immediate repeated
cancellation, and parent close/shutdown both before and after mapping.
`cwhip_gtk_bindings` separately checks all four `GtkFileDialog` operations,
callback-root release under GC and native finalization after late cancellation
completions; `cedit_dialogs` preserves Open multi-select and Save/Save As
overwrite/cancel coverage.

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
sibling directories such as `cwhip` and `cwhip-workspace` are allowed. Their
output checks still reject references to the source/build roots or their files.

`cwhip_install_incompatible_packages` checks the install-time handling of
packages left in the SDK module directory by other projects. It exercises the
checker directly (report-only default, opt-in quarantine, collision-safe
backups, malformed/unreadable manifests, failed moves, and invalid opt-in
values) and, in complete project builds, performs real installs into private
temporary prefixes and `DESTDIR` trees with stale CVM-like packages, verifying
the warning, the `cwhip-pkg init` failure and its hint, the opted-in repair,
preserved compatible packages, and repeated installs.
