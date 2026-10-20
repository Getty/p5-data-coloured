---
name: data-coloured-core
description: "Load before editing Data-Coloured — the ASCII/binary visualiser distribution: two modules (Data::Coloured, DDC), the export contract, the three colour classes, and the encoding rules that decide what a byte is rendered as."
---

# Data::Coloured — core

A small visualisation library: it renders a byte stream as ANSI-coloured text, so that
control characters show by name, printable characters stay readable, and everything
else shows as hex. Built for eyeballing TCP and UART streams.

The distribution has **two modules and one script**:

| File | Role |
|---|---|
| `lib/Data/Coloured.pm` | the implementation — all the logic lives here |
| `lib/DDC.pm` | a thin alias that re-exports the same functions under a short name |
| `bin/ddc` | CLI: reads a file (or stdin) and prints it coloured |

`Data::Coloured` is the real module. `DDC` exists so `use DDC;` is a one-word import
for scripts that only want the visualiser — it holds **no logic of its own**. If you
change behaviour, change it in `Data::Coloured` and let `DDC` keep re-exporting.

## The export contract

`Data::Coloured` exports in two tiers — this asymmetry is deliberate, do not "fix" it
by flattening the two:

```perl
use Exporter 'import';
our @EXPORT_OK = qw( pc c );
our @EXPORT    = qw( coloured poloured );
```

- **`@EXPORT` (always on):** `coloured` returns the coloured string, `poloured`
  prints it. Every user wants these.
- **`@EXPORT_OK` (on request):** `pc` and `c` are the short aliases — `pc` prints,
  `c` returns. They exist for terse call sites, not for a different behaviour.

`DDC` re-exports all four under the same names (`our @EXPORT = qw( pc c coloured poloured )`).
Callers of `DDC` get the short aliases **unconditionally**, even though
`Data::Coloured` only offers them on request — that is the point of the alias module.

A new public function is added to `@EXPORT_OK` in `Data::Coloured` and to the
`@EXPORT` list in `DDC`, and to the POD of both modules in the same edit. Nothing is
exported under a name that does not exist.

## The three colour classes

The whole behaviour is one three-way classification of each character:

| Class | Condition | Rendering | Colour |
|---|---|---|---|
| **control** | `$chr` is a key of `%control` | `[NAME]` in square brackets | `bright_red` |
| **print** | the character matches `/[ -~]/` | the character itself | `bright_yellow` |
| **binary** | everything else | `<hex>` in angle brackets | `bright_cyan` |

The colours live in `%colours` (`control` / `print` / `binary`), the delimiters in
`@control_delimiter` (`[`, `]`) and `@binary_delimiter` (`<`, `>`). Both are plain
package variables, not constants — a caller may change them, and the code reads them
at call time, so that works.

`%control` maps the ASCII control codes 0–31 plus 127 to their abbreviations (`NUL`,
`SOH`, … `US`, `DEL`). Note the deliberate deviation from the Wikipedia table the POD
references: code 9 is named `TAB`, not `HT`. That is intentional and documented —
do not "correct" it back.

The classification order matters: **control is checked before print**, because the
control codes are non-printable and would otherwise fall through to the binary branch.
Keep that order when touching the loop.

## The rendering rules

- **Printable** characters (space to `~`) pass through unchanged, one colour.
- **Binary** characters (everything above 127) are rendered as their hex value in
  angle brackets: `<ff>`.
- **Control** characters are rendered as their name in square brackets: `[ETX]`.

The point of the binary branch is that a byte which is not valid text still has to be
*visible* — `<ff>` is more useful in a terminal than a raw byte that the terminal
interprets or drops.

## The Unicode trap — read this before touching the character loop

This is the known defect of the distribution (GitHub issue #1, "Wrong output for
Unicode chars", open since 2014) and it lives in the character split:

```perl
my @chars = split(//, $_[0]);
```

`split //` splits **by characters**, not bytes, when the string carries the UTF-8
flag — and a multi-byte UTF-8 character then reaches the binary branch as a single
wide character. `unpack('H*', $char)` on a wide character yields its **code point**,
not its UTF-8 bytes, so `ä` comes out as `<e4>` instead of `<c3a4>`. The rendering is
also wrong for the printable branch, because the `/[ -~]/` test is a byte range that a
wide character never matches.

Whichever way this is fixed — decoding the input explicitly, splitting on bytes, or
handling the wide-character case separately — the fix must keep these two properties:

1. **ASCII behaviour is unchanged.** Every byte in 0–127 renders exactly as it does
   today. The existing test suite pins this.
2. **A multi-byte character is rendered from its UTF-8 bytes**, not from its code
   point, so what appears in the terminal is what the stream actually contained.

Do not "fix" it by making the printable branch accept wide characters without
deciding what the hex branch then means — the two branches must agree on what a
"character" is. Whatever the agreed unit is, it is the same unit in both branches.

Note that `poloured`/`pc` print directly to the handle, while `coloured`/`c` return a
string — a fix that changes the returned bytes (e.g. by encoding the result) changes
what a caller gets, and that needs a `Changes` entry.

## The `bin/ddc` script

Reads from `@ARGV` (or stdin when empty), one line at a time, prints each line
coloured via `pc`, and appends a newline only at the end of a file (`print "\n" if
eof`). `$| = 1` keeps the output unbuffered — that matters, because the script is
meant for watching a live stream, where a buffered line would defeat the purpose.

The script's POD still points at `p5-anyevent-itm` — a copy/paste leftover from
another repository. That is wrong and should be corrected when the script's docs are
touched.

## Tests

`t/00-load.t` loads both modules (`Data::Coloured`, `DDC`). The behavioural contract —
the three colour classes, the delimiters, the `TAB` naming, the export tiers — needs
its own test file; a load test alone does not pin any of it.

Run with `prove -lr t/` or `dzil test`.

## Distribution conventions

`dist.ini` uses `[@Author::GETTY]`, so the POD follows that bundle's shortcut
commands (`=synopsis`, `=description`, `=seealso`) and every file carries a
`# ABSTRACT:` line. The CPAN name is `Data-Coloured`; the repo is `p5-data-coloured`.
The last release on CPAN is **0.003** (2015-03-08), so the next version is 0.004 —
see `getty-perl-release-author-getty` for how the version is derived.
