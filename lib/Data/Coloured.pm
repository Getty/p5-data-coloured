package Data::Coloured;
# ABSTRACT: Visualize random ASCII data streams

use strict;
use warnings;
use Exporter 'import';
use Term::ANSIColor qw( colored );

our $VERSION = '0.004';

our @EXPORT_OK = qw( pc c );
our @EXPORT = qw( coloured poloured );

our %control = (qw(
    0 NUL
    1 SOH
    2 STX
    3 ETX
    4 EOT
    5 ENQ
    6 ACK
    7 BEL
    8 BS
    9 TAB
   10 LF
   11 VT
   12 FF
   13 CR
   14 SO
   15 SI 
   16 DLE
   17 DC1
   18 DC2
   19 DC3
   20 DC4
   21 NAK
   22 SYN
   23 ETB
   24 CAN
   25 EM
   26 SUB
   27 ESC
   28 FS
   29 GS
   30 RS
   31 US
  127 DEL
));

our %colours = (qw(
  control bright_red
  print   bright_yellow
  binary  bright_cyan
));

our @control_delimiter = qw( [ ] );
our @binary_delimiter = qw( < > );

sub poloured {
  print coloured(@_);
}
sub pc { poloured(@_) }

sub coloured {
  my $output = "";
  # Every argument is rendered on its own and the parts are put together in
  # the order the arguments were given. The arguments are deliberately not
  # joined: a join lifts an argument without the UTF-8 flag into a string
  # with the flag and would read its bytes as characters.
  for my $data (@_) {
    # The flag decides the unit of the rendering. A string that carries the
    # UTF-8 flag is read as characters, a string without it as bytes.
    my $is_utf8 = utf8::is_utf8($data) ? 1 : 0;
    for my $char (split(//,$data)) {
      my $chr = ord($char);
      if (defined $control{$chr}) {
        $output .= colored($control_delimiter[0].$control{$chr}.$control_delimiter[1],$colours{control});
      } elsif ($char =~ /[ -~]/) {
        $output .= colored($char,$colours{print});
      } else {
        my $hex = $is_utf8 ? _utf8_hex($char) : unpack('H*',$char);
        $output .= colored($binary_delimiter[0].$hex.$binary_delimiter[1], $colours{binary});
      }
    }
  }
  return $output;
}
sub c { coloured(@_) }

# The hex representation of a character of a string that carries the UTF-8
# flag. The character is encoded to its UTF-8 bytes first, so a multi-byte
# character shows the bytes the stream really contained and not its code
# point.
sub _utf8_hex {
  my $bytes = $_[0];
  utf8::upgrade($bytes);
  utf8::encode($bytes);
  return unpack('H*',$bytes);
}

1;


=head1 SYNOPSIS

  use DDC;

  my $coloured = coloured($data);
  my $coloured = c($data);
  poloured($data); # print coloured
  pc($data);       # same

  use Data::Coloured; # no auto export of pc and c

=head1 DESCRIPTION

This module is made for visualizing in coloured and printable form random bytes
of a data stream or any other source. It was specifically made for debugging
TCP and UART connections, to also see the control characters.

This module does the following with the data for return or print:

=over

=item Control characters

The ASCII control characters are described on L<Wikipedia|http://en.wikipedia.org/wiki/ASCII#ASCII_control_code_chart>.
Those get replaced with their name listed in "Abbreviation" on the Wikipedia
page, surrounded by square brackets (exception is here B<HT> which is shown as
B<TAB>). The ANSI colour is B<bright_red>

=item Printable characters

The prinatable characters (from space to ~) are just taken as is, and put in
the colour B<bright_yellow>.

=item Binary characters / extended ASCII

All non printable characters, so those above 127, are converted into their hex
value and surrounded by angle brackets.

Every argument is read on its own: an argument that carries the UTF-8 flag
is read as characters, an argument without the flag is read as bytes. A
multi-byte character of such a string is converted into the hex value of its
UTF-8 bytes, so the character U+00E4 shows up as B<<c3a4>> and not as
B<<e4>>. Every single byte of a string without the flag is shown on its own,
so B<0xff> stays B<<ff>>. The arguments are rendered one after another, in
the order they were given, so a call with more than one argument shows all
of them.

=back

=func coloured

    my $coloured = coloured($data);

Returns the data rendered as coloured text. Every argument is rendered on its
own and the parts are returned in the order the arguments were given.

=func poloured

    poloured($data);

Prints the data rendered as coloured text. Same rendering as L</coloured>, but
to STDOUT instead of returning it.

=func pc

    pc($data);

Short alias for L</poloured>. This module exports it only on request.

=func c

    my $coloured = c($data);

Short alias for L</coloured>. This module exports it only on request.
