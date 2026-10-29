# Debugging Cwhip programs

The compiler's `-g`/`--debug` option emits DWARF debug information for the
generated executable and LLVM IR. Use GDB or LLDB on the executable:

```sh
./bin/cwhip -g tests/functional/positive/positive_debug_info.cw \
  -o build/positive_debug_info
gdb -q build/positive_debug_info
# or:
lldb build/positive_debug_info
```

DWARF maps generated instructions back to Cwhip source lines and can expose
in-scope Cwhip locals when their locations are available. With current `-g`,
user class types include named member DWARF that matches the LLVM `%Class`
layout (including runtime metadata slots and inherited fields), so GDB and
[cdbg](https://github.com/chucktilbury/cdbg) can show fields such as
`Counter {value: 7}` and evaluate watches like `worker.value`. Visibility is
still not guaranteed for every value: compiler-generated temporaries and
optimized-out or out-of-scope locals are not inspectable. This is ordinary
debugger support for the generated executable, not an IDE-specific debugger
integration.

Stepping follows GDB/LLDB's source-level rules: a raw Step Into may enter
runtime C checks before a Cwhip method, and returning can stop on the caller's
existing call line. **cdbg** finishes out of those runtime frames after Step
Into until a `.cw` stop (see cdbg's CDBG.md). Distinct instruction positions on
one source line are not necessarily a lost step. No-op virtual-dispatch thunks
are omitted; necessary receiver-adjustment thunks tail-transfer to the
implementation and carry artificial/trampoline DWARF metadata with line-zero
instructions. This keeps method returns out of anonymous dispatch frames
without function bounds. Rebuild older executables with `-g` to pick up class
member DWARF and thunk metadata.

For compiler tracing, use `-t`/`--trace` with `scanner`, `parser`, `ast`, or
`symbols`; targets can be comma-separated or repeated. AST and symbol-table
traces go to standard output. `-v` increases compiler verbosity, with `-vv`
showing resolved paths and Clang commands and `-vvv` adding phase timings;
verbose diagnostics go to standard error. See [cwhip(1)](cwhip.1) for the full
CLI reference.
