# Cwhip Programming Language examples

These are stand-alone programs that demonstrate practical aspects of the **Cwhip** language.

The [cedit editor](https://github.com/chucktilbury/cedit) and
[cdbg debugger](https://github.com/chucktilbury/cdbg) live in their own repositories
and build against the installed Cwhip SDK; they are not examples in this tree.

## Switches and integer ranges

Start with these four small programs, in order:

| File | Demonstrates |
| --- | --- |
| `switch_delivery.cw` | Class enum endpoints, grouped forward/reverse case intervals, and explicit `next` |
| `range_snapshots.cw` | Endpoint evaluation order/count, changing source variables, and the zero-count trap |
| `range_windows.cw` | Typed parameters/returns, storage, integer promotion, and direction-independent membership |
| `range_slices.cw` | Inclusive list/String/buffer copy slices, shared nested values, and catchable errors |

Build any example with `cwhip examples/range_snapshots.cw -o /tmp/range_snapshots`
and run `/tmp/range_snapshots` from the repository root, using your built or
installed compiler. See [the walkthrough and expected output](../doc/EXAMPLES.md#switches-and-integer-ranges)
and [the range specification](../doc/LANGUAGE-REFERENCE.md#integer-ranges).
