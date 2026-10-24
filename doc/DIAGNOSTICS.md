# Diagnostic contract and code registry

This is the canonical policy for incremental diagnostic work in `cwhip`,
`cwhip-pkg`, `cedit`, and `cdbg`. It is not a claim that every legacy message
already follows it. Each tool owns its implementation and local code
allocations; coordinated application allocations are recorded below.

## Text contract

User-facing CLI diagnostics use this plain-text header:

```text
tool: severity[CODE]: explanation
```

The tool is its executable name; severity is lowercase `error`, `warning`,
`note`, or `help`. Codes are a tool namespace followed by four decimal digits.
An error explains the failed operation, not merely "something went wrong".
Keep relevant paths, option names, package versions, exit statuses, and
underlying causes. Add help only when that action applies to the actual failure.
Do not guess an SDK prefix, project root, package, or build directory and then
report success. An intentional selection fallback must be visible.

Source locations, excerpts, carets, notes, and detailed subprocess output
follow or accompany the header when available. Preserve useful upstream
wording; do not reduce compiler, Git, GDB, or CMake failures to a generic
summary. Multiline detail is not required to repeat the header. This is a
human-readable contract, not a machine-readable wire format.

Normal results (including requested help, version, path listings, shell
exports, package plans, and build confirmations) go to stdout. Diagnostics,
usage accompanying an error, and diagnostic detail go to stderr. Success
returns 0; failure returns nonzero. Use 2 for usage where practical, but keep
documented/historical exit behavior during incremental adoption. A warning
alone does not imply failure. GUI operations can report failure while keeping
the application/session alive; window-close status is not an operation result.

Color is never required to understand a diagnostic. Honor `NO_COLOR` when
present, including an empty value, and disable color when diagnostic output is
redirected. The compiler/package headers currently contain no ANSI sequences,
even on a terminal. The compiler passes `-fno-color-diagnostics` to its backend
for redirected stderr or `NO_COLOR`; package Git calls disable `color.ui`.
Upstream detail is otherwise retained, not stripped or reformatted; arbitrary
replacement backends must honor their own color options.

Use **SDK prefix** for the installation root, **project root** for the selected
project, **package** for an imported/versioned package, and **build directory**
for generated build files. Existing filenames, environment variables, command
flags, and path-listing labels are not renamed by this contract.

## Namespaces and category ranges

| Tool | Namespace |
|---|---|
| `cwhip` | `CWHIP` |
| `cwhip-pkg` | `PKG` |
| `cedit` | `CEDIT` |
| `cdbg` | `CDBG` |

| Numeric range (within each namespace) | Boundary |
|---|---|
| 0001-0999 | CLI usage and startup |
| 1000-1999 | Domain/source/document operations |
| 2000-2999 | SDK/resources/configuration discovery |
| 3000-3999 | Subprocess/session/transport/protocol |
| 9000-9999 | Unclassified failures and cleanup |

Other ranges are unallocated. Do not reuse a global illustrative code such as
`SDK001`: SDK categories belong to each tool's namespace. Codes identify stable
failure boundaries, not every sentence or parser error. Keep an allocated
code's meaning; add a code for a new boundary rather than changing its meaning.
Message text and contextual detail may improve without changing the code.
These broad codes are not yet a promise of per-error classification.

### Implemented compiler and package codes

| Code | Meaning | Exit |
|---|---|---|
| CWHIP0001 | CLI parsing, unsupported inputs/options, option combinations | 2 |
| CWHIP0002 | Cannot open/resolve an input file (historical exit preserved) | 2 |
| CWHIP1001 | Source-located `DiagnosticError` at the CLI boundary | 1 |
| CWHIP2001 | Resource/project-path resolution or required backend SDK resource missing | 1 |
| CWHIP2002 | Configured Clang missing; explicitly warn before selecting `clang` via PATH | Warning; operation determines exit |
| CWHIP3001 | Compiler backend cannot start or fails to compile/link | 1 |
| CWHIP9001 | Remaining driver exceptions, including output/metadata I/O and output collisions | 1 |
| PKG0001 | Argument parser usage failure (including subcommands) | 2 |
| PKG0002 | Python version too old, when the script can be parsed | 2 |
| PKG1001 | Package/project/preferences validation or operation rejected (`CwhipkgError`) | 1 |
| PKG1002 | Unwrapped filesystem/OS failure at the package command boundary | 1 |
| PKG1003 | Invalid or reserved new-project name | 1 |
| PKG1004 | Unsafe/existing project destination or missing destination parent | 1 |
| PKG1005 | Missing, unsafe, oversized, corrupt or unsupported project template | 1 |
| PKG2001 | Selected SDK standard package directory missing | 1 |
| PKG2002 | One or more required doctor checks failed (per-check remedies on stdout) | 1 |
| PKG2003 | Doctor SDK override/configuration selection invalid or unreadable | 1 |
| PKG2004 | Package SDK ABI absent or incompatible; migrate source and rebuild native artifacts (for leftovers in the SDK module directory, see INSTALLATION.md "Leftover packages from other projects") | 1 |
| PKG3001 | Git missing or Git command failure (with context/status and both captured streams) | 1 |
| PKG3002 | Template archive download failed or exceeded the transfer limit | 1 |
| PKG9001 | Rollback could not restore configuration or remove an installed package | Original failure remains nonzero |
| PKG9002 | New-project staging cleanup failed (staging path retained in diagnostic) | 1 |

