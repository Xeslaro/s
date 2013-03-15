#!/usr/bin/perl -w
use strict;
use http;
my $i = 0;
my %cookie;
sub int_handle {
	http::cookie_dump(\%cookie, "sa.cookie");
	exit 0;
}
$SIG{INT} = \&int_handle;
while ($i < @ARGV) {
	if ($ARGV[$i] eq "-c") {
		my @c = `cat $ARGV[++$i]`;
		http::chrome_cookie_extract(\%cookie, @c);
	} elsif ($ARGV[$i] eq "-f") {
		http::cookie_read(\%cookie, $ARGV[++$i]);
	}
	$i++;
}
while (1) {
	my @ans = http::http_get("/profiles/76561198077197678", "steamcommunity.com", 80, \%cookie);
	http::update_cookie(\%cookie, @ans);
	my $cnt;
	for (@ans) {
		$cnt = $1 if (/(\d+) new invites/);
	}
	unless (defined $cnt) {
		my $fh;
		open($fh, ">", "sa.error");
		print $fh $_ for (@ans);
		close($fh);
		die "cookie failed\n";
	}
	if ($cnt > 0) {
		my $dh;
		opendir($dh, "/home/Oralsex/v");
		my @fl;
		while (readdir $dh) {
			push @fl, $_ unless (/^\.{1,2}$/);
		}
		my $r = int(rand(@fl));
		qx|mplayer "/home/Oralsex/v/$fl[$r]" 1>&2|;
	}
	sleep 300;
}
