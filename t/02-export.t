#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Data::Coloured;
# DDC is loaded without an import list, so it hands nothing to this file:
# the probes below do their own importing in throw-away packages, and the
# functions this file uses itself are the ones of Data::Coloured.
use DDC ();

# The export contract has two tiers and the asymmetry between them is
# deliberate: Data::Coloured always exports coloured and poloured and hands
# out the short aliases pc and c only when they are asked for, while DDC
# re-exports all four functions without an import list.
#
# Every tier is probed in a throw-away package of its own, so that a case
# never depends on the use lines of this file.

# The four functions of the contract.
my @FUNCTIONS = qw( coloured poloured pc c );

# The probe, run inside the throw-away package. It reports for every
# function of the contract whether the caller got it at all and whether it
# works there.
my $PROBE = <<'PROBE';
sub probe {
  # The probe calls the functions of the package it runs in by name, and a
  # name that was not imported must not blow up while it is looked up.
  no strict 'refs';
  my %seen;
  for my $name (qw( coloured poloured pc c )) {
    my $full = __PACKAGE__.'::'.$name;
    unless (defined &{$full}) {
      $seen{$name} = { defined => 0, works => 0 };
      next;
    }
    $seen{$name} = { defined => 1 };
    my $function = \&{$full};
    # The alias module must hand out the functions of Data::Coloured
    # themselves, not copies of its own.
    $seen{$name}{same} = $function == \&{"Data::Coloured::$name"} ? 1 : 0;
    if ($name eq 'coloured' or $name eq 'c') {
      my $text = eval { $function->('a') };
      $seen{$name}{works} = defined $text ? 1 : 0;
      $seen{$name}{returns} = $text;
    } else {
      my $buffer = '';
      open my $fh, '>', \$buffer or die "cannot open an in-memory file: $!";
      my $worked = eval { { local *STDOUT = $fh; $function->('a'); } 1 };
      $seen{$name}{works} = $worked ? 1 : 0;
      $seen{$name}{prints} = $buffer;
    }
  }
  return \%seen;
}
PROBE

# Imports the given module into a throw-away package and reports what the
# package received.
sub import_into {
  my ($package, $statement) = @_;
  my $code = "package $package;\n$statement\n".$PROBE."\nprobe();\n";
  my $result = eval $code;
  die "cannot probe $package: $@" if not $result;
  return $result;
}

# Checks that the package got exactly the expected functions, that every
# function it got works and that it got none of the others.
sub check_exports {
  my ($label, $seen, @expected) = @_;
  for my $name (@FUNCTIONS) {
    if (grep { $_ eq $name } @expected) {
      ok($seen->{$name}{defined}, "$label gives the caller $name");
      ok($seen->{$name}{works}, "$label gives the caller a working $name");
    } else {
      ok(!$seen->{$name}{defined}, "$label does not give the caller $name");
    }
  }
}

# The tiers themselves.
is_deeply(\@Data::Coloured::EXPORT, [qw( coloured poloured )], 'Data::Coloured always exports coloured and poloured');
is_deeply(\@Data::Coloured::EXPORT_OK, [qw( pc c )], 'Data::Coloured exports pc and c on request');
is_deeply(\@DDC::EXPORT, [qw( pc c coloured poloured )], 'DDC re-exports all four functions');

# The first tier: coloured and poloured are always there, the short aliases
# are not.
{
  my $seen = import_into('Probe::Default', 'use Data::Coloured;');
  check_exports('use Data::Coloured', $seen, qw( coloured poloured ));
}

# The second tier: an import list hands out exactly the functions it names
# and nothing else.
{
  my $seen = import_into('Probe::Short', 'use Data::Coloured qw( pc c );');
  check_exports('use Data::Coloured qw( pc c )', $seen, qw( pc c ));
}

# The alias module hands out all four functions without an import list.
{
  my $seen = import_into('Probe::DDC', 'use DDC;');
  check_exports('use DDC', $seen, qw( coloured poloured pc c ));

  # DDC's @EXPORT names all four functions, so DDC has to import all four
  # from Data::Coloured. It imported only pc and c, so the two missing
  # names were not defined at all: a call died with "Undefined subroutine
  # &DDC::coloured called" instead of returning anything.
  for my $name (qw( coloured poloured pc c )) {
    ok($seen->{$name}{same}, "use DDC gives the caller the $name of Data::Coloured");
  }
}

# The short aliases do the same as the functions they alias.
{
  my $text = coloured('a');
  my $printed = '';
  open my $fh, '>', \$printed or die "cannot open an in-memory file: $!";
  { local *STDOUT = $fh; poloured('a'); }

  my $short = import_into('Probe::Alias', 'use Data::Coloured qw( pc c );');
  is($short->{c}{returns}, $text, 'c returns what coloured returns');
  is($short->{pc}{prints}, $printed, 'pc prints what poloured prints');

  my $ddc = import_into('Probe::DDCAlias', 'use DDC;');
  is($ddc->{c}{returns}, $text, 'DDC re-exports c as the same function');
  is($ddc->{pc}{prints}, $printed, 'DDC re-exports pc as the same function');
}

done_testing;
