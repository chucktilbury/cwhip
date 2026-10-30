# GTK/SourceView repro bodies

These `.cw` fragments are the SourceView programs used by
`tests/test_gtk_bindings.py`. They are not standalone: the driver prepends the
native `F` / `Keys` bridge from `tests/gtk_bindings_fixture.c`.

| File | Binding case |
| --- | --- |
| `sourceview_editing.cw` | language, highlight, find/replace, undo, margin, range edits |
| `sourceview_allocation.cw` | notebook allocation / resize |
| `shortcuts_dispose.cw` | shortcut callbacks that dispose view/window |

Edit here, then re-run `ctest -R cwhip_gtk_bindings`.
