# cdbg local debugger prototype

`cdbg` is a separate Cwhip/GTK/GtkSourceView application, inspired by KDbg's
source-and-inspector layout. This is a working **local GDB/MI2 prototype**, not
an editor mode or a finished debugger. The Cwhip compiler is still `cwhip`.

## Build and launch

Install the same GTK 4.10+ and GtkSourceView 5 development dependencies as
[cedit](CEDIT.md), plus `gdb` at runtime:

```sh
cmake -S . -B build -DCWHIP_GTK=ON -DCWHIP_GTK_SOURCEVIEW=ON
cmake --build build --target cedit cdbg -j4
./bin/cdbg examples/debugger.cw
```

The build stages `<CWHIP_STAGE_PREFIX>/bin/cdbg` (by default `<source>/bin/cdbg`).
Like cedit, it is not currently a `cmake --install` target and does not install
desktop metadata. Compiler-only configurations provide a `cdbg` target which
fails with a clear missing-GUI dependency message.

`cdbg [SOURCE.cw|EXECUTABLE [-- ARGS...]]` opens the GUI in the foreground;
arguments after the target are passed individually to the inferior, without a
shell. With no target, enter a path and click **Load**. A `.cw` source is compiled
asynchronously using `cwhip -g` to an owned temporary executable. Compilation
errors appear in the status line, Console and stderr; user source/output files
are not overwritten. Other paths are treated as prebuilt executables; compile
these with debug information. Temporary compiler outputs are removed when the
session ends or the window closes.

`CDBG_COMPILER` can select a compiler (otherwise cdbg first tries its sibling
`cwhip`, then PATH); `CDBG_GDB` can select the GDB executable (default `gdb` on
PATH). The compiler's existing package discovery and project lock rules apply.
GDB runs with user init files and auto-load scripts disabled. Programs are
launched in cdbg's current working directory.

## Controls and inspection

1. Load a source or executable. Enter a **function** or **file:line** and click
   **Add**. For the example above, `examples/debugger.cw:10` stops before the
   method call; absolute file paths are also accepted. Breakpoints have numeric
   IDs shown in the Breakpoints pane; **Delete ID** removes one.
2. **Run / Continue**, **Step Into**, **Step Over**, **Step Out** and **Pause**
   use GDB's run/continue/step/next/finish/interrupt commands. Controls reflect
   running versus stopped state. **End Session** stops GDB and its owned process
   group; **Load** starts a fresh session.
3. At each stop the source location/current line, Locals / Arguments, Stack,
   and Watches are refreshed. Enter an expression such as `counter` and click
   **Watch**; out-of-scope/evaluation errors are displayed alongside that
   expression. Enter a stack-frame number and **Select Frame** to inspect that
   frame's source, variables and watches.

The Console shows target output and debugger diagnostics. Source and inspector
text are presentation buffers only: edits are not saved or sent to the target.
Watch expressions persist in memory between loads but not across application
restarts. GDB command/result records use numeric correlation tokens, a bounded
queue and a structured parser for nested tuples/lists and C-string escapes;
paths and expressions are MI-quoted rather than executed through a shell.
The GUI polls the async process with a bounded 10 ms wait, processing up to 64
events per callback. Console history is limited to 64 KiB and an individual MI
record to 1 MiB.

## Boundaries

Only local launch is supported: no remote debugging, attach, DAP, LLDB,
multitarget sessions, thread-selection UI, disassembly, register view, or saved
debug configurations yet. Inferior interactive stdin/terminal emulation is not
provided. The stack view is capped at 31 frames. Watch expressions use GDB's
expression language and may have side effects.

Cwhip's current DWARF exposes scalar locals/arguments and pointer-backed class
values; it does not yet describe full class member layouts or provide language
pretty-printers. Those objects therefore appear as pointers/opaque types rather
than an expandable Cwhip object tree. Step Into may enter compiler/runtime
helpers; use Step Out or file:line breakpoints to return to source. LLDB/DAP and
richer Cwhip object inspection are follow-up work, not implemented features.

## Checks

With Xvfb, dbus-daemon and GDB installed:

```sh
ctest --test-dir build -R '^cdbg_' --output-on-failure
```

The suite checks MI quoting/parsing (including fragmented transport input),
real local GDB launch, source compilation with `-g`, source locations,
breakpoints, stepping, locals, watches, stack-frame selection, errors and
teardown under a private GTK display/session bus. Missing GDB is reported
explicitly at configuration time rather than counted as a passing GUI test.
