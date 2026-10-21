#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Cwd qw( abs_path );
use File::Basename qw( dirname );
use File::Spec;
use File::Temp qw( tempdir );
use IPC::Open3;
use Symbol qw( gensym );

# The command line of the script: the usage goes to STDOUT and exits with 0,
# every error goes to STDERR and exits with a code that is not 0. A Perl
# backtrace on STDERR is a failure.

my $root = dirname(dirname(abs_path(__FILE__)));
my $script = File::Spec->catfile($root, 'bin', 'ddc');
my $lib = File::Spec->catdir($root, 'lib');

ok(-f $script, 'the script is there');

# Runs the script with the given arguments, returns the exit code, the
# output on STDOUT and the output on STDERR.
sub run_ddc {
  my (@arguments) = @_;
  my $stdin = gensym;
  my $stdout = gensym;
  my $stderr = gensym;
  my $pid = open3($stdin, $stdout, $stderr, $^X, '-I'.$lib, $script, @arguments);
  close $stdin;
  my $out = do { local $/; <$stdout> };
  my $err = do { local $/; <$stderr> };
  waitpid($pid, 0);
  return ($? >> 8, defined $out ? $out : '', defined $err ? $err : '');
}

# The same, but with a standard input that is closed before the script
# starts. The shell does this with "ddc <&-".
sub run_ddc_with_closed_stdin {
  my (@arguments) = @_;
  my $stdin = gensym;
  my $stdout = gensym;
  my $stderr = gensym;
  my $pid = open3($stdin, $stdout, $stderr, $^X, '-e', 'close(STDIN); exec { $ARGV[0] } @ARGV', $^X, '-I'.$lib, $script, @arguments);
  close $stdin;
  my $out = do { local $/; <$stdout> };
  my $err = do { local $/; <$stderr> };
  waitpid($pid, 0);
  return ($? >> 8, defined $out ? $out : '', defined $err ? $err : '');
}

# A Perl backtrace looks like "at /path/to/file line 12." and starts with
# the file name of the program.
sub has_backtrace {
  my $error = shift;
  return $error =~ /\bat \S+ line \d+/ ? 1 : 0;
}

# The help goes to STDOUT and exits with 0.
for my $option ('--help', '-h') {
  my ($status, $out, $err) = run_ddc($option);
  is($status, 0, "$option exits with 0");
  like($out, qr/Usage: ddc/, "$option prints the usage on STDOUT");
  like($out, qr/coloured dump/, "$option tells what the script does");
  like($out, qr/\[FILE\]/, "$option tells how the script is called");
  is($err, '', "$option writes nothing to STDERR");
}

# The help is accepted in any position, also behind a file name.
{
  my $dir = tempdir(CLEANUP => 1);
  my $file = File::Spec->catfile($dir, 'data');
  open my $fh, '>', $file or die "cannot write $file: $!";
  print $fh "x\n";
  close $fh;

  my ($status, $out, $err) = run_ddc($file, '--help');
  is($status, 0, 'a file name behind the help exits with 0');
  like($out, qr/Usage: ddc/, 'a file name behind the help prints the usage on STDOUT');
  is($err, '', 'a file name behind the help writes nothing to STDERR');
}

# An unknown option is an error on STDERR.
{
  my ($status, $out, $err) = run_ddc('--bogus');
  isnt($status, 0, 'an unknown option exits with a code that is not 0');
  is($out, '', 'an unknown option writes nothing to STDOUT');
  like($err, qr/unknown option/, 'an unknown option is reported on STDERR');
  like($err, qr/--bogus/, 'the unknown option is named on STDERR');
  unlike($err, qr/readline\(\) on closed filehandle/, 'the error is no Perl error');
  is(has_backtrace($err), 0, 'the error carries no Perl backtrace');
}

# A missing file is an error on STDERR.
{
  my $missing = File::Spec->catfile(File::Spec->tmpdir, 'ddc-does-not-exist-'.$$);
  my ($status, $out, $err) = run_ddc($missing);
  isnt($status, 0, 'a missing file exits with a code that is not 0');
  is($out, '', 'a missing file writes nothing to STDOUT');
  like($err, qr/\Q$missing\E/, 'the missing file is named on STDERR');
  unlike($err, qr/Can't open/, 'the error is no Perl error');
  is(has_backtrace($err), 0, 'the error carries no Perl backtrace');
}

# A closed standard input is an error on STDERR and not the raw Perl error.
{
  my ($status, $out, $err) = run_ddc_with_closed_stdin();
  isnt($status, 0, 'a closed standard input exits with a code that is not 0');
  is($out, '', 'a closed standard input writes nothing to STDOUT');
  like($err, qr/standard input/, 'a closed standard input is reported on STDERR');
  unlike($err, qr/readline\(\) on closed filehandle/, 'the error is no Perl error');
  is(has_backtrace($err), 0, 'the error carries no Perl backtrace');
}

# A successful run exits with 0 and colours the data.
{
  my $dir = tempdir(CLEANUP => 1);
  my $file = File::Spec->catfile($dir, 'data');
  open my $fh, '>', $file or die "cannot write $file: $!";
  print $fh "a\n";
  close $fh;

  my ($status, $out, $err) = run_ddc($file);
  is($status, 0, 'a successful run exits with 0');
  is($err, '', 'a successful run writes nothing to STDERR');
  like($out, qr/\e\[93ma\e\[0m/, 'the printable character is in bright yellow');
  like($out, qr/\e\[91m\[LF\]\e\[0m/, 'the line feed is in bright red');
}

done_testing;
