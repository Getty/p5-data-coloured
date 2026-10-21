# Data-Coloured

Visualize random ASCII data streams: control characters by name, printable
characters as they are, everything else as hex — each in its own colour.

## Synopsis

```perl
use DDC;

my $text = coloured($data);   # returns the coloured text
my $text = c($data);          # same, short alias
poloured($data);              # prints the coloured text
pc($data);                    # same, short alias
```

```bash
ddc file.bin                  # print a file coloured
cat stream.bin | ddc          # print a stream coloured
```

## Description

`Data::Coloured` renders a byte stream as ANSI-coloured text, so that a
terminal shows what a stream actually contains. It was made for debugging TCP
and UART connections, where the control characters are the interesting part.

Every character is put into one of three classes:

| Class | Condition | Rendering | Colour |
|---|---|---|---|
| control | an ASCII control code (0–31, 127) | its name in square brackets, e.g. `[ETX]` | bright red |
| print | a printable character (space to `~`) | the character itself | bright yellow |
| binary | everything else | its hex value in angle brackets, e.g. `<ff>` | bright cyan |

Control codes are named after the abbreviations in the
[ASCII control code chart](https://en.wikipedia.org/wiki/ASCII#ASCII_control_code_chart),
with the exception of code 9, which is shown as `TAB`.

The module exports in two tiers. `coloured` and `poloured` are always
exported; `c` and `pc` come on request:

```perl
use Data::Coloured qw( c pc );
```

`DDC` is an alias module that exports all four functions unconditionally, for
call sites that only want the visualiser.

## Examples

### coloured

`coloured` returns the coloured text, so it can be put wherever a string goes.

```perl
use Data::Coloured;

my $text = coloured("Hi\x00\xff\n");
print $text;
```

```
Hi[NUL]<ff>[LF]
```

The rendered text carries ANSI colour codes; the example shows what a terminal
displays.

### poloured

`poloured` prints the coloured text.

```perl
use Data::Coloured;

poloured("Hi\x00\xff\n");
```

### c

`c` is the short alias of `coloured` and returns the coloured text.

```perl
use Data::Coloured qw( c );

my $text = c("Hi\x00\xff\n");
```

### pc

`pc` is the short alias of `poloured` and prints the coloured text.

```perl
use Data::Coloured qw( pc );

pc("Hi\x00\xff\n");
```

## Installation

```bash
cpanm Data-Coloured
```

## Author

Torsten Raudssus <torsten@raudssus.de>

## License

This is free software; you can redistribute it and/or modify it under the same terms as the Perl 5 programming language system itself.
