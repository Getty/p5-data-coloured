package DDC;
# ABSTRACT: Visualize random bytes

use strict;
use warnings;
use Data::Coloured qw( pc c coloured poloured );
use Exporter 'import';

our @EXPORT = qw( pc c coloured poloured );

1;

=head1 DESCRIPTION

See L<Data::Coloured>

DDC is an alias module for it. It exports the four functions C<coloured>,
C<poloured>, C<c> and C<pc> under the same names, so that a script which
wants only the visualiser needs a single import.

=head1 SUPPORT

IRC

  Join #vonbienenstock on irc.freenode.net. Highlight Getty for fast reaction :).

Repository

  http://github.com/Getty/p5-data-coloured
  Pull request and additional contributors are welcome

Issue Tracker

  http://github.com/Getty/p5-data-coloured/issues
