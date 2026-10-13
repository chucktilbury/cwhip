# Cwhip development changelog

## Source and scope

This is an implementation history for the author of a book about Cwhip and
the process of developing it, not a release-by-release compatibility contract.
It consolidates the complete, non-shallow Git history reachable from
[`f81a155`](https://github.com/chucktilbury/cwhip/commit/f81a155a808883e144fb2135b8ba57b5b56c15e5)
(`GC performance optimizations`, October 13, 2026), beginning with
[`a948573`](https://github.com/chucktilbury/cwhip/commit/a948573f4d7ecc726783634468370e61e67a42ba)
(`initial commit`, September 28, 2026). The cutoff contains **191 commits**,
including branch work and merges, rather than only first-parent history.

The narrative groups repeated fixes, documentation synchronization, and merge
commits into milestones. The appendix retains every original commit subject,
including spelling, and uses Git author dates in their recorded time zones.
Its oldest-first order follows `git log --reverse f81a155`; merges remain
separate traceability records, not additional implementations of a feature.
Historical names and syntax describe the project at the time, not necessarily
the current language. Performance results below are supplied reports from
implementation sessions, not measurements inferred from commit messages or
rerun while writing this document. Planned work is explicitly separated.

## Implemented milestones

### September 28: A compiler foundation and an object model

The initial commit already established the lexer, parser, AST, semantic
analyzer, code generator, command-line driver, CMake build, and tests. Minimal
code generation then developed alongside multiple inheritance, inheritance
visibility, and class visibility. The project was still called **Simple**.

Two commits removed semicolon syntax. Runtime work introduced garbage-collected
destructors and began exception handling, including bound exception messages.
Virtual bases and their constructor arguments arrived before the end of the
day. These were early foundations that later constructor, destructor, and
virtual-base fixes continued to refine.

### September 29: Collections, modular source, and runtime interoperability

Collections first appeared under the names **arrays** and **maps**. Namespaces,
`import`, `include`, and `inline` expanded source organization and native
integration. Follow-up work corrected function-definition scope, runtime shims,
and return syntax, separated the runtime shims, and reorganized functional
tests.

Inline support and scalar types were followed by buffer and handle types,
null values, explicit casts, and runtime thread support.

### September 30: Overloads, exceptions, strings, and package foundations

Method and constructor overloads, resizable arrays with append, exception
classes, and exception stack traces broadened the language. The `is` and `type`
operators, slice shorthand, and reference identity added ways to inspect and
manipulate values.

Basic string support grew into a completed String class. Package design and
implementation began, with module location/settings, Clang configuration, and
optional debug information. Tests were unpacked and adjusted as behavior
changed; the String merge records integration rather than a second feature.

### October 1: System libraries and a rapidly settling language

A system-level interface, implemented and tested standard libraries, build
environment scripts, grammar, and language reference made the project more
usable outside the compiler itself. Repeated documentation and merge commits
tracked the evolving implementation.

Language changes disambiguated the string keyword, added string escapes,
widened `int` to 64 bits, and introduced hexadecimal integer literals.
The declaration keywords `map` and `array` were removed, and the earlier
"array" terminology was corrected to **list**.

Base-constructor syntax was revised, including dot-base construction. Scalar
compound assignments and assignment fixes, named string replacements, returns
from anywhere in a method, and corrected method-call examples continued the
language cleanup.

### October 2-3: Construction semantics and package management

Start-block fixes, direct destructor declarations and corrected destructor
syntax, implicit base-member access, and diagnostics for improper constructor
syntax addressed object-lifecycle rough edges. Constructor exceptions became
catchable. Module version selection and a package manager followed on October 3.

### October 4-5: Conversions, formatting, and practical workflows

Standard-library APIs for inline code were followed by scalar casts and
same-width scalar conversion fixes. Buffer literals, checked object casts,
object-cast corrections, casting all data types from `any`, and integer enums
expanded the value model.

Formatting moved from string-literal format calls to `format` and formatted
print. On October 5, `print` stopped adding an implicit newline. Examples and
the scanner example were updated, compiled binaries were removed, package
workflows improved, and subsequent fixes repaired integration/test failures.

### October 6: Reliability infrastructure and application-building APIs

C++-style virtual-base initialization and package-search fixes were accompanied
by hermetic multi-input tests and a shared directory. A concentrated testing
effort added sanitizer builds and fixed empty-native-string undefined behavior;
compiled and ran repository examples with checked expectations; executed
complete documentation programs and checked their output; and ran hermetic
default and sanitizer suites in GitHub Actions.

LLVM source coverage and combined HTML reports, frontend fuzzing, and parser
and AST depth-exhaustion diagnostics extended the reliability tooling.
SQLite and SQL packages arrived with follow-up test fixes. Typed method
callbacks, GTK foundations and widget interfaces, and an asynchronous process
API supplied the building blocks for GUI applications.

### October 7-8: The editor becomes a real application

The editor's first cut was developed under the name **Tweed**. Menus and
dialogs, bug fixes, a find dialog, font changes, a preferences dialog, and a
project window followed. Build procedure and build-target integration were
improved alongside the application.

October 8 brought project implementation and persistence, a name-collision
test, and GTK warning fixes. The warning history includes an initial fix,
its merge, a revert, and a replacement fix; it should not be read as an
uninterrupted series of independent improvements.

### October 9: Simple becomes Cwhip

The project was renamed from **Simple** to **Cwhip**. Follow-up commits purged
old-name references from documentation and the wider tree, while another
commit repaired an editor test.

### October 10-11: Publishing the documentation on the web

Website work added web assets and prepared the site for live use. Path
corrections, Markdown and preview rendering, CSS/JavaScript cache-version
updates, repeated document additions, and link handling made the documentation
publishable and navigable. The same history includes a password-length change
and a discussion-form fix.

October 11 cleared out the old website and temporarily committed the Doxygen
tree for inspection. Cleanup of generated website files and a superfluous
directory continued on October 12.

### October 12: IDE refinement and language/runtime corrections

IDE progress, test fixes, editor performance optimization, and usability
enhancements refined the editor and its GTK/project-explorer support.
Separate language/runtime fixes repaired constructor arguments through aliased
imports and made file-open failures raise exceptions.

### October 13: Typing performance, shorter tests, and two GC improvements

Editor/GTK performance work improved typing behavior, and long editor tests
were split. Two successive garbage-collector changes then addressed different
performance problems:

1. **Startup-oriented GC fix:** `02f4e0e`, integrated by `58c60b5`, used AVL
   lookup for exact and interior pointers and an adaptive allocation budget of
   `max(256, previous live count)`. `CWHIP_GC_STRESS=1` enabled stress collection.
2. **Subsequent throughput work:** `f81a155` introduced hash-based exact lookup,
   object/metadata coallocation, a lazily built sorted interior-pointer index,
   bulk sweep, metadata caching, Release root-push optimization, and conditional
   finalizer remarking.

**Reported implementation-session measurements (not rerun for this history):**

| Change and workload | Reported method | Before | After |
| --- | --- | --- | --- |
| First GC fix: editor Release readiness | Median of 3 runs under `xvfb-run`/D-Bus with isolated HOME/config | 1.716 s | 0.164 s |
| Subsequent GC work: Release throughput benchmark | Medians from 7 interleaved runs per version | 1.435220 s | 0.496908 s (2.89x speedup) |
| Subsequent GC work: benchmark instruction count | Callgrind | 8.9067 billion | 3.0442 billion |
| Subsequent GC work: separate editor readiness check | Medians of 7 runs | 151.6 ms | 140.9 ms |

The subsequent work also reported **396/396 tests passing**, **15/15 targeted
stress tests passing**, and sanitizer checks in normal and stress modes.
These are historical validation reports, not a new validation of this checkout.
Startup readiness, benchmark throughput, and instruction counts are distinct
workloads/metrics: their gains must not be conflated or multiplied.

## Planned work, not implemented in this history

Plans discussed beyond this cutoff include renaming the editor to **cedit**
and building a **KDbg-inspired cdbg** with breakpoints, locals, watches, and
step-into/over/out, initially for local launch. These are intentions, not
features delivered by the 191 commits below.

## Complete chronological commit appendix

Dates are Git author dates. Each hash links to the original commit. Subjects
are reproduced verbatim; repeated fixes, merges, and the revert are retained.

| Date | Commit | Original subject |
| --- | --- | --- |
| 2026-09-28 | [a948573](https://github.com/chucktilbury/cwhip/commit/a948573) | initial commit |
| 2026-09-28 | [cef2c7e](https://github.com/chucktilbury/cwhip/commit/cef2c7e) | minimal code gen |
| 2026-09-28 | [b2a2b2d](https://github.com/chucktilbury/cwhip/commit/b2a2b2d) | multiple inheritance |
| 2026-09-28 | [3550d73](https://github.com/chucktilbury/cwhip/commit/3550d73) | inheritance visibility |
| 2026-09-28 | [a9b3fe5](https://github.com/chucktilbury/cwhip/commit/a9b3fe5) | class visibility |
| 2026-09-28 | [7a4bc79](https://github.com/chucktilbury/cwhip/commit/7a4bc79) | remove semicolon syntax |
| 2026-09-28 | [e0283fc](https://github.com/chucktilbury/cwhip/commit/e0283fc) | remove semicolon syntax |
| 2026-09-28 | [db6a500](https://github.com/chucktilbury/cwhip/commit/db6a500) | implement destructors with GC |
| 2026-09-28 | [6f664b5](https://github.com/chucktilbury/cwhip/commit/6f664b5) | begin exception implementation |
| 2026-09-28 | [1a6e4f5](https://github.com/chucktilbury/cwhip/commit/1a6e4f5) | support bound exception messages |
| 2026-09-28 | [4e4362f](https://github.com/chucktilbury/cwhip/commit/4e4362f) | more exception work |
| 2026-09-28 | [80a4a5a](https://github.com/chucktilbury/cwhip/commit/80a4a5a) | virtual base |
| 2026-09-28 | [9917553](https://github.com/chucktilbury/cwhip/commit/9917553) | virtual base arguments |
| 2026-09-29 | [5912228](https://github.com/chucktilbury/cwhip/commit/5912228) | implement arrays |
| 2026-09-29 | [05807d0](https://github.com/chucktilbury/cwhip/commit/05807d0) | implement maps |
| 2026-09-29 | [b452105](https://github.com/chucktilbury/cwhip/commit/b452105) | maps |
| 2026-09-29 | [0d83413](https://github.com/chucktilbury/cwhip/commit/0d83413) | namespaces |
| 2026-09-29 | [a6da96d](https://github.com/chucktilbury/cwhip/commit/a6da96d) | import |
| 2026-09-29 | [c7b32eb](https://github.com/chucktilbury/cwhip/commit/c7b32eb) | include |
| 2026-09-29 | [6cad6eb](https://github.com/chucktilbury/cwhip/commit/6cad6eb) | inline |
| 2026-09-29 | [fcf88e8](https://github.com/chucktilbury/cwhip/commit/fcf88e8) | fix scope of function definitions |
| 2026-09-29 | [edced64](https://github.com/chucktilbury/cwhip/commit/edced64) | fix runtime shims, fix return syntax |
| 2026-09-29 | [f278773](https://github.com/chucktilbury/cwhip/commit/f278773) | separate runtime shims, organize functional tests |
| 2026-09-29 | [8317642](https://github.com/chucktilbury/cwhip/commit/8317642) | organize tests |
| 2026-09-29 | [bc88d8b](https://github.com/chucktilbury/cwhip/commit/bc88d8b) | inline and scalar types |
| 2026-09-29 | [378d898](https://github.com/chucktilbury/cwhip/commit/378d898) | buffer and handle types |
| 2026-09-29 | [a3a140f](https://github.com/chucktilbury/cwhip/commit/a3a140f) | null values |
| 2026-09-29 | [2895c3e](https://github.com/chucktilbury/cwhip/commit/2895c3e) | explicit casts |
| 2026-09-29 | [6472686](https://github.com/chucktilbury/cwhip/commit/6472686) | runtime thread support |
| 2026-09-30 | [8bc8bd7](https://github.com/chucktilbury/cwhip/commit/8bc8bd7) | method overloads |
| 2026-09-30 | [7a952f0](https://github.com/chucktilbury/cwhip/commit/7a952f0) | Implement resizable arrays and append |
| 2026-09-30 | [33d464d](https://github.com/chucktilbury/cwhip/commit/33d464d) | Align array resize test with null output |
| 2026-09-30 | [a3a48fb](https://github.com/chucktilbury/cwhip/commit/a3a48fb) | update notes |
| 2026-09-30 | [0fccef6](https://github.com/chucktilbury/cwhip/commit/0fccef6) | exception classes |
| 2026-09-30 | [94149a4](https://github.com/chucktilbury/cwhip/commit/94149a4) | unpack the tests |
| 2026-09-30 | [11af00a](https://github.com/chucktilbury/cwhip/commit/11af00a) | is and type operators |
| 2026-09-30 | [14fd5c8](https://github.com/chucktilbury/cwhip/commit/14fd5c8) | slice shorthand |
| 2026-09-30 | [f3f0d4c](https://github.com/chucktilbury/cwhip/commit/f3f0d4c) | ctor overloads |
| 2026-09-30 | [e111439](https://github.com/chucktilbury/cwhip/commit/e111439) | reference identity |
| 2026-09-30 | [7391605](https://github.com/chucktilbury/cwhip/commit/7391605) | exception stack trace |
| 2026-09-30 | [58abee4](https://github.com/chucktilbury/cwhip/commit/58abee4) | basic package design |
| 2026-09-30 | [169d7a8](https://github.com/chucktilbury/cwhip/commit/169d7a8) | clang configuration |
| 2026-09-30 | [a564879](https://github.com/chucktilbury/cwhip/commit/a564879) | basic string support |
| 2026-09-30 | [da6ee2a](https://github.com/chucktilbury/cwhip/commit/da6ee2a) | complete the string class |
| 2026-09-30 | [cb2c051](https://github.com/chucktilbury/cwhip/commit/cb2c051) | optionally ouput debug info |
| 2026-09-30 | [3cad563](https://github.com/chucktilbury/cwhip/commit/3cad563) | Merge branch 'chucktilbury-complete-string-class' |
| 2026-09-30 | [3fc2656](https://github.com/chucktilbury/cwhip/commit/3fc2656) | Modules location and settings. |
| 2026-09-30 | [834500f](https://github.com/chucktilbury/cwhip/commit/834500f) | Ignore pedantic warning |
| 2026-09-30 | [e0cc139](https://github.com/chucktilbury/cwhip/commit/e0cc139) | Implementing packages |
| 2026-10-01 | [7344c6c](https://github.com/chucktilbury/cwhip/commit/7344c6c) | Implement the system level interface |
| 2026-10-01 | [48d4a08](https://github.com/chucktilbury/cwhip/commit/48d4a08) | Implement and test std libraries |
| 2026-10-01 | [9a47c21](https://github.com/chucktilbury/cwhip/commit/9a47c21) | tweak build environment |
| 2026-10-01 | [fac279e](https://github.com/chucktilbury/cwhip/commit/fac279e) | Build enviroment scripts |
| 2026-10-01 | [5a99279](https://github.com/chucktilbury/cwhip/commit/5a99279) | Grammar and language reference |
| 2026-10-01 | [409f35a](https://github.com/chucktilbury/cwhip/commit/409f35a) | Merge branch 'chucktilbury-grammar-language-reference' |
| 2026-10-01 | [eb278d6](https://github.com/chucktilbury/cwhip/commit/eb278d6) | Documentation update |
| 2026-10-01 | [d6a7737](https://github.com/chucktilbury/cwhip/commit/d6a7737) | Update documentation |
| 2026-10-01 | [29a6dff](https://github.com/chucktilbury/cwhip/commit/29a6dff) | Merge branch 'chucktilbury-fix-build-environment-scripts' |
| 2026-10-01 | [91b5014](https://github.com/chucktilbury/cwhip/commit/91b5014) | Merge branch 'chucktilbury-grammar-language-reference' |
| 2026-10-01 | [08b04be](https://github.com/chucktilbury/cwhip/commit/08b04be) | Disambiguate the string keyword |
| 2026-10-01 | [d36ca5a](https://github.com/chucktilbury/cwhip/commit/d36ca5a) | Add escape to strings |
| 2026-10-01 | [81b1bf5](https://github.com/chucktilbury/cwhip/commit/81b1bf5) | Make an "int" 64 bits |
| 2026-10-01 | [c65a369](https://github.com/chucktilbury/cwhip/commit/c65a369) | Merge branch 'chucktilbury-widen-simple-int' |
| 2026-10-01 | [6d42452](https://github.com/chucktilbury/cwhip/commit/6d42452) | Grammar updates |
| 2026-10-01 | [6a14085](https://github.com/chucktilbury/cwhip/commit/6a14085) | Merge branch 'chucktilbury-grammar-language-reference' |
| 2026-10-01 | [8d3ff13](https://github.com/chucktilbury/cwhip/commit/8d3ff13) | Remove "map" and "array" keywords. |
| 2026-10-01 | [cc67b5c](https://github.com/chucktilbury/cwhip/commit/cc67b5c) | Hex integer literals |
| 2026-10-01 | [b292a77](https://github.com/chucktilbury/cwhip/commit/b292a77) | Merge branch 'chucktilbury-hexadecimal-integer-literals' |
| 2026-10-01 | [dfc1057](https://github.com/chucktilbury/cwhip/commit/dfc1057) | The word "array" should have been "list" |
| 2026-10-01 | [4b895a3](https://github.com/chucktilbury/cwhip/commit/4b895a3) | Fix syntax around bas class ctors |
| 2026-10-01 | [dd044dc](https://github.com/chucktilbury/cwhip/commit/dd044dc) | Scalar compound assignment |
| 2026-10-01 | [25d9032](https://github.com/chucktilbury/cwhip/commit/25d9032) | Scalar assignments |
| 2026-10-01 | [3b29124](https://github.com/chucktilbury/cwhip/commit/3b29124) | dot base ctor |
| 2026-10-01 | [d271dcf](https://github.com/chucktilbury/cwhip/commit/d271dcf) | Merge branch 'chucktilbury-scalar-compound-assignments' |
| 2026-10-01 | [5c41088](https://github.com/chucktilbury/cwhip/commit/5c41088) | Named string replacements |
| 2026-10-01 | [ebafa79](https://github.com/chucktilbury/cwhip/commit/ebafa79) | named string replacement |
| 2026-10-01 | [c664755](https://github.com/chucktilbury/cwhip/commit/c664755) | Synchronize documentation |
| 2026-10-01 | [bd3ee62](https://github.com/chucktilbury/cwhip/commit/bd3ee62) | update doxygen file to reflect project name |
| 2026-10-01 | [e78f089](https://github.com/chucktilbury/cwhip/commit/e78f089) | Return from anywhere in a method |
| 2026-10-01 | [05ac3c3](https://github.com/chucktilbury/cwhip/commit/05ac3c3) | Fix canned method call examples |
| 2026-10-02 | [e24af1d](https://github.com/chucktilbury/cwhip/commit/e24af1d) | Fix start block error |
| 2026-10-02 | [57ee9e9](https://github.com/chucktilbury/cwhip/commit/57ee9e9) | Direct destructor declarations |
| 2026-10-02 | [e8ac6f6](https://github.com/chucktilbury/cwhip/commit/e8ac6f6) | Implicit base members |
| 2026-10-02 | [829fcda](https://github.com/chucktilbury/cwhip/commit/829fcda) | Merge branch 'chucktilbury-implicit-base-qualified-members' |
| 2026-10-02 | [8e0320f](https://github.com/chucktilbury/cwhip/commit/8e0320f) | Correct destructor syntax |
| 2026-10-02 | [1eb5b00](https://github.com/chucktilbury/cwhip/commit/1eb5b00) | Add an error for improper ctor syntax |
| 2026-10-02 | [cc71d42](https://github.com/chucktilbury/cwhip/commit/cc71d42) | Catch constructor exception |
| 2026-10-03 | [0a3845d](https://github.com/chucktilbury/cwhip/commit/0a3845d) | module version selection |
| 2026-10-03 | [57a802b](https://github.com/chucktilbury/cwhip/commit/57a802b) | Package manager |
| 2026-10-04 | [30ab9f6](https://github.com/chucktilbury/cwhip/commit/30ab9f6) | Standard library API for inline code. |
| 2026-10-04 | [451c58d](https://github.com/chucktilbury/cwhip/commit/451c58d) | Add scalar casts |
| 2026-10-04 | [c8addcd](https://github.com/chucktilbury/cwhip/commit/c8addcd) | Merge branch 'chucktilbury-complete-scalar-casts' |
| 2026-10-04 | [b431b7e](https://github.com/chucktilbury/cwhip/commit/b431b7e) | Same sized scalars |
| 2026-10-04 | [8e33e1b](https://github.com/chucktilbury/cwhip/commit/8e33e1b) | Merge branch 'chucktilbury-same-width-signed-casts' |
| 2026-10-04 | [5d481c4](https://github.com/chucktilbury/cwhip/commit/5d481c4) | Implement buffer literals |
| 2026-10-04 | [f21b5bf](https://github.com/chucktilbury/cwhip/commit/f21b5bf) | Implement checked object casts |
| 2026-10-04 | [484b47b](https://github.com/chucktilbury/cwhip/commit/484b47b) | Merge branch 'chucktilbury-checked-object-casts' |
| 2026-10-04 | [8be6ac8](https://github.com/chucktilbury/cwhip/commit/8be6ac8) | Bug fix in object casts |
| 2026-10-04 | [6c44549](https://github.com/chucktilbury/cwhip/commit/6c44549) | Merge branch 'chucktilbury-checked-object-casts' |
| 2026-10-04 | [1dc16f8](https://github.com/chucktilbury/cwhip/commit/1dc16f8) | Support all data types as cast from 'any' |
| 2026-10-04 | [e002a44](https://github.com/chucktilbury/cwhip/commit/e002a44) | Merge branch 'chucktilbury-checked-object-casts' |
| 2026-10-04 | [afa3257](https://github.com/chucktilbury/cwhip/commit/afa3257) | Implement integer enums |
| 2026-10-04 | [97b2bd5](https://github.com/chucktilbury/cwhip/commit/97b2bd5) | Merge branch 'chucktilbury-class-integer-enums' |
| 2026-10-04 | [20122b9](https://github.com/chucktilbury/cwhip/commit/20122b9) | Update stale docs |
| 2026-10-04 | [a7c4c0e](https://github.com/chucktilbury/cwhip/commit/a7c4c0e) | Adding some examples to the tree |
| 2026-10-04 | [2b40d10](https://github.com/chucktilbury/cwhip/commit/2b40d10) | Replace string-literal format calls with format and formatted print |
| 2026-10-05 | [748dfc1](https://github.com/chucktilbury/cwhip/commit/748dfc1) | Make print write without implicit newlines |
| 2026-10-05 | [e08b685](https://github.com/chucktilbury/cwhip/commit/e08b685) | Update scanner example |
| 2026-10-05 | [56a7bcd](https://github.com/chucktilbury/cwhip/commit/56a7bcd) | Delete compiled binaries |
| 2026-10-05 | [cec5175](https://github.com/chucktilbury/cwhip/commit/cec5175) | Work flow improvements |
| 2026-10-05 | [9c90dbf](https://github.com/chucktilbury/cwhip/commit/9c90dbf) | Merge branch 'chucktilbury-package-workflow-improvements' |
| 2026-10-05 | [1394857](https://github.com/chucktilbury/cwhip/commit/1394857) | Broken stuff |
| 2026-10-05 | [1194138](https://github.com/chucktilbury/cwhip/commit/1194138) | Fix merge test failures |
| 2026-10-06 | [98077b6](https://github.com/chucktilbury/cwhip/commit/98077b6) | C++ style virtual base |
| 2026-10-06 | [fe5f599](https://github.com/chucktilbury/cwhip/commit/fe5f599) | Merge branch 'chucktilbury-cpp-style-virtual-base-init' |
| 2026-10-06 | [53d2d0f](https://github.com/chucktilbury/cwhip/commit/53d2d0f) | Fix package search |
| 2026-10-06 | [3814d48](https://github.com/chucktilbury/cwhip/commit/3814d48) | Fix broken tests |
| 2026-10-06 | [47cb8b4](https://github.com/chucktilbury/cwhip/commit/47cb8b4) | Fix broken tests |
| 2026-10-06 | [98a79b4](https://github.com/chucktilbury/cwhip/commit/98a79b4) | Merge branch 'chucktilbury-hermetic-multi-input-tests' |
| 2026-10-06 | [3fbae34](https://github.com/chucktilbury/cwhip/commit/3fbae34) | Add the "shared" directory |
| 2026-10-06 | [b8276b2](https://github.com/chucktilbury/cwhip/commit/b8276b2) | Add sanitizer builds and fix empty native string UB |
| 2026-10-06 | [bcbfceb](https://github.com/chucktilbury/cwhip/commit/bcbfceb) | Compile and run every repository example with checked expectations |
| 2026-10-06 | [6d79eaa](https://github.com/chucktilbury/cwhip/commit/6d79eaa) | Execute complete documentation programs and check documented output |
| 2026-10-06 | [dd465e1](https://github.com/chucktilbury/cwhip/commit/dd465e1) | Run hermetic default and sanitizer suites in GitHub Actions |
| 2026-10-06 | [d621a37](https://github.com/chucktilbury/cwhip/commit/d621a37) | Add LLVM source coverage instrumentation and combined HTML reports |
| 2026-10-06 | [9d08325](https://github.com/chucktilbury/cwhip/commit/9d08325) | Add frontend fuzzing and diagnose parser and AST depth exhaustion |
| 2026-10-06 | [e48b603](https://github.com/chucktilbury/cwhip/commit/e48b603) | Index the testing infrastructure guide |
| 2026-10-06 | [72cc8b1](https://github.com/chucktilbury/cwhip/commit/72cc8b1) | Implement sqlite and sql packages |
| 2026-10-06 | [f12646a](https://github.com/chucktilbury/cwhip/commit/f12646a) | Merge branch 'chucktilbury-sql-sqlite-packages' |
| 2026-10-06 | [8d5ce36](https://github.com/chucktilbury/cwhip/commit/8d5ce36) | Fix failed sqlite test |
| 2026-10-06 | [c93a224](https://github.com/chucktilbury/cwhip/commit/c93a224) | Merge branch 'chucktilbury-sql-sqlite-packages' |
| 2026-10-06 | [b98d8c0](https://github.com/chucktilbury/cwhip/commit/b98d8c0) | Typed method callbacks |
| 2026-10-06 | [7bf9c9a](https://github.com/chucktilbury/cwhip/commit/7bf9c9a) | Merge branch 'chucktilbury-typed-method-callbacks' |
| 2026-10-06 | [79983f4](https://github.com/chucktilbury/cwhip/commit/79983f4) | Fix stdlib document |
| 2026-10-06 | [0436231](https://github.com/chucktilbury/cwhip/commit/0436231) | GTK foundation work |
| 2026-10-06 | [2e8c362](https://github.com/chucktilbury/cwhip/commit/2e8c362) | Implement GTK widget interface |
| 2026-10-06 | [f8698d6](https://github.com/chucktilbury/cwhip/commit/f8698d6) | Asynchronous process API |
| 2026-10-07 | [35519b8](https://github.com/chucktilbury/cwhip/commit/35519b8) | Editor first cut |
| 2026-10-07 | [b2c6983](https://github.com/chucktilbury/cwhip/commit/b2c6983) | Merge branch 'chucktilbury-tweed-editor-first-iteration' |
| 2026-10-07 | [1ca64b7](https://github.com/chucktilbury/cwhip/commit/1ca64b7) | Editor menus and dialogs |
| 2026-10-07 | [2f38447](https://github.com/chucktilbury/cwhip/commit/2f38447) | Clean up build proceedure |
| 2026-10-07 | [2498d1c](https://github.com/chucktilbury/cwhip/commit/2498d1c) | Merge branch 'chucktilbury-tweed-build-target' |
| 2026-10-07 | [bf806fa](https://github.com/chucktilbury/cwhip/commit/bf806fa) | Fix editor bugs |
| 2026-10-07 | [d910fc0](https://github.com/chucktilbury/cwhip/commit/d910fc0) | Add find dialog and change editor font |
| 2026-10-07 | [d8891c7](https://github.com/chucktilbury/cwhip/commit/d8891c7) | Add some linefeeds to the end |
| 2026-10-07 | [a086929](https://github.com/chucktilbury/cwhip/commit/a086929) | Implement preferences dialog |
| 2026-10-07 | [c176689](https://github.com/chucktilbury/cwhip/commit/c176689) | Fix build warnings in gtk.c |
| 2026-10-07 | [d6e584f](https://github.com/chucktilbury/cwhip/commit/d6e584f) | Implement project window |
| 2026-10-08 | [462b82e](https://github.com/chucktilbury/cwhip/commit/462b82e) | Merge branch 'chucktilbury-gtk-deprecated-warnings' |
| 2026-10-08 | [16861e3](https://github.com/chucktilbury/cwhip/commit/16861e3) | Revert "Fix build warnings in gtk.c" |
| 2026-10-08 | [a29d554](https://github.com/chucktilbury/cwhip/commit/a29d554) | Fix GTK deprecation warnings. |
| 2026-10-08 | [c25d9a8](https://github.com/chucktilbury/cwhip/commit/c25d9a8) | Implement projects |
| 2026-10-08 | [b4c39b5](https://github.com/chucktilbury/cwhip/commit/b4c39b5) | Merge branch 'chucktilbury-tweed-project-persistence' |
| 2026-10-08 | [fa8b9cd](https://github.com/chucktilbury/cwhip/commit/fa8b9cd) | Add name collision test |
| 2026-10-09 | [3eaceb4](https://github.com/chucktilbury/cwhip/commit/3eaceb4) | Name change from "Simple" to "Cwhip" |
| 2026-10-09 | [3e71f8a](https://github.com/chucktilbury/cwhip/commit/3e71f8a) | Purge references to "Simple" in docs |
| 2026-10-09 | [68bb1c0](https://github.com/chucktilbury/cwhip/commit/68bb1c0) | Fix failed editor test |
| 2026-10-09 | [cbbbf3e](https://github.com/chucktilbury/cwhip/commit/cbbbf3e) | Full purge of old name and replace with cwhip |
| 2026-10-10 | [ad87bf9](https://github.com/chucktilbury/cwhip/commit/ad87bf9) | Create repo for web assets |
| 2026-10-10 | [4fdd8ea](https://github.com/chucktilbury/cwhip/commit/4fdd8ea) | Get it ready for actual web site |
| 2026-10-10 | [a8e73bf](https://github.com/chucktilbury/cwhip/commit/a8e73bf) | Make changes to accomodate live web site |
| 2026-10-10 | [a45a444](https://github.com/chucktilbury/cwhip/commit/a45a444) | Path corrections |
| 2026-10-10 | [72b016f](https://github.com/chucktilbury/cwhip/commit/72b016f) | Fix markdown rendering |
| 2026-10-10 | [83f2047](https://github.com/chucktilbury/cwhip/commit/83f2047) | increment the css and js versions to make the cache behave |
| 2026-10-10 | [e34126a](https://github.com/chucktilbury/cwhip/commit/e34126a) | fix preview rendering |
| 2026-10-10 | [cdba7cf](https://github.com/chucktilbury/cwhip/commit/cdba7cf) | fix versions |
| 2026-10-10 | [40f16ce](https://github.com/chucktilbury/cwhip/commit/40f16ce) | add documents |
| 2026-10-10 | [f097952](https://github.com/chucktilbury/cwhip/commit/f097952) | add documents |
| 2026-10-10 | [a7a9205](https://github.com/chucktilbury/cwhip/commit/a7a9205) | add documents |
| 2026-10-10 | [904eb0f](https://github.com/chucktilbury/cwhip/commit/904eb0f) | add documents |
| 2026-10-10 | [3532fe9](https://github.com/chucktilbury/cwhip/commit/3532fe9) | fix document links |
| 2026-10-10 | [a9bb2a8](https://github.com/chucktilbury/cwhip/commit/a9bb2a8) | allow markdown links to work |
| 2026-10-10 | [1d41094](https://github.com/chucktilbury/cwhip/commit/1d41094) | change min password length from 12 to 8 |
| 2026-10-10 | [61d7d4e](https://github.com/chucktilbury/cwhip/commit/61d7d4e) | fix discussion form |
| 2026-10-11 | [a17928a](https://github.com/chucktilbury/cwhip/commit/a17928a) | clear out old web site |
| 2026-10-11 | [d23fcd6](https://github.com/chucktilbury/cwhip/commit/d23fcd6) | Temp commit the whole doxygen tree so GROK can see it. |
| 2026-10-12 | [dc71bf6](https://github.com/chucktilbury/cwhip/commit/dc71bf6) | clean up web site generated files. |
| 2026-10-12 | [978bedf](https://github.com/chucktilbury/cwhip/commit/978bedf) | Remove superfulous directory |
| 2026-10-12 | [8793884](https://github.com/chucktilbury/cwhip/commit/8793884) | IDE progress |
| 2026-10-12 | [6ee5cf0](https://github.com/chucktilbury/cwhip/commit/6ee5cf0) | Fix tests |
| 2026-10-12 | [b5a0854](https://github.com/chucktilbury/cwhip/commit/b5a0854) | Optimise editor performance |
| 2026-10-12 | [60a64c5](https://github.com/chucktilbury/cwhip/commit/60a64c5) | IDE usability enhansements |
| 2026-10-12 | [d8bb475](https://github.com/chucktilbury/cwhip/commit/d8bb475) | Bug where aliased import ctor broken |
| 2026-10-12 | [19a4121](https://github.com/chucktilbury/cwhip/commit/19a4121) | Merge branch 'chucktilbury-fix-aliased-import-ctor-args' |
| 2026-10-12 | [3b75229](https://github.com/chucktilbury/cwhip/commit/3b75229) | File open fail raises exception |
| 2026-10-13 | [c648a50](https://github.com/chucktilbury/cwhip/commit/c648a50) | Performance optimizations |
| 2026-10-13 | [77afcff](https://github.com/chucktilbury/cwhip/commit/77afcff) | Split long editor tests |
| 2026-10-13 | [eb93e96](https://github.com/chucktilbury/cwhip/commit/eb93e96) | Merge branch 'chucktilbury-split-long-editor-tests' |
| 2026-10-13 | [02f4e0e](https://github.com/chucktilbury/cwhip/commit/02f4e0e) | GC performance |
| 2026-10-13 | [58c60b5](https://github.com/chucktilbury/cwhip/commit/58c60b5) | Merge branch 'chucktilbury-fix-gc-bound-editor-startup' |
| 2026-10-13 | [f81a155](https://github.com/chucktilbury/cwhip/commit/f81a155) | GC performance optimizations |