### Coordinated application allocations

These allocations are owned by the separate application repositories, not
implemented by this compiler/package change. Consult their local diagnostic
guides for adoption coverage and exit behavior.

| Code | Owner-provided boundary |
|---|---|
| CEDIT0001 | Setup usage/executable-path startup |
| CEDIT0002 | Background startup readiness |
| CEDIT1001 | Document open |
| CEDIT1002 | Document save |
| CEDIT2001 | SDK/settings configuration |
| CEDIT2002 | Project metadata/folder operations |
| CEDIT3001 | Launcher/process and setup/CMake subprocess failures |
| CDBG0001 | CLI usage |
| CDBG1000 | Rejected operation |
| CDBG1001 | Source/target load |
| CDBG2001 | Saved-state warning |
| CDBG3001 | Compiler boundary |
| CDBG3002 | GDB session/command |
| CDBG3003 | Transport/PTY |
| CDBG3004 | Protocol/limits |
| CDBG9001 | Cleanup |

## Adoption boundaries and compatibility

The compiler's `DiagnosticError::what()` and `formatDiagnostic()` retain their
existing `file:line:column: error: explanation` format. Only the CLI reporter
adds a summary above that source line. For example, previously:

```text
example.cw:2:2: error: unexpected character
```

Now, on stderr with exit 1:

```text
cwhip: error[CWHIP1001]: source compilation failed
example.cw:2:2: error: unexpected character
```

The legacy line is intentionally neither indented nor prefixed, so consumers
can still recognize source locations. Existing multiline notes/excerpts/carets
inside source diagnostics are emitted intact. The frontend does not currently
generate a source excerpt for every error; this change does not invent one.
Library consumers still receive the same exception type and `what()` text.

Driver errors now have coded headers. For example:

```text
cwhip: error[CWHIP0002]: cannot open input file: missing.cw
```

Backend detail is emitted live, before the failure summary; both backend
stdout and stderr are directed to compiler stderr so diagnostic output cannot
look like a normal build result. The summary names the selected compiler,
operation, and exit status. An explicit `CC` failure never retries another
compiler. The existing configured-Clang-to-PATH fallback remains, now with
CWHIP2002 when compilation is requested; `--print-paths` already describes
the selection origin and `--check-only` does not invoke a backend.

Package command errors and argparse errors use coded headers. Successful
`env` output remains shell exports only, and successful plans/listings are
unchanged. A command that fails after printing a plan may still have that plan
on stdout; it does not print an installation-success confirmation. Rollback
errors are additional diagnostics and do not replace the original failure.
Git failure detail preserves both captured streams (stdout then stderr);
relative interleaving cannot be recovered from separate captures.
`doctor` prints required/optional check results and remedies to stdout; failed
required checks also emit PKG2002 on stderr. Optional GUI checks do not fail
the command. Invalid SDK configuration additionally emits PKG2003.

Legacy boundaries intentionally retained:

- Compiler tracing, timings, verbosity, AST/symbol dumps, successful build
  output, path-listing labels (including `prefix`), runtime diagnostics, and
  CMake configuration diagnostics are not rewritten.
- Some source-located SDK/package failures (for example, loading the String
  builtin) still use CWHIP1001. Module-directory validation and other
  unclassified driver exceptions still use CWHIP9001. Package TOML read errors
  wrapped as `CwhipkgError` still use PKG1001 rather than PKG1002.
- Existing best-effort temporary-file cleanup and removal of empty rollback
  parent directories are unchanged; this is not a cleanup-reliability rewrite.
- Unexpected Python programming errors are not swallowed by a catch-all.
  Python must still be able to parse the script to report PKG0002.

Structured/JSON output, per-parser-error codes, broad wording changes, and
unrelated command/features are future work, not part of this adoption.

## Coverage and installation

`cwhip_cli_diagnostics` checks representative usage, source/include/semantic,
SDK, driver-I/O, and backend failures; stdout/stderr and exit status; preserved
upstream source/caret detail; successful help/build/env; and plain text on
redirected output and a PTY with `NO_COLOR` unset, empty, or set.
`cwhip-pkg_cli` covers package behavior and Git-detail preservation.
Compiler unit tests preserve the legacy source API and multiline reporter
detail. Existing include-search/multi-input tests exercise compatibility.

This file is linked from the documentation index and installed through the
existing recursive Markdown documentation rule as
`<docdir>/doc/DIAGNOSTICS.md`. The install-layout check requires that file in
both staged and relocated installations.
