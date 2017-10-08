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

  chdir "$__dirname/apps/invert-window-colors/";
  unlink 'main' if -f 'main' ;

} elsif ($ARGV[0] eq 'build-invert-window-colors') {

  chdir "$__dirname/apps/invert-window-colors";
  runx qw(nimble install -y);
  runx qw(nim c -o:invert-window-colors main.nim);

} elsif ($ARGV[0] eq 'clean-invert-window-colors') {

  chdir "$__dirname/apps/invert-window-colors/";
  unlink 'main' if -f 'main' ;
  unlink 'invert-window-colors' if -f 'invert-window-colors' ;
  runx qw(rm -rf nimcache) if -d 'nimcache';

} else {
  die "unknown argument: '$ARGV[0]'";
}

# vim: et ts=2 sts=2 sw=2 cc=81 tw=80 :
