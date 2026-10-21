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
`@EXPORT` list in `DDC`, and gets a `=func` entry in the POD of **both** modules in
the same edit. Nothing is exported under a name that does not exist.

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
- Every argument of a call is rendered on its own, the parts are put together in the
  order the arguments were given.

The point of the binary branch is that a byte which is not valid text still has to be
*visible* — `<ff>` is more useful in a terminal than a raw byte that the terminal
interprets or drops.

## The Unicode trap — read this before touching the character loop

The trap is real, but it is **solved** since the fix of GitHub issue #1 ("Wrong output
for Unicode chars", open since 2014). The rule that is in force now:

**The UTF-8 flag of a string decides the unit of its rendering.**

- A string **with** the flag is read as characters, and a multi-byte character is
  rendered from its **UTF-8 bytes**: U+00E4 shows as `<c3a4>`, U+20AC as `<e282ac>`.
- A string **without** the flag stays a byte stream: every byte is its own unit, so
  0xff shows as `<ff>`.

Both branches of the classification use the same unit — the printable branch and the
hex branch must always agree on what a "character" is.

The unit is decided **per argument**, not per call: `coloured("\xff", $aumlaut)`
renders `<ff><c3a4>`. The arguments are deliberately **not joined** before the
rendering — a `join` lifts an argument without the flag into a string with the flag,
and the byte 0xff would then be read as the character U+00FF and show as `<c3bf>`
instead of `<ff>`.

Two properties stay fixed and are pinned by the test suite:

1. **ASCII behaviour is unchanged.** Every byte in 0–127 renders exactly as it always
   did, with and without the flag.
2. **A multi-byte character is rendered from its UTF-8 bytes**, not from its code
   point, so what appears in the terminal is what the stream actually contained.

The trap still lurks where the split happens: `split //` splits **by characters** when
the flag is set, and `unpack('H*', $char)` on a wide character yields its **code
point**, not its UTF-8 bytes (`<e4>` instead of `<c3a4>`). That is why the hex branch
encodes the character first (`_utf8_hex`) — a change to the loop must not lose that
encoding step, and it must not widen the printable branch to accept wide characters
without deciding what the hex branch then means.

Note that `poloured`/`pc` print directly to the handle, while `coloured`/`c` return a
string — a change that changes the returned bytes (e.g. by encoding the result) changes
what a caller gets, and that needs a `Changes` entry.

## The `bin/ddc` script

Reads from `@ARGV` (or stdin when empty), one line at a time, prints each line
coloured via `pc`, and appends a newline only at the end of a file (`print "\n" if
eof`). `$| = 1` keeps the output unbuffered — that matters, because the script is
meant for watching a live stream, where a buffered line would defeat the purpose.

The POD of the script is written by hand and documents the synopsis, the options and
the exit status; the bundle adds the generated sections around it. The exit status is
part of the contract: 0 the dump was printed, 1 the data could not be read, 2 the
command line was wrong.

## Tests

`t/00-load.t` loads both modules (`Data::Coloured`, `DDC`), `t/01-render.t` pins the
behavioural contract — the three colour classes, the delimiters, the `TAB` naming and
the unit that decides how a byte is rendered — `t/02-export.t` pins the export tiers
and `t/03-cli.t` the command line of the script. A new behaviour needs a new
assertion in the file that owns it.

Run with `prove -lr t/` or `dzil test`.

## Distribution conventions

`dist.ini` uses `[@Author::GETTY]`, so the POD follows that bundle's shortcut
commands (`=synopsis`, `=description`, `=seealso`) and every file carries a
`# ABSTRACT:` line. The CPAN name is `Data-Coloured`; the repo is `p5-data-coloured`.
The last release on CPAN is **0.003** (2015-03-08), so the next version is 0.004 —
see `getty-perl-release-author-getty` for how the version is derived.
