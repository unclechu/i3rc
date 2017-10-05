#!/usr/bin/env perl6
use v6.c;
$*IN.close;

my IO::Path $inv-app := $*PROGRAM.dirname.IO.child: 'invert-window-colors.pl';

my %mapping := {
	audacious   => @(:class('^Audacious$')),
	thunderbird => @(:class('^Thunderbird$')),
	gajim       => @(:class('^Gajim$')),
	nheko       => @(:class('^nheko$')),
	keepassx    => @(:class('^Keepassx$')),
	qbittorrent => @(:class('^qBittorrent$')),
	hexchat     => @(:class('^Hexchat$')),
	doublecmd   => @(:class('^Doublecmd$')),
	gmrun       => @(:class('^Gmrun$')),
};

my @search-pfx         := qw<xdotool search --onlyvisible --all>;
my @get-parent-wid-pfx := qw<xwininfo -int -children -id>;

my Int $root-wnd = sub {
	with run(:out, qw<xwininfo -int -root>).out {
		loop {
			my Str $x = .get;
			die "Root window id not found!" unless $x.defined;
			return $<wid>.Int if $x ~~ /'Window id:' \s+ $<wid>=\d+/;
		}
	}
}();

sub get-parent-wid(Int $wid) of Int {
	my @cmd = @get-parent-wid-pfx;
	@cmd.push: $wid;
	my Proc $proc = run :out, @cmd;

	loop {
		my Str $x = $proc.out.get;
		die "Parent window id for '$wid' not found!" unless $x.defined;
		return $<wid>.Int if $x ~~ /'Parent window id:' \s+ $<wid>=\d+/;
	}
}

sub invert-colors-for-app(Bool $off, Bool $reset, %filter) {
	my Str @cmd = @search-pfx;
	@cmd.push('--class').push(%filter<class>) if %filter<class>:exists;
	@cmd.push('--name').push(%filter<name>)   if %filter<name>:exists;
	my Channel $ch = Channel.new;
	my Proc::Async $proc = Proc::Async.new: |@cmd;
	my @jobs;

	my Promise $ch-reader = start {
		loop {
			with $ch.receive.Int {@jobs.push: start {get-parent-wid $_}}
			CATCH {when X::Channel::ReceiveOnClosed {last}}
		}
	};

	$proc.stdout.lines.tap(
		{$ch.send: $_},
		done => {$ch.close},
		quit => {$ch.close; die $_}
	);

	await Promise.allof($proc.start, $ch-reader, Promise.allof(@jobs));
	await Promise.allof(@jobs».result.grep({$_ != $root-wnd})».&{
		.say;
		start {
			run $inv-app, 'for', $_, '0' if $off || $reset;
			run $inv-app, 'for', $_, '1' unless $off;
		}
	});
}

sub MAIN(Bool :$off = False, Bool :$reset = False, |applications) {
	my %to-process;

	if applications.elems > 0 {
		for applications {
			die "Unknown '$_' application!" unless %mapping{$_}:exists;
			%to-process{$_} = %mapping{$_};
		}
	} else {
		%to-process = %mapping;
	}

	for %to-process.kv -> $app, @_ {
		"Handling '$app' application…".say;
		invert-colors-for-app $off, $reset, %($_) for @_;
	}
}
