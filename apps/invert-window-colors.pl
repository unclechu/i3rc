#!/usr/bin/env perl
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
	my $to;
	my $cur_wnd = dbus_req('find_win', dbus_string('focused'))->get_uint32;

	if (scalar(@_) > 0) {
		$to = shift;
	} else {
		$to = dbus_req(
			'win_get', dbus_uint32($cur_wnd), dbus_string('invert_color_force')
		)->get_uint16 == 1 ? 0 : 1;
	}

	dbus_req
		'win_set',
		dbus_uint32($cur_wnd),
		dbus_string('invert_color_force'),
		dbus_uint16($to);
}

dbus_req 'opts_set', dbus_string('track_focus'), dbus_boolean(1);

if ($ARGC == 0) {
	# toggle inverting colors
	set_it;
} elsif ($ARGC == 1 && ($ARGV[0] eq '0' || $ARGV[0] eq '1')) {
	# set inverting colors state explicitly
	set_it $ARGV[0];
} else {
	die q(Incorrect arguments: [) . join(', ', @ARGV) . q(]);
}
