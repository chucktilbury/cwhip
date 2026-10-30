# Test repro programs

Checked-in programs that were (or would otherwise be) generated inside Python
test drivers. Use them for hand debugging and failure reproduction without
hunting through string literals.

## Layout

| Path | Role |
| --- | --- |
| `*.cw` + `manifest.json` | Standalone language repros; `cwhip` then run |
| `gtk/*.cw` | GTK/SourceView bodies loaded by `tests/test_gtk_bindings.py` (need the native fixture) |

## Standalone

```sh
./bin/cwhip tests/repro/numeric_boundaries.cw -o /tmp/numeric_boundaries
/tmp/numeric_boundaries

./bin/cwhip tests/repro/range_control.cw -o /tmp/range_control
/tmp/range_control
```

CTest label `repro` compiles and checks stdout against `manifest.json`:

```sh
ctest --test-dir build -L repro --output-on-failure
```

## GTK bodies

`gtk/sourceview_editing.cw`, `gtk/sourceview_allocation.cw`, and
`gtk/shortcuts_dispose.cw` are the SourceView cases formerly embedded in
`test_gtk_bindings.py`. That driver still prepends the native `F` / `Keys`
bridge and links `tests/gtk_bindings_fixture.c`. Prefer:

```sh
ctest --test-dir build -R cwhip_gtk_bindings --output-on-failure
```

## Policy

- **`examples/`** — curated demos for teaching; readable without a test harness.
- **`tests/functional/`** — compiler positive/negative corpus (keep micro-negatives there).
- **`tests/repro/`** — peel runtime-generated driver programs into real files when
  you need to open, edit, and re-run them by hand. Exhaustive generative coverage
  can stay in the Python driver; keep a curated subset here.

Do not copy the same program into both `examples/` and `repro/` — pick one home.
