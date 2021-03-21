#! /usr/bin/env perl
# Author: Viacheslav Lotsmanov
# License: MIT https://raw.githubusercontent.com/unclechu/i3rc/master/LICENSE-MIT
use v5.10; use strict; use warnings; use autodie qw<:all>;
use Env qw<DISPLAY>;
use IPC::System::Simple qw<runx capturex>;
use Net::DBus qw<dbus_boolean dbus_string dbus_uint16 dbus_uint32>;

my $ARGC = scalar @ARGV;
(my $dpy = $DISPLAY) =~ s/(:|\.)/_/g;
my $conn = Net::DBus->find->get_connection;

sub dbus_req {
	my $call = $conn->make_method_call_message(
		"com.github.chjj.compton.$dpy",
		'/',
		'com.github.chjj.compton',
		shift
	);

	$call->append_args_list(@_);
	$conn->send_with_reply_and_block($call, 1000 * 5)->iterator;
}

sub set_it {
	my $wnd = defined($_[0]) ? $_[0] :
		dbus_req('find_win', dbus_string('focused'))->get_uint32;

	my $to = defined($_[1]) ? $_[1] : (
		dbus_req(
			'win_get', dbus_uint32($wnd), dbus_string('invert_color_force')
		)->get_uint16 == 1 ? 0 : 1
	);

	dbus_req
		'win_set',
		dbus_uint32($wnd),
		dbus_string('invert_color_force'),
		dbus_uint16($to);
}

dbus_req 'opts_set', dbus_string('track_focus'), dbus_boolean(1);

if ($ARGC == 0) {
	# toggle inverting colors
	set_it undef, undef;
} elsif ($ARGC == 1 && $ARGV[0] =~ m/^(0|1)$/) {
	# set inverting colors state explicitly
	set_it undef, $ARGV[0];
} elsif ($ARGC == 2 && $ARGV[0] eq 'for' && $ARGV[1] =~ m/^[0-9]+$/) {
	# toggle inverting colors for specific window
	set_it $ARGV[1], undef;
} elsif (
	$ARGC == 3
	&& $ARGV[0] eq 'for'
	&& $ARGV[1] =~ m/^[0-9]+$/
	&& $ARGV[2] =~ m/^(0|1)$/
) {
	# set inverting colors state explicitly for specific window
	set_it $ARGV[1], $ARGV[2];
} else {
	die 'Incorrect arguments: [' . join(', ', @ARGV) . ']';
}
