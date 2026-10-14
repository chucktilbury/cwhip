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
in-scope Cwhip locals when their locations are available. Visibility is not
guaranteed for every value or point in a program: compiler-generated
temporaries and optimized-out or out-of-scope locals are not inspectable, and
class fields are not necessarily shown as source-level members. This is
ordinary debugger support for the generated executable, not an IDE-specific
debugger integration.

Stepping follows GDB/LLDB's source-level rules: Step Into may enter runtime C
checks before a Cwhip method, and returning can stop on the caller's existing
call line. Distinct instruction positions on one source line are not
necessarily a lost step. No-op virtual-dispatch thunks are omitted; necessary
receiver-adjustment thunks tail-transfer to the implementation and carry
artificial/trampoline DWARF metadata with line-zero instructions. This keeps
method returns out of anonymous dispatch frames without function bounds.
Rebuild older executables with `-g` to pick up this compiler change.

For compiler tracing, use `-t`/`--trace` with `scanner`, `parser`, `ast`, or
`symbols`; targets can be comma-separated or repeated. AST and symbol-table
traces go to standard output. `-v` increases compiler verbosity, with `-vv`
showing resolved paths and Clang commands and `-vvv` adding phase timings;
verbose diagnostics go to standard error. See [cwhip(1)](cwhip.1) for the full
CLI reference.
