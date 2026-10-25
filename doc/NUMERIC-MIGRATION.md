# Numeric SDK migration (0.0.2 / numeric-v2)

The fixed-width numeric migration is intentionally source- and ABI-incompatible.
Rebuild applications and native packages; do not mix files from different SDK
prefixes. FP8, FP16, BF16, parser recovery, and new library facilities are deferred.

## Source and API replacements

`int`, `uint`, and `float` are target-checked aliases for `int32`, `uint32`, and
`fp32`; they do not introduce new numeric identities or widths. The old
`unsigned` spelling remains reserved and rejected. The complete fixed-width
numeric set is `int8`, `uint8`, `int16`, `uint16`, `int32`, `uint32`, `int64`,
`uint64`, `fp32`, and `fp64`.

This replacement alone does not preserve every expression:

- Unsuffixed integer literals choose the smallest fitting signed width; `u`/`U`
  literals choose the smallest fitting unsigned width. Widen an operand before
  arithmetic when the intermediate needs a wider range.
- Ordinary floating literals initially round to fp32. Use `0.1f64` for direct
  fp64 rounding, not `fp64(0.1)`, which widens an already rounded fp32 value.
- Lists/dicts preserve exact numeric tags. `[1][0] as int64` fails because `1`
  is int8. Use `[int64(1)]` when storing int64, or extract int8 before converting.
- Integer casts reduce modulo the destination width; text parsing does not.
  Floating-to-integer conversion truncates first, then checks range.

The bundled stdlib keeps former integer counts, indices, file offsets,
descriptors, GUI tokens/coordinates, SQL integer values, and enum constants
as **int64**. Clock milliseconds/seconds remain **uint64**; math and SQL real
values remain **fp64**. Math constants now use direct fp64 literals.
`String.byteAt(int64)` retains its uint64 public/native result.
Buffer element expressions return **uint8**, with modulo-256 writes; buffer
lengths and source indices remain int64. Non-language control interfaces
(C `main` arguments/results, bool native results, runtime status codes) are not
mechanically narrowed or widened.

### Checked String parsers

| Removed method | Replacement |
|---|---|
| `toInt()` | `toInt64()` (or `toInt8()`, `toInt16()`, `toInt32()`) |
| `toUnsigned()` | `toUint64()` (or `toUint8()`, `toUint16()`, `toUint32()`) |
| `toFloat()` | `toFp64()` (or `toFp32()`) |

All ten destination-named methods return that exact type. Integer parsers accept
decimal digits with an optional sign (unsigned rejects `-`, including `-0`).
They check textual range before narrowing and never wrap. Floating parsers accept
decimal/exponent notation, parse directly with `strtof` or `strtod`, preserve
negative zero, and accept nonzero subnormals. They reject infinity/NaN/hexadecimal
spellings, overflow, nonzero text rounding to zero, malformed text, whitespace,
partial parses, and strings longer than 127 bytes. Failures raise catchable
language exceptions. Native code must preserve the supported floating environment
and C numeric locale.

Formatting retains existing categories: decimal for all integer widths, `x`/`X`
and `c` plus padding/alignment for integer widths, and `%.15g` for both floating
widths (fp32 bits are decoded before widening for display). This is a human
display contract, **not** lossless floating serialization. Applications requiring
round-trip persistence must not assume `format` preserves every fp64 bit.

## Compatibility and native interfaces

The installed SDK version is **0.0.2**, discovered with
`find_package(Cwhip 0.0.2 EXACT CONFIG REQUIRED)`.
`Cwhip_SDK_ABI` in CMake and `CWHIP_SDK_ABI` in `<cwhip/Stdlib.h>` are
`"numeric-v2"`; `CWHIP_SDK_VERSION` is `"0.0.2"`.

Every package manifest, including source-only packages, must declare:

```toml
[package]
sdk-abi = "numeric-v2"
# name, version, source, export follow as before
```

Only set this after migrating source and rebuilding any native archive against
the new headers. Missing or different identifiers are rejected by both compiler
and package manager, with migration guidance (`PKG2004` in the package tool).
Regenerate project locks with `cwhip-pkg`: their content hashes change with the
migrated manifests, sources, and native archives. The graph/lock schema remains 1;
no automatic rewriting of old artifacts or user configuration occurs.

