#!/usr/bin/env perl
use v5.10; use strict; use warnings; use autodie qw(:all);
die 'unexpected arguments count' if scalar(@ARGV) != 1;
use Env qw<HOME>;
use Cwd qw(abs_path);
use IPC::System::Simple qw<runx>;

my $__dirname = abs_path './';

if ($ARGV[0] eq 'create-symlink') {

  chdir "$HOME/.config/";
  runx 'ln', '-s', '--', "$__dirname/", 'i3';

} elsif ($ARGV[0] eq 'clean') {

  chdir "$HOME/.config/";
  unlink 'i3' if -l 'i3';

} else {
  die "unknown argument: '$ARGV[0]'";
}

# vim: et ts=2 sts=2 sw=2 cc=81 tw=80 :
