#!/usr/bin/env perl
use v5.10; use strict; use warnings; use autodie qw<:all>;
use IPC::System::Simple qw<runx capturex>;
use Env qw<DISPLAY>;

(my $dpy = $DISPLAY) =~ s/(:|\.)/_/g;
my $service = "com.github.chjj.compton.$dpy";
my $iface = 'com.github.chjj.compton';

sub dbus_req {
	my $verbose = shift;
	my $method = shift;
	my @needs_reply = $verbose ? qw<--print-reply> : ();

	qw<dbus-send --session>,
		@needs_reply, "--dest=$service", '/', "$iface.$method", @_;
}

runx dbus_req 0, 'opts_set', 'string:track_focus', 'boolean:true';
chomp(my @x = capturex dbus_req 1, 'find_win', 'string:focused');
my $cur_wnd = do {$x[1] =~ m/uint32\s+(\d+)/; $1};

chomp(my $is_inverted = do {
	$_ = capturex dbus_req 1, 'win_get',
		"uint32:$cur_wnd", 'string:invert_color_force';

	m/uint16\s+(\d+)/;
	($1 == 1) ? 1 : 0;
});

runx dbus_req 1, 'win_set', "uint32:$cur_wnd",
	'string:invert_color_force', 'uint16:'.($is_inverted ? 0 : 1);
