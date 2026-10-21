#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Data::Coloured;

# The rendering contract: control characters by name in square brackets in
# bright red, printable characters as they are in bright yellow, everything
# else as hex in angle brackets in bright cyan.

my $CONTROL = 91;    # ANSI bright red
my $PRINT   = 93;    # ANSI bright yellow
my $BINARY  = 96;    # ANSI bright cyan

# The names of the control characters, code 9 is TAB and not HT.
my %control_name = (
  0 => 'NUL',   1 => 'SOH',  2 => 'STX',  3 => 'ETX',  4 => 'EOT',
  5 => 'ENQ',   6 => 'ACK',  7 => 'BEL',  8 => 'BS',   9 => 'TAB',
  10 => 'LF',  11 => 'VT',  12 => 'FF',  13 => 'CR',  14 => 'SO',
  15 => 'SI',  16 => 'DLE', 17 => 'DC1', 18 => 'DC2', 19 => 'DC3',
  20 => 'DC4', 21 => 'NAK', 22 => 'SYN', 23 => 'ETB', 24 => 'CAN',
  25 => 'EM',  26 => 'SUB', 27 => 'ESC', 28 => 'FS',  29 => 'GS',
  30 => 'RS',  31 => 'US', 127 => 'DEL',
);

# The text of a rendered string without any ANSI sequence.
sub strip_ansi {
  my $rendered = shift;
  $rendered =~ s/\e\[[0-9;]*m//g;
  return $rendered;
}

# The colour codes a rendered string uses, reset codes are dropped. This pins
# the colour itself (bright red is ANSI 91) without depending on how a
# specific Term::ANSIColor version spells the reset sequence.
sub colour_codes {
  my $rendered = shift;
  my @codes;
  while ($rendered =~ /\e\[([0-9;]*)m/g) {
    for my $code (split(/;/, $1)) {
      next if $code eq '' || $code eq '0';
      push @codes, $code;
    }
  }
  return @codes;
}

# A character that carries the UTF-8 flag, like a string decoded from UTF-8.
sub wide {
  my $char = chr($_[0]);
  utf8::upgrade($char);
  return $char;
}

# Every byte from 0 to 127 renders exactly as it always did.
for my $byte (0..127) {
  my $control = exists $control_name{$byte};
  my $text = $control ? '['.$control_name{$byte}.']' : chr($byte);
  my $colour = $control ? $CONTROL : $PRINT;

  my $rendered = coloured(chr($byte));
  is(strip_ansi($rendered), $text, sprintf('byte %d (0x%02x) renders as %s',$byte,$byte,$text));
  is_deeply([colour_codes($rendered)], [$colour], sprintf('byte %d (0x%02x) is in ANSI colour %d',$byte,$byte,$colour));
}

# The delimiters are package variables, a caller may change them and the
# rendering reads them at call time.
{
  is_deeply(\@Data::Coloured::control_delimiter, ['[',']'], 'the control characters are surrounded by square brackets');
  is_deeply(\@Data::Coloured::binary_delimiter, ['<','>'], 'the binary characters are surrounded by angle brackets');
}

# The delimiters are read at call time, so a caller can change them.
{
  local @Data::Coloured::control_delimiter = ('{','}');
  local @Data::Coloured::binary_delimiter = ('(',')');
  is(strip_ansi(coloured("\x00")), '{NUL}', 'the control delimiter is used at call time');
  is(strip_ansi(coloured("\xff")), '(ff)', 'the binary delimiter is used at call time');
  is_deeply([colour_codes(coloured("\x00"))], [$CONTROL], 'the control character keeps its colour');
  is_deeply([colour_codes(coloured("\xff"))], [$BINARY], 'the binary character keeps its colour');
}

# A byte that is no valid text stays visible, it is not decoded.
{
  my $rendered = coloured("\xff");
  is(strip_ansi($rendered), '<ff>', 'an unflagged byte 0xff renders as <ff>');
  is_deeply([colour_codes($rendered)], [$BINARY], 'an unflagged byte 0xff is in ANSI colour '.$BINARY);
}

# A multi-byte character is rendered from its UTF-8 bytes and not from its
# code point.
{
  my $aumlaut = wide(0xe4);
  my $euro    = wide(0x20ac);
  ok(utf8::is_utf8($aumlaut), 'the test fixture carries the UTF-8 flag');
  ok(utf8::is_utf8($euro), 'the test fixture carries the UTF-8 flag');

  my $rendered = coloured($aumlaut);
  is(strip_ansi($rendered), '<c3a4>', 'U+00E4 renders as its UTF-8 bytes <c3a4>');
  is_deeply([colour_codes($rendered)], [$BINARY], 'U+00E4 is in ANSI colour '.$BINARY);

  $rendered = coloured($euro);
  is(strip_ansi($rendered), '<e282ac>', 'U+20AC renders as its UTF-8 bytes <e282ac>');
  is_deeply([colour_codes($rendered)], [$BINARY], 'U+20AC is in ANSI colour '.$BINARY);
}

# ASCII and multi-byte characters side by side.
{
  my $rendered = coloured('a'.wide(0xe4)."\x00".wide(0x20ac));
  is(strip_ansi($rendered), 'a<c3a4>[NUL]<e282ac>', 'ASCII, control and multi-byte characters render in order');
  is_deeply([colour_codes($rendered)], [$PRINT,$BINARY,$CONTROL,$BINARY], 'each character keeps its own colour');
}

# The UTF-8 flag does not change the rendering of ASCII.
{
  my $ascii = join('',map { chr($_) } 0..127);
  my $flagged = $ascii;
  utf8::upgrade($flagged);
  ok(utf8::is_utf8($flagged), 'the ASCII test fixture carries the UTF-8 flag');
  is(coloured($flagged), coloured($ascii), 'ASCII renders the same with and without the UTF-8 flag');
}

# The result stays ASCII, it is not encoded.
{
  my $rendered = coloured('a'.wide(0xe4).wide(0x20ac));
  like($rendered, qr/\A[\x00-\x7f]*\z/, 'the rendered result stays ASCII');
}

# A call with more than one argument renders every argument, in the order
# they were given.
{
  my $rendered = coloured('a','b');
  is(strip_ansi($rendered), 'ab', 'both arguments are rendered');
  is_deeply([colour_codes($rendered)], [$PRINT,$PRINT], 'both arguments keep their colour');
  is(coloured('a','b'), coloured('ab'), 'two arguments render like one argument with both');
}

# The unit is decided per argument. An unflagged argument is a byte stream
# even when a flagged argument with characters sits next to it.
{
  my $aumlaut = wide(0xe4);
  my $euro    = wide(0x20ac);

  my $rendered = coloured("\xff",$aumlaut);
  is(strip_ansi($rendered), '<ff><c3a4>', 'the byte stays <ff> and the character shows its UTF-8 bytes <c3a4>');
  is_deeply([colour_codes($rendered)], [$BINARY,$BINARY], 'the byte and the character keep their colour');

  $rendered = coloured("\xff",'a');
  is(strip_ansi($rendered), '<ff>a', 'an unflagged byte argument next to a printable argument');

  $rendered = coloured($aumlaut,$euro);
  is(strip_ansi($rendered), '<c3a4><e282ac>', 'two flagged arguments render their UTF-8 bytes');

  # The arguments are not joined into one string, a join would lift the
  # unflagged argument into the flagged one and read the byte 0xff as the
  # character U+00FF.
  isnt(coloured("\xff",$aumlaut), coloured("\xff".$aumlaut), 'the arguments are not joined into a single string');
}

done_testing;