`cwhip -c` now writes `CWHIP-LINK 2 numeric-v2` in `<object>.cwhip-link`.
Older/different sidecar headers are rejected before linking (`CWHIP2001`).
Distribute that sidecar with a Cwhip object; unannotated objects remain accepted
as ordinary C/native inputs, whose provenance cannot be established automatically.
Generated entry points reference `cwhip_runtime_abi_numeric_v2`, so an old runtime
archive fails linking with an explicit versioned missing symbol.
Manifests are compatibility declarations, not cryptographic proof of how an
arbitrary replacement native archive was compiled.

Native numeric arguments/results use `int8_t`/`uint8_t` through
`int64_t`/`uint64_t`, C `float` for fp32, and C `double` for fp64, including
required target extension attributes for narrow arguments/results. Inline
captures point at storage of those exact types. Callable source types use `R<P...>` (for example `int8<int8>`), while native
callback signature strings retain the canonical ABI spelling
`callback<int8(int8)>`.

The boxed layout remains `{ uint64_t tag; int64_t integer; void *pointer;
uint64_t length; }`. Numeric tag IDs are int64=1, fp64=7, uint64=8, int8=12,
uint8=13, int16=14, uint16=15, int32=16, uint32=17, fp32=18. fp32 occupies the
low 32 payload bits. Use destination-specific `CWHIP_ARRAY_INT64`,
`CWHIP_ARRAY_UINT64`, `CWHIP_ARRAY_FP64`, etc.; the old generic INTEGER,
UNSIGNED, and FLOAT C tag aliases are removed. These process-local pointer
structures are not a portable on-disk serialization format.

## Reproducible private GUI SDK

Run from an isolated worktree with the GTK 4 >=4.10 and GtkSourceView 5
development packages already available. Choose an absolute private fixture
directory, never a user's installed SDK prefix:

```sh
fixture="$PWD/build-numeric-sdk-fixture"
mkdir -p "$fixture/home" "$fixture/xdg"
export HOME="$fixture/home" XDG_CONFIG_HOME="$fixture/xdg"
export XDG_DATA_HOME="$fixture/data" XDG_CACHE_HOME="$fixture/cache"
export XDG_STATE_HOME="$fixture/state"
cmake -S . -B "$fixture/build" -DCMAKE_BUILD_TYPE=Debug \
  -DCWHIP_STAGE_PREFIX="$fixture/stage" \
  -DCMAKE_INSTALL_PREFIX="$fixture/sdk" -DCMAKE_INSTALL_LIBDIR=lib \
  -DCWHIP_REGISTER_SDK=OFF -DCWHIP_GTK=ON -DCWHIP_GTK_SOURCEVIEW=ON
cmake --build "$fixture/build" --target cwhip cwhip_numeric_semantic_tests \
  cwhip_gc_runtime_tests --parallel 4
cmake --install "$fixture/build"
ctest --test-dir "$fixture/build" \
  -R 'cwhip_numeric_|cwhip_gc_runtime_' --output-on-failure
python3 tests/test_numeric_sdk.py --sdk "$fixture/sdk" --require-installed --clang /usr/bin/clang
```

Unset preexisting `CWHIP_*` resource overrides and `DESTDIR` before using this
recipe. `CWHIP_REGISTER_SDK=OFF` prevents SDK registration; private HOME/XDG
prevents application defaults from using user configuration. Downstream CMake
consumers pass `-DCMAKE_PREFIX_PATH="$fixture/sdk"`. Keep the whole prefix.
GUI runtime checks use private Xvfb and D-Bus processes when available; otherwise
the test explicitly reports that only GUI compilation was exercised.

Targeted coverage includes all parser destination boundaries and rejection cases,
direct fp32 rounding, signed zero/subnormals, formatting widths, wide stdlib
counts, SQLite int64/fp64 bindings, a native archive with all ten exact-width
interfaces, stale package/object diagnostics, external CMake consumption,
SourceView language loading, callback tokens/cursor coordinates, tree
activation/expansion with IDs above 2^32, directory-scan callbacks, and GUI
resource staging. Native GTK callback signature strings use exact numeric names.
The existing numeric execution suite additionally covers optimized execution,
callbacks, captures, boxing, and arithmetic.

Verified execution platform: Linux x86-64. Other target C ABIs still require
platform validation. Consumer migrations are owned by the standalone
[cedit](https://github.com/chucktilbury/cedit) and
[cdbg](https://github.com/chucktilbury/cdbg) repositories, not this compiler tree.
